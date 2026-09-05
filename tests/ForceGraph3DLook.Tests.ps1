#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The 3D backend's APPEARANCE and INTERACTION surface, and the labelled variant
# catalogue that makes it something an operator can point at.
#
# tests/ForceGraph.Tests.ps1 established that the backend exists, renders, and
# carries all three link modes without a .ps1 under src/ being edited. It says
# nothing about what the page LOOKS like, because until this pass there was
# nothing to say: one geometry, one flat colour per classification, and not a
# single interaction a caller could configure.
#
# Five acceptances, in the pass's own words:
#
#   A  options are DECLARED. Every appearance and interaction choice named in
#      the prompt is a typed schema entry with a default, in the file the schema
#      says it belongs in. Absent keys are the red this file was written to see.
#   B  shapes MEAN something. Geometry is driven by a declared kind -> shape
#      mapping, an unmapped kind gets the declared fallback, and a declared
#      metrics key scales an item. The browser half is ./build.ps1 -Task TestLook.
#   C  interactions OBEY their settings. Also the browser half: a zoom speed
#      that never reaches the live controls is a setting in name only.
#   D  the catalogue is REAL. >= 16 labelled variants across >= 5 families, each
#      one overlay diff from default, each committed as html + png, and a
#      catalogue page GENERATED from the variant table rather than written.
#   E  nothing else moved. cytoscape and plain byte-identical to this pass's
#      base commit, and every browser defect the 0049 pass repaired still repaired.
#
# A and D and E are decidable from the tree and are here. B and C are decidable
# only in a browser and are not: a schema entry proves a setting was DECLARED,
# and only a live page proves it was CONSUMED. Presence is not consumption -
# the lesson pass 0050 paid for with a probe that corrupted a value rather than
# removing one.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue
    Import-PSGraphRenderUnderTest

    $script:RepoRootDir = Split-Path $PSScriptRoot -Parent
    $script:SetName = 'forcegraph3d'
    $script:SrcSets = Join-Path $script:RepoRootDir 'src/PSGraphRender/TemplateSets'
    $script:ShippedSet = Join-Path $script:SrcSets $script:SetName
    $script:SchemaPath = Join-Path $script:ShippedSet 'Config/settings.schema.psd1'
    $script:ManifestPath = Join-Path $script:ShippedSet 'templateset.psd1'
    $script:ExamplesRoot = Join-Path $script:RepoRootDir 'examples'
    $script:CatalogRoot = Join-Path $script:ExamplesRoot 'threed/catalog'
    $script:VariantTablePath = Join-Path $script:ExamplesRoot 'threed/variants.psd1'

    $script:Schema = Import-PowerShellDataFile -LiteralPath $script:SchemaPath
    $script:Entries = $script:Schema.Entries
    $script:Manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath

    # The base this pass is measured against. Recorded as a REF rather than as a
    # copy of the files, so "byte-identical to base" is decided by git and not by
    # a snapshot this suite could take of a tree it had already changed.
    $script:BaseRef = 'e7bbfca'

    $script:Scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-look-$PID"
    New-Item -ItemType Directory -Path $script:Scratch -Force | Out-Null

    function Get-SchemaEntry {
        param([Parameter(Mandatory)] [string] $Key)
        if (-not $script:Entries.Contains($Key)) { return $null }
        $script:Entries[$Key]
    }

    function Get-VariantTable {
        if (-not (Test-Path -LiteralPath $script:VariantTablePath)) { return $null }
        Import-PowerShellDataFile -LiteralPath $script:VariantTablePath
    }
}

