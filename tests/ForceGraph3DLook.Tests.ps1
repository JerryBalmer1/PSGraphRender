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

    # The base the CURRENT pass is measured against. Recorded as a REF rather
    # than as a copy of the files, so "byte-identical to base" is decided by git
    # and not by a snapshot this suite could take of a tree it had already
    # changed.
    #
    # Moved e7bbfca -> dba1f4d at v0.17.0. A control still comparing against the
    # base of the pass before last goes green over everything the last pass did,
    # which is the one thing it exists to catch.
    $script:BaseRef = 'dba1f4d'

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

        # v0.17.0: the control panel, and the camera flight a click starts.
        @{ Key = 'ShowControlPanel'; Type = 'Enum' }
        @{ Key = 'AutoRotate'; Type = 'Boolean' }
        @{ Key = 'AutoRotateSpeed'; Type = 'Number' }
        @{ Key = 'FocusOnClick'; Type = 'Boolean' }
        @{ Key = 'FocusDistance'; Type = 'Number' }
        @{ Key = 'FocusTransitionMs'; Type = 'Integer' }
    ) {
        $entry = Get-SchemaEntry -Key $Key
        $entry | Should-NotBeNull -Because "$Key is an option this pass promised and the schema is where an option becomes real"
        $entry.Type | Should-Be $Type
        $entry.In | Should-Be 'Settings' -Because 'behaviour belongs in settings.psd1 and the schema says which file every value lives in'
        $entry.Contains('Default') | Should-BeTrue -Because 'a setting with no default is a setting that cannot be left alone'
        $entry.Description | Should-NotBeNull
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

        # v0.17.0: the environment the graph sits in. Scene geometry rather than
        # a CSS backdrop, so it turns with the camera - see Config/theme.psd1.
        @{ Key = 'GridStyle'; Type = 'Enum' }
        @{ Key = 'GridColor'; Type = 'Color' }
        @{ Key = 'GridOpacity'; Type = 'Number' }
        @{ Key = 'GridGlow'; Type = 'Number' }
        @{ Key = 'GridDivisions'; Type = 'Integer' }
        @{ Key = 'GridExtent'; Type = 'Number' }
        @{ Key = 'GridDrop'; Type = 'Number' }
        @{ Key = 'GridLineWidth'; Type = 'Number' }
    ) {
        $entry = Get-SchemaEntry -Key $Key
        $entry | Should-NotBeNull -Because "$Key is an option this pass promised and the schema is where an option becomes real"
        $entry.Type | Should-Be $Type
        $entry.In | Should-Be 'Theme'
        $entry.Contains('Default') | Should-BeTrue
        $entry.Description | Should-NotBeNull
    }

    It 'bounds every new Number and Integer, so a variant cannot ask for a value that renders nothing' -ForEach @(
        @{ Key = 'ZoomSpeed' }, @{ Key = 'RotateSpeed' }, @{ Key = 'LabelMaxNodes' }
        @{ Key = 'NodeSizeMetricMax' }, @{ Key = 'GlowStrength' }, @{ Key = 'GlowSize' }
        @{ Key = 'GlowOpacity' }, @{ Key = 'FogDensity' }, @{ Key = 'ParticleCount' }
        @{ Key = 'ParticleSpeed' }, @{ Key = 'ParticleWidth' }, @{ Key = 'ToneMappingExposure' }
        @{ Key = 'AutoRotateSpeed' }, @{ Key = 'FocusDistance' }, @{ Key = 'FocusTransitionMs' }
        @{ Key = 'GridOpacity' }, @{ Key = 'GridGlow' }, @{ Key = 'GridDivisions' }
        @{ Key = 'GridExtent' }, @{ Key = 'GridDrop' }, @{ Key = 'GridLineWidth' }
    ) {
        $entry = Get-SchemaEntry -Key $Key
        $entry | Should-NotBeNull
        $entry.Contains('Min') | Should-BeTrue -Because 'an unbounded number is a setting whose worst value nobody has considered'
        $entry.Contains('Max') | Should-BeTrue
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
        @{ Key = 'ShowControlPanel'; File = 'settings.psd1' }
        @{ Key = 'AutoRotate'; File = 'settings.psd1' }
        @{ Key = 'AutoRotateSpeed'; File = 'settings.psd1' }
        @{ Key = 'FocusOnClick'; File = 'settings.psd1' }
        @{ Key = 'FocusDistance'; File = 'settings.psd1' }
        @{ Key = 'FocusTransitionMs'; File = 'settings.psd1' }
        @{ Key = 'GridStyle'; File = 'theme.psd1' }
        @{ Key = 'GridColor'; File = 'theme.psd1' }
        @{ Key = 'GridOpacity'; File = 'theme.psd1' }
        @{ Key = 'GridGlow'; File = 'theme.psd1' }
        @{ Key = 'GridDivisions'; File = 'theme.psd1' }
        @{ Key = 'GridExtent'; File = 'theme.psd1' }
        @{ Key = 'GridDrop'; File = 'theme.psd1' }
        @{ Key = 'GridLineWidth'; File = 'theme.psd1' }
    ) {
        # A schema entry with no shipped value renders the default and warns at
        # nobody, which is the quiet half of a setting that does not exist.
        $values = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet "Config/$File")
        $values.Contains($Key) | Should-BeTrue -Because "$Key must ship a deliberate current value in $File, not fall through to its schema default"
    }

    It 'names a shape vocabulary big enough for the mapping to say anything' {
        $entry = Get-SchemaEntry -Key 'NodeShapeFallback'
        $entry | Should-NotBeNull
        @($entry.Values).Count | Should-BeGreaterThanOrEqual 5 -Because 'a mapping with four shapes cannot distinguish four kinds and a fallback'
    }

    It 'declares the shape mapping as producer-blind data, the way KindColor is' {
        # The KEYS are whatever the payload carries. A schema that enumerated
        # them would put a producer's vocabulary back inside the renderer, which
        # is the whole thing ColorMap exists to prevent - and the reason this is
        # a grammar in a String rather than a map type is that adding a type
        # needs a validator under src/, which this pass may not touch.
        $entry = Get-SchemaEntry -Key 'KindShape'
        $entry | Should-NotBeNull
        $entry.Contains('Values') | Should-BeFalse -Because 'enumerating classifications here is the defect, not the feature'
    }

    It 'still declares no setting nothing consumes' {
        # Every schema key must be consumed SOMEWHERE. The inverse of the usual
        # check, and the one that keeps a settings surface from becoming a list
        # of promises: twenty-six new keys is exactly the size of change where
        # one of them quietly reaches nothing.
        #
        # THREE places consume one, not one, and the distinction is the reason
        # this check nearly went wrong. A value can be read by the page's
        # scripts, or named by the stylesheet as a custom property, or resolved
        # when the document is ASSEMBLED - which is what LinkMode is, and it
        # appears in no .js at all because SlotsBySetting decides which files
        # are in the document rather than what a script branches on. A check
        # that only read the scripts would have called the oldest setting here
        # dead.
        $code = (Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'scripts') -Recurse -Filter *.js |
                ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $css = (Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'styles') -Filter *.css |
                ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $atAssembly = @($script:Manifest.SlotsBySetting.Keys)

        $unread = @($script:Entries.Keys | Where-Object {
                $code -notmatch [regex]::Escape($_) -and
                $css -notmatch [regex]::Escape($_) -and
                $atAssembly -notcontains $_
            })
        $unread | Should-BeNull -Because 'a declared setting nothing reads is a setting that does not exist'
    }
}

