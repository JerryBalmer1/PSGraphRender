function Get-RenderTemplateSet {
    <#
    .SYNOPSIS
        Assembles a template set into a single document with slots substituted.
    .DESCRIPTION
        See docs/render-architecture.md. Knows nothing about what the document
        describes.
    .PARAMETER Path
        Directory holding templateset.psd1 and the files it names. A caller
        supplying its own directory is what makes the renderer reusable, so this
        parameter existed before there was a second backend.
    .PARAMETER Name
        A backend shipped with the module, by directory name. Defaults to
        whatever TemplateSets/index.psd1 names. Ignored when -Path is given.
    .PARAMETER SetName
        Manifest file name within Path.
    .PARAMETER Configuration
        Resolved settings, for a manifest whose SlotsBySetting makes some slots
        depend on a setting's value. Omit and it is resolved from Path, which is
        what makes a bare Get-RenderTemplateSet still assemble a working
        document; New-RenderDocument passes the configuration it already has so
        the files are not read and validated twice.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string] $Path,

        [Parameter()]
        [string] $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $SetName = 'templateset.psd1',

        [Parameter()]
        $Configuration
    )

    # Where a backend lives is Resolve-RenderTemplateSetPath's answer and
    # nobody else's. See the comment there for what three copies of it cost.
    if (-not $Path) { $Path = Resolve-RenderTemplateSetPath -Name $Name }

    $manifestPath = Join-Path $Path $SetName
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Template set manifest not found at '$manifestPath'."
    }

    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop
    $layoutName = Get-HashtableValue -InputObject $manifest -Key 'Layout'
    if (-not $layoutName) {
        throw "Template set '$manifestPath' declares no Layout."
    }
    $slots = Get-HashtableValue -InputObject $manifest -Key 'Slots' -Default @{}

    # Slots a SETTING chooses between. A backend declaring none of these is
    # unaffected and never pays for the feature - `plain` has no SlotsBySetting
    # and this block does nothing for it.
    #
    # Resolved here, at assembly, rather than by the page at load: it is what
    # lets a mode be absent from the document instead of merely unused by it.
    # See SlotsBySetting in the cytoscape templateset.psd1 for why that
    # distinction is the whole point.
    $bySetting = Get-HashtableValue -InputObject $manifest -Key 'SlotsBySetting' -Default @{}
    if ($bySetting.Keys.Count) {
        if ($null -eq $Configuration) {
            $Configuration = Resolve-RenderConfiguration -TemplateSetPath $Path
        }

        foreach ($settingName in @($bySetting.Keys)) {
            $choices = $bySetting[$settingName]
            $value = $Configuration[$settingName]

            # A value with no entry is not silently ignored. The schema validates
            # the setting, so reaching here means the manifest declares a value
            # it has no files for - which would otherwise ship a document with
            # the default mode's code under a different mode's name.
            if ($null -eq $value -or -not $choices.Contains([string]$value)) {
                throw ("Template set '$manifestPath' has no SlotsBySetting entry for $settingName = " +
                    "'$value'. It declares: " + (@($choices.Keys | Sort-Object) -join ', ') + '.')
            }

            $chosen = $choices[[string]$value]
            foreach ($slot in @($chosen.Keys)) { $slots[$slot] = $chosen[$slot] }
        }
    }

    function Read-Part {
        param([string] $Root, [string] $Relative)

        $full = Join-Path $Root $Relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "Template part '$Relative' not found at '$full'."
        }
        # Verbatim. A part must not end with a trailing newline: the slot
        # marker's own newline supplies it. Stripping one here instead would be
        # indistinguishable from a part whose last line is deliberately blank,
        # and ten of them are.
        [System.IO.File]::ReadAllText($full)
    }

    $document = Read-Part -Root $Path -Relative $layoutName

    # Slots may nest, so repeat until none resolve. The cap is a runaway guard:
    # a slot whose partial contains itself would otherwise loop forever.
    for ($pass = 0; $pass -lt 20; $pass++) {
        $substituted = $false

        foreach ($slot in @($slots.Keys)) {
            # Two marker forms so each part stays valid in its own language: an
            # HTML comment in markup, a block comment in CSS and JavaScript.
            foreach ($token in "<!--__SLOT_$($slot)__-->", "/*__SLOT_$($slot)__*/") {
                if ($document.Contains($token)) {
                    $parts = @($slots[$slot] | ForEach-Object { Read-Part -Root $Path -Relative $_ })
                    # [string]::Replace, never -replace: the parts contain '$'
                    # and '\', which the regex engine would eat.
                    $document = $document.Replace($token, ($parts -join "`n"))
                    $substituted = $true
                }
            }
        }

        if (-not $substituted) { break }
    }

    $unresolved = [regex]::Matches($document, '__SLOT_[A-Z0-9_]+__') |
        ForEach-Object { $_.Value } |
        Select-Object -Unique
    if ($unresolved) {
        throw ("Template set '$manifestPath' left slots unresolved: " + ($unresolved -join ', ') + '.')
    }

    $document
}
