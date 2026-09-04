@{
    # Current values for behaviour settings: what the report does.
    # Appearance lives in theme.psd1. Types, ranges and descriptions live in
    # settings.schema.psd1. See docs/render-architecture.md.
    #
    # This file is DATA, read with Import-PowerShellDataFile and never executed.
    # Expressions, variables and commands will not run here.

    ZoomSpeed     = 1.25
    ZoomSpeedMin  = 0.25
    ZoomSpeedMax  = 5
    ZoomSpeedStep = 0.25

    FocusDepth    = 2

    # Gravity: what everything rests on sits at the foot of the page.
    DefaultFlow   = 'foundation'

    # 0 derives the layer capacity from the window shape, which is what keeps
    # the drawing near the screen's own aspect instead of a long thin band.
    FoundationLayerCapacity = 0

    # Fitting a large graph to the window zooms it into illegibility. Below
    # this the opening view stops shrinking and the reader pans instead.
    MinReadableZoom = 0.45

    # 'structure' is today's behaviour: one colour per kind. Any metric id in
    # the payload colours by heat instead. Changing which state a report OPENS
    # in is a deliberate decision and this one has not been made - the control
    # is in the sidebar, and flipping the default is this one line.
    ColorBy       = 'structure'

    # 'editor' is today's behaviour and stays the default: a report built by
    # someone looking at the code is still the common case. Changing this is a
    # deliberate decision about who the report is FOR, and it is one line.
    LinkMode         = 'editor'

    # Only read when LinkMode is hrefTemplate. Empty rather than an example
    # URL: a plausible-looking default is one somebody ships by accident.
    LinkHrefTemplate = ''

    NodeLimit     = 400
}
