@{
    # Declared assembly order for one template set. A caller supplies its own
    # directory containing a file like this one; nothing here is specific to any
    # one report. See docs/render-architecture.md.
    Layout = 'layout.html'

    # Slot name -> ordered list of files whose contents replace it. Slots may
    # appear inside partials as well as in the layout; substitution repeats
    # until none are left.
    Slots  = @{
        STYLES           = @('styles/base.css', 'styles/overlays.css', 'styles/components.css')
        HEADER           = @('partials/header.html')
        SIDEBAR          = @('partials/sidebar.html')
        DETAILS          = @('partials/details-panel.html')
        CANVAS           = @('partials/canvas.html')
        BANNER           = @('partials/banner.html')
        CONTEXT_MENU     = @('partials/context-menu.html')
        INFO_PANEL       = @('partials/info-panel.html')
        TEMPLATE_NOTICE  = @('partials/template-notice.html')

        # Third-party libraries, inlined so the page is one file that needs
        # nothing. They are assets of THIS backend, not of the module: a
        # backend needing a different library brings its own vendor/ and
        # nothing above this file has to know. See vendor/vendor.psd1 for where
        # each came from and the hash it was verified against.
        VENDOR           = @('vendor/cytoscape.min.js', 'vendor/cytoscape-dagre.min.js')

        SCRIPT           = @('scripts/bootstrap.js')
        SCRIPT_ORDER     = @('scripts/order.js')
        SCRIPT_ELEMENTS  = @('scripts/elements.js')
        SCRIPT_RENDER    = @('scripts/render.js')
        SCRIPT_FOUNDATION = @('scripts/foundation.js')
        SCRIPT_SIDEBAR   = @('scripts/sidebar.js')
        SCRIPT_FILTERS   = @('scripts/filters.js')
        SCRIPT_FOCUS     = @('scripts/focus.js')
        SCRIPT_EDITOR_LINK = @('scripts/editor-link.js')
        SCRIPT_DIAGNOSTICS = @('scripts/diagnostics.js')
        SCRIPT_SELECTION = @('scripts/selection.js')
        SCRIPT_MENU      = @('scripts/menu.js')
        SCRIPT_CONTROLS  = @('scripts/controls.js')
    }
    # What "this page came alive" means for THIS backend, as data. The headless
    # harness in tests/browser/ reads it and knows nothing else about any
    # backend - a harness naming '#c-nodes' would be a second place this
    # backend's shape is written down, somewhere other than this backend.
    #
    # A value names a payload collection, and the assertion is against its count.
    Smoke  = @{
        # Selector -> its text must be the count of that collection.
        Text               = @{ '#c-nodes' = 'nodes'; '#c-edges' = 'links' }

        # Selector -> the number of elements matching it must be that count.
        Elements           = @{}

        # Selectors that must match at least one element.
        Present            = @('#cy canvas')

        # Selector -> how many times larger a screenshot of it must be than the
        # same selector in this backend's render of an EMPTY payload.
        #
        # This view draws into a canvas, so every DOM assertion above passes
        # just as happily over a blank rectangle - which is exactly the failure
        # a smoke test exists to catch.
        #
        # A ratio rather than a byte count, because a byte count cannot survive
        # the move to another machine: viewport, device pixel ratio, available
        # fonts and Chromium version all change how many bytes a drawn canvas
        # compresses to. The harness measures the empty render itself, in the
        # same run, so the floor comes from the machine doing the checking.
        #
        # Measured at v0.5.0: 53,971 bytes drawn against 4,413 empty, a ratio of
        # 12.2. Four is not a marginal call.
        CanvasGrowth       = @{ '#cy' = 4 }
    }
}