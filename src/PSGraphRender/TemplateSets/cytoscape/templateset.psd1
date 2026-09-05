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
        # Node links. These four are the DEFAULTS, and SlotsBySetting below
        # overrides them with whichever mode the render is configured for.
        # Stated here as well so a caller assembling with no configuration still
        # gets a working document, and so every file stays reachable from Slots.
        SCRIPT_NODE_LINK = @('scripts/link/common.js', 'scripts/link/editor.js')
        NODE_LINK_ACTIONS = @('scripts/link/editor-node-actions.js')
        SELECTION_LINK_ACTIONS = @('scripts/link/editor-selection-actions.js')
        LINK_DIAGNOSTIC_ROWS = @('scripts/link/editor-diagnostics.js')
        SCRIPT_DIAGNOSTICS = @('scripts/diagnostics.js')
        SCRIPT_SELECTION = @('scripts/selection.js')
        SCRIPT_MENU      = @('scripts/menu.js')
        SCRIPT_CONTROLS  = @('scripts/controls.js')
    }
    # Slot contents a SETTING chooses between. The outer key names the
    # setting, each inner key one of its values, and the map replaces those
    # slots in Slots when that value is in force.
    #
    # This exists so link mode is resolved when the document is ASSEMBLED rather
    # than in the browser. A report is one self-contained file that gets
    # forwarded, so 'none' has to mean the scheme construction is not IN it -
    # not that a runtime branch declines to call it. The same seam is what lets
    # a mode bring its own menu entries instead of every backend script carrying
    # a conditional for every mode.
    #
    # An empty list is a real answer: it clears the slot, which is how 'none'
    # removes the link actions without removing the menu.
    SlotsBySetting = @{
        LinkMode = @{
            editor = @{
                SCRIPT_NODE_LINK       = @('scripts/link/common.js', 'scripts/link/editor.js')
                NODE_LINK_ACTIONS      = @('scripts/link/editor-node-actions.js')
                SELECTION_LINK_ACTIONS = @('scripts/link/editor-selection-actions.js')
                LINK_DIAGNOSTIC_ROWS   = @('scripts/link/editor-diagnostics.js')
            }
            hrefTemplate = @{
                SCRIPT_NODE_LINK       = @('scripts/link/common.js', 'scripts/link/href.js')
                NODE_LINK_ACTIONS      = @('scripts/link/href-node-actions.js')
                SELECTION_LINK_ACTIONS = @('scripts/link/href-selection-actions.js')
                LINK_DIAGNOSTIC_ROWS   = @('scripts/link/href-diagnostics.js')
            }
            none = @{
                SCRIPT_NODE_LINK       = @('scripts/link/common.js', 'scripts/link/none.js')
                NODE_LINK_ACTIONS      = @()
                SELECTION_LINK_ACTIONS = @()
                LINK_DIAGNOSTIC_ROWS   = @('scripts/link/none-diagnostics.js')
            }
        }
    }

    # Slots whose parts are FRAGMENTS: text that is valid only where the slot
    # puts it. These three sit inside an array literal, so each part is a run of
    # array elements and `node --check` on one alone reports a syntax error
    # about the check rather than about the file.
    #
    # Declared by SLOT rather than by listing files, so a fourth link mode
    # brings its parts already covered instead of arriving unchecked and looking
    # checked. LintJavaScript wraps a fragment in the shape named here before
    # parsing it; the assembled document is what has to be valid, and this is
    # how a per-file check can still say WHICH file broke it.
    FragmentSlots = @{
        NODE_LINK_ACTIONS      = 'ArrayElements'
        SELECTION_LINK_ACTIONS = 'ArrayElements'
        LINK_DIAGNOSTIC_ROWS   = 'ArrayElements'
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

    # How a browser reaches a node's actions on THIS backend, as data, for the
    # same reason Smoke is here. tests/browser/link-mode.cjs reads it and knows
    # nothing else about any backend.
    #
    # It lived in a $LINK_PROBE map in PSGraphRender.build.ps1 until v0.15.1,
    # which made the build task a second place this backend's shape was written
    # down - the defect the Smoke block above exists to prevent. Only a backend
    # declaring SlotsBySetting.LinkMode needs one, and the task throws by name
    # for one that declares modes and no way to drive them.
    LinkProbe = @{
        # The element to click in.
        Canvas = '#cy'

        # The button that opens a node's actions, and the container they land
        # in. `Open` is what proves a node was selected and defaults to Menu:
        # they are the same element for a context menu, and different for a
        # panel that names the item and then lists what it offers.
        Button = 'right'
        Menu   = '#node-menu'

        # What must exist before the probe touches anything.
        Ready  = '#cy canvas'
    }
}