#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# What a node link is allowed to be. Before this suite a link could only ever be
# an editor scheme: vsCodeUriFor hardcoded vscode://file/ and NODE_ACTIONS bound
# to it, with no configuration naming an alternative. Link mode is declared
# configuration now, and these are the three behaviours it declares.
#
# The mode is resolved at ASSEMBLY, not in the browser. A none-mode document
# contains no scheme construction at all rather than carrying it inert behind a
# runtime branch - which is what "the action absent, not stubbed" has to mean for
# a renderer whose whole output is one self-contained file somebody may forward.
#
# What a click actually navigates to is a DOM fact and is not asserted here.
# tests/browser/link-mode.cjs does that, in a real browser, because a string in
# a document is not a link until something resolves it.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Same rule as Render.FromViewModel.Tests.ps1: no producer is imported here
    # and none may be. The payload is JSON on disk.
    Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue

    Import-PSGraphRenderUnderTest

    $script:RepoRootDir = Split-Path $PSScriptRoot -Parent
    $script:ShippedSet = Join-Path $script:RepoRootDir 'src/PSGraphRender/TemplateSets/cytoscape'
    $script:SchemaPath = Join-Path $script:ShippedSet 'Config/settings.schema.psd1'

    $script:ViewModel = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'sample-module.json') -Raw |
        ConvertFrom-Json

    $script:Scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-linkmode-$PID"
    New-Item -ItemType Directory -Path $script:Scratch -Force | Out-Null

    # A template set configured however a case needs it. A COPY of the shipped
    # set, never an edit in place: a suite that rewrites src/ to make its own
    # assertion pass has stopped testing the thing that ships.
    #
    # Settings are written as data, the same way a caller sets any other
    # setting - there is no test-only mechanism here, which is the point.
    function New-ConfiguredTemplateSet {
        param(
            [Parameter(Mandatory)] [string] $Name,
            [Parameter()] [hashtable] $Setting = @{}
        )

        $source = Join-Path (Get-BuiltModuleRoot) 'TemplateSets/cytoscape'
        if (-not (Test-Path -LiteralPath $source)) { $source = $script:ShippedSet }

        $dest = Join-Path $script:Scratch $Name
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Copy-Item -LiteralPath $source -Destination $dest -Recurse -Force

        if ($Setting.Count) {
            $settingsFile = Join-Path $dest 'Config/settings.psd1'
            $text = [System.IO.File]::ReadAllText($settingsFile)

            foreach ($key in ($Setting.Keys | Sort-Object)) {
                $value = $Setting[$key]
                $assignment = if ($value -is [string]) { "    $key = '$($value.Replace("'", "''"))'" }
                else { "    $key = $value" }

                # REPLACE a shipped key, append only a new one. Appending
                # unconditionally produces a duplicate hash key, which is a parse
                # error rather than an override - PowerShell does not take the
                # last value, it refuses the file. That failure is silent in the
                # useful sense: Resolve-RenderConfiguration warns and falls back
                # to the schema defaults, so every case renders the DEFAULT mode
                # and the suite reports the feature missing when it is present.
                if ($text -match "(?m)^\s*$key\s*=") {
                    $text = $text -replace "(?m)^\s*$key\s*=.*$", $assignment.Replace('$', '$$')
                }
                else {
                    $text = $text.Insert($text.LastIndexOf('}'), $assignment + "`n")
                }
            }
            [System.IO.File]::WriteAllText($settingsFile, $text)
        }

        $dest
    }

    function New-Document {
        param([Parameter(Mandatory)] [string] $TemplateSetPath)

        New-RenderDocument -ViewModel $script:ViewModel.data -Meta $script:ViewModel.meta `
            -Title 'Link mode fixture' -TemplateSetPath $TemplateSetPath
    }

    # The document arrives as four `const NAME = {` blocks, each closed by a `};`
    # at column zero. Located by those bounds rather than by taking one line:
    # every block is pretty-printed JSON spanning tens of lines, and a
    # single-line read of one silently yields a fragment.
    function Get-DocumentBlockRange {
        param([string[]] $Lines, [string] $Name)

        $start = -1
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match "^const $Name = ") { $start = $i; break }
        }
        if ($start -lt 0) { throw "No $Name assignment in the document." }

        for ($j = $start; $j -lt $Lines.Count; $j++) {
            if ($Lines[$j] -match '^\};?\s*$') { return @($start, $j) }
        }
        throw "The $Name block is never closed."
    }

    # One block as the page receives it: parsed out of the document rather than
    # re-resolved, because what the page gets is the claim.
    function Get-DocumentBlock {
        param([Parameter(Mandatory)] [string] $Document, [Parameter(Mandatory)] [string] $Name)

        $lines = $Document -split "`r?`n"
        $range = Get-DocumentBlockRange -Lines $lines -Name $Name
        $text = ($lines[$range[0]..$range[1]] -join "`n") -replace "^const $Name = ", '' -replace ';\s*$', ''
        $text | ConvertFrom-Json
    }

    # Everything in the document except the STRINGS block. That block is where
    # the renderer's own UI messages live, and five of them name vscode:// in
    # prose about what a blocked link looks like - which is not construction of
    # one. Acceptance B's carve-out is exactly this block and nothing else.
    function Get-DocumentCode {
        param([Parameter(Mandatory)] [string] $Document)

        $lines = @($Document -split "`r?`n")
        $range = Get-DocumentBlockRange -Lines $lines -Name 'STRINGS'
        $keep = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -lt $range[0] -or $i -gt $range[1]) { $keep += $lines[$i] }
        }
        $keep -join "`n"
    }

    # Where two documents first differ, as a short report. Should-Be on a
    # 3,000-line string prints both of them, which buries the one line that
    # matters under the whole page twice.
    function Get-FirstDifference {
        param([string] $Expected, [string] $Actual)

        if ($Expected -ceq $Actual) { return $null }
        $e = @($Expected -split "`r?`n")
        $a = @($Actual -split "`r?`n")
        $n = [Math]::Min($e.Count, $a.Count)
        for ($i = 0; $i -lt $n; $i++) {
            if ($e[$i] -cne $a[$i]) {
                return "line $($i + 1): base [$($e[$i])] head [$($a[$i])]"
            }
        }
        "line counts differ: base $($e.Count), head $($a.Count)"
    }
}

