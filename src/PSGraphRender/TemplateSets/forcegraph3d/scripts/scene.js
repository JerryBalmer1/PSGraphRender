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

    // The panel's live value, or null while nobody has moved the slider. Kept
    // as an OVERRIDE rather than by writing into CONFIG: CONFIG is what the
    // document was rendered with, tests/browser/look.cjs compares against it,
    // and a page that edited its own configuration would make the two
    // indistinguishable.
    var FOG_OVERRIDE = null;

    function configuredFogDensity() {
        return FOG_OVERRIDE === null ? cfgNumber('FogDensity', 0.0016) : FOG_OVERRIDE;
    }

    function fogDensityFor(graph) {
        var configured = configuredFogDensity();
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

    // -- the environment ---------------------------------------------------
    //
    // What the graph sits IN. Until v0.17.0 there was nothing: a fitted view
    // put a cloud of items in the middle of an unbroken rectangle, and a cloud
    // with no reference has no near and no far. Fog said "this one is further
    // away" and nothing said how much further, because nothing was at a known
    // distance to compare against.
    //
    // IT COULD NOT SHIP BEFORE THE FLOOR WAS REPAIRED, and that is the whole
    // reason this pass has two halves in one order. The smoke gate screenshots
    // #fg and used to divide by the same element in an EMPTY render, so
    // anything drawn in that rectangle for both payloads sat in the numerator
    // and the denominator together - which is what took a vignette from 4.32
    // to 1.05. The gate is a changed-pixel fraction now, so an environment
    // cancels instead of blinding it. See templateset.psd1.
    //
    // A GRID IS SCENE GEOMETRY AND NOT A CSS BACKDROP, unlike BackgroundStyle,
    // and the difference is the one that matters here: it has to rotate with
    // the camera. A perspective floor painted in CSS looks right in a
    // screenshot and reads as broken the instant a reader drags, because the
    // one thing a ground plane has to do is stay where the ground is.
    var GRID_MESH = null;

    // The panel's live choice, or null while nobody has changed it. Same
    // argument as FOG_OVERRIDE: CONFIG stays what the document was rendered
    // with.
    var GRID_OVERRIDE = null;

    // Emissive rather than lit, for the reason the item cores are: a Lambert
    // surface on a dark ground with one directional light is nearly black
    // wherever it faces away, and half of a room faces away by construction.
    //
    // side 2 is DoubleSide - a floor has to be visible from under it, and a
    // room is seen from inside. depthWrite off so the environment never
    // occludes an item: it is a reference, and a reference that hides the
    // thing being referenced is scenery.
    //
    // FOG APPLIES TO IT, and that is the point rather than a side effect. The
    // far edge of a ruled plane fades at a rate the reader can read, which is
    // what turns fog from "things get dimmer" into a measurable distance.
    function gridMaterial() {
        var color = new THREE_CTOR.Color(cfgText('GridColor', '#2b4a6b'));
        return new THREE_CTOR.Material({
            color: color,
            emissive: color,
            emissiveIntensity: cfgNumber('GridGlow', 0.55),
            transparent: true,
            opacity: cfgNumber('GridOpacity', 0.5),
            side: 2,
            depthWrite: false
        });
    }

    function gridStyle() {
        var style = GRID_OVERRIDE === null ? cfgText('GridStyle', 'floor') : GRID_OVERRIDE;
        return isBuildableGrid(style) ? style : 'none';
    }

    // Rebuilt rather than scaled, because the graph's extent changes twice -
    // once when warmup ends and once when the simulation settles - and a grid
    // sized to the first is the wrong size for the second.
    function applyEnvironment(graph) {
        if (!THREE_CTOR) { return; }
        var scene = graph.scene();

        if (GRID_MESH) {
            scene.remove(GRID_MESH);
            // Disposed by hand: this runs again on every fit, and a page that
            // dropped a geometry per fit would leak GPU memory for as long as
            // it is open.
            if (GRID_MESH.geometry) { GRID_MESH.geometry.dispose(); }
            if (GRID_MESH.material) { GRID_MESH.material.dispose(); }
            GRID_MESH = null;
        }

        var style = gridStyle();
        if (style === 'none') { return; }

        var box = graph.getGraphBbox();
        if (!box) { return; }

        var centre = [
            (box.x[0] + box.x[1]) / 2,
            (box.y[0] + box.y[1]) / 2,
            (box.z[0] + box.z[1]) / 2
        ];
        // Half the widest span, times the room the theme asks for. Sized to
        // the graph rather than to a constant: a grid built to a fixed number
        // is either inside a large payload or a speck under a small one.
        var widest = Math.max(
            box.x[1] - box.x[0], box.y[1] - box.y[0], box.z[1] - box.z[0], cfgNumber('NodeSize', 14) * 4);
        var reach = (widest / 2) * cfgNumber('GridExtent', 1.7);

        var geometry = buildGridGeometry(
            style, centre, reach,
            Math.max(2, Math.round(cfgNumber('GridDivisions', 14))),
            // Line width scales with the grid, so the ruling reads the same
            // whatever size the payload is. A constant width is a hairline on
            // a large graph and a stripe on a small one.
            reach * cfgNumber('GridLineWidth', 0.004),
            // Where a GROUND plane goes: just under the lowest item, by a
            // fraction of the graph rather than a fixed distance.
            box.y[0] - widest * cfgNumber('GridDrop', 0.16));
        if (!geometry) { return; }

        GRID_MESH = new THREE_CTOR.Mesh(geometry, gridMaterial());
        // Behind everything, so a translucent environment never sorts in
        // front of an item it is supposed to sit behind.
        GRID_MESH.renderOrder = -1;
        scene.add(GRID_MESH);
    }

    // -- the camera, turning by itself -------------------------------------
    //
    // BY HAND, because the controls the library builds are TrackballControls
    // and TrackballControls has no autoRotate - that is OrbitControls, and the
    // bundle ships one of the two. Read off the live object rather than
    // assumed: its own keys are rotateSpeed, zoomSpeed, panSpeed, noRotate,
    // staticMoving, dynamicDampingFactor and target, and there is no
    // autoRotate among them.
    //
    // So the camera is moved around the controls' own target, which is the
    // point they already orbit, and the controls follow rather than fight.
    // OFF BY DEFAULT and deliberately: a report that spins on its own cannot
    // be screenshotted twice the same way, and this repository's catalogue,
    // its pixel gate and its floor all compare two pictures.
    var AUTO_ROTATE = false;
    var AUTO_ROTATE_FRAME = null;

    function autoRotateStep() {
        if (!AUTO_ROTATE) { AUTO_ROTATE_FRAME = null; return; }
        try {
            var camera = graph.cameraPosition();
            var target = graph.controls().target;
            var dx = camera.x - target.x;
            var dz = camera.z - target.z;
            var angle = cfgNumber('AutoRotateSpeed', 0.12) * Math.PI / 180;
            var cos = Math.cos(angle), sin = Math.sin(angle);
            graph.cameraPosition({
                x: target.x + dx * cos - dz * sin,
                y: camera.y,
                z: target.z + dx * sin + dz * cos
            });
        }
        catch (err) {
            // A camera that cannot be driven is not worth a broken page.
            AUTO_ROTATE = false;
            AUTO_ROTATE_FRAME = null;
            return;
        }
        AUTO_ROTATE_FRAME = window.requestAnimationFrame(autoRotateStep);
    }

    function setAutoRotate(on) {
        AUTO_ROTATE = !!on;
        if (AUTO_ROTATE && AUTO_ROTATE_FRAME === null) {
            AUTO_ROTATE_FRAME = window.requestAnimationFrame(autoRotateStep);
        }
        publishLive();
    }

    function isAutoRotating() { return AUTO_ROTATE; }

    // How many objects the environment actually put in the scene, counted off
    // the scene rather than inferred from the setting. `floor` is one mesh and
    // `none` is nought, and a page that resolved a style and built nothing
    // reports the difference here instead of looking identical to one that
    // did. tests/browser/look.cjs reads it.
    function gridMeshCount() {
        return GRID_MESH ? 1 : 0;
    }

    function applyScene(graph) {
        applyFog(graph);
        applyEnvironment(graph);

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

    // -- what the control panel moves --------------------------------------
    //
    // Every one of these writes to the SAME object the corresponding setting
    // in Config/ writes to at render time. That is the panel's whole contract:
    // it adjusts at runtime what configuration decides at assembly, so a
    // reader who moves a slider and a caller who sets a value are changing one
    // thing and not two.
    //
    // Which is also why they are here rather than in the panel. The panel
    // knows what a reader asked for; this file knows what consumes it.

    // EVERY ONE OF THESE REPUBLISHES, and that is not bookkeeping. #fg-live is
    // how a check reads what the scene actually holds, and a setter that moved
    // the scene without republishing leaves the page reporting the value it had
    // before - which reads exactly like a control that does nothing. Four of
    // these five shipped without it for the length of one test run and the look
    // gate caught all four by name; that is what the gate is for.

    function setZoomSpeed(value) {
        try { graph.controls().zoomSpeed = value; }
        catch (err) { /* a page whose controls will not take a number still draws */ }
        publishLive();
    }

    function setFogDensity(value) {
        FOG_OVERRIDE = value;
        applyFog(graph);
        publishLive();
    }

    function setGridStyle(style) {
        // Written through CONFIG's reader rather than into CONFIG, for the
        // reason FOG_OVERRIDE exists. An unbuildable name draws nothing, the
        // same answer the render-time path gives.
        GRID_OVERRIDE = isBuildableGrid(style) || style === 'none' ? style : null;
        applyEnvironment(graph);
        publishLive();
    }

    function fitNow() {
        fitView();
        publishLive();
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

    // The rim an exported item wears when ExportedEmphasis says so, and it
    // gets its OWN material rather than borrowing the glow shell's.
    //
    // Borrowing was the first version and it was wrong in a way only a picture
    // showed: the shell's opacity is GlowOpacity, so a look that turns the glow
    // off turns the mark off with it - and E3 in the catalogue is exactly that
    // look, a schematic with no atmosphere at all, which is also the look where
    // a crisp mark is most useful. Two channels the theme controls separately
    // must not be one channel here.
    //
    // AN INVERTED HULL, not a torus, and v0.17.0 changed that because a picture
    // showed the torus was wrong too. A ring is a shape in a PLANE: it lies
    // flat through the item, reads as a saucer from most angles and vanishes
    // edge-on - and this view's whole premise is that the reader is turning it.
    // The old geometry was also the `torus` NODE shape, sized to have a
    // sphere's visual mass, so its tube was wider than the item's own radius.
    //
    // A slightly larger copy of the item's OWN shape, drawn back-face only,
    // shows exactly where the silhouette is and nowhere else: the item is
    // opaque and occludes the hull's far wall everywhere they overlap, so what
    // survives is a thin outline around the edge. It follows the silhouette
    // from every angle, it costs one mesh, and it is the "rim rather than a
    // washed halo" this pass was asked for.
    //
    // Solid rather than additive: a mark that brightens what is behind it
    // disappears against a bright item.
    function rimMaterial(color) {
        return new THREE_CTOR.Material({
            color: color,
            emissive: new THREE_CTOR.Color(color),
            emissiveIntensity: 0.9,
            transparent: true,
            opacity: 0.9,
            // side 1 is BackSide. depthWrite off so the hull never occludes
            // the item it outlines, and depth TESTING - which stays on - is
            // what makes only the rim survive.
            side: 1,
            depthWrite: false
        });
    }

