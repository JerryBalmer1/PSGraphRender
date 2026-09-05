@{
    # Appearance: what it looks like. Behaviour lives in settings.psd1.
    #
    # A dark ground, unlike the other two backends, and that is not taste. This
    # view is lit geometry: the library shades solids and lines with a light
    # source, and pale material on a pale ground loses the shading that says
    # which way an item is facing. It is also what makes the canvas-growth floor
    # mean anything - an empty render is a flat dark rectangle and a drawn one
    # is not.
    #
    # v0.16.0 made this a designed scene rather than a default one. Every value
    # below that is new since v0.15.1 is a choice with a reason beside it, and
    # every one of them is what one variant in examples/threed/catalog.html
    # moves. The catalogue is how a reader disagrees with a decision made here
    # by pointing at a picture instead of describing one.

    PageBackground      = '#080b12'
    BodyColor           = '#e6edf3'
    MutedColor          = '#8b949e'
    AccentColor         = '#58a6ff'
    ChromeBackground    = '#0e1420'
    ChromeBorder        = '#1f2937'
    BodyFont            = 'system-ui, -apple-system, Segoe UI, sans-serif'

    # Item geometry. Radius is nodeRelSize in the library's terms: the size of
    # an item of unit value.
    NodeSize            = 14
    NodeOpacity         = 1

    # -- Shape ---------------------------------------------------------------
    # One geometry per classification. The KEYS are whatever the payload
    # carries; the renderer does not know them and must not - the same rule
    # KindColor is built on, and for the same reason.
    #
    # A grammar in a string rather than a map, and that is a limitation rather
    # than a design. A `ShapeMap` type beside `ColorMap` is the right shape for
    # this and it needs a validator in src/PSGraphRender/Private/Config/, which
    # is a module change; this pass adds a backend's look and edits no .ps1.
    # Logged in docs/improvements.md as the proposal it is. The page validates
    # each shape name against the geometry it can actually build and falls back
    # for anything it cannot, so a typo degrades one classification rather than
    # the page.
    #
    # The four names are the four KindColor already names, deliberately: a
    # payload that reads one way by colour reads the same way by silhouette,
    # and a reader who has learnt one has learnt the other. Classifications
    # beyond them - and every producer has some - take NodeShapeFallback.
    KindShape           = 'Function=sphere; Class=box; Enum=octahedron; Script=cone'

    # For a classification KindShape does not name. A producer may send
    # anything, so this branch is always reachable: `infrastructure.json` maps
    # none of its four kinds and is drawn entirely from here.
    #
    # sphere, because it is the shape that claims the least. A fallback with a
    # strong silhouette reads as a classification of its own, and "I have no
    # rule for this" is not a classification.
    NodeShapeFallback   = 'sphere'

    # For an item the renderer INVENTED because a link named a target the
    # payload does not contain. A distinct silhouette rather than only a
    # distinct colour: this is the one item on the page that is not a thing the
    # producer said exists, and colour alone puts that fact in the same channel
    # as every classification.
    UnresolvedShape     = 'tetrahedron'

    # -- Size by metric ------------------------------------------------------
    # Which of the payload's own metrics scales an item, by key. Empty means
    # uniform, and that is the shipped default on purpose: the renderer does
    # not know what a producer's metrics MEAN, and picking one to make things
    # big would be the renderer deciding what the data is about - the same line
    # docs/constraints.md draws for the fill channel.
    #
    # A caller who knows their payload sets one key. A1 and A2 in the
    # catalogue are what blastRadius and reach look like.
    NodeSizeMetric      = ''
    # How many times the radius of the smallest the largest item may reach.
    # Rank over distinct values rather than magnitude, the same algorithm the
    # heat ramp uses and with the same accepted limitation (0010-t5): it
    # answers "which of these is worst", not "is this one twice that one".
    NodeSizeMetricMax   = 2.6

    # -- Exported ------------------------------------------------------------
    # isExported is a field the payload already carries and nothing drew it
    # before v0.16.0. 'glow' rather than 'size' or 'ring': size is already
    # spoken for by NodeSizeMetric and would collide with it the moment both
    # are set, and a ring is a second silhouette competing with the shape.
    # Brightness is the one channel nothing else here uses.
    ExportedEmphasis    = 'glow'

    # -- Glow ----------------------------------------------------------------
    # Emissive material plus an additively-blended back-face shell, which is
    # what "bloom" means here and it is worth being exact about why. The
    # vendored bundle contains no post-processing bloom pass: `UnrealBloomPass`
    # and `ShaderPass` are absent from 3d-force-graph@1.80.0, verified by
    # inspection of the bytes, and the composer it does expose holds only a
    # render pass. Adding one means vendoring three.js AGAIN - the addon is an
    # ES module that imports it - and a second copy of three.js in the page is
    # what the bundle's own "Multiple instances" warning exists to report. See
    # vendor/vendor.psd1 and docs/vendoring.md.
    #
    # So the glow is geometry rather than a filter: it is per-item, it occludes
    # correctly against items in front of it, and it costs one extra mesh per
    # item instead of three full-frame passes. What it cannot do is bleed
    # across the whole frame the way a real bloom does, and that is the trade.
    GlowStrength        = 0.3
    # Shell radius as a multiple of the item's own. Below about 1.4 it reads as
    # a rim light rather than a glow; above about 2.5 neighbouring items merge
    # into one cloud at the densities this renderer sees.
    GlowSize            = 1.55
    # Faint on purpose. The shells are additive, so they SUM where they
    # overlap: a value that looks right on one item is a white blob on six.
    GlowOpacity         = 0.16

    # -- Depth ---------------------------------------------------------------
    # Exponential fog, which is the depth cue that makes a cloud of items read
    # as having a front and a back. Without it every item is equally bright at
    # every distance and the drawing flattens into a disc.
    #
    # 0.0016 is tuned to the scene scale the force layout actually produces:
    # the far side of a 24-item graph sits around 600 units out, where this
    # density removes roughly 60% of an item's brightness. Denser than about
    # 0.004 and the back half disappears rather than recedes.
    FogDensity          = 0.0016
    # Slightly darker than the page, not equal to it. Fog that matches the
    # background exactly makes distant items dissolve into nothing; a shade
    # below it keeps a silhouette and reads as depth rather than as absence.
    FogColor            = '#05070d'

    # -- Environment ---------------------------------------------------------
    # What is behind the graph, and the one value here that is NOT the choice
    # this pass would have made on looks alone.
    #
    # 'vignette' is better looking and it was the default until it was
    # measured. The canvas-growth floor in templateset.psd1 screenshots this
    # element and compares it against the SAME element in an empty render, and
    # a gradient is in both pictures - so it does not move the ratio, it
    # removes it. Measured on sample-module at 1280x900, everything else held
    # still:
    #
    #   BackgroundStyle   empty px     drawn px   ratio
    #   flat                 5,168       19,586    3.79
    #   gradient           313,384      329,766    1.05
    #   vignette           313,384      329,766    1.05
    #
    # And it is not a matter of degree. A gradient whose two colours differ by
    # two steps per channel - #0a0e18 against #080b12, invisible in a
    # screenshot - still costs 122,355 bytes of empty render and still scores
    # 1.14. PNG cannot compress a gradient, and the floor is the ONLY thing
    # that can tell a drawn 3D view from a blank one: every DOM assertion in
    # the Smoke block passes just as happily over an empty rectangle.
    #
    # So the trade is a background against the gate that proves the page draws,
    # and the gate wins. The environment is not gone - it is declared, it is
    # implemented, and B1 and B2 in the catalogue are what it looks like. An
    # operator who wants it as the default is choosing to weaken that gate, and
    # this comment is so that choice is made rather than inherited.
    BackgroundStyle     = 'flat'
    # The tint the vignette lifts toward its centre. A cold blue, well below
    # the accent, so it reads as distance rather than as a coloured light
    # somebody would look for the source of.
    BackgroundGlowColor = '#16304d'

    # -- Connectors ----------------------------------------------------------
    # Thin and translucent on purpose: in three dimensions every link crosses
    # every other one somewhere, and opaque lines at cytoscape's weight read as
    # a solid mesh from most angles.
    EdgeColor           = '#57657a'
    EdgeOpacity         = 0.42
    EdgeWidth           = 1.0
    ArrowSize           = 4

    # Moving particles along each link, which is the one thing on this page
    # that says which way a link POINTS without the reader chasing an arrowhead
    # around a rotation. Two rather than one: a single particle on a long link
    # is off the link more often than on it, and the direction is only readable
    # while it is moving.
    #
    # Zero is a real setting and C3 in the catalogue is what it looks like -
    # a still page, which is the right choice for a report that will be read
    # beside something else.
    ParticleCount       = 2
    ParticleSpeed       = 0.006
    ParticleWidth       = 1.6
    ParticleColor       = '#7fd4ff'

    # -- Link confidence -----------------------------------------------------
    # links[].resolution is a field the payload already carries and nothing
    # drew it before v0.16.0. The KEYS are the producer's words, not this
    # renderer's - `Certain`, `Ambiguous`, `Unique` and `SameFile` all appear
    # in the fixtures, and a producer may send others. A resolution this map
    # does not name draws in EdgeColor, which is the honest answer: the
    # renderer has no opinion about a word it has never seen.
    #
    # Only `Ambiguous` is coloured by default, and only it is worth colouring:
    # it is the one value that means the producer was NOT SURE, and a reader
    # deciding from this page deserves to see which lines are guesses.
    LinkResolutionColor = @{
        Ambiguous = '#e8a33d'
    }

    # One colour per classification. The keys are whatever the payload carries;
    # the renderer does not know them and must not. Same values as the reference
    # backend ships, so the same payload reads the same way in both.
    KindColor           = @{
        Function = '#4da3ff'
        Class    = '#c78bff'
        Enum     = '#ffb84d'
        Script   = '#5ad1a5'
    }
    KindColorFallback   = '#8895a7'

    # For an item the renderer invented because a link named a target the
    # payload does not contain. Not a classification: no producer sends it.
    UnresolvedColor     = '#ff7043'

    # -- Camera and chrome ---------------------------------------------------
    # Slightly above neutral. The scene is emissive material on a dark ground,
    # so the histogram sits low and a flat exposure leaves it muddy; 1.15 lifts
    # the mid-range without clipping the glow shells to white.
    ToneMappingExposure = 1.0

    PanelWidth          = 340

    # Room left around the graph when the opening view fits it, in the library's
    # own units.
    #
    # Raised from 20 at v0.16.0, and it had to be: zoomToFit frames the graph
    # from node POSITIONS and the library's own idea of an item's radius, and a
    # custom object is neither. A glow shell at GlowSize reaches half again as
    # far as the item it wraps, so the old padding put the outermost items'
    # haloes off the bottom of the frame. Measured by looking - the fit was
    # correct for the data and wrong for the drawing.
    FitPadding          = 70
}
