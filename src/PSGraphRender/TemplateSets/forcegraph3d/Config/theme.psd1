@{
    # Appearance: what it looks like. Behaviour lives in settings.psd1.
    #
    # A dark ground, unlike the other two backends, and that is not taste. This
    # view is lit geometry: the library shades spheres and lines with a light
    # source, and pale material on a pale ground loses the shading that says
    # which way a node is facing. It is also what makes the canvas-growth floor
    # mean anything - an empty render is a flat dark rectangle and a drawn one
    # is not.

    PageBackground    = '#0d1117'
    BodyColor         = '#e6edf3'
    MutedColor        = '#8b949e'
    AccentColor       = '#58a6ff'
    ChromeBackground  = '#161b22'
    ChromeBorder      = '#30363d'
    BodyFont          = 'system-ui, -apple-system, Segoe UI, sans-serif'

    # Item geometry. Radius is nodeRelSize in the library's terms: the size of
    # an item of unit value.
    NodeSize          = 14
    NodeOpacity       = 0.95

    # Connectors. Thin and translucent on purpose: in three dimensions every
    # link crosses every other one somewhere, and opaque lines at cytoscape's
    # weight read as a solid mesh from most angles.
    EdgeColor         = '#6b7785'
    EdgeOpacity       = 0.65
    EdgeWidth         = 1.2
    ArrowSize         = 4

    # One colour per classification. The keys are whatever the payload carries;
    # the renderer does not know them and must not. Same values as the reference
    # backend ships, so the same payload reads the same way in both.
    KindColor         = @{
        Function = '#4da3ff'
        Class    = '#c78bff'
        Enum     = '#ffb84d'
        Script   = '#5ad1a5'
    }
    KindColorFallback = '#8895a7'

    # For an item the renderer invented because a link named a target the
    # payload does not contain. Not a classification: no producer sends it.
    UnresolvedColor   = '#ff7043'

    # Chrome geometry.
    PanelWidth        = 340

    # Room left around the graph when the opening view fits it, in the library's
    # own units.
    FitPadding        = 20
}
