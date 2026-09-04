#requires -Version 7.0
<#
.SYNOPSIS
    Regenerates the committed examples under examples/.
.DESCRIPTION
    Run from the repository root. Every example in examples/README.md names the
    exact invocation that rebuilds it, and this script is what those commands
    call.

    Settings reach PSGraphRender only through a template-set DIRECTORY - there
    is no -Setting parameter on New-RenderDocument, by design. So each variant
    here materialises a caller-owned OVERLAY of the shipped cytoscape set in a
    temporary directory, edits the one data file it needs, and hands the
    directory over with -TemplateSetPath. That is the seam the module documents
    for a backend that does not ship with it, and it means generating an
    example never edits the renderer.

    The overlay is temporary and is removed afterwards, so nothing committed
    carries a path from the machine that generated it.
.PARAMETER Only
    Build one example instead of all of them.
.PARAMETER OutputRoot
    Where the examples tree lives. Defaults to examples/ beside this script.
.EXAMPLE
    pwsh -NoProfile -File examples/Build-Examples.ps1

    Rebuilds every example.
.EXAMPLE
    pwsh -NoProfile -File examples/Build-Examples.ps1 -Only callflow

    Rebuilds examples/layouts/callflow.html and nothing else.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('all', 'foundation', 'testorder', 'callflow', 'default', 'contrast', 'links', 'forge')]
    [string] $Only = 'all',

    [Parameter()]
    [string] $OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$examplesRoot = if ($OutputRoot) { $OutputRoot } else { $PSScriptRoot }
$repoRoot = Split-Path -Parent $examplesRoot
$inputRoot = Join-Path $examplesRoot 'input'

# -- import the module, built output first, source second --------------------
$built = Join-Path $repoRoot 'output/PSGraphRender/PSGraphRender.psd1'
$source = Join-Path $repoRoot 'src/PSGraphRender/PSGraphRender.psd1'
$manifest = if (Test-Path -LiteralPath $built) { $built } else { $source }
if (-not (Test-Path -LiteralPath $manifest)) {
    throw "No PSGraphRender manifest found. Looked for '$built' and '$source'. Run ./build.ps1 first."
}
Import-Module -Name $manifest -Force -ErrorAction Stop
$module = Get-Module -Name PSGraphRender
Write-Host "PSGraphRender $($module.Version) from $($module.Path)"

$shippedSet = Join-Path (Split-Path -Parent $module.Path) 'TemplateSets/cytoscape'
if (-not (Test-Path -LiteralPath $shippedSet)) {
    throw "PSGraphRender $($module.Version) ships no cytoscape template set. Looked in '$shippedSet'."
}

# -- overlay helpers ---------------------------------------------------------
function New-Overlay {
    <#
        A caller-owned copy of the shipped backend. Returns its path.
    #>
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('psgraphrender-example-' + [guid]::NewGuid().ToString('n'))
    Copy-Item -LiteralPath $shippedSet -Destination $dir -Recurse -Force
    return $dir
}

