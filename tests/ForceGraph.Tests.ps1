#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# A third rendering backend, and what it has to be true of.
#
# `plain` proved that adding a backend is a directory, and `docs/constraints.md`
# records why that proof is weaker than the count suggests: `plain` renders a
# table, asks configuration for nothing structural, and could not have inherited
# a Cytoscape assumption because it has never heard of Cytoscape. `forcegraph3d`
# is the other kind of evidence - a backend with a library, a canvas, its own
# vendoring question and all three link modes - and the seam has to survive it
# without a single .ps1 under src/ being edited. SC1 asserts exactly that.
#
# Three acceptances, in the pass's own words:
#
#   A  the set renders and comes alive. The PowerShell half is here; the browser
#      half is ./build.ps1 -Task TestBrowser, which discovers backends and reads
#      each one's Smoke block as data, so this set joins it by existing.
#   B  link modes, all three, with TOKEN PARITY against cytoscape - derived from
#      cytoscape's own resolver rather than from a list retyped here, so a token
#      that arrives in one backend and not the other is red instead of unnoticed.
#   C  the other two backends are untouched, byte for byte, against this pass's
#      base commit.
#
# What a click actually navigates to is a DOM fact and is not asserted here.
# ./build.ps1 -Task TestLinkMode does that, in a real browser, for this set as
# well as for cytoscape.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Same rule as every other suite here: no producer is imported and none may
    # be. The payload is JSON on disk.
    Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue

    Import-PSGraphRenderUnderTest

    $script:RepoRootDir = Split-Path $PSScriptRoot -Parent
    $script:SetName = 'forcegraph3d'
    $script:SrcSets = Join-Path $script:RepoRootDir 'src/PSGraphRender/TemplateSets'
    $script:ShippedSet = Join-Path $script:SrcSets $script:SetName
    $script:CytoscapeSet = Join-Path $script:SrcSets 'cytoscape'
    $script:SchemaPath = Join-Path $script:ShippedSet 'Config/settings.schema.psd1'
    $script:ManifestPath = Join-Path $script:ShippedSet 'templateset.psd1'

    # The pass's own payload: the same ecosystem viewmodel the committed
    # examples are built from, so the document under test here and the document
    # a reader opens from examples/ are the same rendering of the same data.
    $script:ViewModel = Get-Content -LiteralPath (
        Join-Path $script:RepoRootDir 'examples/input/ecosystem-viewmodel.json') -Raw | ConvertFrom-Json

    $script:Scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-forcegraph-$PID"
    New-Item -ItemType Directory -Path $script:Scratch -Force | Out-Null

    # A COPY of the shipped set, configured as data the way any caller would.
    # Never an edit in place: a suite that rewrites src/ to make its own
    # assertion pass has stopped testing the thing that ships.
    function New-ConfiguredSet {
        param(
            [Parameter(Mandatory)] [string] $Name,
            [Parameter()] [hashtable] $Setting = @{},
            [Parameter()] [string] $From
        )

        $source = if ($From) { $From } else {
            $built = Join-Path (Get-BuiltModuleRoot) "TemplateSets/$script:SetName"
            if (Test-Path -LiteralPath $built) { $built } else { $script:ShippedSet }
        }

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
                # unconditionally produces a duplicate hash key, which PowerShell
                # refuses rather than resolving last-wins - and the refusal is
                # quiet in the worst way: Resolve-RenderConfiguration warns and
                # falls back to the schema defaults, so every case renders the
                # DEFAULT mode and the suite reports the feature missing when it
                # is present.
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
            -Title 'Force graph fixture' -TemplateSetPath $TemplateSetPath
    }

    # The document carries four `const NAME = {` blocks, each closed by a `};` at
    # column zero. Located by those bounds rather than by taking one line: every
    # block is pretty-printed JSON spanning tens of lines, and a single-line read
    # of one silently yields a fragment.
    #
    # Defined here rather than shared with tests/LinkMode.Tests.ps1 on purpose.
    # That file holds the strongest gate in this repository - an editor-mode
    # cytoscape document byte-identical to a base commit's - and hoisting its
    # helpers into TestHelpers.ps1 to save thirty lines would give the strongest
    # gate a reason to change that has nothing to do with what it guards.
    function Get-BlockRange {
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

    function Get-Block {
        param([Parameter(Mandatory)] [string] $Document, [Parameter(Mandatory)] [string] $Name)

        $lines = $Document -split "`r?`n"
        $range = Get-BlockRange -Lines $lines -Name $Name
        $text = ($lines[$range[0]..$range[1]] -join "`n") -replace "^const $Name = ", '' -replace ';\s*$', ''
        $text | ConvertFrom-Json
    }

    # Everything except the STRINGS block. That block is where the renderer's own
    # UI messages live, and a message may legitimately say the words `vscode://`
    # in prose about what a blocked link looks like - which is not construction
    # of one. The carve-out is exactly that block and nothing else, the same
    # carve-out tests/LinkMode.Tests.ps1 draws for cytoscape.
    function Get-Code {
        param([Parameter(Mandatory)] [string] $Document)

        $lines = @($Document -split "`r?`n")
        $range = Get-BlockRange -Lines $lines -Name 'STRINGS'
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

# --- Acceptance A --------------------------------------------------------

Describe 'Acceptance A: the set renders and comes alive' {

    It 'is discovered as a backend without being registered anywhere' {
        # A backend is a directory. Nothing was added to a list to make this
        # true, and if it had been, this passing would prove less than it looks.
        InModuleScope PSGraphRender { Get-RenderTemplateSetName } |
            Should-ContainCollection $script:SetName
    }

    It 'renders the ecosystem viewmodel into a finished document' {
        $document = New-Document -TemplateSetPath (New-ConfiguredSet -Name 'render')

        $document | Should-MatchString '<!DOCTYPE html>'
        $document | Should-MatchString 'Force graph fixture'
        $document | Should-NotMatchString '__SLOT_[A-Z0-9_]+__'
        $document | Should-NotMatchString '/\*__[A-Z]+__\*/ null'
        $document | Should-NotMatchString '__PAGE_TITLE__'
    }

    It 'is one file that needs nothing: the library is inlined, not fetched' {
        # The stronger claim - zero requests actually made - belongs to the
        # headless harness with the network blocked. This is the document-side
        # half: nothing in it asks a browser to go anywhere.
        $document = New-Document -TemplateSetPath (New-ConfiguredSet -Name 'offline')

        foreach ($pattern in @(
                '<script[^>]+\bsrc\s*=\s*["'']?https?:'
                '<link[^>]+\bhref\s*=\s*["'']?https?:'
                '<img[^>]+\bsrc\s*=\s*["'']?https?:'
                '@import\s+(url\()?["'']?https?:')) {
            [regex]::Matches($document, $pattern).Count |
                Should-Be 0 -Because 'the page must ask the browser to fetch nothing'
        }

        # And the library really is in there, rather than the page merely not
        # asking for it: an empty VENDOR slot would satisfy every line above.
        $document | Should-MatchString 'ForceGraph3D'
    }

    It 'declares what a live page means for THIS backend, as data' {
        # The headless harness knows nothing about any backend. A harness naming
        # this set's selectors would be a second place its shape is written down,
        # somewhere other than this set.
        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath

        $manifest.Contains('Smoke') | Should-BeTrue
        @($manifest.Smoke.Present).Count | Should-BeGreaterThan 0
        @($manifest.Smoke.Text.Keys).Count | Should-BeGreaterThan 0
    }

    It 'declares a canvas-growth floor, because every DOM assertion passes over a blank rectangle' {
        # This view draws into a canvas. Counting elements says the page ran; it
        # says nothing about whether anything was drawn, which is exactly the
        # failure a smoke test exists to catch.
        #
        # The first two lines are not ceremony. Written as
        # `@($manifest.Smoke.CanvasGrowth.Keys).Count | Should-BeGreaterThan 0`
        # this test PASSED against a set that did not exist yet: property access
        # on $null yields $null, @($null) is a one-element array, and the count
        # was 1. Found by running the red - the assertion was in the seven that
        # went green before anything was written.
        Test-Path -LiteralPath $script:ManifestPath | Should-BeTrue
        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
        $manifest.Smoke.Contains('CanvasGrowth') | Should-BeTrue

        $selectors = @($manifest.Smoke.CanvasGrowth.Keys)
        $selectors.Count |
            Should-BeGreaterThan 0 -Because 'a canvas backend with no growth floor is a smoke test that cannot see a blank page'
        foreach ($selector in $selectors) {
            $manifest.Smoke.CanvasGrowth[$selector] |
                Should-BeGreaterThan 1 -Because "a floor of 1 or less for $selector is not a floor"
        }
    }

    It 'ships its own configuration rather than borrowing another backend''s' {
        # Every backend carrying every other backend's keys is how a config
        # split stops meaning anything.
        foreach ($file in 'settings.psd1', 'settings.schema.psd1', 'theme.psd1', 'strings.psd1') {
            $full = Join-Path $script:ShippedSet "Config/$file"
            Test-Path -LiteralPath $full | Should-BeTrue -Because "$script:SetName is missing $file"
            Import-PowerShellDataFile -LiteralPath $full | Should-NotBeNull
        }
    }
}

# --- Acceptance B --------------------------------------------------------

Describe 'Acceptance B: all three link modes, with token parity against cytoscape' {

    It 'declares LinkMode as an enum of exactly the three modes, defaulting to editor' {
        $schema = Import-PowerShellDataFile -LiteralPath $script:SchemaPath

        @($schema.Entries.Keys) | Should-ContainCollection 'LinkMode'
        $entry = $schema.Entries['LinkMode']
        $entry.Type | Should-Be 'Enum'
        $entry.Default | Should-Be 'editor'
        @($entry.Values) | Should-BeCollection @('editor', 'hrefTemplate', 'none')
        $entry.In | Should-Be 'Settings'
    }

    It 'declares the href template beside it, as a string, empty by default' {
        # Empty rather than an example URL: a plausible-looking default is one
        # somebody ships by accident.
        $schema = Import-PowerShellDataFile -LiteralPath $script:SchemaPath

        @($schema.Entries.Keys) | Should-ContainCollection 'LinkHrefTemplate'
        $schema.Entries['LinkHrefTemplate'].Type | Should-Be 'String'
        $schema.Entries['LinkHrefTemplate'].In | Should-Be 'Settings'

        (Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet 'Config/settings.psd1')).LinkHrefTemplate |
            Should-Be ''
    }

    Context 'hrefTemplate' {
        BeforeAll {
            $script:HrefSet = New-ConfiguredSet -Name 'href' -Setting @{
                LinkMode         = 'hrefTemplate'
                LinkHrefTemplate = 'https://example.invalid/{relativePath}#L{line}'
            }
            $script:HrefDoc = New-Document -TemplateSetPath $script:HrefSet
            $script:HrefCode = Get-Code -Document $script:HrefDoc

            # The tokens cytoscape's resolver actually offers, read out of its
            # own token table. DERIVED, not retyped: a list here would be a
            # second statement of the same fact, and the two would drift on the
            # day a sixth token is added to one backend and not the other -
            # which is precisely the failure this assertion exists to catch.
            $cytoscapeHref = [System.IO.File]::ReadAllText(
                (Join-Path $script:CytoscapeSet 'scripts/link/href.js'))
            $tokenBlock = [regex]::Match($cytoscapeHref, '(?s)var LINK_TOKENS = \{.*?\n    \};')
            $script:CytoscapeTokens = @([regex]::Matches($tokenBlock.Value, "'\{([a-zA-Z]+)\}'") |
                    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        }

        It 'read a non-empty token table out of cytoscape to compare against' {
            # Without this, every parity assertion below passes vacuously if the
            # regex stops matching - which is the failure mode of deriving a
            # list instead of writing one down.
            @($script:CytoscapeTokens).Count |
                Should-BeGreaterThan 4 -Because 'cytoscape declares five tokens; matching none of them would make parity meaningless'
        }

        It 'carries the configured template to the page' {
            (Get-Block -Document $script:HrefDoc -Name 'CONFIG').LinkHrefTemplate |
                Should-Be 'https://example.invalid/{relativePath}#L{line}'
        }

        It 'assembles the href resolver rather than another mode''s' {
            $script:HrefCode.Contains('LINK_MODE_HREF_TEMPLATE') | Should-BeTrue
        }

        It 'constructs no editor scheme in this mode' {
            $script:HrefCode.Contains('vscode://') |
                Should-BeFalse -Because 'hrefTemplate mode constructs no editor URI'
        }

        It 'resolves every token cytoscape resolves' {
            # Parity in the direction that matters: a template written for one
            # backend must not silently lose a token in the other.
            $missing = @($script:CytoscapeTokens | Where-Object { -not $script:HrefCode.Contains("'{$_}'") })
            ($missing -join ', ') |
                Should-Be '' -Because "these tokens resolve in cytoscape and not in $script:SetName"
        }

        It 'splits the encoders the same way: separators survive in {relativePath} and nothing else' {
            # THE defect 0047's browser gate caught. encodeURIComponent over a
            # whole path escapes / as %2F, which is right for a query VALUE and
            # wrong for the thing {relativePath} exists for: a forge URL of the
            # shape .../blob/main/{relativePath} needs real slashes or it
            # resolves to nothing.
            $script:HrefCode | Should-MatchString 'function encodePathSegments'
            $script:HrefCode | Should-MatchString "split\('/'\)\.map\(encodeURIComponent\)\.join\('/'\)"
            $script:HrefCode.Contains('encodeURIComponent') | Should-BeTrue
        }
    }

    Context 'editor' {
        BeforeAll {
            $script:EditorSet = New-ConfiguredSet -Name 'editor' -Setting @{ LinkMode = 'editor' }
            $script:EditorDoc = New-Document -TemplateSetPath $script:EditorSet
            $script:EditorCode = Get-Code -Document $script:EditorDoc
        }

        It 'is what the set ships with, so a caller who configures nothing still gets a link' {
            (Get-Block -Document $script:EditorDoc -Name 'CONFIG').LinkMode | Should-Be 'editor'
        }

        It 'builds vscode://file/ from rootPath, path and startLine' {
            $script:EditorCode.Contains('vscode://file/') | Should-BeTrue
            $script:EditorCode | Should-MatchString 'rootPath'
            $script:EditorCode | Should-MatchString 'startLine'
        }
    }

    Context 'none' {
        BeforeAll {
            $script:NoneSet = New-ConfiguredSet -Name 'none' -Setting @{ LinkMode = 'none' }
            $script:NoneDoc = New-Document -TemplateSetPath $script:NoneSet
            $script:NoneCode = Get-Code -Document $script:NoneDoc
        }

        It 'carries no <_>' -ForEach @('vscode://', 'function vsCodeUriFor', 'function nodeLinkUriFor') {
            # Assembly-time absence, which is the 0047 ruling. A report is one
            # self-contained file that gets forwarded, so `none` has to mean the
            # scheme construction is not IN it - not that a runtime branch
            # declines to call it.
            $script:NoneCode.Contains($_) |
                Should-BeFalse -Because 'the action is absent in none mode, not stubbed'
        }

        It 'leaves the rest of the page intact - none removes links, not the report' {
            $script:NoneDoc.Contains('<!DOCTYPE html>') | Should-BeTrue
            $script:NoneDoc.Contains('Force graph fixture') | Should-BeTrue
            ($script:NoneDoc -match '__SLOT_[A-Z0-9_]+__') | Should-BeFalse
            ($script:NoneDoc -match '/\*__[A-Z]+__\*/ null') | Should-BeFalse
        }

        It 'clears the action slots rather than removing the machinery that reads them' {
            # An empty list in SlotsBySetting is a real answer: it clears the
            # slot. The registry that renders actions stays; there is simply
            # nothing in it.
            $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
            $none = $manifest.SlotsBySetting.LinkMode['none']

            @($none['NODE_LINK_ACTIONS']).Count |
                Should-Be 0 -Because 'none ships no node link action'
        }
    }
}

# --- Acceptance C --------------------------------------------------------
# The no-regression control. Green before and green after; its red capability is
# demonstrated against a scratch mutation, never by letting this go red.

Describe 'Acceptance C: cytoscape and plain are untouched' {

    BeforeAll {
        # A fresh clone at this pass's base, which is what SC1 asks for too. A
        # clone rather than a worktree: it touches nothing in the repository
        # under test, so a crashed run leaves no state behind.
        $script:BaseSha = '5501755'
        $script:BaseClone = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-0049-base-$PID"

        if (Test-Path -LiteralPath $script:BaseClone) { Remove-Item -LiteralPath $script:BaseClone -Recurse -Force }
        & git clone --quiet --no-hardlinks $script:RepoRootDir $script:BaseClone 2>&1 | Out-Null
        & git -C $script:BaseClone checkout --quiet $script:BaseSha 2>&1 | Out-Null

        # Built with the clone's OWN build script, then rendered by a CHILD
        # process importing what that produced. Three reasons, all load-bearing:
        # src/ is not importable (the manifest names a .psm1 the build composes);
        # two versions of one module cannot be loaded in a session; and
        # reproducing the base renderer here to dodge either would compare this
        # file against itself instead of against the base.
        $script:BaseDocs = @{}
        $fixture = Join-Path $script:RepoRootDir 'examples/input/ecosystem-viewmodel.json'
        $manifest = Join-Path $script:BaseClone 'output/PSGraphRender/PSGraphRender.psd1'

        $lines = @(
            "`$ErrorActionPreference = 'Stop'"
            "& '$(Join-Path $script:BaseClone 'build.ps1')' -Task Build | Out-Null"
            "Import-Module '$manifest' -Force"
            "`$vm = Get-Content -LiteralPath '$fixture' -Raw | ConvertFrom-Json"
        )
        foreach ($backend in 'cytoscape', 'plain') {
            $script:BaseDocs[$backend] = Join-Path $script:Scratch "base-$backend.html"
            $set = Join-Path $script:BaseClone "output/PSGraphRender/TemplateSets/$backend"
            $lines += "`$doc = New-RenderDocument -ViewModel `$vm.data -Meta `$vm.meta -Title 'Force graph fixture' -TemplateSetPath '$set'"
            $lines += "[System.IO.File]::WriteAllText('$($script:BaseDocs[$backend])', `$doc)"
        }

        $script:BaseRenderLog = & pwsh -NoProfile -NonInteractive -Command ($lines -join "`n") 2>&1
    }

    It 'produced a base document for <_> to compare against' -ForEach @('cytoscape', 'plain') {
        # A control that silently compared nothing would report the strongest
        # result in the file for the weakest reason.
        $path = $script:BaseDocs[$_]
        (Test-Path -LiteralPath $path) |
            Should-BeTrue -Because "the base render must have produced a document; it said: $($script:BaseRenderLog -join ' / ')"
        (Get-Item -LiteralPath $path).Length | Should-BeGreaterThan 5000
    }

    It 'renders <_> byte-identically to the base' -ForEach @('cytoscape', 'plain') {
        # No carve-out and no stripped block, unlike the 0047 control: this pass
        # adds a DIRECTORY. Neither of these two backends gains a setting, a
        # string or a script line, so the whole document has to be equal -
        # including CONFIG and STRINGS.
        $set = New-ConfiguredSet -Name "untouched-$_" -From (Join-Path $script:SrcSets $_)
        $head = New-Document -TemplateSetPath $set
        $base = [System.IO.File]::ReadAllText($script:BaseDocs[$_])

        Get-FirstDifference -Expected $base -Actual $head |
            Should-BeNull -Because "$_ must not move: a third backend is a directory, not an edit"
    }

    It 'leaves the default backend where it was' {
        # cytoscape stays the default. Changing which backend renders when a
        # caller names none is a decision, and this pass is not making it.
        (Import-PowerShellDataFile -LiteralPath (Join-Path $script:SrcSets 'index.psd1')).Default |
            Should-Be 'cytoscape'
    }

    It 'edits no .ps1 under src to add a backend' {
        # SC1, asserted in the suite as well as in the pass's spot-checks. The
        # whole claim of the template-set design is that this diff is empty.
        $changed = @(& git -C $script:RepoRootDir diff --name-only "$script:BaseSha..HEAD" -- 'src/PSGraphRender/*.ps1' 'src/PSGraphRender/**/*.ps1')

        ($changed -join ', ') |
            Should-Be '' -Because 'adding a backend must be a data change; a needed .ps1 edit is a design bug, not a workaround'
    }
}
