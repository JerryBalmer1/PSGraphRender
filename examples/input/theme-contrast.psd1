@{
    # The second half of the R-theme pair. Appearance only - every key here is
    # declared 'In = Theme' by Config/settings.schema.psd1, and a behaviour key
    # in this file would be a setting in the wrong place.
    #
    # This exists to show that the palette is DATA. Nothing in the renderer
    # knows the words Function, Script, Config or Contract: they are this
    # payload's classifications, and a producer describing something else ships
    # its own map. Compare theme/default.png with theme/contrast.png - same
    # viewmodel, same layout, different theme.psd1, no code changed.

    KindColor         = @{
        Function = '#00c2a8'
        Script   = '#ff9f1c'
        Config   = '#b07bd6'
        Contract = '#e0e6ed'
    }

    # Deliberately loud: a classification the map does not name has to be
    # obviously unstyled rather than quietly plausible.
    KindColorFallback = '#ff2e88'

    # A named link kind draws dashed in its colour; everything else is solid in
    # EdgeColor. 'Reads' and 'Validates' are this payload's words.
    LinkColor         = @{
        Reads     = '#ffd166'
        Validates = '#4cc9f0'
    }
    EdgeColor         = '#5a6b7d'

    EdgeWidth         = 2.0
    FocusEdgeWidth    = 3.4

    NodeFontSize      = 12
    NodeHeight        = 30
    NodePadding       = 10
    NodeMaxWidth      = 300

    NodeSep           = 18
    RankSep           = 96

    HeatRamp          = @('#2b5876', '#4e7ea8', '#7aa6c2', '#c9a227', '#ff5964')
}
