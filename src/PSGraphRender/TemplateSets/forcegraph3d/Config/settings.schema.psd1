@{
    # Every value this backend ships must have an entry here, or it warns at the
    # user. The schema types and range-checks; it does not hold current values.
    #
    # Entry fields:
    #   Type        Number | Integer | Boolean | String | Color | ColorMap | Enum
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
    # every other backend's keys is how a config split stops meaning anything -
    # there is no ZoomSpeed here because nothing reads one.

    Entries     = @{

        # -- Links ---------------------------------------------------------
        # The same two settings, the same three values and the same default as
        # the reference backend. Not a coincidence and not duplication for its
        # own sake: link mode is a property of a REPORT rather than of a
        # drawing, so a caller who sets it should get the same answer whichever
        # backend renders. tests/ForceGraph.Tests.ps1 asserts the enum and the
        # default here, and asserts token parity against the other backend's own
        # resolver rather than against a list.
        LinkMode          = @{
            Type = 'Enum'; Default = 'editor'
            Values = @('editor', 'hrefTemplate', 'none')
            In = 'Settings'; Group = 'Links'
            Description = 'What an item links to. editor opens the file on the reader''s machine; hrefTemplate builds a URL from LinkHrefTemplate; none ships no link at all.'
        }
        LinkHrefTemplate  = @{
            Type = 'String'; Default = ''
            In = 'Settings'; Group = 'Links'
            Description = 'URL pattern for hrefTemplate mode. Tokens: {relativePath} {path} {id} {label} {line}, each a field the payload already carries. Token values are percent-encoded; the pattern around them is not.'
        }

        # -- Layout --------------------------------------------------------
        WarmupTicks       = @{
            Type = 'Integer'; Default = 80; Min = 0; Max = 2000
            In = 'Settings'; Group = 'Layout'
            Description = 'Simulation ticks run before the first paint, so the opening view is a laid-out graph rather than a knot unwinding.'
        }
        CooldownTicks     = @{
            Type = 'Integer'; Default = 160; Min = 1; Max = 5000
            In = 'Settings'; Group = 'Layout'
            Description = 'Ticks the layout runs for after that, then it stops and the view fits itself. Ticks rather than seconds so a payload settles the same way on any machine.'
        }

        # -- Appearance ----------------------------------------------------
        PageBackground    = @{
            Type = 'Color'; Default = '#0d1117'
            In = 'Theme'; Group = 'Appearance'
            Description = 'The ground the scene is lit against, and the page behind it.'
        }
        BodyColor         = @{
            Type = 'Color'; Default = '#e6edf3'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Body text.'
        }
        MutedColor        = @{
            Type = 'Color'; Default = '#8b949e'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Secondary text, and the colour of an action that is unavailable.'
        }
        AccentColor       = @{
            Type = 'Color'; Default = '#58a6ff'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Counts and links.'
        }
        ChromeBackground  = @{
            Type = 'Color'; Default = '#161b22'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Behind the status bar and the item panel.'
        }
        ChromeBorder      = @{
            Type = 'Color'; Default = '#30363d'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Rules and outlines on that chrome.'
        }
        BodyFont          = @{
            Type = 'String'; Default = 'system-ui, sans-serif'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Font stack for the whole document.'
        }

        KindColor         = @{
            Type = 'ColorMap'
            Default = @{}
            In = 'Theme'; Group = 'Appearance'
            Description = 'One colour per classification. The keys are whatever the payload carries; the renderer does not know them and must not.'
        }
        KindColorFallback = @{
            Type = 'Color'; Default = '#8895a7'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Fill for a classification KindColor does not name. A producer may send anything, so there is always an unlisted case.'
        }
        UnresolvedColor   = @{
            Type = 'Color'; Default = '#ff7043'
            In = 'Theme'; Group = 'Appearance'
            Description = 'Fill for an item the renderer invented for a target the payload names but does not contain. Not a classification: no producer sends it.'
        }

        # -- Item geometry -------------------------------------------------
        NodeSize          = @{
            Type = 'Number'; Default = 6; Min = 0.5; Max = 60
            In = 'Theme'; Group = 'Geometry'
            Description = 'Radius of an item of unit value, in scene units.'
        }
        NodeOpacity       = @{
            Type = 'Number'; Default = 0.95; Min = 0.05; Max = 1
            In = 'Theme'; Group = 'Geometry'
            Description = 'How solid an item is. Below one, items behind show through.'
        }

        # -- Connectors ----------------------------------------------------
        EdgeColor         = @{
            Type = 'Color'; Default = '#6b7785'
            In = 'Theme'; Group = 'Connectors'
            Description = 'Line and arrowhead colour.'
        }
        EdgeOpacity       = @{
            Type = 'Number'; Default = 0.5; Min = 0.05; Max = 1
            In = 'Theme'; Group = 'Connectors'
            Description = 'How solid a connector is. In three dimensions every link crosses others, and opaque lines read as a mesh.'
        }
        EdgeWidth         = @{
            Type = 'Number'; Default = 0.8; Min = 0.1; Max = 20
            In = 'Theme'; Group = 'Connectors'
            Description = 'Connector thickness, in scene units.'
        }
        ArrowSize         = @{
            Type = 'Number'; Default = 3; Min = 0; Max = 40
            In = 'Theme'; Group = 'Connectors'
            Description = 'Length of the arrowhead at the target end. Zero draws none.'
        }

        # -- Chrome and camera ---------------------------------------------
        PanelWidth        = @{
            Type = 'Number'; Default = 340; Min = 120; Max = 1200
            In = 'Theme'; Group = 'Chrome'
            Description = 'Widest the item panel may grow, in pixels.'
        }
        FitPadding        = @{
            Type = 'Number'; Default = 60; Min = 0; Max = 500
            In = 'Theme'; Group = 'Chrome'
            Description = 'Room left around the graph when the opening view fits it.'
        }
    }

    # Cross-setting rules. This backend has none; the key exists so the shape is
    # the same as every other backend's and a reader is not left wondering.
    Constraints = @()
}