AfterAll {
    if ($script:Scratch -and (Test-Path -LiteralPath $script:Scratch)) {
        Remove-Item -LiteralPath $script:Scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Acceptance A ---------------------------------------------------------
#
# Every option the prompt named, as a typed declaration with a default. The
# -ForEach table IS the prompt's list: appearance and interaction, one row each,
# and a row with no schema entry fails by the key's own name rather than as a
# count that came up short.

Describe 'Acceptance A: every option is a declared setting' {

    # In = Settings. Behaviour: what the report DOES.
    It 'declares behaviour setting <Key> as <Type>, in the settings file' -ForEach @(
        @{ Key = 'ZoomSpeed'; Type = 'Number' }
        @{ Key = 'RotateSpeed'; Type = 'Number' }
        @{ Key = 'HoverMode'; Type = 'Enum' }
        @{ Key = 'HoverTooltip'; Type = 'Enum' }
        @{ Key = 'NodeActionButton'; Type = 'Enum' }
        @{ Key = 'ShowLabels'; Type = 'Enum' }
        @{ Key = 'LabelMaxNodes'; Type = 'Integer' }
    ) {
        $entry = Get-SchemaEntry -Key $Key
        $entry | Should -Not -BeNullOrEmpty -Because "$Key is an option this pass promised and the schema is where an option becomes real"
        $entry.Type | Should -Be $Type
        $entry.In | Should -Be 'Settings' -Because 'behaviour belongs in settings.psd1 and the schema says which file every value lives in'
        $entry.Contains('Default') | Should -BeTrue -Because 'a setting with no default is a setting that cannot be left alone'
        $entry.Description | Should -Not -BeNullOrEmpty
    }

    # In = Theme. Appearance: what it LOOKS like.
    It 'declares appearance setting <Key> as <Type>, in the theme file' -ForEach @(
        @{ Key = 'KindShape'; Type = 'String' }
        @{ Key = 'NodeShapeFallback'; Type = 'Enum' }
        @{ Key = 'UnresolvedShape'; Type = 'Enum' }
        @{ Key = 'NodeSizeMetric'; Type = 'String' }
        @{ Key = 'NodeSizeMetricMax'; Type = 'Number' }
        @{ Key = 'ExportedEmphasis'; Type = 'Enum' }
        @{ Key = 'GlowStrength'; Type = 'Number' }
        @{ Key = 'GlowSize'; Type = 'Number' }
        @{ Key = 'GlowOpacity'; Type = 'Number' }
        @{ Key = 'FogDensity'; Type = 'Number' }
        @{ Key = 'FogColor'; Type = 'Color' }
        @{ Key = 'BackgroundStyle'; Type = 'Enum' }
        @{ Key = 'BackgroundGlowColor'; Type = 'Color' }
        @{ Key = 'ParticleCount'; Type = 'Integer' }
        @{ Key = 'ParticleSpeed'; Type = 'Number' }
        @{ Key = 'ParticleWidth'; Type = 'Number' }
        @{ Key = 'ParticleColor'; Type = 'Color' }
        @{ Key = 'LinkResolutionColor'; Type = 'ColorMap' }
        @{ Key = 'ToneMappingExposure'; Type = 'Number' }
    ) {
        $entry = Get-SchemaEntry -Key $Key
        $entry | Should -Not -BeNullOrEmpty -Because "$Key is an option this pass promised and the schema is where an option becomes real"
        $entry.Type | Should -Be $Type
        $entry.In | Should -Be 'Theme'
        $entry.Contains('Default') | Should -BeTrue
        $entry.Description | Should -Not -BeNullOrEmpty
    }

    It 'bounds every new Number and Integer, so a variant cannot ask for a value that renders nothing' -ForEach @(
        @{ Key = 'ZoomSpeed' }, @{ Key = 'RotateSpeed' }, @{ Key = 'LabelMaxNodes' }
        @{ Key = 'NodeSizeMetricMax' }, @{ Key = 'GlowStrength' }, @{ Key = 'GlowSize' }
        @{ Key = 'GlowOpacity' }, @{ Key = 'FogDensity' }, @{ Key = 'ParticleCount' }
        @{ Key = 'ParticleSpeed' }, @{ Key = 'ParticleWidth' }, @{ Key = 'ToneMappingExposure' }
    ) {
        $entry = Get-SchemaEntry -Key $Key
        $entry | Should -Not -BeNullOrEmpty
        $entry.Contains('Min') | Should -BeTrue -Because 'an unbounded number is a setting whose worst value nobody has considered'
        $entry.Contains('Max') | Should -BeTrue
    }

    It 'ships a current value for every new key, in the file the schema names' -ForEach @(
        @{ Key = 'ZoomSpeed'; File = 'settings.psd1' }
        @{ Key = 'RotateSpeed'; File = 'settings.psd1' }
        @{ Key = 'HoverMode'; File = 'settings.psd1' }
        @{ Key = 'HoverTooltip'; File = 'settings.psd1' }
        @{ Key = 'NodeActionButton'; File = 'settings.psd1' }
        @{ Key = 'ShowLabels'; File = 'settings.psd1' }
        @{ Key = 'LabelMaxNodes'; File = 'settings.psd1' }
        @{ Key = 'KindShape'; File = 'theme.psd1' }
        @{ Key = 'NodeShapeFallback'; File = 'theme.psd1' }
        @{ Key = 'UnresolvedShape'; File = 'theme.psd1' }
        @{ Key = 'NodeSizeMetric'; File = 'theme.psd1' }
        @{ Key = 'NodeSizeMetricMax'; File = 'theme.psd1' }
        @{ Key = 'ExportedEmphasis'; File = 'theme.psd1' }
        @{ Key = 'GlowStrength'; File = 'theme.psd1' }
        @{ Key = 'GlowSize'; File = 'theme.psd1' }
        @{ Key = 'GlowOpacity'; File = 'theme.psd1' }
        @{ Key = 'FogDensity'; File = 'theme.psd1' }
        @{ Key = 'FogColor'; File = 'theme.psd1' }
        @{ Key = 'BackgroundStyle'; File = 'theme.psd1' }
        @{ Key = 'BackgroundGlowColor'; File = 'theme.psd1' }
        @{ Key = 'ParticleCount'; File = 'theme.psd1' }
        @{ Key = 'ParticleSpeed'; File = 'theme.psd1' }
        @{ Key = 'ParticleWidth'; File = 'theme.psd1' }
        @{ Key = 'ParticleColor'; File = 'theme.psd1' }
        @{ Key = 'LinkResolutionColor'; File = 'theme.psd1' }
        @{ Key = 'ToneMappingExposure'; File = 'theme.psd1' }
    ) {
        # A schema entry with no shipped value renders the default and warns at
        # nobody, which is the quiet half of a setting that does not exist.
        $values = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet "Config/$File")
        $values.Contains($Key) | Should -BeTrue -Because "$Key must ship a deliberate current value in $File, not fall through to its schema default"
    }

    It 'names a shape vocabulary big enough for the mapping to say anything' {
        $entry = Get-SchemaEntry -Key 'NodeShapeFallback'
        $entry | Should -Not -BeNullOrEmpty
        @($entry.Values).Count | Should -BeGreaterOrEqual 5 -Because 'a mapping with four shapes cannot distinguish four kinds and a fallback'
    }

    It 'declares the shape mapping as producer-blind data, the way KindColor is' {
        # The KEYS are whatever the payload carries. A schema that enumerated
        # them would put a producer's vocabulary back inside the renderer, which
        # is the whole thing ColorMap exists to prevent - and the reason this is
        # a grammar in a String rather than a map type is that adding a type
        # needs a validator under src/, which this pass may not touch.
        $entry = Get-SchemaEntry -Key 'KindShape'
        $entry | Should -Not -BeNullOrEmpty
        $entry.Contains('Values') | Should -BeFalse -Because 'enumerating classifications here is the defect, not the feature'
    }

    It 'still declares no setting the page does not read' {
        # Every schema key must be consumed by this backend's own scripts. The
        # inverse of the usual check, and the one that keeps a settings surface
        # from becoming a list of promises.
        $code = (Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'scripts') -Recurse -Filter *.js |
                ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $css = (Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'styles') -Filter *.css |
                ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $unread = @($script:Entries.Keys | Where-Object {
                $code -notmatch [regex]::Escape($_) -and $css -notmatch [regex]::Escape($_)
            })
        $unread | Should -BeNullOrEmpty -Because 'a declared setting nothing reads is a setting that does not exist'
    }
}

# --- Acceptance D ---------------------------------------------------------

Describe 'Acceptance D: the catalogue is real' {

    It 'has a variant table' {
        Test-Path -LiteralPath $script:VariantTablePath | Should -BeTrue -Because 'the catalogue is generated FROM this table; without it there is nothing to generate from'
    }

    It 'carries at least 16 variants across at least 5 families' {
        $table = Get-VariantTable
        $table | Should -Not -BeNullOrEmpty
        $variants = @($table.Variants)
        $variants.Count | Should -BeGreaterOrEqual 16
        @($variants.Family | Sort-Object -Unique).Count | Should -BeGreaterOrEqual 5
    }

    It 'labels every variant with a family letter and a number, uniquely' {
        $table = Get-VariantTable
        $labels = @($table.Variants.Label)
        @($labels | Sort-Object -Unique).Count | Should -Be $labels.Count -Because 'a label is a coordinate and two variants cannot share one'
        foreach ($label in $labels) { $label | Should -Match '^[A-E][0-9]+$' }
    }

    It 'gives every variant a one-line caption saying what it changes from default' {
        $table = Get-VariantTable
        foreach ($v in $table.Variants) {
            $v.Caption | Should -Not -BeNullOrEmpty -Because "$($v.Label) is a coordinate the operator will point with, and a coordinate with no caption points at nothing"
            $v.Caption | Should -Not -Match "`n"
        }
    }

    It 'commits an html and a png for <Label>' -ForEach @(
        $t = if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) '../examples/threed/variants.psd1')) {
            Import-PowerShellDataFile -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) '../examples/threed/variants.psd1')
        }
        else { $null }
        if ($t) { @($t.Variants | ForEach-Object { @{ Label = $_.Label } }) } else { @(@{ Label = '(no variant table)' }) }
    ) {
        $Label | Should -Not -Be '(no variant table)' -Because 'there is no variant table to enumerate'
        Test-Path -LiteralPath (Join-Path $script:CatalogRoot "$Label.html") | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:CatalogRoot "$Label.png") | Should -BeTrue
    }

    It 'has a generated catalogue page that names every variant in the table' {
        $page = Join-Path $script:ExamplesRoot 'threed/catalog.html'
        Test-Path -LiteralPath $page | Should -BeTrue
        $html = [System.IO.File]::ReadAllText($page)
        $table = Get-VariantTable
        foreach ($v in $table.Variants) {
            $html | Should -BeLike "*$($v.Label)*" -Because "$($v.Label) exists in the table, so it must exist in the page the table generates"
        }
    }

    It 'ships a catalogue page that fetches nothing and inlines no library' {
        $html = [System.IO.File]::ReadAllText((Join-Path $script:ExamplesRoot 'threed/catalog.html'))
        $html | Should -Not -Match 'https?://' -Because 'offline is absolute, and a catalogue page is an artifact like any other'
        $html | Should -Not -Match 'ForceGraph3D' -Because 'the catalogue is a grid of links and pictures; it draws no graph'
    }

    It 'declares A0 as the shipped default, so every conversation has a fixed origin' {
        $table = Get-VariantTable
        $a0 = @($table.Variants | Where-Object { $_.Label -eq 'A0' })
        @($a0).Count | Should -Be 1
        @($a0[0].Overlay.Keys).Count | Should -Be 0 -Because 'A0 IS the default: an overlay with anything in it is a different look'
    }

    It 'keeps every variant to one overlay diff, touching only settings and theme' {
        # SC1, as a test rather than as a spot-check note. A variant that needs a
        # script edit is not a variant, it is a fork.
        $table = Get-VariantTable
        $known = @($script:Entries.Keys)
        foreach ($v in $table.Variants) {
            foreach ($key in @($v.Overlay.Keys)) {
                $known | Should -Contain $key -Because "$($v.Label) overlays '$key', which is not a declared setting - a variant may only move configuration"
            }
        }
    }
}

