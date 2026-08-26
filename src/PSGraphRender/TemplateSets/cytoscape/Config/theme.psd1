@{
    # Current values for appearance: how the report reads, not what it does.
    # Behaviour lives in settings.psd1. Types, ranges and descriptions live in
    # settings.schema.psd1. See docs/render-architecture.md.
    #
    # This file is DATA, read with Import-PowerShellDataFile and never executed.

    NodeFontSize     = 10
    NodeHeight       = 24
    NodePadding      = 7
    NodeMaxWidth     = 340

    NodeSep          = 14
    RankSep          = 80

    EdgeWidth        = 1.4
    FocusEdgeWidth   = 2.6

    FocusShadeStep   = 0.2
    FocusShadeMax    = 0.6
    RelatedShadeBase = 0.62
    RelatedShadeMax  = 0.78

    # Cold to hot, in order. Every stop stays light enough to carry the
    # near-black node label - a heat ramp that reaches unreadable at the top is
    # a ramp that hides the thing it exists to point at.
    HeatRamp         = @('#6e7d8c', '#a8756e', '#d1665a', '#f05340', '#ff3b2f')

    # One colour per classification, for ColorBy = structure.
    #
    # These keys are PowerShell's, and that is the point: they are DATA here, so
    # a producer describing Terraform ships its own theme.psd1 with resource,
    # module, variable and output instead. Until v0.3.0 this map was KIND_HEX in
    # bootstrap.js - a hardcoded list of one producer's node kinds inside the
    # renderer, which is the third item in the charter's forbidden list.
    #
    # A key here is never validated against anything. Validating it would put
    # the list back.
    KindColor        = @{
        Function = '#4da3ff'
        Class    = '#f2c14e'
        Enum     = '#6ddf6d'
        Script   = '#9b8cff'
    }

    # There is always an unlisted classification, because a producer may send
    # any word at all.
    KindColorFallback = '#8895a7'

    # One colour per LINK classification, and the same story as KindColor:
    # render.js carried `edge[kind = "Inherits"]` with a literal colour, which
    # is a producer's word in a renderer that must not have one.
    #
    # A kind named here is drawn DASHED in its colour; a kind that is not is
    # drawn solid in EdgeColor. That convention is the renderer's, so it stays
    # in script - what may not stay there is which kinds exist.
    LinkColor        = @{
        Inherits = '#f2c14e'
    }
    EdgeColor        = '#6b7785'

    # NOT a KindColor entry, deliberately. An unresolved node is one the
    # renderer INVENTED for a target the payload names but does not contain -
    # `External` is this renderer's word, not a producer's, and no producer
    # emits it. Putting it in the map beside four PowerShell kinds is what made
    # the whole map look like renderer vocabulary in the first place.
    UnresolvedColor  = '#ff7043'

    SidebarWidth     = 300
    SidebarMinWidth  = 200
    CanvasMinWidth   = 320
}
