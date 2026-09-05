@{
    # The third backend, and the one that tests the seam rather than
    # demonstrating it.
    #
    # `plain` proved that adding a backend is a directory, and docs/constraints.md
    # records why that proof is weaker than the count suggests: it renders a
    # table, asks configuration for nothing structural, and could not have
    # inherited a Cytoscape assumption because it has never heard of Cytoscape.
    # This one has a library, a canvas, its own vendoring question and all three
    # link modes - everything that could have leaked - and it was added without
    # editing a single .ps1 under src/. That is the claim, and
    # tests/ForceGraph.Tests.ps1 asserts the diff is empty.
    #
    # It draws in three dimensions and reads the same contract 1.1.0 payload as
    # the other two. No coordinate, position or layout field was needed: the
    # force simulation computes positions from nodes and links, and consulting a
    # fixed one is a capability it offers rather than an input it demands. That
    # was established from the vendored bundle before this file existed - see
    # vendor/vendor.psd1.
    Layout = 'layout.html'

    # Slot name -> ordered list of files whose contents replace it. Slots may
    # appear inside partials and inside scripts as well as in the layout;
    # substitution repeats until none are left.
    Slots  = @{
        STYLES = @('styles/base.css')
        GRAPH  = @('partials/graph.html')

        # The library, inlined so the page is one file that needs nothing. It is
        # an asset of THIS backend, not of the module. See vendor/vendor.psd1
        # for where it came from, the hash it was verified against, and why
        # there is no second file for three.js.
        VENDOR = @('vendor/3d-force-graph.min.js')

        SCRIPT           = @('scripts/bootstrap.js')
        SCRIPT_ACTIONS   = @('scripts/actions.js')
        SCRIPT_GRAPH     = @('scripts/graph.js')

        # Node links. These two are the DEFAULTS, and SlotsBySetting below
        # overrides them with whichever mode the render is configured for.
        # Stated here as well so a caller assembling with no configuration still
        # gets a working document, and so every file stays reachable from Slots.
        SCRIPT_NODE_LINK  = @('scripts/link/common.js', 'scripts/link/editor.js')
        NODE_LINK_ACTIONS = @('scripts/link/editor-node-actions.js')
    }

    # Slot contents a SETTING chooses between. The outer key names the setting,
    # each inner key one of its values, and the map replaces those slots in
    # Slots when that value is in force.
    #
    # This exists so link mode is resolved when the document is ASSEMBLED rather
    # than in the browser. A report is one self-contained file that gets
    # forwarded, so 'none' has to mean the scheme construction is not IN it -
    # not that a runtime branch declines to call it.
    #
    # An empty list is a real answer: it clears the slot, which is how 'none'
    # removes the link action without removing the panel it would have sat in.
    #
    # Only the modes that need common.js get it. The reference backend
    # assembles that file in all three because its Copy Path action needs an
    # absolute path in every mode; nothing here does, so 'hrefTemplate' and
    # 'none' carry less rather than carrying it unused - which is the same
    # argument the mode split is made of.
    SlotsBySetting = @{
        LinkMode = @{
            editor = @{
                SCRIPT_NODE_LINK  = @('scripts/link/common.js', 'scripts/link/editor.js')
                NODE_LINK_ACTIONS = @('scripts/link/editor-node-actions.js')
            }
            hrefTemplate = @{
                SCRIPT_NODE_LINK  = @('scripts/link/href.js')
                NODE_LINK_ACTIONS = @('scripts/link/href-node-actions.js')
            }
            none = @{
                SCRIPT_NODE_LINK  = @('scripts/link/none.js')
                NODE_LINK_ACTIONS = @()
            }
        }
    }

    # Slots whose parts are FRAGMENTS: text that is valid only where the slot
    # puts it. This one sits inside an array literal, so each part is a run of
    # array elements and `node --check` on one alone would report a syntax error
    # about the check rather than about the file.
    #
    # Declared by SLOT rather than by listing files, so a fourth link mode
    # brings its parts already covered instead of arriving unchecked and looking
    # checked.
    FragmentSlots = @{
        NODE_LINK_ACTIONS = 'ArrayElements'
    }

    # What "this page came alive" means for THIS backend, as data. The headless
    # harness in tests/browser/ reads it and knows nothing else about any
    # backend - a harness naming '#fg-nodes' would be a second place this
    # backend's shape is written down, somewhere other than this backend.
    #
    # A value names a payload collection, and the assertion is against its count.
    Smoke  = @{
        # Selector -> its text must be the count of that collection.
        Text     = @{ '#fg-nodes' = 'nodes'; '#fg-links' = 'links' }

        # Selector -> the number of elements matching it must be that count.
        Elements = @{}

        # Selectors that must match at least one element. The canvas is the
        # whole claim: WebGL that cannot initialise leaves the container empty
        # and every other assertion here still passes.
        Present  = @('#fg canvas', '#fg-status')

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
        # MEASURED, NOT COPIED. The reference backend records 12.2 and requires
        # 4, and taking those digits would have been the easiest thing to write
        # and wrong: this backend draws far less ink for the same payload -
        # lit spheres and thin lines on a dark ground, against filled boxes with
        # labels - so its numbers are lower and its floor is a different number.
        #
        # Measured at 1280x900 DSF 1 against this backend's own empty render
        # (5,168 bytes) in the same run, at two moments, because a force layout
        # is still moving when a check first looks at it:
        #
        #   fixture              while settling   settled
        #   ambiguous  (6/6)         4.51           6.49
        #   sample-module (9/5)      5.20           3.50
        #   infrastructure (17/20)   6.26           4.77
        #
        # The thinnest thing observed anywhere is 3.50 - sample-module settled,
        # which is nine items and five links spread across the frame and is
        # genuinely close to empty. Two is the floor. That is 1.75x below the
        # thinnest case, and the reference backend's 4 sits 1.84x below its own
        # thinnest (7.34); the same daylight, not the same digit, which is what
        # "four is not a marginal call" was actually claiming.
        #
        # It also fills in a gap the archive records as open. Thread 0006-t2
        # says this ratio "has never met a legitimately sparse payload" - 4x
        # required against measured values of 12.2 and 13.6, with nothing in
        # between. 3.50 is in between, and it comes from a backend that draws
        # sparsely by nature rather than from a payload that happens to be thin.
        CanvasGrowth = @{ '#fg' = 2 }
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
        Canvas = '#fg'

        # The button that opens a node's actions, the container they land in,
        # and what proves one was selected. Open and Menu are DIFFERENT here:
        # this backend opens a panel that names the item and then lists what it
        # offers, and in `none` mode the actions are empty by design while the
        # panel is not. Reading "did it open" off the action list would make
        # correct `none` behaviour indistinguishable from a click that landed
        # on nothing.
        Button = 'left'
        Menu   = '#fg-actions'
        Open   = '#fg-panel'

        # What must exist before the probe touches anything.
        Ready  = '#fg canvas'

        # A force simulation is still moving when the canvas first exists, and
        # the view fits itself when it stops. The probe clicks a point, so it
        # clicks after the item has stopped arriving at it.
        Settle = 3000

        # And this backend resolves what is under the pointer in its render
        # loop rather than on the event, so the pointer has to be somewhere
        # before the press.
        Hover  = 150
    }
}