# --- Acceptance E ---------------------------------------------------------

Describe 'Acceptance E: nothing else moved' {

    It 'leaves <_> byte-identical to the base commit' -ForEach @('cytoscape', 'plain') {
        Push-Location $script:RepoRootDir
        try {
            $diff = & git diff --name-only "$script:BaseRef" -- "src/PSGraphRender/TemplateSets/$_" 2>&1
            $LASTEXITCODE | Should -Be 0
            @($diff | Where-Object { $_ }) | Should -BeNullOrEmpty -Because "this pass is about the 3D backend and $_ is not it"
        }
        finally { Pop-Location }
    }

    It 'leaves the default backend where it was' {
        Push-Location $script:RepoRootDir
        try {
            $diff = & git diff --name-only "$script:BaseRef" -- 'src/PSGraphRender/TemplateSets/index.psd1' 2>&1
            @($diff | Where-Object { $_ }) | Should -BeNullOrEmpty
        }
        finally { Pop-Location }
    }

    It 'edits no .ps1 under src/ - a backend is still a directory' {
        Push-Location $script:RepoRootDir
        try {
            $diff = @(& git diff --name-only "$script:BaseRef" -- 'src/**/*.ps1' 'src/*.ps1' 2>&1 | Where-Object { $_ })
            $diff | Should -BeNullOrEmpty -Because 'the whole claim of the seam is that a backend needs no module change'
        }
        finally { Pop-Location }
    }

    It 'changes no contract file' {
        Push-Location $script:RepoRootDir
        try {
            $diff = @(& git diff --name-only "$script:BaseRef" -- 'contract' 2>&1 | Where-Object { $_ })
            $diff | Should -BeNullOrEmpty -Because 'every distinction here is driven by a field the viewmodel already carries, or by configuration'
        }
        finally { Pop-Location }
    }

    # The four repairs pass 0049 made in a browser. Each one is re-stated here as
    # the property it establishes rather than as the line that fixed it, so a
    # rewrite that keeps the property passes and a rewrite that loses it does not.
    Context 'the 0049 browser repairs still hold' {

        It 'builds the hover label as an ELEMENT, never as a string' {
            # The library inserts a STRING as markup and appends an ELEMENT as
            # itself. A label is free text from a producer and one of them
            # eventually contains a bracket.
            $graph = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'scripts/graph.js'))
            $labelSource = ($graph + (Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'scripts') -Recurse -Filter *.js |
                        ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n")
            $labelSource | Should -Match 'createElement' -Because 'the tooltip must be built as an element'
            $labelSource | Should -Not -Match '\.innerHTML\s*=' -Because 'innerHTML anywhere in this backend re-opens the injection surface 0049 closed'
        }

        It 'still fits the view immediately as well as on settle' {
            $graph = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'scripts/graph.js'))
            $graph | Should -Match 'onEngineStop' -Because 'the second fit is what catches the drift after warmup'
            ([regex]::Matches($graph, 'fitView\s*\(')).Count | Should -BeGreaterOrEqual 2 -Because 'fitting only on settle leaves the view unfitted for the whole cooldown'
        }

        It 'still sizes the drawing buffer from the container explicitly' {
            $graph = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'scripts/graph.js'))
            $graph | Should -Match 'clientWidth' -Because 'left to itself the library opened a 1280x900 buffer inside an 859px box'
            $graph | Should -Match 'clientHeight'
        }

        It 'still beats the user agent on [hidden] for every element that uses it' {
            # A display rule on an element that is sometimes hidden kills the
            # attribute. The notice is inset:0, so losing it puts an invisible
            # sheet over the canvas that swallows every click.
            $css = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'styles/base.css'))
            $css | Should -Match '#fg-notice\[hidden\]'
            $css | Should -Match '#fg-status\[hidden\]'
        }
    }

    It 'still names every vendored file in a slot, and vendors nothing new without provenance' {
        $vendor = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet 'vendor/vendor.psd1')
        $slotted = @($script:Manifest.Slots.Values | ForEach-Object { $_ }) + @(
            $script:Manifest.SlotsBySetting.Values | ForEach-Object { $_.Values | ForEach-Object { $_ } } | ForEach-Object { $_ }
        )
        foreach ($file in $vendor.Files) {
            @($slotted) | Should -Contain "vendor/$($file.Name)" -Because 'a vendored file no slot names never reaches the document'
        }
        $onDisk = @(Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'vendor') -File |
                Where-Object { $_.Name -ne 'vendor.psd1' } | Select-Object -ExpandProperty Name)
        @($onDisk | Sort-Object) | Should -Be @(@($vendor.Files.Name) | Sort-Object) -Because 'a blob with no provenance is worse than a CDN link'
    }

    It 'drives the link probe from the setting that decides the button' {
        # If NodeActionButton is a setting, the gate that exercises node actions
        # has to follow it, or the pass ships a mode nothing drove.
        $settings = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet 'Config/settings.psd1')
        $script:Manifest.LinkProbe.Button | Should -Be $settings.NodeActionButton -Because 'a probe pressing a button the document no longer listens on is a green gate over a dead feature'
    }

    It 're-measured the canvas-growth floor under the new look' {
        # A changed look with an unexamined floor is a gate quietly wrong in
        # either direction. The manifest records the measurement the way 3.50
        # over 2 was recorded; this asserts the record was revisited, not that
        # the number moved.
        $text = [System.IO.File]::ReadAllText($script:ManifestPath)
        $text | Should -Match '(?s)CanvasGrowth'
        $text | Should -Match 'v0\.16\.0' -Because 'the floor comment must say which look it was measured under'
    }
}
