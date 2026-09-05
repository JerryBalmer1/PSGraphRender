@{
    # Every value this backend ships must have an entry here, or it warns at the
    # user. The schema types and range-checks; it does not hold current values.
    #
    # Entry fields:
    #   Type        Number | Integer | Boolean | String | Color | ColorList |
    #               ColorMap | StyleMap | Enum
    #   Default     used when the value is absent, wrong, or out of range
    #   Min / Max   Number and Integer only
    #   Values      Enum only
    #   In          Settings (behaviour) or Theme (appearance) - which file the
    #               value belongs in. A value in the wrong file still applies,
    #               but is reported on every render.
    #   Group       for grouping in any future settings UI
    #   Description one line, for the same
    #
    # This backend's own schema, not a copy of another's. Every backend carrying
    # every other backend's keys is how a config split stops meaning anything.
    #
    # Until v0.16.0 the note here read "there is no ZoomSpeed here because
    # nothing reads one", and it was correct: this backend had no camera setting
    # because it consumed none. There is one now, and tests/browser/look.cjs
    # reads it back off the live controls rather than off CONFIG, because a
    # value that reaches the document and not the object is exactly the shape of
    # a setting that exists in name only.
    #
    # EVERY TYPE HERE ALREADY EXISTED. Adding a setting is a data change and
    # adding a TYPE is a module change - the setting validator under
    # src/PSGraphRender/Private/Config/ says so at its ColorList case - and this
    # pass adds twenty-six settings and no type. KindShape pays for that in the
    # one place it shows: see its entry.
    #
    # Named by PATH rather than by the command it defines, deliberately: the
    # producer-vocabulary scan in tests/Module.Quality.Tests.ps1 forbids a
    # Verb-Noun name anywhere in a backend, and it is right to. A backend
    # quoting the module's function names is a backend that knows about the
    # module, which is the coupling the whole seam exists to prevent. It caught
    # this comment.

    Entries     = @{

        # -- Links ---------------------------------------------------------
        # The same two settings, the same three values and the same default as
        # the reference backend. Not a coincidence and not duplication for its
        # own sake: link mode is a property of a REPORT rather than of a
        # drawing, so a caller who sets it should get the same answer whichever
        # backend renders. tests/ForceGraph.Tests.ps1 asserts the enum and the
        # default here, and asserts token parity against the other backend's own
        # resolver rather than against a list.
        LinkMode            = @{
            Type = 'Enum'; Default = 'editor'
            Values = @('editor', 'hrefTemplate', 'none')
            In = 'Settings'; Group = 'Links'
            Description = 'What an item links to. editor opens the file on the reader''s machine; hrefTemplate builds a URL from LinkHrefTemplate; none ships no link at all.'
        }
        LinkHrefTemplate    = @{
            Type = 'String'; Default = ''
            In = 'Settings'; Group = 'Links'
            Description = 'URL pattern for hrefTemplate mode. Tokens: {relativePath} {path} {id} {label} {line}, each a field the payload already carries. Token values are percent-encoded; the pattern around them is not.'
        }

        # -- Layout --------------------------------------------------------
        WarmupTicks         = @{
            Type = 'Integer'; Default = 80; Min = 0; Max = 2000
            In = 'Settings'; Group = 'Layout'
            Description = 'Simulation ticks run before the first paint, so the opening view is a laid-out graph rather than a knot unwinding.'
        }
        CooldownTicks       = @{
            Type = 'Integer'; Default = 160; Min = 1; Max = 5000
            In = 'Settings'; Group = 'Layout'
            Description = 'Ticks the layout runs for after that, then it stops and the view fits itself. Ticks rather than seconds so a payload settles the same way on any machine.'
        }

        # -- Camera --------------------------------------------------------
        # Both reach the library's own controls object, which is the only
        # thing that can act on them. Bounded well inside what that object
        # accepts: it takes any positive number, and at 20 one wheel notch
        # leaves the graph behind the camera.
        ZoomSpeed           = @{
            Type = 'Number'; Default = 0.9; Min = 0.1; Max = 5
            In = 'Settings'; Group = 'Camera'
            Description = 'How far one wheel notch moves the camera. Below the library''s own 1.2, because this view is mostly small corrections to an angle the reader nearly has.'
        }
        RotateSpeed         = @{
            Type = 'Number'; Default = 0.85; Min = 0.1; Max = 5
            In = 'Settings'; Group = 'Camera'
            Description = 'How far one drag turns the scene. Below the library''s own 1.0, for the same reason as ZoomSpeed.'
        }

        # -- Hover ---------------------------------------------------------
        HoverMode           = @{
            Type = 'Enum'; Default = 'neighbors'
            Values = @('none', 'node', 'neighbors')
            In = 'Settings'; Group = 'Hover'
            Description = 'What passing the pointer over an item highlights. neighbors also lifts everything it links to, which is the question a reader actually has in three dimensions.'
        }
        HoverTooltip        = @{
            Type = 'Enum'; Default = 'labelAndKind'
            Values = @('none', 'label', 'labelAndKind', 'labelAndLocation')
            In = 'Settings'; Group = 'Hover'
            Description = 'What the tooltip says. Always built as an element carrying text, never as markup: a label is free text from a producer.'
        }

        # -- Pointer -------------------------------------------------------
        NodeActionButton    = @{
            Type = 'Enum'; Default = 'left'
            Values = @('left', 'right')
            In = 'Settings'; Group = 'Pointer'
            Description = 'Which button opens an item''s actions. The LinkProbe block in templateset.psd1 reads this value, so the browser gate drives whatever ships.'
        }

        # -- Controls ------------------------------------------------------
        # The in-page panel. Every control it carries moves one of the values
        # in this file at RUNTIME, which is the panel's whole contract: a
        # reader dragging a slider and a caller setting a value are changing
        # one thing rather than two, and each control opens at the position
        # its setting shipped.
        ShowControlPanel    = @{
            Type = 'Enum'; Default = 'open'
            Values = @('open', 'collapsed', 'none')
            In = 'Settings'; Group = 'Controls'
            Description = 'The in-page control panel. open shows it expanded, collapsed shows only its header, none removes it from the document entirely - for a report nobody can press.'
        }
        AutoRotate          = @{
            Type = 'Boolean'; Default = $false
            In = 'Settings'; Group = 'Controls'
            Description = 'Whether the camera turns by itself on load. Off by default because a moving view cannot be screenshotted twice the same way, and the catalogue, the look gate and the smoke floor all compare two pictures.'
        }
        AutoRotateSpeed     = @{
            Type = 'Number'; Default = 0.12; Min = 0.01; Max = 3
            In = 'Settings'; Group = 'Controls'
            Description = 'Degrees per frame when it does. At 60fps, 0.12 is a revolution in about fifty seconds - a drift rather than a carousel.'
        }

        # -- Focus ---------------------------------------------------------
        FocusOnClick        = @{
            Type = 'Boolean'; Default = $true
            In = 'Settings'; Group = 'Focus'
            Description = 'Whether clicking an item flies the camera to it and its neighbourhood. Camera and fog, not depth of field: the vendored library ships no post-processing pass.'
        }
        FocusDistance       = @{
            Type = 'Number'; Default = 2.2; Min = 1; Max = 8
            In = 'Settings'; Group = 'Focus'
            Description = 'Where the camera stops, as a multiple of the reach of the item''s own neighbourhood. Sized to what it must frame, so a hub and a leaf are both held.'
        }
        FocusTransitionMs   = @{
            Type = 'Integer'; Default = 700; Min = 0; Max = 5000
            In = 'Settings'; Group = 'Focus'
            Description = 'How long that flight takes, in milliseconds. Zero is a cut.'
        }

        # -- Labels --------------------------------------------------------
        ShowLabels          = @{
            Type = 'Enum'; Default = 'hover'
            Values = @('none', 'hover', 'always')
            In = 'Settings'; Group = 'Labels'
            Description = 'When an item''s name is shown. always positions text over the canvas from projected coordinates, so it costs a layout per item per frame.'
        }
        LabelMaxNodes       = @{
            Type = 'Integer'; Default = 60; Min = 0; Max = 5000
            In = 'Settings'; Group = 'Labels'
            Description = 'Above this many items, ShowLabels = always falls back to hover. A ceiling rather than a warning: the alternative is an unreadable page with no way to know why.'
        }

        # -- Appearance ----------------------------------------------------
        PageBackground      = @{
            Type = 'Color'; Default = '#080b12'
            In = 'Theme'; Group = 'Appearance'
            Description = 'The ground the scene is lit against, and the page behind it.'
        }
        BodyColor           = @{
            Type = 'Color'; Default = '#e6edf3'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Body text.'
        }
        MutedColor          = @{
            Type = 'Color'; Default = '#8b949e'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Secondary text, and the colour of an action that is unavailable.'
        }
        AccentColor         = @{
            Type = 'Color'; Default = '#58a6ff'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Counts and links.'
        }
        ChromeBackground    = @{
            Type = 'Color'; Default = '#0e1420'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Behind the status bar and the item panel.'
        }
        ChromeBorder        = @{
            Type = 'Color'; Default = '#1f2937'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Rules and outlines on that chrome.'
        }
        BodyFont            = @{
            Type = 'String'; Default = 'system-ui, sans-serif'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Font stack for the whole document.'
        }

        KindColor           = @{
            Type = 'ColorMap'
            Default = @{}
            In = 'Theme'; Group = 'Appearance'
            Description = 'One colour per classification. The keys are whatever the payload carries; the renderer does not know them and must not.'
        }
        KindColorFallback   = @{
            Type = 'Color'; Default = '#8895a7'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Fill for a classification KindColor does not name. A producer may send anything, so there is always an unlisted case.'
        }
        UnresolvedColor     = @{
            Type = 'Color'; Default = '#ff7043'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Fill for an item the renderer invented for a target the payload names but does not contain. Not a classification: no producer sends it.'
        }

        # -- Shape ---------------------------------------------------------
        # KindShape is a String and it should not be. It is a map from a
        # producer's classifications to this renderer's shape names, which is
        # exactly what ColorMap is for colours - and there is no ShapeMap type,
        # because adding a type needs a validator under src/ and a backend is a
        # directory. The grammar is `kind=shape`, separated by `;` or `,`,
        # whitespace ignored. The page validates each shape NAME against the
        # geometry it can build and falls back for anything else, so the
        # validation that would live here lives one layer down instead.
        #
        # No Values entry, deliberately: enumerating the KEYS would put a
        # producer's vocabulary back inside the renderer, which is the defect
        # ColorMap exists to prevent and the reason tests/ForceGraph3DLook
        # asserts this entry has none.
        #
        # Proposed as a real type in docs/improvements.md.
        KindShape           = @{
            Type = 'String'; Default = ''
            In = 'Theme'; Group = 'Shape'
            Description = 'One geometry per classification, as kind=shape pairs separated by semicolons. Keys are whatever the payload carries; an unlisted or unbuildable name takes NodeShapeFallback.'
        }
        NodeShapeFallback   = @{
            Type = 'Enum'; Default = 'sphere'
            Values = @('sphere', 'box', 'octahedron', 'tetrahedron', 'icosahedron', 'cone', 'cylinder', 'torus')
            In = 'Theme'; Group = 'Shape'
            Description = 'Geometry for a classification KindShape does not name. Always reachable: a producer may send anything.'
        }
        UnresolvedShape     = @{
            Type = 'Enum'; Default = 'tetrahedron'
            Values = @('sphere', 'box', 'octahedron', 'tetrahedron', 'icosahedron', 'cone', 'cylinder', 'torus')
            In = 'Theme'; Group = 'Shape'
            Description = 'Geometry for an item the renderer invented. A silhouette rather than only a colour, because "this is not a thing the producer said exists" is not a classification.'
        }

        # -- Size ----------------------------------------------------------
        NodeSize            = @{
            Type = 'Number'; Default = 6; Min = 0.5; Max = 60
            In = 'Theme'; Group = 'Geometry'
            Description = 'Radius of an item of unit value, in scene units.'
        }
        NodeOpacity         = @{
            Type = 'Number'; Default = 0.95; Min = 0.05; Max = 1
            In = 'Theme'; Group = 'Geometry'
            Description = 'How solid an item is. Below one, items behind show through.'
        }
        NodeSizeMetric      = @{
            Type = 'String'; Default = ''
            In = 'Theme'; Group = 'Geometry'
            Description = 'Which of the payload''s own metrics scales an item, by key. Empty means uniform, which is the default: the renderer does not know what a producer''s metrics mean.'
        }
        NodeSizeMetricMax   = @{
            Type = 'Number'; Default = 2.6; Min = 1; Max = 8
            In = 'Theme'; Group = 'Geometry'
            Description = 'How many times the smallest item''s radius the largest may reach. Rank over distinct values, not magnitude - the same algorithm and the same limitation as the heat ramp.'
        }
        ExportedEmphasis    = @{
            Type = 'Enum'; Default = 'glow'
            Values = @('none', 'glow', 'ring', 'size')
            In = 'Theme'; Group = 'Geometry'
            Description = 'How an exported item is set apart. glow uses brightness, the one channel nothing else here spends.'
        }

        # -- Glow ----------------------------------------------------------
        # Not a post-processing bloom, and the schema says so where a reader
        # setting the value will see it. The vendored bundle ships no bloom
        # pass; see theme.psd1 and docs/vendoring.md for what was verified.
        GlowStrength        = @{
            Type = 'Number'; Default = 0.3; Min = 0; Max = 3
            In = 'Theme'; Group = 'Glow'
            Description = 'How brightly an item lights itself. Emissive material plus an additive shell, not a full-frame bloom: the vendored library ships no post-processing pass.'
        }
        GlowSize            = @{
            Type = 'Number'; Default = 1.55; Min = 1; Max = 4
            In = 'Theme'; Group = 'Glow'
            Description = 'Radius of the glow shell as a multiple of the item''s own. At 1 there is no shell at all.'
        }
        GlowOpacity         = @{
            Type = 'Number'; Default = 0.16; Min = 0; Max = 1
            In = 'Theme'; Group = 'Glow'
            Description = 'How solid that shell is. The shells blend additively, so they sum where they overlap and a value that suits one item is a white blob on six.'
        }

        # -- Depth ---------------------------------------------------------
        FogDensity          = @{
            Type = 'Number'; Default = 0.0016; Min = 0; Max = 0.02
            In = 'Theme'; Group = 'Depth'
            Description = 'Exponential depth falloff. Zero flattens the cloud into a disc; past about 0.004 the far half disappears rather than recedes.'
        }
        FogColor            = @{
            Type = 'Color'; Default = '#05070d'
            In = 'Theme'; Group = 'Depth'
            Description = 'What distance fades toward. A shade below the page rather than equal to it, so a far item keeps a silhouette.'
        }

        # -- Environment ---------------------------------------------------
        BackgroundStyle     = @{
            Type = 'Enum'; Default = 'flat'
            Values = @('flat', 'gradient', 'vignette')
            In = 'Theme'; Group = 'Environment'
            Description = 'What is behind the graph. Drawn in CSS under a transparent canvas, so it costs nothing in the scene - but a gradient is in the canvas-growth floor''s picture of an EMPTY render too, and takes that gate from 3.79 to 1.05. See Config/theme.psd1.'
        }
        BackgroundGlowColor = @{
            Type = 'Color'; Default = '#16304d'
            In = 'Theme'; Group = 'Environment'
            Description = 'The tint a gradient or vignette lifts toward. Ignored when BackgroundStyle is flat.'
        }

        # -- The grid ------------------------------------------------------
        # Scene geometry rather than a CSS backdrop, unlike BackgroundStyle,
        # and the difference is the one that matters: it has to rotate with
        # the camera. A perspective floor painted in CSS looks right in a
        # screenshot and reads as broken the instant a reader drags.
        GridStyle           = @{
            Type = 'Enum'; Default = 'floor'
            Values = @('none', 'floor', 'room')
            In = 'Theme'; Group = 'Environment'
            Description = 'What the graph sits in. floor rules one plane beneath it and is never between the reader and an item; room encloses it on six sides, which still reads at eye level but rules its near wall across the graph. Sized to the graph''s own extent, so it fits any payload.'
        }
        GridColor           = @{
            Type = 'Color'; Default = '#2b4a6b'
            In = 'Theme'; Group = 'Environment'
            Description = 'The ruling''s colour. Well below the accent, so the environment reads as behind the graph rather than as part of it.'
        }
        GridOpacity         = @{
            Type = 'Number'; Default = 0.5; Min = 0; Max = 1
            In = 'Theme'; Group = 'Environment'
            Description = 'How solid the ruling is. The environment writes no depth, so it never hides an item behind it - but room is ruled on all six sides and its near wall does cross the items, which is one reason floor is the default.'
        }
        GridGlow            = @{
            Type = 'Number'; Default = 0.55; Min = 0; Max = 3
            In = 'Theme'; Group = 'Environment'
            Description = 'How brightly the ruling lights itself. Emissive rather than lit, because half of a room faces away from the light by construction.'
        }
        GridDivisions       = @{
            Type = 'Integer'; Default = 14; Min = 2; Max = 64
            In = 'Theme'; Group = 'Environment'
            Description = 'Cells across each ruled plane. Past about 24 the ruling reads as a texture rather than as a measure, which is the opposite of what it is for.'
        }
        GridExtent          = @{
            Type = 'Number'; Default = 1.7; Min = 1; Max = 6
            In = 'Theme'; Group = 'Environment'
            Description = 'How far the environment reaches past the graph, as a multiple of the graph''s own half-extent. At 1 the outermost items touch it.'
        }
        GridDrop            = @{
            Type = 'Number'; Default = 0.16; Min = 0; Max = 3
            In = 'Theme'; Group = 'Environment'
            Description = 'How far below the lowest item a ground plane sits, as a fraction of the graph''s widest span. Read by floor only: an enclosure is centred on the graph by construction.'
        }
        GridLineWidth       = @{
            Type = 'Number'; Default = 0.004; Min = 0.0005; Max = 0.05
            In = 'Theme'; Group = 'Environment'
            Description = 'Thickness of one ruled line, as a fraction of the environment''s reach. A fraction rather than a length, so the ruling reads the same on a payload of six items and one of six hundred.'
        }
        ToneMappingExposure = @{
            Type = 'Number'; Default = 1.0; Min = 0.2; Max = 3
            In = 'Theme'; Group = 'Environment'
            Description = 'Overall exposure. The scene is emissive material on a dark ground, so its histogram sits low and a flat exposure leaves it muddy.'
        }

        # -- Connectors ----------------------------------------------------
        EdgeColor           = @{
            Type = 'Color'; Default = '#57657a'
            In = 'Theme'; Group = 'Connectors'
            Description = 'Line and arrowhead colour, and the colour of a link whose resolution LinkResolutionColor does not name.'
        }
        EdgeOpacity         = @{
            Type = 'Number'; Default = 0.42; Min = 0.05; Max = 1
            In = 'Theme'; Group = 'Connectors'
            Description = 'How solid a connector is. In three dimensions every link crosses others, and opaque lines read as a mesh.'
        }
        EdgeWidth           = @{
            Type = 'Number'; Default = 1.0; Min = 0.1; Max = 20
            In = 'Theme'; Group = 'Connectors'
            Description = 'Connector thickness, in scene units.'
        }
        ArrowSize           = @{
            Type = 'Number'; Default = 4; Min = 0; Max = 40
            In = 'Theme'; Group = 'Connectors'
            Description = 'Length of the arrowhead at the target end. Zero draws none.'
        }
        LinkResolutionColor = @{
            Type = 'ColorMap'
            Default = @{}
            In = 'Theme'; Group = 'Connectors'
            Description = 'One colour per link resolution, by the producer''s own word for it. A resolution this does not name draws in EdgeColor: the renderer has no opinion about a word it has never seen.'
        }

        # -- Particles -----------------------------------------------------
        ParticleCount       = @{
            Type = 'Integer'; Default = 2; Min = 0; Max = 12
            In = 'Theme'; Group = 'Particles'
            Description = 'Moving marks per link, which is what says which way a link points without chasing an arrowhead around a rotation. Zero is a real answer and ships a still page.'
        }
        ParticleSpeed       = @{
            Type = 'Number'; Default = 0.006; Min = 0; Max = 0.05
            In = 'Theme'; Group = 'Particles'
            Description = 'Fraction of a link travelled per frame.'
        }
        ParticleWidth       = @{
            Type = 'Number'; Default = 1.6; Min = 0.1; Max = 8
            In = 'Theme'; Group = 'Particles'
            Description = 'Radius of one mark, in scene units.'
        }
        ParticleColor       = @{
            Type = 'Color'; Default = '#7fd4ff'
            In = 'Theme'; Group = 'Particles'
            Description = 'Colour of those marks. Brighter than the connector on purpose: they carry the direction and the line does not.'
        }

        # -- Chrome and camera ---------------------------------------------
        PanelWidth          = @{
            Type = 'Number'; Default = 340; Min = 120; Max = 1200
            In = 'Theme'; Group = 'Chrome'
            Description = 'Widest the item panel may grow, in pixels.'
        }
        FitPadding          = @{
            Type = 'Number'; Default = 70; Min = 0; Max = 500
            In = 'Theme'; Group = 'Chrome'
            Description = 'Room left around the graph when the opening view fits it.'
        }
    }

    # Cross-setting rules. This backend has none; the key exists so the shape is
    # the same as every other backend's and a reader is not left wondering.
    #
    # ExportedEmphasis = 'size' and a set NodeSizeMetric are the one pair that
    # can fight, and it is deliberately NOT a constraint: both are legitimate
    # together, the page multiplies them, and a rule refusing the combination
    # would decide for a caller who may well mean it. Said here so the absence
    # is a decision rather than an oversight.
    Constraints = @()
}