# --- Acceptance C, the half a browser is not needed for -------------------
#
# Whether a control WORKS is decidable only in a browser and lives in
# ./build.ps1 -Task TestLook. What is decidable from the tree is that the panel
# is in the document at all, that every word it shows comes from data, and that
# it never became the thing it was written not to be - a copy of the 2D
# sidebar, with its English in the markup.

Describe 'Acceptance C: the control panel is in the document, and says nothing of its own' {

    BeforeAll {
        $script:PanelMarkup = [System.IO.File]::ReadAllText(
            (Join-Path $script:ShippedSet 'partials/graph.html'))
        $script:PanelScript = [System.IO.File]::ReadAllText(
            (Join-Path $script:ShippedSet 'scripts/panel.js'))
        $script:Strings = Import-PowerShellDataFile -LiteralPath (
            Join-Path $script:ShippedSet 'Config/strings.psd1')
    }

    It 'ships a panel the layout actually assembles' {
        # A file no slot names never reaches the document, which is the shape of
        # mistake bootstrap.js's library check exists to catch - and it would be
        # invisible here without this, because every assertion below reads the
        # SOURCE rather than a render.
        $parts = @($script:Manifest.Slots.Values | ForEach-Object { $_ })
        $parts | Should-ContainCollection 'scripts/panel.js' -Because 'a panel no slot assembles is a panel no reader gets'
        $parts | Should-ContainCollection 'styles/controls.css'
    }

    It 'declares the panel container and its collapse control' {
        foreach ($id in 'fg-controls', 'fg-controls-toggle', 'fg-controls-body') {
            $script:PanelMarkup | Should-MatchString ([regex]::Escape("id=`"$id`"")) -Because "$id is what makes the panel collapsible"
        }
    }

    It 'declares a control for <_>' -ForEach @(
        'fg-zoom-speed', 'fg-fit', 'fg-rotate',
        'fg-fog', 'fg-grid', 'fg-focus',
        'fg-labels-on', 'fg-particles', 'fg-glow',
        'fg-kinds'
    ) {
        # The prompt's minimum set, one row each, so a control that goes missing
        # fails by its own name rather than as a count that came up short.
        $script:PanelMarkup | Should-MatchString ([regex]::Escape("id=`"$_`""))
    }

    It 'wires every control it declares' {
        # Presence is not consumption - the lesson pass 0050 paid for. A markup
        # id with no script reading it is a control that visibly does nothing.
        #
        # `fg-controls-chevron` is excluded BY NAME rather than by narrowing the
        # pattern until it passes. It is the only id in the panel that is
        # deliberately unwired: it is drawn by the stylesheet and rotated from
        # the [data-collapsed] attribute, so a script naming it would be a
        # second place the collapse state is written down.
        $ids = @([regex]::Matches($script:PanelMarkup, 'id="(fg-(?:controls|zoom|fit|rotate|fog|grid|focus|labels-on|particles|glow|kinds)[a-z-]*)"') |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -ne 'fg-controls-chevron' } |
                Sort-Object -Unique)
        $ids.Count | Should-BeGreaterThan 8 -Because 'matching nothing would make the assertion below vacuous'

        $unwired = @($ids | Where-Object { $script:PanelScript -notmatch [regex]::Escape($_) })
        $unwired | Should-BeNull -Because 'a control the panel script never names is a control that does nothing'
    }

    It 'writes no user-visible word of its own into the markup' {
        # THE HALF THE 2D SIDEBAR GETS WRONG, and the reason this panel is its
        # own design rather than that one moved across: cytoscape's sidebar has
        # "Order", "Search", "Kinds" and "Zoom speed" written into a partial,
        # where nothing can translate them and strings.psd1 cannot see them.
        #
        # Every text node in the panel's region must be whitespace. The panel's
        # own script fills each span with textContent from STRINGS.
        #
        # The region is taken between two ids rather than by matching a closing
        # tag: markup nests, a lazy `.*?</div>` stops at the first inner one,
        # and a greedy one runs to the end of the file. Both would pass while
        # reading the wrong thing.
        $withoutComments = [regex]::Replace($script:PanelMarkup, '(?s)<!--.*?-->', '')
        $start = $withoutComments.IndexOf('<div id="fg-controls"')
        $end = $withoutComments.IndexOf('<div id="fg-resolved"')
        $start | Should-BeGreaterThan 0
        $end | Should-BeGreaterThan $start -Because 'the panel region is bounded by the element that follows it'

        $region = $withoutComments.Substring($start, $end - $start)
        $text = ([regex]::Replace($region, '(?s)<[^>]*>', ' ')).Trim()
        $text | Should-Be '' -Because "the panel markup shows text of its own: '$text'"
    }

    It 'takes every word it shows from strings.psd1' {
        # Each string the panel asks for must be a key the backend ships, or the
        # page falls back to printing the KEY at a reader - the quiet failure
        # str()'s own fallback is designed to make visible, and which nothing
        # else would catch.
        #
        # BOTH call shapes, because the panel has two: setText(id, key) fills a
        # span, and str(key) is used where the word is not a span's whole
        # content. A pattern that knew only one of them would have read three
        # keys out of twenty-two and passed everything it did not look at.
        $keys = @(
            [regex]::Matches($script:PanelScript, "setText\('[a-z0-9-]+',\s*'([A-Za-z]+)'\)") +
            [regex]::Matches($script:PanelScript, "str\('([A-Za-z]+)'\)") |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $keys.Count | Should-BeGreaterThan 12 -Because 'a panel that asked for no strings would pass this vacuously'

        $missing = @($keys | Where-Object { -not $script:Strings.Contains($_) })
        $missing | Should-BeNull -Because 'a string key the panel asks for and the backend does not ship is printed to the reader as its own key'
    }

    It 'names no classification anywhere in the panel' {
        # The filter rows are built from the PAYLOAD. A vocabulary here would be
        # the defect tests/NoProducerKinds.Tests.ps1 exists to find, arriving in
        # the one file whose whole job is to list a producer's classifications.
        $script:PanelScript | Should-MatchString ([regex]::Escape('kindBuckets()')) -Because 'the rows come from the data or they come from a list'
        $script:PanelMarkup | Should-MatchString ([regex]::Escape('id="fg-kinds"'))
    }
}

# --- Acceptance D ---------------------------------------------------------

Describe 'Acceptance D: the catalogue is real' {

    It 'has a variant table' {
        Test-Path -LiteralPath $script:VariantTablePath | Should-BeTrue -Because 'the catalogue is generated FROM this table; without it there is nothing to generate from'
    }

    It 'carries at least 16 variants across at least 5 families' {
        $table = Get-VariantTable
        $table | Should-NotBeNull
        $variants = @($table.Variants)
        $variants.Count | Should-BeGreaterThanOrEqual 16
        @($variants.Family | Sort-Object -Unique).Count | Should-BeGreaterThanOrEqual 5
    }

    It 'labels every variant with a family letter and a number, uniquely' {
        $table = Get-VariantTable
        $labels = @($table.Variants.Label)
        @($labels | Sort-Object -Unique).Count | Should-Be $labels.Count -Because 'a label is a coordinate and two variants cannot share one'
        foreach ($label in $labels) { $label | Should-MatchString '^[A-E][0-9]+$' }
    }

    It 'gives every variant a one-line caption saying what it changes from default' {
        $table = Get-VariantTable
        foreach ($v in $table.Variants) {
            $v.Caption | Should-NotBeNull -Because "$($v.Label) is a coordinate the operator will point with, and a coordinate with no caption points at nothing"
            $v.Caption | Should-NotMatchString "`n"
        }
    }

    It 'commits an html and a png for <Label>' -ForEach @(
        $t = if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) '../examples/threed/variants.psd1')) {
            Import-PowerShellDataFile -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) '../examples/threed/variants.psd1')
        }
        else { $null }
        if ($t) { @($t.Variants | ForEach-Object { @{ Label = $_.Label } }) } else { @(@{ Label = '(no variant table)' }) }
    ) {
        $Label | Should-NotBe '(no variant table)' -Because 'there is no variant table to enumerate'
        Test-Path -LiteralPath (Join-Path $script:CatalogRoot "$Label.html") | Should-BeTrue
        Test-Path -LiteralPath (Join-Path $script:CatalogRoot "$Label.png") | Should-BeTrue
    }

    It 'has a generated catalogue page that names every variant in the table' {
        $page = Join-Path $script:ExamplesRoot 'threed/catalog.html'
        Test-Path -LiteralPath $page | Should-BeTrue
        $html = [System.IO.File]::ReadAllText($page)
        $table = Get-VariantTable
        foreach ($v in $table.Variants) {
            $html | Should-BeLikeString "*$($v.Label)*" -Because "$($v.Label) exists in the table, so it must exist in the page the table generates"
        }
    }

    It 'ships a catalogue page that fetches nothing and inlines no library' {
        $html = [System.IO.File]::ReadAllText((Join-Path $script:ExamplesRoot 'threed/catalog.html'))

        # Offline is absolute, and a catalogue page is an artifact like any
        # other: relative paths to the pictures beside it, and nothing fetched.
        $html | Should-NotMatchString 'https?://' -Because 'offline is absolute, and a catalogue page is an artifact like any other'

        # NO SCRIPT AT ALL, which is the property that matters. Naming the
        # library's global here was the first version of this check and it was
        # wrong twice over: Pester's string match is case-insensitive, and the
        # page's own title says `forcegraph3d`, so it failed on a page that was
        # entirely correct. The right assertion is not "the library's name is
        # absent" - it is "there is no code here", and that is checkable
        # directly.
        $html | Should-NotMatchString '<script' -Because 'the catalogue is a grid of links and pictures; it runs nothing and draws no graph'

        # And it is a page, not a report. A catalogue that had inlined the 1.3 MB
        # drawing library would pass both checks above if the library ever
        # stopped naming itself.
        $html.Length | Should-BeLessThan 200000 -Because 'a catalogue that inlined anything would not be this size'
    }

    It 'declares A0 as the shipped default, so every conversation has a fixed origin' {
        $table = Get-VariantTable
        $a0 = @($table.Variants | Where-Object { $_.Label -eq 'A0' })
        @($a0).Count | Should-Be 1
        @($a0[0].Overlay.Keys).Count | Should-Be 0 -Because 'A0 IS the default: an overlay with anything in it is a different look'
    }

    It 'renders A0 identically to a no-overlay render of the shipped backend' {
        # The declaration above says A0 has no overlay. This says the COMMITTED
        # A0 is what no overlay actually produces - which is the half that can
        # rot, because the file was generated once and the backend moves.
        #
        # Line endings normalised before comparing, and only line endings.
        # .gitattributes stores every text file as LF and the generator writes
        # whatever the assembled parts carry, so a byte comparison of a
        # committed file against a fresh render measures git's normalisation
        # rather than the renderer. The examples have worked this way since
        # they existed; see examples/Build-Examples.ps1.
        $table = Get-VariantTable
        $payload = Get-Content -LiteralPath (Join-Path $script:ExamplesRoot $table.Input) -Raw | ConvertFrom-Json
        $fresh = New-RenderDocument -ViewModel $payload.data -Meta $payload.meta `
            -Title ($table.Title -replace '\{label\}', 'A0') -TemplateSet $script:SetName

        $committed = [System.IO.File]::ReadAllText((Join-Path $script:CatalogRoot 'A0.html'))
        $normalise = { param($t) $t -replace "`r`n", "`n" }

        (& $normalise $committed) | Should-Be (& $normalise $fresh) -Because 'the catalogue''s fixed origin has to be the thing that actually ships'
    }

    It 'keeps every variant to one overlay diff, touching only settings and theme' {
        # SC1, as a test rather than as a spot-check note. A variant that needs a
        # script edit is not a variant, it is a fork.
        $table = Get-VariantTable
        $known = @($script:Entries.Keys)
        foreach ($v in $table.Variants) {
            foreach ($key in @($v.Overlay.Keys)) {
                $known | Should-ContainCollection $key -Because "$($v.Label) overlays '$key', which is not a declared setting - a variant may only move configuration"
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
            $LASTEXITCODE | Should-Be 0
            @($diff | Where-Object { $_ }) | Should-BeNull -Because "this pass is about the 3D backend and $_ is not it"
        }
        finally { Pop-Location }
    }

    It 'leaves the default backend where it was' {
        Push-Location $script:RepoRootDir
        try {
            $diff = & git diff --name-only "$script:BaseRef" -- 'src/PSGraphRender/TemplateSets/index.psd1' 2>&1
            @($diff | Where-Object { $_ }) | Should-BeNull
        }
        finally { Pop-Location }
    }

    It 'edits no .ps1 under src/ - a backend is still a directory' {
        Push-Location $script:RepoRootDir
        try {
            $diff = @(& git diff --name-only "$script:BaseRef" -- 'src/**/*.ps1' 'src/*.ps1' 2>&1 | Where-Object { $_ })
            $diff | Should-BeNull -Because 'the whole claim of the seam is that a backend needs no module change'
        }
        finally { Pop-Location }
    }

    It 'changes no contract file' {
        Push-Location $script:RepoRootDir
        try {
            $diff = @(& git diff --name-only "$script:BaseRef" -- 'contract' 2>&1 | Where-Object { $_ })
            $diff | Should-BeNull -Because 'every distinction here is driven by a field the viewmodel already carries, or by configuration'
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
            $labelSource | Should-MatchString 'createElement' -Because 'the tooltip must be built as an element'
            $labelSource | Should-NotMatchString '\.innerHTML\s*=' -Because 'innerHTML anywhere in this backend re-opens the injection surface 0049 closed'
        }

        It 'still fits the view immediately as well as on settle' {
            $graph = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'scripts/graph.js'))
            $graph | Should-MatchString 'onEngineStop' -Because 'the second fit is what catches the drift after warmup'
            ([regex]::Matches($graph, 'fitView\s*\(')).Count | Should-BeGreaterThanOrEqual 2 -Because 'fitting only on settle leaves the view unfitted for the whole cooldown'
        }

        It 'still sizes the drawing buffer from the container explicitly' {
            $graph = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'scripts/graph.js'))
            $graph | Should-MatchString 'clientWidth' -Because 'left to itself the library opened a 1280x900 buffer inside an 859px box'
            $graph | Should-MatchString 'clientHeight'
        }

        It 'still beats the user agent on [hidden] for every element that uses it' {
            # A display rule on an element that is sometimes hidden kills the
            # attribute. The notice is inset:0, so losing it puts an invisible
            # sheet over the canvas that swallows every click.
            $css = [System.IO.File]::ReadAllText((Join-Path $script:ShippedSet 'styles/base.css'))
            $css | Should-MatchString '#fg-notice\[hidden\]'
            $css | Should-MatchString '#fg-status\[hidden\]'
        }
    }

    It 'still names every vendored file in a slot, and vendors nothing new without provenance' {
        $vendor = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet 'vendor/vendor.psd1')
        $slotted = @($script:Manifest.Slots.Values | ForEach-Object { $_ }) + @(
            $script:Manifest.SlotsBySetting.Values | ForEach-Object { $_.Values | ForEach-Object { $_ } } | ForEach-Object { $_ }
        )
        foreach ($file in $vendor.Files) {
            @($slotted) | Should-ContainCollection "vendor/$($file.Name)" -Because 'a vendored file no slot names never reaches the document'
        }
        $onDisk = @(Get-ChildItem -LiteralPath (Join-Path $script:ShippedSet 'vendor') -File |
                Where-Object { $_.Name -ne 'vendor.psd1' } | Select-Object -ExpandProperty Name)
        @($onDisk | Sort-Object) | Should-BeCollection @(@($vendor.Files.Name) | Sort-Object) -Because 'a blob with no provenance is worse than a CDN link'
    }

    It 'drives the link probe from the setting that decides the button' {
        # If NodeActionButton is a setting, the gate that exercises node actions
        # has to follow it, or the pass ships a mode nothing drove.
        $settings = Import-PowerShellDataFile -LiteralPath (Join-Path $script:ShippedSet 'Config/settings.psd1')
        $script:Manifest.LinkProbe.Button | Should-Be $settings.NodeActionButton -Because 'a probe pressing a button the document no longer listens on is a green gate over a dead feature'
    }

    It 're-measured the canvas-growth floor under the new look' {
        # A changed look with an unexamined floor is a gate quietly wrong in
        # either direction. The manifest records the measurement the way 3.50
        # over 2 was recorded; this asserts the record was revisited, not that
        # the number moved.
        $text = [System.IO.File]::ReadAllText($script:ManifestPath)
        $text | Should-MatchString '(?s)CanvasGrowth'
        $text | Should-MatchString 'v0\.16\.0' -Because 'the floor comment must say which look it was measured under'
    }
}
