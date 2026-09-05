    // The scene's mood: what is behind the graph, how distance reads, and how
    // bright the whole thing is. Everything here is driven by theme data and
    // nothing in it is a literal a variant would need to vary.

    // Whether the canvas is drawn over a CSS ground rather than filling itself.
    // 'flat' clears to PageBackground, which is what this backend did before
    // v0.16.0 and is still the right answer for a report that will be printed
    // or pasted into something with its own background.
    function backgroundStyle() {
        var style = cfgText('BackgroundStyle', 'flat');
        return (style === 'gradient' || style === 'vignette') ? style : 'flat';
    }

    function backgroundIsTransparent() {
        return backgroundStyle() !== 'flat';
    }

    // The stylesheet cannot branch on a custom property's VALUE, so the style
    // reaches CSS as an attribute. Set from the same setting the clear colour
    // is read from, in one place, because the two disagreeing means a
    // transparent canvas over no gradient - a black frame with no environment
    // and no way to tell it from a configuration mistake.
    function applyBackgroundAttribute() {
        document.documentElement.setAttribute('data-background', backgroundStyle());
    }

    // The clear colour handed to the library. A fully transparent one lets the
    // stylesheet's gradient show through the canvas, which is how the
    // environment costs nothing in the scene: no skybox, no extra geometry, no
    // texture to fetch - and a texture is the one thing that could not be
    // offline anyway.
    function backgroundClearColor() {
        return backgroundIsTransparent() ? 'rgba(0,0,0,0)' : cfgText('PageBackground', '#080b12');
    }

    // Exponential depth falloff, as a DUCK-TYPED object rather than a
    // constructed one, and that needs saying plainly because it is the one
    // place this backend leans on a shape it did not construct.
    //
    // three.js's FogExp2 CLASS is tree-shaken out of the vendored bundle - the
    // only occurrences of the name in the file are the `isFogExp2` flag the
    // renderer tests for. The renderer's SUPPORT is entirely intact: it reads
    // `fog.isFogExp2`, copies `fog.color` and passes `fog.density` to the
    // shader's `fogDensity` uniform, and every one of those names is in the
    // bundle. So the renderer is asked for fog with an object carrying exactly
    // those three things.
    //
    // three.js tests capability with `isXxx` flags rather than `instanceof`
    // precisely so that objects from elsewhere work; this uses that on purpose
    // and not by accident. `clone` and `toJSON` are present because Scene's own
    // serialisation calls them, and an object that cannot answer would throw
    // somewhere far away from here.
    //
    // Verified by rendering, not by reading: the alternative was vendoring
    // three.js a second time for one class.
    function makeFog(color, density) {
        return {
            isFogExp2: true,
            name: '',
            color: color,
            density: density,
            clone: function () { return makeFog(this.color, this.density); },
            toJSON: function () { return { type: 'FogExp2', color: 0, density: this.density }; }
        };
    }

    // The camera distance the shipped FogDensity is calibrated against, in
    // scene units. Chosen so the default puts about a fifth of the fog at the
    // middle of the graph - see below for the arithmetic.
    var FOG_REFERENCE_DISTANCE = 300;

    // Fog is NORMALISED to how far the camera ended up, and that is the
    // difference between a setting and a number that happened to work once.
    //
    // Exponential fog attenuates by distance FROM THE CAMERA, and the camera is
    // wherever zoomToFit put it, which depends entirely on how spread out the
    // payload is. Measured across the four fixtures, after the fit:
    //
    //   fixture          camera distance   graph extent
    //   ambiguous              224              156
    //   ecosystem              362              256
    //   sample-module          568              312
    //   infrastructure         565              367
    //
    // Two and a half times the range on the camera, which is what makes a fixed
    // density unusable: the same number is a hint on one payload and a blackout
    // on another. Normalising against the EXTENT was the first attempt and was
    // still wrong, because the camera does not sit at the edge of the graph -
    // it produced a near-constant 62% fog at the centre of every fixture, which
    // is consistent and far too much. Both numbers above are why: extent and
    // camera distance do not move together.
    //
    // FogExp2 attenuates by 1 - exp(-(density * depth)^2), so the fog at the
    // middle of the graph depends only on the product density * cameraDistance.
    // Holding that product fixed is what makes one value mean one appearance:
    //
    //   density = FogDensity * FOG_REFERENCE_DISTANCE / cameraDistance
    //
    // At the shipped 0.0016 the product is 0.48, which is 21% fog at the centre
    // of the graph, about 9% at the near face and about 34% at the far one.
    // That is a depth cue a reader can see and read through, which is the whole
    // requirement.
    function fogDensityFor(graph) {
        var configured = cfgNumber('FogDensity', 0.0016);
        if (configured <= 0) { return 0; }

        var box = graph.getGraphBbox();
        var camera = graph.cameraPosition();
        if (!box || !camera) { return configured; }

        var dx = camera.x - (box.x[0] + box.x[1]) / 2;
        var dy = camera.y - (box.y[0] + box.y[1]) / 2;
        var dz = camera.z - (box.z[0] + box.z[1]) / 2;
        var distance = Math.max(Math.sqrt(dx * dx + dy * dy + dz * dz), 1);
        return configured * (FOG_REFERENCE_DISTANCE / distance);
    }

    function applyFog(graph) {
        // Fog needs a Color, which is only reachable once a node mesh has been
        // made. A payload with no items has no fog and needs none: there is
        // nothing at any distance to fall off.
        if (!THREE_CTOR) { return; }
        var scene = graph.scene();
        var density = fogDensityFor(graph);
        scene.fog = density > 0
            ? makeFog(new THREE_CTOR.Color(cfgText('FogColor', '#05070d')), density)
            : null;
    }

    function applyScene(graph) {
        applyFog(graph);

        // The scene is emissive material on a dark ground, so its histogram
        // sits low and a flat exposure leaves it muddy. 4 is ACESFilmic, whose
        // shoulder is what keeps the glow shells from clipping to white where
        // they overlap - the numeric constant rather than the name, because
        // three.js's exported constants are values and the bundle re-exports
        // none of them.
        try {
            var renderer = graph.renderer();
            renderer.toneMapping = 4;
            renderer.toneMappingExposure = cfgNumber('ToneMappingExposure', 1.15);
        }
        catch (err) {
            // A renderer that cannot be configured still draws. Exposure is
            // the least load-bearing thing on this page and is not worth a
            // blank report.
        }
    }

    // The camera's controls. The library builds them; this only says how fast
    // they respond. Read back off the same object by tests/browser/look.cjs,
    // because a value that reaches CONFIG and not the controls is a setting
    // that exists in name only.
    function applyControls(graph) {
        try {
            var controls = graph.controls();
            controls.zoomSpeed = cfgNumber('ZoomSpeed', 0.9);
            controls.rotateSpeed = cfgNumber('RotateSpeed', 0.85);
        }
        catch (err) {
            // Nothing else depends on this having worked.
        }
    }

    // -- item materials ----------------------------------------------------

    // The lit body of an item. Emissive rather than merely coloured: a
    // Lambert surface on a dark ground with one directional light is almost
    // black wherever it faces away, and a graph is mostly items facing away.
    // Emission is what keeps an item readable from every angle, and it is what
    // "glow" means here.
    function coreMaterial(color, emphasis) {
        var strength = cfgNumber('GlowStrength', 0.85) * emphasis;
        return new THREE_CTOR.Material({
            color: color,
            emissive: new THREE_CTOR.Color(color),
            emissiveIntensity: strength,
            transparent: cfgNumber('NodeOpacity', 0.95) < 1,
            opacity: cfgNumber('NodeOpacity', 0.95)
        });
    }

    // The halo around it: the same shape, larger, drawn inside-out and added
    // to whatever is behind it.
    //
    //   side 1        BackSide, so the shell's far wall is what is drawn and
    //                 the item inside it is never hidden by its own glow.
    //   blending 2    AdditiveBlending, so it brightens rather than covers -
    //                 which is what a glow does and what an alpha-blended
    //                 shell conspicuously does not.
    //   depthWrite    off, so shells do not occlude each other and the sort
    //                 order stops mattering.
    //
    // The three numeric constants are three.js's own values. The bundle
    // exports no names to use instead, and they are stable API: BackSide has
    // been 1 and AdditiveBlending 2 since three.js had them.
    //
    // This is NOT a post-processing bloom, and the difference is visible: it is
    // per item, it occludes correctly against things in front of it, and it
    // does not bleed across the frame. The vendored bundle contains no bloom
    // pass and adding one means a second copy of three.js in the page. See
    // Config/theme.psd1 and docs/vendoring.md.
    function glowMaterial(color, emphasis) {
        return new THREE_CTOR.Material({
            color: color,
            transparent: true,
            opacity: cfgNumber('GlowOpacity', 0.22) * emphasis,
            blending: 2,
            side: 1,
            depthWrite: false
        });
    }