function Set-OverlayFlow {
    param([string] $OverlayPath, [string] $Flow)

    # Replace the value in place rather than writing a minimal file: a minimal
    # settings.psd1 would silently reset every other setting to its schema
    # default, which is the same thing today and would stop being the same
    # thing the moment a shipped value diverges from its default.
    $file = Join-Path $OverlayPath 'Config/settings.psd1'
    $text = [System.IO.File]::ReadAllText($file)
    $pattern = "(?m)^(\s*DefaultFlow\s*=\s*)'[^']*'"

    # Assert the LINE EXISTS rather than that the text changed. Setting
    # foundation over foundation is a legitimate no-op, and a guard that treats
    # "unchanged" as "not found" fails the one variant whose value already
    # matches - which is exactly what it did the first time this ran.
    if ($text -notmatch $pattern) {
        throw "Could not set DefaultFlow in '$file' - the settings file has no DefaultFlow line to replace."
    }
    [System.IO.File]::WriteAllText($file, ($text -replace $pattern, ('${1}''' + $Flow + '''')))
}

function Set-OverlayLinkMode {
    param([string] $OverlayPath, [string] $Mode, [string] $Template)

    # Same in-place replacement as Set-OverlayFlow, and for the same reason: a
    # minimal settings.psd1 would reset every other setting to its schema
    # default. Both keys are shipped values, so both lines exist to replace -
    # asserted rather than assumed, because a silent no-op here would render the
    # DEFAULT mode and look like the feature is missing.
    $file = Join-Path $OverlayPath 'Config/settings.psd1'
    $text = [System.IO.File]::ReadAllText($file)

    foreach ($pair in @(@{ Key = 'LinkMode'; Value = $Mode }, @{ Key = 'LinkHrefTemplate'; Value = $Template })) {
        if ($null -eq $pair.Value) { continue }
        $pattern = "(?m)^(\s*$($pair.Key)\s*=\s*)'[^']*'"
        if ($text -notmatch $pattern) {
            throw "Could not set $($pair.Key) in '$file' - the settings file has no $($pair.Key) line to replace."
        }
        $text = $text -replace $pattern, ('${1}''' + $pair.Value + '''')
    }
    [System.IO.File]::WriteAllText($file, $text)
}

function Set-OverlayTheme {
    param([string] $OverlayPath, [string] $ThemeFile)

    Copy-Item -LiteralPath $ThemeFile -Destination (Join-Path $OverlayPath 'Config/theme.psd1') -Force
}

function Invoke-Render {
    param(
        [string] $InputFile,
        [string] $OutputFile,
        [string] $Flow,
        [string] $ThemeFile,
        [string] $LinkMode,
        [string] $LinkHrefTemplate,
        [string] $Title
    )

    $payload = Get-Content -LiteralPath $InputFile -Raw | ConvertFrom-Json
    $overlay = New-Overlay
    try {
        if ($Flow) { Set-OverlayFlow -OverlayPath $overlay -Flow $Flow }
        if ($ThemeFile) { Set-OverlayTheme -OverlayPath $overlay -ThemeFile $ThemeFile }
        if ($LinkMode) { Set-OverlayLinkMode -OverlayPath $overlay -Mode $LinkMode -Template $LinkHrefTemplate }

        $document = New-RenderDocument `
            -ViewModel $payload.data `
            -Meta $payload.meta `
            -Title $(if ($Title) { $Title } else { $payload.meta.title }) `
            -TemplateSetPath $overlay

        $dir = Split-Path -Parent $OutputFile
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }

        # UTF8 without BOM, LF-normalised by .gitattributes on the way in.
        [System.IO.File]::WriteAllText($OutputFile, $document, [System.Text.UTF8Encoding]::new($false))
        Write-Host ("  wrote {0} ({1:N0} bytes)" -f (Resolve-Path -Relative $OutputFile), (Get-Item $OutputFile).Length)
    }
    finally {
        Remove-Item -LiteralPath $overlay -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# -- the matrix --------------------------------------------------------------
$ecosystem = Join-Path $inputRoot 'ecosystem-viewmodel.json'
$linksInput = Join-Path $inputRoot 'links-viewmodel.json'
$contrastTheme = Join-Path $inputRoot 'theme-contrast.psd1'

$builds = @(
    @{ Name = 'foundation'; Input = $ecosystem; Out = 'layouts/foundation.html'; Flow = 'foundation' }
    @{ Name = 'testorder'; Input = $ecosystem; Out = 'layouts/testorder.html'; Flow = 'testorder' }
    @{ Name = 'callflow'; Input = $ecosystem; Out = 'layouts/callflow.html'; Flow = 'callflow' }
    @{ Name = 'default'; Input = $ecosystem; Out = 'theme/default.html'; Flow = 'foundation' }
    @{ Name = 'contrast'; Input = $ecosystem; Out = 'theme/contrast.html'; Flow = 'foundation'; Theme = $contrastTheme }
    @{ Name = 'links'; Input = $linksInput; Out = 'links/editor-links.html'; Flow = 'callflow'
        LinkMode = 'editor'
        Title = 'Node links - editor mode, opening a node in your own editor'
    }
    # The same payload, the same layout, one setting different - and links that
    # actually go somewhere from a committed file. hrefTemplate never reads
    # meta.rootPath, so the placeholder in the input stays put and no machine
    # path is baked in: the URL is built from each node's own relative path.
    @{ Name = 'forge'; Input = $linksInput; Out = 'links/forge-links.html'; Flow = 'callflow'
        LinkMode = 'hrefTemplate'
        LinkHrefTemplate = 'https://github.com/JerryBalmer1/PSGraphRender/blob/main/{relativePath}#L{line}'
        Title = 'Node links - hrefTemplate mode, opening a node on GitHub'
    }
)

foreach ($b in $builds) {
    if ($Only -ne 'all' -and $Only -ne $b.Name) { continue }
    Write-Host "building $($b.Name)"
    Invoke-Render `
        -InputFile $b.Input `
        -OutputFile (Join-Path $examplesRoot $b.Out) `
        -Flow $b.Flow `
        -ThemeFile $(if ($b.ContainsKey('Theme')) { $b.Theme } else { $null }) `
        -LinkMode $(if ($b.ContainsKey('LinkMode')) { $b.LinkMode } else { $null }) `
        -LinkHrefTemplate $(if ($b.ContainsKey('LinkHrefTemplate')) { $b.LinkHrefTemplate } else { $null }) `
        -Title $(if ($b.ContainsKey('Title')) { $b.Title } else { $null })
}

Write-Host 'done.'
