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

        # -- A: the origins, and the shape channel -----------------------
        # A0 is what ships. A5 is what shipped BEFORE it, kept as a row rather
        # than as a paragraph so the promotion at v0.17.0 can be looked at
        # instead of read about. Between them, what an item IS and how big -
        # the channel this backend did not have before v0.16.0.
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
        @{
            Label = 'A5'; Family = 'A'
            Name = 'The v0.16.0 default'
            Caption = 'The look this backend shipped before v0.17.0 promoted the composed one: flat ground, no environment, no panel, a wider softer glow and a torus on exported items.'
            Overlay = @{
                # THE PREVIOUS ORIGIN, kept whole. Every value here was a
                # default until v0.17.0, so this row is the reversal: an
                # operator who preferred the old look can read what to move
                # back rather than reconstruct it from a changelog.
                #
                # It is also the honest comparison. A0 and A5 draw the same
                # payload through the same generator, so the difference between
                # the two pictures is exactly what this pass changed and
                # nothing else.
                BackgroundStyle = 'flat'; BackgroundGlowColor = '#16304d'
                GridStyle = 'none'
                ShowControlPanel = 'none'
                NodeSize = 14
                GlowStrength = 0.3; GlowSize = 1.55; GlowOpacity = 0.16
                ExportedEmphasis = 'glow'
                EdgeColor = '#57657a'; EdgeOpacity = 0.42; EdgeWidth = 1.0
                ParticleCount = 2; ParticleWidth = 1.6; ParticleColor = '#7fd4ff'
                KindColor = @{ Function = '#4da3ff'; Class = '#c78bff'; Enum = '#ffb84d'; Script = '#5ad1a5' }
                KindColorFallback = '#8895a7'
                FitPadding = 70
            }
        }

        # -- B: colour, mood, and what the graph sits in -----------------
        # The scene the items sit in. B1 and B2 are the backgrounds the default
        # is NOT, now that the default IS a vignette - which it could not be
        # until part 1 of pass 0052 replaced the byte-ratio floor a painted
        # background blinded. B5 and B6 are the other two environments.
        # Config/theme.psd1 carries both measurements.
        @{
            Label = 'B1'; Family = 'B'
            Name = 'Flat ground'
            Caption = 'BackgroundStyle vignette -> flat. One unbroken colour behind the graph - what shipped as the default until v0.17.0.'
            Overlay = @{ BackgroundStyle = 'flat' }
        }
        @{
            Label = 'B2'; Family = 'B'
            Name = 'Top-lit gradient'
            Caption = 'BackgroundStyle vignette -> gradient. The same environment lit from above rather than from behind.'
            Overlay = @{ BackgroundStyle = 'gradient' }
        }
        @{
            Label = 'B3'; Family = 'B'
            Name = 'Ember'
            Caption = 'A warm palette and a much stronger glow: GlowStrength 0.4 -> 1.4, GlowOpacity 0.1 -> 0.42, and warm KindColor.'
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
        @{
            Label = 'B5'; Family = 'B'
            Name = 'Enclosure'
            Caption = 'GridStyle floor -> room. Ruled on all six sides, so there is a reference whichever way the reader turns - which a floor stops giving at eye level.'
            Overlay = @{ GridStyle = 'room' }
        }
        @{
            Label = 'B6'; Family = 'B'
            Name = 'Ungrounded'
            Caption = 'GridStyle floor -> none. The graph with nothing at a known distance behind it - the complaint that prompted the environment, kept as a picture.'
            Overlay = @{ GridStyle = 'none' }
        }

        # -- C: connectors ------------------------------------------------
        # The links, which carry both direction and the producer's confidence.
        @{
            Label = 'C1'; Family = 'C'
            Name = 'Dense particles'
            Caption = 'ParticleCount 3 -> 6 and faster. Direction becomes the loudest thing on the page.'
            Overlay = @{ ParticleCount = 6; ParticleSpeed = 0.012; ParticleWidth = 2.2 }
        }
        @{
            Label = 'C2'; Family = 'C'
            Name = 'Heavy connectors'
            Caption = 'EdgeWidth 1.4 -> 3.0 and EdgeOpacity 0.62 -> 0.8, with no particles. Structure over motion.'
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
            Caption = 'ShowLabels hover -> always. Every item names itself, positioned over the canvas from its projected coordinates - which it did not actually do until v0.17.0.'
            Overlay = @{ ShowLabels = 'always' }
        }
        @{
            Label = 'D4'; Family = 'D'
            Name = 'No controls at all'
            Caption = 'ShowControlPanel open -> none. The panel is removed from the document rather than hidden - for a report built for print, or for a wall nobody can press.'
            Overlay = @{ ShowControlPanel = 'none' }
        }

        # -- E: composed looks --------------------------------------------
        # A whole aesthetic rather than one channel. Any of them can be
        # promoted to the default by moving its values into Config/theme.psd1,
        # which is the point of writing them as overlays.
        #
        # E1 IS GONE FROM THIS TABLE BECAUSE IT WON. "Nebula - the recommended
        # look" was pass 0051's answer to "make it look modern"; v0.17.0 moved
        # its treatments into Config/theme.psd1 and added the environment and
        # the panel on top, so E1 is now what A0 draws. A row for it would be a
        # second picture of the default, and rule 4 - one caption saying what
        # this changes FROM DEFAULT - cannot be written for a variant that
        # changes nothing.
        #
        # THE COORDINATE IS RETIRED RATHER THAN REUSED. A label is a thing the
        # operator points with, and a pointer that quietly starts meaning
        # something else is worse than one that is gone. E1 means "the look
        # that became the default at v0.17.0", and it means that permanently.
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
            Caption = 'Everything atmospheric off: no glow, no fog, no particles, no environment, flat ground. Three dimensions drawn as a diagram.'
            Overlay = @{
                GlowStrength = 0; GlowSize = 1; GlowOpacity = 0
                FogDensity = 0; ParticleCount = 0
                BackgroundStyle = 'flat'; GridStyle = 'none'; ToneMappingExposure = 1.0
                EdgeOpacity = 0.7; EdgeWidth = 1.4
                KindShape = 'Function=sphere; Script=cone; Config=box; Contract=octahedron'
                ExportedEmphasis = 'ring'
            }
        }
    )
}
