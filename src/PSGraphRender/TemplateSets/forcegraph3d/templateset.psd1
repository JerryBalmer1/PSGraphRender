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
        # Two stylesheets rather than one, split the way the reference backend
        # splits base from components: base.css is the document and the
        # drawing, controls.css is the one component that sits over it.
        STYLES = @('styles/base.css', 'styles/controls.css')
        GRAPH  = @('partials/graph.html')

        # The library, inlined so the page is one file that needs nothing. It is
        # an asset of THIS backend, not of the module. See vendor/vendor.psd1
        # for where it came from, the hash it was verified against, and why
        # there is no second file for three.js.
        VENDOR = @('vendor/3d-force-graph.min.js')

        SCRIPT           = @('scripts/bootstrap.js')
        SCRIPT_ACTIONS   = @('scripts/actions.js')

        # Geometry, mood and labels, split from the view rather than piled into
        # it. The split is by WHAT EACH ONE NEEDS TO KNOW: shapes.js knows the
        # vendored bundle's constructors and nothing about a payload, scene.js
        # knows the renderer and nothing about items, graph.js knows the
        # payload, and labels.js knows only how to put text where a projection
        # says. A change to the shape vocabulary touches one file.
        SCRIPT_SHAPES    = @('scripts/shapes.js')
        SCRIPT_SCENE     = @('scripts/scene.js')
        SCRIPT_GRAPH     = @('scripts/graph.js')
        SCRIPT_LABELS    = @('scripts/labels.js')

        # The control panel, and it is last on purpose: it is the only file
        # here that CONSUMES the others rather than declaring anything they
        # need. It knows what a reader asked for; scene.js and graph.js know
        # what consumes it, and every control is wired to the same object the
        # matching setting in Config/ reaches at render time.
        SCRIPT_PANEL     = @('scripts/panel.js')

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

        # Selector -> the fraction of that rectangle whose pixels the payload
        # must CHANGE, against the same selector in this backend's render of an
        # EMPTY payload.
        #
        # This view draws into a canvas, so every DOM assertion above passes
        # just as happily over a blank rectangle - which is exactly the failure
        # a smoke test exists to catch. A screenshot is the only thing that can
        # tell them apart, and the harness takes both pictures in the same run
        # on the same machine, so nothing here is pinned to the hardware that
        # wrote it.
        #
        # A DIFFERENCE RATHER THAN A RATIO, AND THAT IS THE POINT OF THE CHANGE.
        # Until v0.16.0 this was `CanvasGrowth`: drawn PNG bytes divided by
        # empty PNG bytes. Anything painted inside the captured rectangle is in
        # BOTH pictures, so it lands in the numerator and the denominator
        # together and drives the ratio toward 1 - which is why `Config/theme.psd1`
        # could not ship the environment it wanted. Measured on sample-module,
        # everything else held still:
        #
        #   BackgroundStyle    old ratio   new fraction
        #   flat                 4.32          0.0295
        #   vignette             1.05          0.0258
        #
        # The same drawing, the same ink, and the old gate calls one of them
        # blank: 1.05 is under the 2.25 that shipped. The new number barely
        # moves, because a background is identical in both pictures and
        # contributes no changed pixels at all. `styles/base.css` carried that
        # warning in prose from v0.15.0 and nothing turned the sentence into a
        # check - which is the whole of finding 67.
        #
        # MEASURED, NOT COPIED. Three consecutive runs of ./build.ps1 -Task
        # TestBrowser at 1280x900 DSF 1, per-channel threshold 12/255, against
        # this backend's own empty render:
        #
        #   fixture                 run 1    run 2    run 3
        #   ambiguous  (6/6)        0.1222   0.1222   0.1221
        #   sample-module (9/5)     0.0294   0.0294   0.0295
        #   infrastructure (17/20)  0.0294   0.0271   0.0294
        #
        # THREE RUNS RATHER THAN ONE, kept from v0.16.0 and still needed:
        # ParticleCount puts moving marks on every link, so a single reading of
        # a moving picture is a reading of its best moment. The spread is
        # wider on this metric than on the old one - 0.0271 against 0.0294 is
        # 8% - because a changed-pixel count is a threshold and a mark that
        # drifts one shade crosses it.
        #
        # The thinnest thing observed anywhere is 0.0271. The floor is 0.015,
        # which keeps this file's OWN standard for daylight rather than
        # inventing a new one: 2 over 3.50 was 1.75x, 2.25 over 4.03 was 1.79x,
        # and the reference backend's 4 over 7.34 is 1.84x. 0.015 under 0.0271
        # is 1.81x - the same daylight, again, on numbers that all moved.
        #
        # The table above is the v0.16.0 look. v0.17.0 changed the default -
        # an environment, a control panel and E1's treatments - and a floor
        # nobody re-examined after a look change is a gate quietly wrong in one
        # direction or the other, so it was measured again on what ships:
        #
        #   fixture                 run 1    run 2    run 3
        #   ambiguous  (6/6)        __RM1__  __RM2__  __RM3__
        #   sample-module (9/5)     __RM4__  __RM5__  __RM6__
        #   infrastructure (17/20)  __RM7__  __RM8__  __RM9__
        CanvasDelta = @{ '#fg' = 0.015 }
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
        #
        # SINCE v0.16.0 THIS IS A SETTING, and this value has to be the same one
        # Config/settings.psd1 ships as NodeActionButton. The page binds ONE
        # handler rather than both, so a probe pressing the other button opens
        # nothing and the whole link gate goes red - which is the correct
        # failure, and better than the alternative: a gate that pressed a fixed
        # button would stay green while the shipped document listened on
        # another, and the mode nobody drove would be the one every reader got.
        # tests/ForceGraph3DLook.Tests.ps1 asserts the two agree.
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

    # How a browser checks what this backend DREW, as data, for the same reason
    # Smoke and LinkProbe are here. tests/browser/look.cjs reads it and knows
    # nothing else about any backend.
    #
    # It exists because neither of the other two gates can see a look. Smoke
    # asks whether a page came alive and LinkProbe asks where a link goes, and
    # both are satisfied by a page that draws every item as the same blue ball
    # - which is exactly what this backend did until v0.16.0. A backend that
    # declares no LookProbe is skipped rather than failed: `plain` renders a
    # table and has no geometry, no hover and no camera, so demanding one of it
    # would be the gate inventing a requirement the backend never took on.
    LookProbe = @{
        # The element the drawing lives in, and what must exist before the
        # probe touches anything.
        Canvas   = '#fg'
        Ready    = '#fg canvas'

        # A force simulation is still moving when the canvas first exists, and
        # the view fits itself when it stops. Longer than LinkProbe's, because
        # the pixel cases compare two screenshots and a graph still drifting
        # would make two runs of the SAME document differ - which is a
        # difference the check must not be able to manufacture.
        Settle   = 3200
        Hover    = 220

        # Where the page states what it RESOLVED, per item: the classification
        # each item carries and the geometry the mapping produced for it, as
        # JSON in an attribute. The same argument as the counts in #fg-status -
        # a drawing cannot be read from the DOM, so a backend that makes one
        # says in text what it did.
        Resolved = '#fg-resolved'

        # And where it states what its LIVE objects report: zoom speed off the
        # controls, particle count off the graph, fog density off the scene.
        # Read back from the object that consumes each value rather than echoed
        # from CONFIG, because a value that reaches the document and never
        # reaches the object is exactly the failure this gate exists to catch.
        # data-hover on the same element carries what the last pointer move
        # highlighted.
        Live     = '#fg-live'

        # Where to look for an item, as fractions of the canvas box so the job
        # carries no pixel coordinate that holds at one viewport only. Scanned
        # in order until one lands: a fitted force layout puts items near the
        # centre but not reliably AT it.
        Points   = @(
            @(0.5, 0.5), @(0.42, 0.46), @(0.58, 0.54), @(0.5, 0.38), @(0.5, 0.62)
            @(0.36, 0.5), @(0.64, 0.5), @(0.44, 0.58), @(0.56, 0.42)
        )
    }
}
