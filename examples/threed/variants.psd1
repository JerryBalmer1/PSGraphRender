@{
    # THE VARIANT TABLE. Nineteen labelled looks for the forcegraph3d backend,
    # in five families, and the only place any of them is written down.
    #
    # This file is DATA, read with Import-PowerShellDataFile and never executed.
    #
    # WHY IT EXISTS. The operator's complaint about this backend was that it
    # looked like a tech demo, and the reply to that cannot be a paragraph. A
    # look is judged by seeing it, and "do this, but like that" needs a `that`
    # to point at. So every variant here has a LABEL, and the label is the
    # vocabulary: A3, C1, E2. One coordinate instead of three sentences.
    #
    # HOW IT IS USED. examples/Build-Examples.ps1 reads this table and builds
    # every row - the document, the screenshot, and the catalogue page that
    # indexes them. The page is GENERATED from these rows and never written by
    # hand, so a variant exists in the catalogue because it exists here. Drift
    # is not prevented by discipline; it is impossible.
    #
    #   pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant all
    #   pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant E1
    #
    # THE RULES EVERY ROW FOLLOWS, and tests/ForceGraph3DLook.Tests.ps1 checks
    # all four:
    #
    #   1. ONE OVERLAY DIFF FROM DEFAULT. Overlay holds settings and theme keys
    #      and nothing else. A variant that needed a script edit would not be a
    #      variant, it would be a fork - and the whole claim of this pass is
    #      that the look is configuration.
    #   2. EVERY KEY IS DECLARED. Each name in an Overlay is an entry in the
    #      backend's own settings.schema.psd1. An undeclared key applies,
    #      warns on every render, and would put a look in the catalogue that no
    #      caller could reproduce.
    #   3. A0 IS THE DEFAULT, with an EMPTY overlay. Every conversation needs a
    #      fixed origin, and the origin has to be the thing that actually
    #      ships - so it is rendered with no overlay at all rather than with an
    #      overlay that restates the defaults.
    #   4. ONE CAPTION, ONE LINE, saying what this changes FROM DEFAULT. Not
    #      what it looks like - what was moved.
    #
    # ONE PAYLOAD FOR ALL OF THEM, deliberately. Every row draws
    # examples/input/ecosystem-viewmodel.json, the same twenty-four items the
    # layout examples use, so the ONLY difference between any two pictures in
    # the catalogue is the overlay between them. A variant that also changed
    # payload would be showing two things and proving neither.
    #
    # That payload carries four classifications - Function, Script, Config and
    # Contract - and the shipped KindShape names two of them. So A0 shows the
    # fallback doing its job on real data rather than in a fixture written to
    # make it look good, and A3 is what the same payload looks like when every
    # classification is mapped.

    Input    = 'input/ecosystem-viewmodel.json'
    Title    = 'forcegraph3d variant {label}'

    Variants = @(

        # -- A: shape and size -------------------------------------------
        # What an item IS, and how big. The channel this backend did not have
        # before v0.16.0: one geometry, one size, for everything.
        @{
            Label = 'A0'; Family = 'A'
            Name = 'The default'
            Caption = 'Nothing. This is what New-RenderDocument -TemplateSet forcegraph3d produces with no overlay, and every other variant is a diff from it.'
            Overlay = @{}
        }
        @{
            Label = 'A1'; Family = 'A'
            Name = 'Size by blast radius'
            Caption = 'NodeSizeMetric = blastRadius. Radius follows how much breaks if this changes, by rank.'
            Overlay = @{ NodeSizeMetric = 'blastRadius' }
        }
        @{
            Label = 'A2'; Family = 'A'
            Name = 'Size by reach, harder'
            Caption = 'NodeSizeMetric = reach and NodeSizeMetricMax 2.6 -> 4.5, so the spread between smallest and largest is wider.'
            Overlay = @{ NodeSizeMetric = 'reach'; NodeSizeMetricMax = 4.5 }
        }
        @{
            Label = 'A3'; Family = 'A'
            Name = 'Every classification its own solid'
            Caption = 'KindShape names all four of this payload''s classifications instead of two, so nothing falls back to a sphere.'
            Overlay = @{ KindShape = 'Function=sphere; Script=cone; Config=box; Contract=octahedron' }
        }
        @{
            Label = 'A4'; Family = 'A'
            Name = 'Shape channel off'
            Caption = 'KindShape empty, so every item takes NodeShapeFallback. What the backend drew before v0.16.0, on the new scene.'
            Overlay = @{ KindShape = '' }
        }

        # -- B: colour and mood ------------------------------------------
        # The scene the items sit in. B1 and B2 are the environment the
        # canvas-growth floor keeps out of the default - see Config/theme.psd1
        # for the measurement that decided it.
        @{
            Label = 'B1'; Family = 'B'
            Name = 'Vignette'
            Caption = 'BackgroundStyle = vignette. A centred glow behind the graph, so it sits IN something rather than against it.'
            Overlay = @{ BackgroundStyle = 'vignette' }
        }
        @{
            Label = 'B2'; Family = 'B'
            Name = 'Top-lit gradient'
            Caption = 'BackgroundStyle = gradient. The same environment lit from above rather than from behind.'
            Overlay = @{ BackgroundStyle = 'gradient' }
        }
        @{
            Label = 'B3'; Family = 'B'
            Name = 'Ember'
            Caption = 'A warm palette and a much stronger glow: GlowStrength 0.3 -> 1.4, GlowOpacity 0.16 -> 0.42, and warm KindColor.'
            Overlay = @{
                GlowStrength = 1.4; GlowOpacity = 0.42; GlowSize = 1.9
                ParticleColor = '#ffcf8a'
                KindColor = @{ Function = '#ff9a3c'; Class = '#ff5f6d'; Enum = '#ffd166'; Script = '#f0724a' }
                KindColorFallback = '#8a6b5a'
                PageBackground = '#0f0805'; FogColor = '#0a0503'
            }
        }
        @{
            Label = 'B4'; Family = 'B'
            Name = 'Deep ice'
            Caption = 'Cold and far: FogDensity 0.0016 -> 0.006, a cool monochrome KindColor, and almost no glow.'
            Overlay = @{
                FogDensity = 0.006; FogColor = '#02060c'
                GlowStrength = 0.12; GlowOpacity = 0.08
                KindColor = @{ Function = '#7fd4ff'; Class = '#a8c7e8'; Enum = '#d6ecff'; Script = '#5aa8d6' }
                KindColorFallback = '#4a6070'
            }
        }

        # -- C: connectors ------------------------------------------------
        # The links, which carry both direction and the producer's confidence.
        @{
            Label = 'C1'; Family = 'C'
            Name = 'Dense particles'
            Caption = 'ParticleCount 2 -> 6 and faster. Direction becomes the loudest thing on the page.'
            Overlay = @{ ParticleCount = 6; ParticleSpeed = 0.012; ParticleWidth = 2.2 }
        }
        @{
            Label = 'C2'; Family = 'C'
            Name = 'Heavy connectors'
            Caption = 'EdgeWidth 1.0 -> 3.0 and EdgeOpacity 0.42 -> 0.8, with no particles. Structure over motion.'
            Overlay = @{ EdgeWidth = 3.0; EdgeOpacity = 0.8; ParticleCount = 0; ArrowSize = 7 }
        }
        @{
            Label = 'C3'; Family = 'C'
            Name = 'Still'
            Caption = 'ParticleCount = 0. Nothing on the page moves after it settles - the right choice for a report read beside something else.'
            Overlay = @{ ParticleCount = 0 }
        }
        @{
            Label = 'C4'; Family = 'C'
            Name = 'Confidence in colour'
            Caption = 'LinkResolutionColor names every resolution this payload carries instead of only Ambiguous.'
            Overlay = @{
                LinkResolutionColor = @{ Certain = '#3d7a5a'; Ambiguous = '#e8a33d' }
                EdgeOpacity = 0.75; EdgeWidth = 1.8
            }
        }

        # -- D: interaction -----------------------------------------------
        # These are the variants a screenshot serves worst: a zoom speed does
        # not photograph. Their pictures show the parts that DO - the tooltip,
        # the highlight, the labels - and the caption carries the rest.
        @{
            Label = 'D1'; Family = 'D'
            Name = 'Slow and narrow'
            Caption = 'ZoomSpeed 0.9 -> 0.35, RotateSpeed 0.85 -> 0.4, HoverMode neighbors -> node. A deliberate camera that lights one item at a time.'
            Overlay = @{ ZoomSpeed = 0.35; RotateSpeed = 0.4; HoverMode = 'node' }
        }
        @{
            Label = 'D2'; Family = 'D'
            Name = 'Right-click, and say where'
            Caption = 'NodeActionButton left -> right and HoverTooltip labelAndKind -> labelAndLocation, so the tooltip names the file.'
            Overlay = @{ NodeActionButton = 'right'; HoverTooltip = 'labelAndLocation' }
        }
        @{
            Label = 'D3'; Family = 'D'
            Name = 'Names always on'
            Caption = 'ShowLabels hover -> always. Every item names itself, positioned over the canvas from its projected coordinates.'
            Overlay = @{ ShowLabels = 'always' }
        }

        # -- E: composed looks --------------------------------------------
        # A whole aesthetic rather than one channel. These are the ones to
        # judge: the pass's own answer to "make it look modern" is E1, and any
        # of them can be promoted to the default by moving its values into
        # Config/theme.psd1 - which is the point of writing them as overlays.
        @{
            Label = 'E1'; Family = 'E'
            Name = 'Nebula - the recommended look'
            Caption = 'The whole scene at once: vignette environment, every classification shaped, a slightly warmer palette, and a ring on everything the module exports.'
            Overlay = @{
                BackgroundStyle = 'vignette'; BackgroundGlowColor = '#173553'
                KindShape = 'Function=sphere; Script=cone; Config=box; Contract=octahedron'
                KindColor = @{ Function = '#4ea8ff'; Class = '#c78bff'; Enum = '#ffc55c'; Script = '#4fd6a8' }
                KindColorFallback = '#7c8ba1'
                GlowStrength = 0.32; GlowSize = 1.45; GlowOpacity = 0.14
                ExportedEmphasis = 'ring'
                ParticleCount = 3; ParticleWidth = 1.9; ParticleColor = '#9fe6ff'
                EdgeOpacity = 0.5; EdgeWidth = 1.2
                NodeSize = 12
            }
        }
        @{
            Label = 'E2'; Family = 'E'
            Name = 'Atlas - built to be read'
            Caption = 'Names on, shapes mapped, glow down and fog down: a look for finding one item rather than for looking at all of them.'
            Overlay = @{
                ShowLabels = 'always'
                KindShape = 'Function=sphere; Script=cone; Config=box; Contract=octahedron'
                GlowStrength = 0.18; GlowOpacity = 0.08; GlowSize = 1.3
                FogDensity = 0.0008
                EdgeOpacity = 0.55; ParticleCount = 1
                NodeSize = 11
            }
        }
        @{
            Label = 'E3'; Family = 'E'
            Name = 'Schematic - no atmosphere at all'
            Caption = 'Everything atmospheric off: no glow, no fog, no particles, flat ground. Three dimensions drawn as a diagram.'
            Overlay = @{
                GlowStrength = 0; GlowSize = 1; GlowOpacity = 0
                FogDensity = 0; ParticleCount = 0
                BackgroundStyle = 'flat'; ToneMappingExposure = 1.0
                EdgeOpacity = 0.7; EdgeWidth = 1.4
                KindShape = 'Function=sphere; Script=cone; Config=box; Contract=octahedron'
                ExportedEmphasis = 'ring'
            }
        }
    )
}
