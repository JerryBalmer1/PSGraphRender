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
}