AfterAll {
    foreach ($dir in @($script:Scratch, $script:BaseClone)) {
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Link mode is declared configuration' {

    It 'declares LinkMode in the template set schema, as an enum of exactly three modes' {
        $schema = Import-PowerShellDataFile -LiteralPath $script:SchemaPath

        @($schema.Entries.Keys) | Should-ContainCollection 'LinkMode'

        $entry = $schema.Entries['LinkMode']
        $entry.Type | Should-Be 'Enum'
        $entry.Default | Should-Be 'editor'
        @($entry.Values) | Should-BeCollection @('editor', 'hrefTemplate', 'none')
    }

    It 'declares the href template beside the mode, as a string setting' {
        $schema = Import-PowerShellDataFile -LiteralPath $script:SchemaPath

        @($schema.Entries.Keys) | Should-ContainCollection 'LinkHrefTemplate'
        $schema.Entries['LinkHrefTemplate'].Type | Should-Be 'String'
    }

    It 'declares both in the behaviour file, not the theme file' {
        # In = Settings is not decoration: Resolve-RenderConfiguration warns when
        # a value is found in the wrong file, so declaring it wrong ships a
        # warning on every render.
        $schema = Import-PowerShellDataFile -LiteralPath $script:SchemaPath
        $schema.Entries['LinkMode'].In | Should-Be 'Settings'
        $schema.Entries['LinkHrefTemplate'].In | Should-Be 'Settings'
    }

    It 'reaches the page: a configured mode arrives in CONFIG' {
        $set = New-ConfiguredTemplateSet -Name 'mode-in-config' -Setting @{ LinkMode = 'none' }
        (Get-DocumentBlock -Document (New-Document -TemplateSetPath $set) -Name 'CONFIG').LinkMode |
            Should-Be 'none'
    }
}

# --- Acceptance A --------------------------------------------------------

Describe 'Acceptance A: hrefTemplate builds a per-node URL from the viewmodel' {

    BeforeAll {
        $script:HrefSet = New-ConfiguredTemplateSet -Name 'href' -Setting @{
            LinkMode         = 'hrefTemplate'
            LinkHrefTemplate = 'https://example.invalid/{relativePath}'
        }
        $script:HrefDoc = New-Document -TemplateSetPath $script:HrefSet
        $script:HrefCode = Get-DocumentCode -Document $script:HrefDoc
    }

    It 'carries the template to the page' {
        (Get-DocumentBlock -Document $script:HrefDoc -Name 'CONFIG').LinkHrefTemplate |
            Should-Be 'https://example.invalid/{relativePath}'
    }

    It 'ships the href-template resolver' {
        $script:HrefCode.Contains('LINK_MODE_HREF_TEMPLATE') |
            Should-BeTrue -Because 'the hrefTemplate mode script must be the one assembled in'
    }

    It 'ships no editor-scheme construction in this mode' {
        $script:HrefCode.Contains('vscode://') |
            Should-BeFalse -Because 'hrefTemplate mode constructs no editor URI'
    }

    It 'resolves <_> as a token' -ForEach @('relativePath', 'path', 'id', 'label') {
        # The four this pass owes at minimum. Asserted against the resolver's own
        # token table so a token that silently stopped resolving is a red test
        # rather than a link nobody clicked.
        $script:HrefCode.Contains("'{$_}'") |
            Should-BeTrue -Because "{$_} is a token the href template must resolve"
    }
}

# --- Acceptance B --------------------------------------------------------

Describe 'Acceptance B: none means no link is constructed anywhere in the document' {

    BeforeAll {
        $script:NoneSet = New-ConfiguredTemplateSet -Name 'none' -Setting @{ LinkMode = 'none' }
        $script:NoneDoc = New-Document -TemplateSetPath $script:NoneSet
        $script:NoneCode = Get-DocumentCode -Document $script:NoneDoc
    }

    It 'carries no <_>' -ForEach @("id: 'open-in-vscode'", "id: 'copy-editor-link'", 'function vsCodeUriFor') {
        $script:NoneCode.Contains($_) |
            Should-BeFalse -Because 'the action is absent in none mode, not stubbed'
    }

    It 'carries no vscode:// occurrence outside the renderer''s static UI strings' {
        # THE acceptance, worded as the pass prompt words it. The carve-out is
        # the STRINGS block and nothing else.
        $script:NoneCode.Contains('vscode://') |
            Should-BeFalse -Because 'none mode constructs no editor URI anywhere in the document'
    }

    It 'still carries those UI strings, so the carve-out excludes something real' {
        # Without this, the assertion above would pass just as happily if
        # Get-DocumentCode had eaten the whole document.
        $strings = Get-DocumentBlock -Document $script:NoneDoc -Name 'STRINGS'
        (@($strings.PSObject.Properties.Value) -match 'vscode://').Count |
            Should-BeGreaterThan 0
    }

    It 'leaves the rest of the page intact - none removes links, not the report' {
        $script:NoneDoc.Contains('<!DOCTYPE html>') | Should-BeTrue
        $script:NoneDoc.Contains('Link mode fixture') | Should-BeTrue
        ($script:NoneDoc -match '__SLOT_[A-Z0-9_]+__') | Should-BeFalse -Because 'no slot may be left unresolved'
        ($script:NoneDoc -match '/\*__[A-Z]+__\*/ null') | Should-BeFalse -Because 'every payload marker is filled'
    }
}

# --- Acceptance C --------------------------------------------------------
# The no-regression control. Green before and green after; its red capability is
# demonstrated against a scratch render with the default flipped, never by
# letting this go red.

Describe 'Acceptance C: editor mode preserves the base document exactly' {

    BeforeAll {
        # A fresh clone at the base commit, which is what SC1 asks for too. A
        # clone rather than a worktree: it touches nothing in the repository
        # under test, so a crashed run leaves no state behind.
        $script:BaseSha = 'cd4857d'
        $script:BaseClone = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-base-$PID"

        if (Test-Path -LiteralPath $script:BaseClone) { Remove-Item -LiteralPath $script:BaseClone -Recurse -Force }
        & git clone --quiet --no-hardlinks $script:RepoRootDir $script:BaseClone 2>&1 | Out-Null
        & git -C $script:BaseClone checkout --quiet $script:BaseSha 2>&1 | Out-Null

        # Built with the clone's OWN build script, then rendered by a CHILD
        # process importing what that produced. Three reasons, all load-bearing:
        # src/ is not importable (the manifest names a .psm1 the build composes,
        # backlog 10); two versions of one module cannot be loaded in a session;
        # and reproducing the base renderer here to dodge either would compare
        # this file against itself instead of against the base.
        $script:BaseDocPath = Join-Path $script:Scratch 'base.html'
        $fixture = Get-ViewModelFixturePath -Name 'sample-module.json'
        $manifest = Join-Path $script:BaseClone 'output/PSGraphRender/PSGraphRender.psd1'
        $baseSet = Join-Path $script:BaseClone 'output/PSGraphRender/TemplateSets/cytoscape'

        $script:BaseRenderLog = & pwsh -NoProfile -NonInteractive -Command @"
`$ErrorActionPreference = 'Stop'
& '$(Join-Path $script:BaseClone 'build.ps1')' -Task Build | Out-Null
Import-Module '$manifest' -Force
`$vm = Get-Content -LiteralPath '$fixture' -Raw | ConvertFrom-Json
`$doc = New-RenderDocument -ViewModel `$vm.data -Meta `$vm.meta -Title 'Link mode fixture' -TemplateSetPath '$baseSet'
[System.IO.File]::WriteAllText('$($script:BaseDocPath)', `$doc)
"@ 2>&1

        if (Test-Path -LiteralPath $script:BaseDocPath) {
            $script:BaseDoc = [System.IO.File]::ReadAllText($script:BaseDocPath)
        }
    }

    It 'produced a base document to compare against' {
        # A control that silently compared nothing would report the strongest
        # result in the file for the weakest reason.
        (Test-Path -LiteralPath $script:BaseDocPath) |
            Should-BeTrue -Because "the base render must have produced a document; it said: $($script:BaseRenderLog -join ' / ')"
        (Get-Item -LiteralPath $script:BaseDocPath).Length | Should-BeGreaterThan 10000
    }

    It 'renders identically to the base with linkMode absent entirely' {
        $set = New-ConfiguredTemplateSet -Name 'default'
        $head = New-Document -TemplateSetPath $set

        # CONFIG is compared separately below: this pass adds two keys to it,
        # which is the declared change and the only difference permitted.
        $strip = { param($d) (Get-DocumentCode -Document $d) -replace '(?ms)^const CONFIG = \{.*?^\};', '' }
        Get-FirstDifference -Expected (& $strip $script:BaseDoc) -Actual (& $strip $head) |
            Should-BeNull -Because 'the default document must not move'
    }

    It 'renders identically to the base with linkMode set explicitly to editor' {
        $set = New-ConfiguredTemplateSet -Name 'editor' -Setting @{ LinkMode = 'editor' }
        $head = New-Document -TemplateSetPath $set

        $strip = { param($d) (Get-DocumentCode -Document $d) -replace '(?ms)^const CONFIG = \{.*?^\};', '' }
        Get-FirstDifference -Expected (& $strip $script:BaseDoc) -Actual (& $strip $head) |
            Should-BeNull -Because 'editor mode is the preserved behaviour'
    }

    It 'changes CONFIG only by adding the two link settings, and defaults the mode to editor' {
        # The half of the control that pins WHICH value the default is. Flipping
        # the shipped default turns this red - and, because the mode is resolved
        # at assembly rather than in the browser, it turns the comparisons above
        # red too: a different mode assembles different files, so the document
        # body moves as well as CONFIG. Verified by probe P1b in the pass's
        # verify.ps1, which was written asserting the opposite and was wrong.
        $set = New-ConfiguredTemplateSet -Name 'default-config'
        $head = Get-DocumentBlock -Document (New-Document -TemplateSetPath $set) -Name 'CONFIG'
        $base = Get-DocumentBlock -Document $script:BaseDoc -Name 'CONFIG'

        $baseNames = @($base.PSObject.Properties.Name)
        @($head.PSObject.Properties.Name | Where-Object { $_ -notin $baseNames } | Sort-Object) |
            Should-BeCollection @('LinkHrefTemplate', 'LinkMode')

        $head.LinkMode | Should-Be 'editor'

        foreach ($name in $baseNames) {
            ($head.$name | ConvertTo-Json -Compress -Depth 10) |
                Should-Be ($base.$name | ConvertTo-Json -Compress -Depth 10) -Because "setting '$name' must be untouched"
        }
    }
}
