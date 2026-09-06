#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The fourth rendering backend, and the first contract change since 1.1.0.
#
# `forcegraph3d` established that a backend with a library, a canvas and three
# link modes needs no .ps1 edit under src/. This one asks a harder question, and
# it is the reason the contract moves: every backend so far reads a FLAT list of
# nodes and invents its own arrangement of them. A containment grammar cannot be
# invented - "Public is inside Functions" is a fact only a producer knows - so
# either the contract carries it or the renderer guesses, and guessing is the one
# thing the seam exists to prevent.
#
# Seven acceptances, in the pass's own words:
#
#   A  the schema addition. Both existing payloads validate UNCHANGED under
#      1.2.0, and a `parent` naming no node is refused by name. Optional and
#      additive: a payload with no containment renders as a flat row of
#      top-level containers, honestly, rather than erroring.
#   B  the grammar renders. Containment packed per the reference lab, bright
#      borders, titles in border colour, depth reveal at two camera distances.
#      The pixel half is ./build.ps1 -Task TestLook, which reads this backend's
#      LookProbe block as data.
#   C  link modes, all three, with the five-token surface and the two-encoder
#      split the sibling backends declare - derived from a sibling's own
#      resolver rather than retyped here.
#   D  nothing else moved. The three existing backends byte-identical to this
#      pass's base commit, index.psd1 untouched, cytoscape still the default.
#   E  webview-safe. The defence list is present and every failure branch names
#      itself in a card - a blank page is structurally impossible.
#   F  the module example is honest. Every `parent` resolves and every leaf link
#      lands on a file that exists in this tree.
#   G  trace playback. Both committed traces play from one code path, and an
#      unknown node id or an unknown event kind is refused by name rather than
#      skipped silently.
#
# What a click NAVIGATES to, what a menu action DOES to the scene, and what the
# page DRAWS are DOM and pixel facts and are not asserted here.
# ./build.ps1 -Task TestLinkMode and -Task TestLook do those, in a real browser.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Same rule as every other suite here: no producer is imported and none may
    # be. Every payload is JSON on disk.
    Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue

    Import-PSGraphRenderUnderTest

    $script:RepoRootDir = Split-Path $PSScriptRoot -Parent
    $script:SetName = 'containers3d'
    $script:SrcSets = Join-Path $script:RepoRootDir 'src/PSGraphRender/TemplateSets'
    $script:ShippedSet = Join-Path $script:SrcSets $script:SetName
    $script:ForceGraphSet = Join-Path $script:SrcSets 'forcegraph3d'
    $script:ContractDir = Join-Path $script:RepoRootDir 'contract'
    $script:ViewModelSchemaPath = Join-Path $script:ContractDir 'viewmodel.schema.json'
    $script:TraceSchemaPath = Join-Path $script:ContractDir 'trace.schema.json'
    $script:ExamplesRoot = Join-Path $script:RepoRootDir 'examples'
    $script:InputRoot = Join-Path $script:ExamplesRoot 'input'
    $script:TraceRoot = Join-Path $script:ExamplesRoot 'traces'

    # The base this pass is measured against, recorded as a REF rather than as a
    # copy of the files: "byte-identical to base" is decided by git and not by a
    # snapshot a suite could take of a tree it had already changed.
    #
    # Moved dba1f4d -> c308b75 at this pass. A control still comparing against
    # the base of the pass before goes green over everything the last pass did,
    # which is the one thing it exists to catch.
    $script:BaseRef = 'c308b75'

    $script:Scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-containers3d-$PID"
    New-Item -ItemType Directory -Path $script:Scratch -Force | Out-Null

    function Get-JsonFile {
        param([Parameter(Mandatory)] [string] $Path)
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }

    function Get-SetManifest {
        $path = Join-Path $script:ShippedSet 'templateset.psd1'
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        Import-PowerShellDataFile -LiteralPath $path
    }

    function Get-SetFileText {
        <#
            One file of the backend under test, or $null when the backend or the
            file is not there yet. Returning $null rather than throwing is what
            lets every assertion below state its OWN reason for being red today
            instead of every one of them reporting the same missing directory.
        #>
        param([Parameter(Mandatory)] [string] $Relative)
        $path = Join-Path $script:ShippedSet $Relative
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        [System.IO.File]::ReadAllText($path)
    }

    function Get-SetScriptText {
        <#
            Every script this backend ships, concatenated. The assertions below
            ask whether a PROPERTY is present in the backend, not which file
            carries it - a concern moved between two files under scripts/ is a
            refactor and must not be a red line.
        #>
        $dir = Join-Path $script:ShippedSet 'scripts'
        if (-not (Test-Path -LiteralPath $dir)) { return $null }
        (Get-ChildItem -LiteralPath $dir -Recurse -File -Filter *.js |
            Sort-Object FullName |
            ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
    }

    function New-ContainmentPayload {
        <#
            Two nodes and one containment edge, built here rather than read from
            disk: acceptance A is about what the SEAM accepts, and a fixture on
            disk would make it about a file as well.
        #>
        param([Parameter()] [string] $Parent = 'root')

        [pscustomobject]@{
            nodes = @(
                [pscustomobject]@{ id = 'root'; name = 'Root'; kind = 'Container'; tags = @('top') }
                [pscustomobject]@{ id = 'leaf'; name = 'Leaf'; kind = 'Leaf'; parent = $Parent; tags = @('inner') }
            )
            links = @()
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:Scratch -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Acceptance A ---------------------------------------------------------

Describe 'Acceptance A: the contract carries containment' {

    It 'declares contract 1.2.0' {
        $schema = Get-JsonFile -Path $script:ViewModelSchemaPath
        $schema | Should-NotBeNull
        $schema.version | Should-Be '1.2.0' -Because 'a field gained is a minor, and this pass gains two'
    }

    It 'declares an optional parent on a node' {
        $schema = Get-JsonFile -Path $script:ViewModelSchemaPath
        $node = $schema.properties.data.properties.nodes.items
        @($node.properties.PSObject.Properties.Name) |
            Should-ContainCollection 'parent' -Because 'containment is a producer fact and nothing else can supply it'
        @($node.required) | Should-BeCollection @('id')
    }

    It 'declares optional tags on a node' {
        $schema = Get-JsonFile -Path $script:ViewModelSchemaPath
        $node = $schema.properties.data.properties.nodes.items
        @($node.properties.PSObject.Properties.Name) | Should-ContainCollection 'tags'
        $node.properties.tags.type | Should-Be 'array'
        $node.properties.tags.items.type | Should-Be 'string'
    }

    It 'says which version each new field arrived in' {
        # The contract's own rule, applied to itself: `resolution` carries
        # `since: 1.1.0`, so a reader can tell a field that has always been
        # there from one a payload may predate.
        $schema = Get-JsonFile -Path $script:ViewModelSchemaPath
        $node = $schema.properties.data.properties.nodes.items
        $node.properties.parent.since | Should-Be '1.2.0'
        $node.properties.tags.since | Should-Be '1.2.0'
    }

    It 'validates <_> unchanged' -ForEach @('ecosystem-viewmodel.json', 'links-viewmodel.json') {
        # THE HALF THAT MATTERS MOST. An additive-optional change that breaks a
        # payload written for 1.1.0 is not additive, whatever the version number
        # says. Both existing inputs are re-validated against the NEW schema and
        # neither is edited to pass.
        $payload = Get-JsonFile -Path (Join-Path $script:InputRoot $_)
        $payload | Should-NotBeNull

        $document = New-RenderDocument -ViewModel $payload.data -Meta $payload.meta -Title 'contract 1.2.0'
        $document | Should-MatchString '<!DOCTYPE html>'
    }

    It 'refuses a parent that names no node, by name' {
        # Referential, so no JSON Schema can express it: `parent` is a string in
        # every payload, and whether that string is a node id is a fact about
        # the OTHER nodes. Checked at the seam, where validation lives - see
        # `0003-t4` in docs/constraints.md for why there is exactly one place.
        $message = $null
        try {
            New-RenderDocument -ViewModel (New-ContainmentPayload -Parent 'nowhere') -Title 'dangling' | Out-Null
        }
        catch { $message = $_.Exception.Message }

        $message | Should-NotBeNull -Because 'a dangling parent is a payload defect and rendering it draws a lie'
        $message | Should-MatchString 'nowhere'
        # Both halves of the sentence. A payload with three hundred nodes and
        # one bad reference is one nobody can search without the node as well as
        # the id it named.
        $message | Should-MatchString 'leaf'
    }

    It 'accepts a parent that names a node' {
        $document = New-RenderDocument -ViewModel (New-ContainmentPayload) -Title 'contained'
        $document | Should-MatchString '<!DOCTYPE html>'
    }

    It 'accepts a payload with no containment at all' {
        # SC1's green half. Containment is OPTIONAL input: a producer that
        # cannot say what is inside what omits `parent` and every node is a
        # top-level container, which is the honest answer rather than an error.
        $flat = [pscustomobject]@{
            nodes = @(
                [pscustomobject]@{ id = 'a'; name = 'A'; kind = 'Container' }
                [pscustomobject]@{ id = 'b'; name = 'B'; kind = 'Container' }
            )
            links = @()
        }
        $document = New-RenderDocument -ViewModel $flat -Title 'flat'
        $document | Should-MatchString '<!DOCTYPE html>'
    }
}

Describe 'Acceptance A: the trace sidecar is its own contract' {

    It 'ships contract/trace.schema.json' {
        Test-Path -LiteralPath $script:TraceSchemaPath |
            Should-BeTrue -Because 'a trace has its own lifecycle and is optional input, so it is its own document'
    }

    It 'versions itself rather than the view model' {
        $trace = Get-JsonFile -Path $script:TraceSchemaPath
        $trace | Should-NotBeNull
        $trace.version | Should-Be '1.0.0'
        $trace.'$id' | Should-MatchString 'trace\.schema\.json'
    }

    It 'names the payload the events are over' {
        $trace = Get-JsonFile -Path $script:TraceSchemaPath
        $trace | Should-NotBeNull
        @($trace.properties.PSObject.Properties.Name) | Should-ContainCollection 'events'
        @($trace.properties.PSObject.Properties.Name) | Should-ContainCollection 'payload'
    }

    It 'declares the five event kinds' {
        $trace = Get-JsonFile -Path $script:TraceSchemaPath
        $trace | Should-NotBeNull
        $kinds = @($trace.properties.events.items.properties.kind.enum)
        $kinds | Should-BeCollection @('call', 'return', 'test', 'assert', 'error') -Because 'a test-only shape is one a later producer replaces'
    }

    It 'is frame-aware from day one' {
        # A Pester run and a debugger stack walk are the same shape or they are
        # two schemas. `depth`, `file`, `line` and `durationMs` are what make
        # them one.
        $trace = Get-JsonFile -Path $script:TraceSchemaPath
        $trace | Should-NotBeNull
        $event = $trace.properties.events.items
        $names = @($event.properties.PSObject.Properties.Name)
        foreach ($field in @('seq', 'kind', 'nodeId', 'depth', 'file', 'line', 'durationMs', 'status', 'detail')) {
            $names | Should-ContainCollection $field
        }
        @($event.required) | Should-BeCollection @('seq', 'kind', 'nodeId', 'depth')
    }
}

# --- Acceptance B ---------------------------------------------------------

Describe 'Acceptance B: the grammar renders' {

    It 'is discovered without a registry' {
        # A backend is a directory containing templateset.psd1. There is no list
        # to add to, which is the whole reason index.psd1 holds only a default.
        Test-Path -LiteralPath (Join-Path $script:ShippedSet 'templateset.psd1') -PathType Leaf |
            Should-BeTrue -Because 'discovery is enumerating directories that contain one'
    }

    It 'ships four config data files that still parse' {
        foreach ($file in @('settings.psd1', 'settings.schema.psd1', 'strings.psd1', 'theme.psd1')) {
            $path = Join-Path $script:ShippedSet "Config/$file"
            Test-Path -LiteralPath $path | Should-BeTrue -Because "$file is one of the four every backend declares"
            $data = Import-PowerShellDataFile -LiteralPath $path -ErrorAction SilentlyContinue
            $data | Should-NotBeNull
        }
    }

    It 'keeps its concerns in directories rather than in one file' {
        # Ruling 6: backend code is containers of concerns. The engine that
        # measures and places boxes, the interaction that drives them and the
        # trace that plays over them are three different jobs, and a change to
        # one must not open the file the other two live in.
        foreach ($concern in @('engine', 'interact', 'trace')) {
            Test-Path -LiteralPath (Join-Path $script:ShippedSet "scripts/$concern") -PathType Container |
                Should-BeTrue -Because "scripts/$concern is a concern this backend separates"
        }
    }

    It 'derives its boxes from the containment tree' {
        $text = Get-SetScriptText
        $text | Should-NotBeNull -Because 'the backend must exist before it can read anything'
        $text | Should-MatchString 'parent'
    }

    It 'measures, places and colourises as three steps' {
        # The reference lab's engine, kept as three functions rather than one:
        # a size is computed bottom-up, a position top-down, and a colour is a
        # third pass that needs both to have happened.
        $text = Get-SetScriptText
        $text | Should-NotBeNull
        foreach ($step in @('function measure', 'function place', 'function colorize')) {
            $text | Should-MatchString ([regex]::Escape($step))
        }
    }

    It 'declares a Smoke block with a measured canvas floor' {
        $manifest = Get-SetManifest
        $manifest | Should-NotBeNull
        $manifest.Contains('Smoke') | Should-BeTrue
        @($manifest.Smoke.CanvasDelta.Keys).Count |
            Should-BeGreaterThan 0 -Because 'a canvas backend that declares no floor has no gate that can tell it from a blank rectangle'
    }

    It 'declares a LookProbe, and its own cases with it' {
        # The look gate's case list was written in one backend's vocabulary -
        # `KindShape`, `#fg-zoom-speed`, `GlowStrength` - while claiming to be
        # driven by whatever declares a LookProbe. A backend that declares one
        # and does not answer to those keys was unreachable. This backend brings
        # its cases as data, which is what the Smoke block already does for the
        # smoke gate.
        $manifest = Get-SetManifest
        $manifest | Should-NotBeNull
        $manifest.Contains('LookProbe') | Should-BeTrue
        $manifest.LookProbe.Contains('Cases') | Should-BeTrue
        @($manifest.LookProbe.Cases).Count | Should-BeGreaterThan 4
    }

    It 'asserts a bright border against the colour the theme computes' {
        # Acceptance B in one line: borders are BRIGHT on every layer, and the
        # only thing that can say so is a pixel read next to a declared colour.
        $manifest = Get-SetManifest
        $manifest | Should-NotBeNull
        @($manifest.LookProbe.Cases | Where-Object { $_.kind -eq 'edgeColor' }).Count |
            Should-BeGreaterThan 0 -Because 'a border nobody photographed is a border nobody has seen'
    }

    It 'asserts depth reveal at two camera distances' {
        $manifest = Get-SetManifest
        $manifest | Should-NotBeNull
        @($manifest.LookProbe.Cases | Where-Object { $_.kind -eq 'wheel' }).Count |
            Should-BeGreaterThan 0 -Because '"zoom in and inner layers resolve" is a claim about two distances, not one'
    }
}

# --- Acceptance C ---------------------------------------------------------

Describe 'Acceptance C: link modes, first-class' {

    It 'declares the three modes as slot data' {
        $manifest = Get-SetManifest
        $manifest | Should-NotBeNull
        $manifest.Contains('SlotsBySetting') | Should-BeTrue
        @($manifest.SlotsBySetting.LinkMode.Keys | Sort-Object) |
            Should-BeCollection @('editor', 'hrefTemplate', 'none')
    }

    It 'resolves every token a sibling backend resolves' {
        # Parity derived from a sibling's OWN resolver rather than from a list
        # retyped here. A template written for one backend that silently lost a
        # token in another is a link nobody clicked reporting nothing.
        $sibling = [System.IO.File]::ReadAllText((Join-Path $script:ForceGraphSet 'scripts/link/href.js'))
        $expected = @([regex]::Matches($sibling, "'(\{[a-zA-Z]+\})'") |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $expected.Count | Should-Be 5 -Because 'the five-token surface is what both siblings declare'

        $mine = Get-SetFileText -Relative 'scripts/link/href.js'
        $mine | Should-NotBeNull
        foreach ($token in $expected) {
            $mine | Should-MatchString ([regex]::Escape($token))
        }
    }

    It 'splits the two encoders' {
        # {relativePath} keeps its separators and escapes each segment;
        # everything else is one opaque value and is escaped whole. One encoder
        # cannot be right for both, and a forge URL escaped whole resolves to
        # nothing.
        $mine = Get-SetFileText -Relative 'scripts/link/href.js'
        $mine | Should-NotBeNull
        $mine | Should-MatchString 'encodeURIComponent'
        $mine | Should-MatchString "split\('/'\)"
    }

    It 'ships no scheme construction in none mode' {
        $noneFile = Get-SetFileText -Relative 'scripts/link/none.js'
        $noneFile | Should-NotBeNull
        $noneFile | Should-NotMatchString 'vscode'
        $noneFile | Should-NotMatchString 'encodeURIComponent'
    }

    It 'declares a LinkProbe beside Smoke and LookProbe' {
        $manifest = Get-SetManifest
        $manifest | Should-NotBeNull
        $manifest.Contains('LinkProbe') | Should-BeTrue
        $manifest.LinkProbe.Button |
            Should-Be 'right' -Because 'this backend opens a context menu, and a probe pressing the other button opens nothing'
    }

    It 'agrees with the setting the document actually binds' {
        $manifest = Get-SetManifest
        $settings = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet 'Config/settings.psd1') -ErrorAction SilentlyContinue
        $manifest | Should-NotBeNull
        $settings | Should-NotBeNull
        $manifest.LinkProbe.Button | Should-Be $settings.NodeActionButton
    }
}

# --- Acceptance D ---------------------------------------------------------

Describe 'Acceptance D: nothing else moved' {

    It 'leaves <_> byte-identical to the base commit' -ForEach @('cytoscape', 'forcegraph3d', 'plain') {
        Push-Location $script:RepoRootDir
        try {
            $diff = & git diff --name-only "$script:BaseRef" -- "src/PSGraphRender/TemplateSets/$_" 2>&1
            $LASTEXITCODE | Should-Be 0
            @($diff | Where-Object { $_ }) | Should-BeNull -Because "this pass adds a fourth backend and $_ is not it"
        }
        finally { Pop-Location }
    }

    It 'leaves the default backend where it was' {
        Push-Location $script:RepoRootDir
        try {
            $diff = & git diff --name-only "$script:BaseRef" -- 'src/PSGraphRender/TemplateSets/index.psd1' 2>&1
            @($diff | Where-Object { $_ }) |
                Should-BeNull -Because 'cytoscape stays the default; a new backend is a directory and nothing else'
        }
        finally { Pop-Location }
    }

    It 'edits exactly one .ps1 under src, and it is where validation lives' {
        # NOT "edits no .ps1". This pass changes the contract, and the contract
        # is enforced in exactly one function - so the honest control is that
        # the edit is confined to it, rather than that there is no edit.
        Push-Location $script:RepoRootDir
        try {
            $diff = @(& git diff --name-only "$script:BaseRef" -- 'src/**/*.ps1' 'src/*.ps1' 2>&1 | Where-Object { $_ })
            @($diff) | Should-BeCollection @('src/PSGraphRender/Private/Contract/Test-RenderViewModel.ps1')
        }
        finally { Pop-Location }
    }
}

# --- Acceptance E ---------------------------------------------------------

Describe 'Acceptance E: a blank page is structurally impossible' {

    It 'declares <What> in the renderer' -ForEach @(
        @{ What = 'an opaque canvas'; Pattern = 'alpha\s*:\s*false' }
        @{ What = 'a solid clear colour'; Pattern = 'setClearColor' }
        @{ What = 'a pinned pixel ratio'; Pattern = 'setPixelRatio\(\s*1\s*\)' }
        @{ What = 'a WebGL1 fallback'; Pattern = 'WebGL1Renderer' }
        @{ What = 'a context-lost handler'; Pattern = 'webglcontextlost' }
        @{ What = 'a no-frame watchdog'; Pattern = 'WatchdogMs' }
    ) {
        $text = Get-SetScriptText
        $text | Should-NotBeNull -Because 'the backend must exist before its defences can'
        $text | Should-MatchString $Pattern -Because "the v1 lab white-screened in a webview and $What is one of the six defences that answers it"
    }

    It 'ships a named explanation card rather than a blank body' {
        $layout = Get-SetFileText -Relative 'layout.html'
        $partialDir = Join-Path $script:ShippedSet 'partials'
        $partial = if (Test-Path -LiteralPath $partialDir) {
            (Get-ChildItem -LiteralPath $partialDir -File |
                ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
        }
        else { '' }
        ("$layout`n$partial") | Should-MatchString 'c3-fail'
    }

    It 'names every failure branch rather than returning silently' {
        # The lesson the v1 lab cost: a function that returns on a missing
        # element leaves a white page and no sentence. Every branch that gives
        # up must reach the card.
        $text = Get-SetScriptText
        $text | Should-NotBeNull
        @([regex]::Matches($text, 'showFailure\(')).Count |
            Should-BeGreaterThan 4 -Because 'one card with one call site is a card for one failure'
    }
}

# --- Acceptance F ---------------------------------------------------------

Describe 'Acceptance F: the module example is honest' {

    It 'ships a module payload that draws this repository as containers' {
        Test-Path -LiteralPath (Join-Path $script:InputRoot 'module-viewmodel.json') | Should-BeTrue
    }

    It 'resolves every parent it names' {
        $payload = Get-JsonFile -Path (Join-Path $script:InputRoot 'module-viewmodel.json')
        $payload | Should-NotBeNull
        $ids = @{}
        foreach ($node in $payload.data.nodes) { $ids[$node.id] = $true }

        $dangling = @(
            foreach ($node in $payload.data.nodes) {
                $parent = $node.PSObject.Properties['parent']
                if ($parent -and $parent.Value -and -not $ids.ContainsKey($parent.Value)) {
                    "$($node.id) -> $($parent.Value)"
                }
            }
        )
        $dangling -join '; ' | Should-Be ''
    }

    It 'points every leaf at a file that exists in this tree' {
        # Against the TREE, never the network. A committed example whose links
        # are checked by fetching them is an example that passes on a machine
        # with a proxy and fails on the reader's.
        $payload = Get-JsonFile -Path (Join-Path $script:InputRoot 'module-viewmodel.json')
        $payload | Should-NotBeNull

        $missing = @(
            foreach ($node in $payload.data.nodes) {
                $prop = $node.PSObject.Properties['path']
                if (-not $prop -or -not $prop.Value) { continue }
                $full = Join-Path $script:RepoRootDir $prop.Value
                if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { "$($node.id) -> $($prop.Value)" }
            }
        )
        $missing -join '; ' | Should-Be '' -Because 'the shipped hrefTemplate example builds a URL from each of these'
    }

    It 'carries containment and tags throughout' {
        $payload = Get-JsonFile -Path (Join-Path $script:InputRoot 'module-viewmodel.json')
        $payload | Should-NotBeNull
        @($payload.data.nodes | Where-Object { $_.PSObject.Properties['parent'] }).Count |
            Should-BeGreaterThan 10
        @($payload.data.nodes | Where-Object { $_.PSObject.Properties['tags'] }).Count |
            Should-BeGreaterThan 10
    }

    It 'ships an estate payload that reaches further than one module' {
        Test-Path -LiteralPath (Join-Path $script:InputRoot 'estate-viewmodel.json') | Should-BeTrue
    }

    It 'nests the estate at least five containers deep' {
        # Companies -> vCenters -> datacenters -> racks -> sections -> devices.
        # The claim of the grammar is that it recurses; a two-level payload
        # cannot show that.
        $payload = Get-JsonFile -Path (Join-Path $script:InputRoot 'estate-viewmodel.json')
        $payload | Should-NotBeNull

        $parentOf = @{}
        foreach ($node in $payload.data.nodes) {
            $prop = $node.PSObject.Properties['parent']
            $parentOf[$node.id] = if ($prop) { $prop.Value } else { $null }
        }
        $deepest = 0
        foreach ($id in @($parentOf.Keys)) {
            $depth = 0
            $walk = $id
            while ($parentOf[$walk]) { $walk = $parentOf[$walk]; $depth++; if ($depth -gt 50) { break } }
            if ($depth -gt $deepest) { $deepest = $depth }
        }
        $deepest | Should-BeGreaterThanOrEqual 5
    }
}

# --- Acceptance G ---------------------------------------------------------

Describe 'Acceptance G: trace playback' {

    It 'ships <_>' -ForEach @('pester-run.trace.json', 'stack-walk.trace.json') {
        Test-Path -LiteralPath (Join-Path $script:TraceRoot $_) | Should-BeTrue
    }

    It 'validates <_> against the sidecar schema' -ForEach @('pester-run.trace.json', 'stack-walk.trace.json') {
        $path = Join-Path $script:TraceRoot $_
        Test-Path -LiteralPath $path | Should-BeTrue
        Test-Path -LiteralPath $script:TraceSchemaPath | Should-BeTrue
        $json = Get-Content -LiteralPath $path -Raw
        $valid = $false
        try { $json | Test-Json -SchemaFile $script:TraceSchemaPath -ErrorAction Stop | Out-Null; $valid = $true }
        catch { $valid = $_.Exception.Message }
        $valid | Should-BeTrue
    }

    It 'names only nodes the module payload contains, in <_>' -ForEach @('pester-run.trace.json', 'stack-walk.trace.json') {
        $trace = Get-JsonFile -Path (Join-Path $script:TraceRoot $_)
        $payload = Get-JsonFile -Path (Join-Path $script:InputRoot 'module-viewmodel.json')
        $trace | Should-NotBeNull
        $payload | Should-NotBeNull

        $ids = @{}
        foreach ($node in $payload.data.nodes) { $ids[$node.id] = $true }
        $unknown = @($trace.events | Where-Object { -not $ids.ContainsKey($_.nodeId) } |
                ForEach-Object { $_.nodeId } | Select-Object -Unique)
        $unknown -join '; ' | Should-Be ''
    }

    It 'walks call and return in matched pairs in stack-walk.trace.json' {
        # A debug flow is a stack: every call that descends comes back up, or
        # the depth readout is a number nobody can trust.
        $trace = Get-JsonFile -Path (Join-Path $script:TraceRoot 'stack-walk.trace.json')
        $trace | Should-NotBeNull
        $calls = @($trace.events | Where-Object { $_.kind -eq 'call' }).Count
        $returns = @($trace.events | Where-Object { $_.kind -eq 'return' }).Count
        $returns | Should-Be $calls
    }

    It 'carries a caught-and-rethrown error event' {
        $trace = Get-JsonFile -Path (Join-Path $script:TraceRoot 'stack-walk.trace.json')
        $trace | Should-NotBeNull
        @($trace.events | Where-Object { $_.kind -eq 'error' }).Count | Should-BeGreaterThan 0
    }

    It 'plays both traces from one code path' {
        $dir = Join-Path $script:ShippedSet 'scripts/trace'
        Test-Path -LiteralPath $dir -PathType Container | Should-BeTrue
        @(Get-ChildItem -LiteralPath $dir -File -Filter *.js -ErrorAction SilentlyContinue).Count |
            Should-BeGreaterThan 0 -Because 'one playback, two files - a second code path is a second set of semantics'
    }

    It 'refuses an unknown node id and an unknown kind by name' {
        # The meaningful red: a scaffold that SKIPPED an event it did not
        # recognise passed every other assertion in this block. Both refusals
        # have to be in the playback, and both have to name what they refused.
        $text = Get-SetScriptText
        $text | Should-NotBeNull
        $text | Should-MatchString 'TraceUnknownNode'
        $text | Should-MatchString 'TraceUnknownKind'
    }

    It 'offers play, pause, step and speed' {
        $text = Get-SetScriptText
        $text | Should-NotBeNull
        foreach ($control in @('c3-trace-play', 'c3-trace-step', 'c3-trace-speed')) {
            $text | Should-MatchString ([regex]::Escape($control))
        }
    }
}

# --- The spec panel, a standing dev-tool requirement ----------------------

Describe 'The spec panel exports and applies the current state' {

    It 'ships an export and a paste box' {
        $text = Get-SetScriptText
        $text | Should-NotBeNull
        $text | Should-MatchString 'c3-spec-export'
        $text | Should-MatchString 'c3-spec-import'
    }

    It 'round-trips through one declared shape' {
        $text = Get-SetScriptText
        $text | Should-NotBeNull
        $text | Should-MatchString 'function readSpec'
        $text | Should-MatchString 'function applySpec'
    }
}
