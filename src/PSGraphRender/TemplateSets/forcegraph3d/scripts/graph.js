    // The view. Nodes and links go to the library as they arrive and it works
    // out where they belong: the contract carries no coordinate, no position
    // and no layout field, and this backend needs none.
    //
    // That was established from the vendored bundle before a line of this file
    // was written, rather than assumed from the phrase "force-directed". The
    // simulation consults a fixed position when a node states one - `fx`, `fy`,
    // `fz` - and computes one from a spherical lattice when it does not, which
    // is the direction that matters: it CAN take coordinates and does not ASK
    // for them. A backend that demanded them would need the payload to carry
    // them, and that is a contract change and therefore a decision nobody has
    // made. See vendor/vendor.psd1.
    //
    // Everything the drawing DOES is configuration. Shape, size, glow, fog,
    // background, particles, hover, labels and which button opens an item's
    // actions are all theme or settings values, and examples/threed/catalog.html
    // is what each of them looks like when moved. Nothing a variant needs to
    // vary is written down in this file.

    var graph = null;

    // id -> the Mesh drawn for it. Kept because hover has to change the
    // appearance of items OTHER than the one under the pointer, and the
    // library's own accessors only ever ask about one node at a time.
    var MESH_BY_ID = {};

    // id -> the ids it is linked to, either way round. Built once from the
    // payload rather than searched per hover: a hover on a 532-item graph
    // would otherwise walk every link on every pointer move.
    var NEIGHBORS = {};

    // What the page RESOLVED, per item, as a DOM fact. Same argument as the
    // counts in #fg-status: a canvas cannot be read, so a backend that draws
    // one has to state what it did once in pixels for a person and once in
    // text for a check. tests/browser/look.cjs reads this; nothing here
    // exposes the graph instance itself, because a global for tooling would
    // ship in every report.
    //
    // Keyed by id rather than appended to, because the library may ask for an
    // item's object more than once - a resize, a refresh, a second pass over
    // the accessor - and a list would then carry the same item twice and
    // report a count that is not the payload's.
    var RESOLVED_BY_ID = {};

    // The last thing handed to the library as a tooltip, as text. Recorded at
    // the moment the library asks for it, so what the check reads is what the
    // library was given rather than a second claim about it.
    var LAST_TOOLTIP = null;

    function byId(id) {
        return document.getElementById(id);
    }

    // The counts, as text a check can read. A canvas cannot be counted from the
    // DOM, so a backend that draws into one has to state the same fact twice -
    // once in pixels for a person and once in text for the harness. That is
    // what the Smoke block in templateset.psd1 names.
    function fillStatus() {
        byId('fg-nodes').textContent = String(nodes.length);
        byId('fg-links').textContent = String(links.length);
        byId('fg-nodes-label').textContent = str('NodesLabel');
        byId('fg-links-label').textContent = str('LinksLabel');
        byId('fg-title').textContent = meta.title || '';
        byId('fg-generated').textContent = meta.generatedAt
            ? fmt('Generated', { generatedAt: meta.generatedAt })
            : '';
        byId('fg-close').textContent = str('PanelClose');
        byId('fg-hint').textContent = str('Hint');
        byId('fg-status').hidden = false;
    }

    // A link may name a target the payload does not contain - the contract
    // permits it, and the force layout throws rather than tolerating it, which
    // would take the whole page down for one unresolved reference. So the
    // target is invented, the way the reference backend invents one, and drawn
    // in its own colour AND its own silhouette, because it is not a
    // classification: no producer sends it.
    function withInventedTargets(nodeList, linkList) {
        var known = {};
        var out = nodeList.slice();
        for (var i = 0; i < nodeList.length; i++) { known[nodeList[i].id] = true; }

        for (var j = 0; j < linkList.length; j++) {
            var ends = [linkList[j].source, linkList[j].target];
            for (var k = 0; k < ends.length; k++) {
                var id = ends[k];
                if (typeof id === 'string' && !known[id]) {
                    known[id] = true;
                    out.push({ id: id, name: id, invented: true });
                }
            }
        }
        return out;
    }

    function noteNeighbors(linkList) {
        function add(a, b) {
            if (!NEIGHBORS[a]) { NEIGHBORS[a] = {}; }
            NEIGHBORS[a][b] = true;
        }
        for (var i = 0; i < linkList.length; i++) {
            var s = linkList[i].source, t = linkList[i].target;
            var sid = (s && s.id !== undefined) ? s.id : s;
            var tid = (t && t.id !== undefined) ? t.id : t;
            if (sid === undefined || tid === undefined) { continue; }
            add(sid, tid);
            add(tid, sid);
        }
    }

    // One colour per classification, from theme data. Nothing here knows a
    // classification: the keys are whatever the payload carries and the map is
    // whatever the theme names, so a producer's vocabulary never reaches this
    // file. A classification the map does not name gets the fallback, and there
    // is always an unnamed case because a producer may send anything.
    function colorFor(node) {
        if (node.invented) { return cfgText('UnresolvedColor', '#ff7043'); }
        var map = (CONFIG && CONFIG.KindColor) || {};
        var named = node.kind && Object.prototype.hasOwnProperty.call(map, node.kind)
            ? map[node.kind] : null;
        return named || cfgText('KindColorFallback', '#8895a7');
    }

    // The same argument as colorFor, one channel over. An item the renderer
    // invented takes UnresolvedShape rather than a mapped one, because it has
    // no classification to map.
    var SHAPE_MAP = {};

    function shapeFor(node) {
        if (node.invented) {
            var invented = cfgText('UnresolvedShape', 'tetrahedron');
            return isBuildableShape(invented) ? invented : 'tetrahedron';
        }
        if (node.kind && Object.prototype.hasOwnProperty.call(SHAPE_MAP, node.kind)) {
            return SHAPE_MAP[node.kind];
        }
        var fallback = cfgText('NodeShapeFallback', 'sphere');
        return isBuildableShape(fallback) ? fallback : 'sphere';
    }

    // -- size --------------------------------------------------------------
    //
    // RANK over distinct values rather than magnitude, which is the same
    // algorithm the reference backend's heat ramp uses and carries the same
    // accepted limitation (docs/constraints.md, 0010-t5): on a skewed metric
    // the outliers separate cleanly and the bulk does not. It answers "which
    // of these is biggest", not "is this one twice that one" - and the raw
    // number is one click away in the panel, which answers the second question
    // exactly.
    //
    // Rank rather than magnitude on purpose here too: blast radius on a real
    // module runs 0 to 281 with a median of 1, and scaling by magnitude draws
    // 87% of a graph at the minimum size and one item the size of the frame.
    var METRIC_RANK = null;

    function buildMetricRank(nodeList) {
        METRIC_RANK = null;
        var key = cfgText('NodeSizeMetric', '');
        if (!key) { return; }

        var seen = {};
        var values = [];
        for (var i = 0; i < nodeList.length; i++) {
            var m = nodeList[i].metrics;
            var v = m && typeof m[key] === 'number' ? m[key] : null;
            if (v === null) { continue; }
            if (!Object.prototype.hasOwnProperty.call(seen, v)) { seen[v] = true; values.push(v); }
        }
        // Nothing to rank. A metric key that no item carries is not an error -
        // a producer may send a payload with different metrics than the one
        // this theme was written for - so it silently means "uniform", which is
        // what an unset key means too.
        if (values.length < 2) { return; }

        values.sort(function (a, b) { return a - b; });
        var rank = {};
        for (var j = 0; j < values.length; j++) { rank[values[j]] = j / (values.length - 1); }
        METRIC_RANK = { key: key, rank: rank };
    }

    function sizeFactorFor(node) {
        var factor = 1;
        if (METRIC_RANK) {
            var m = node.metrics;
            var v = m && typeof m[METRIC_RANK.key] === 'number' ? m[METRIC_RANK.key] : null;
            var r = (v === null || !Object.prototype.hasOwnProperty.call(METRIC_RANK.rank, v))
                ? 0 : METRIC_RANK.rank[v];
            factor *= 1 + r * (cfgNumber('NodeSizeMetricMax', 2.6) - 1);
        }
        // isExported is a field the payload already carries and nothing drew it
        // before v0.16.0. Only 'size' touches the radius; 'glow' is brightness
        // and is applied with the material instead. Both together is a
        // legitimate combination and the schema declines to forbid it.
        if (node.isExported && cfgText('ExportedEmphasis', 'glow') === 'size') { factor *= 1.35; }
        return factor;
    }

    // How brightly this item lights itself, before GlowStrength scales it.
    function emphasisFor(node) {
        var mode = cfgText('ExportedEmphasis', 'glow');
        if (mode === 'glow' && node.isExported) { return 1.6; }
        if (mode === 'none' || !node.isExported) { return 1; }
        return 1;
    }

    // -- the item itself ---------------------------------------------------
    //
    // Returning undefined leaves the library's own lit sphere in place, which
    // is the correct drawing when there is nothing to build geometry from - an
    // empty payload, or a browser where the harvest failed.
    function nodeObjectFor(node) {
        if (!THREE_CTOR) { return undefined; }

        // NodeSize IS the radius here, and that needs saying: nodeRelSize only
        // ever sized the library's own sphere, and a custom object is used as
        // it arrives. So the value that meant "radius of an item of unit value"
        // through the accessor has to mean the same thing through the
        // constructor, or the same theme draws two different sizes depending on
        // whether the harvest succeeded. Measured against the v0.15.1 render:
        // any other factor here makes the items visibly smaller than the
        // backend has always drawn them.
        var radius = cfgNumber('NodeSize', 14) * sizeFactorFor(node);
        var shape = shapeFor(node);
        var geometry = geometryFor(shape, radius);
        if (!geometry) { return undefined; }

        var color = colorFor(node);
        var emphasis = emphasisFor(node);
        var mesh = new THREE_CTOR.Mesh(geometry, coreMaterial(color, emphasis));

        // The halo, as a CHILD so it follows the item without the layout
        // needing to know it exists.
        var glowSize = cfgNumber('GlowSize', 1.8);
        var glowOpacity = cfgNumber('GlowOpacity', 0.22);
        if (glowSize > 1 && glowOpacity > 0) {
            var shell = geometryFor(shape, radius * glowSize);
            if (shell) { mesh.add(new THREE_CTOR.Mesh(shell, glowMaterial(color, emphasis))); }
        }

        // A ring is a second silhouette rather than a brighter one, for a
        // caller who wants exported items called out without spending the
        // brightness channel.
        if (node.isExported && cfgText('ExportedEmphasis', 'glow') === 'ring') {
            var ring = geometryFor('torus', radius * 1.5);
            if (ring) { mesh.add(new THREE_CTOR.Mesh(ring, glowMaterial(color, 2.2))); }
        }

        MESH_BY_ID[node.id] = mesh;
        RESOLVED_BY_ID[node.id] = { id: node.id, kind: node.kind || null, shape: shape, invented: !!node.invented };
        schedulePublish();
        return mesh;
    }

    // -- links -------------------------------------------------------------
    //
    // links[].resolution is a field the payload already carries and nothing
    // drew it before v0.16.0. The KEYS are the producer's own words; a
    // resolution the theme does not name draws in EdgeColor, which is the
    // honest answer for a word this renderer has never seen.
    function linkColorFor(link) {
        var map = (CONFIG && CONFIG.LinkResolutionColor) || {};
        var named = link.resolution && Object.prototype.hasOwnProperty.call(map, link.resolution)
            ? map[link.resolution] : null;
        return named || cfgText('EdgeColor', '#57657a');
    }

    // -- the hover label ---------------------------------------------------
    //
    // As an ELEMENT rather than a string, and that is not a style preference.
    // The library's tooltip does
    //     "string" == typeof content ? tooltipEl.html(content) : ... append(content)
    // so a string is inserted as MARKUP and an element is appended as itself. A
    // label is free text from a producer and one of them eventually contains a
    // bracket, so it goes in as an element whose textContent carries it - safe
    // by construction rather than by an escaper this file would have to get
    // right. Read out of the vendored bundle, not assumed.
    //
    // Every branch below builds elements and sets textContent. HoverTooltip
    // chooses WHAT is said and never HOW, so no setting can turn this into a
    // string and reopen the surface pass 0049 closed.
    function labelFor(node) {
        var mode = cfgText('HoverTooltip', 'labelAndKind');
        if (mode === 'none') {
            LAST_TOOLTIP = '';
            publishHover();
            return '';
        }

        var el = document.createElement('div');
        el.className = 'fg-tip';

        var name = document.createElement('div');
        name.className = 'fg-tip-name';
        name.textContent = node.name || node.id;
        el.appendChild(name);

        if (mode === 'labelAndKind' && node.kind) {
            var kind = document.createElement('div');
            kind.className = 'fg-tip-sub';
            kind.textContent = node.kind;
            el.appendChild(kind);
        }
        else if (mode === 'labelAndLocation') {
            var where = document.createElement('div');
            where.className = 'fg-tip-sub';
            where.textContent = node.path
                ? fmt('At', { path: node.path, line: node.startLine || 1 })
                : str('NoFile');
            el.appendChild(where);
        }

        LAST_TOOLTIP = el.textContent;
        publishHover();
        return el;
    }

    // -- hover -------------------------------------------------------------

    var HOVER_ID = null;

    // The set the last pointer move lit, kept rather than passed around.
    //
    // It has to be kept because TWO things publish the hover state and only one
    // of them knows the set: onHover computes it, and labelFor publishes again
    // when the library asks for a tooltip - which it does on the same pointer
    // move. Passing nothing from labelFor meant the tooltip's publish landed
    // last and overwrote a real count with zero, so every hover mode reported
    // nothing highlighted while the drawing was visibly highlighting. Found by
    // tests/browser/look.cjs on its first run, which is what it is for.
    var HIGHLIGHTED = {};

    function highlightSet(node) {
        var mode = cfgText('HoverMode', 'neighbors');
        if (!node || mode === 'none') { return {}; }
        var set = {};
        set[node.id] = true;
        if (mode === 'neighbors') {
            var near = NEIGHBORS[node.id] || {};
            for (var id in near) {
                if (Object.prototype.hasOwnProperty.call(near, id)) { set[id] = true; }
            }
        }
        return set;
    }

    // Applied to the MESHES rather than through the library's colour accessor,
    // because the change is to items other than the one the pointer is on and
    // the accessors only ever ask about one node at a time. Dimming the rest
    // rather than only brightening the few: in three dimensions the thing that
    // makes a subset readable is everything else getting out of the way.
    function applyHighlight(set) {
        var any = false;
        for (var id in set) { if (Object.prototype.hasOwnProperty.call(set, id)) { any = true; break; } }

        for (var key in MESH_BY_ID) {
            if (!Object.prototype.hasOwnProperty.call(MESH_BY_ID, key)) { continue; }
            var mesh = MESH_BY_ID[key];
            var lit = !any || set[key];
            var material = mesh.material;
            if (material.__baseEmissive === undefined) {
                material.__baseEmissive = material.emissiveIntensity;
                material.__baseOpacity = material.opacity;
            }
            material.emissiveIntensity = lit ? material.__baseEmissive * (any ? 1.9 : 1) : material.__baseEmissive * 0.25;
            material.opacity = lit ? material.__baseOpacity : material.__baseOpacity * 0.28;
            material.transparent = material.opacity < 1;
            for (var c = 0; c < mesh.children.length; c++) {
                var shell = mesh.children[c].material;
                if (shell.__baseOpacity === undefined) { shell.__baseOpacity = shell.opacity; }
                shell.opacity = lit ? shell.__baseOpacity : shell.__baseOpacity * 0.15;
            }
        }
    }

    function onHover(node) {
        HOVER_ID = node ? node.id : null;
        HIGHLIGHTED = highlightSet(node);
        applyHighlight(HIGHLIGHTED);
        if (!node) { LAST_TOOLTIP = null; }
        publishHover();
    }

    // -- what a check can read ---------------------------------------------
    //
    // Two hidden elements carrying JSON in attributes. They exist for the same
    // reason #fg-nodes does - a drawing cannot be read from the DOM - and they
    // are declared to the harness by name in templateset.psd1's LookProbe
    // block, so no gate names a selector of this backend's.
    //
    // The LIVE values are read back off the objects that consume them, not
    // echoed from CONFIG. A zoom speed written into the document and never
    // applied is precisely the failure this reports.
    // The library asks for an item's object once per item, in a batch, and it
    // does so in ITS OWN render cycle rather than when the accessor is
    // assigned. So the DOM fact is published on the first frame after a batch
    // finishes rather than after any single item - once, from a dirty flag,
    // because publishing per item would serialise the whole list N times for a
    // payload of N.
    var PUBLISH_PENDING = false;

    function schedulePublish() {
        if (PUBLISH_PENDING) { return; }
        PUBLISH_PENDING = true;
        window.requestAnimationFrame(function () {
            PUBLISH_PENDING = false;
            publishResolved();
            publishLive();
        });
    }

    function publishResolved() {
        var el = byId('fg-resolved');
        if (!el) { return; }
        var out = [];
        for (var id in RESOLVED_BY_ID) {
            if (Object.prototype.hasOwnProperty.call(RESOLVED_BY_ID, id)) { out.push(RESOLVED_BY_ID[id]); }
        }
        el.setAttribute('data-resolved', JSON.stringify(out));
    }

    function publishLive() {
        var el = byId('fg-live');
        if (!el) { return; }
        var live = { nodeActionButton: BOUND_BUTTON };
        try {
            var controls = graph.controls();
            live.zoomSpeed = controls.zoomSpeed;
            live.rotateSpeed = controls.rotateSpeed;
        }
        catch (err) { live.zoomSpeed = null; live.rotateSpeed = null; }
        try { live.particleCount = graph.linkDirectionalParticles(); }
        catch (err) { live.particleCount = null; }
        // The EFFECTIVE density, off the scene's own fog object. It is not the
        // configured number and must not be reported as one: fogDensityFor
        // scales it by camera distance so one setting means one appearance on
        // any payload. What a check can hold this to is proportionality, and
        // tests/browser/look.cjs does exactly that with two documents.
        try { var fog = graph.scene().fog; live.fogDensity = fog ? fog.density : 0; }
        catch (err) { live.fogDensity = null; }
        el.setAttribute('data-live', JSON.stringify(live));
    }

    function publishHover() {
        var el = byId('fg-live');
        if (!el) { return; }
        var count = 0;
        for (var id in HIGHLIGHTED) {
            if (Object.prototype.hasOwnProperty.call(HIGHLIGHTED, id)) { count++; }
        }
        el.setAttribute('data-hover', JSON.stringify({
            over: HOVER_ID, highlighted: count, tooltip: LAST_TOOLTIP
        }));
    }

    // Which button was actually bound, recorded rather than assumed. The
    // LinkProbe block in templateset.psd1 declares the same value, and
    // tests/ForceGraph3DLook asserts the two agree - a probe pressing a button
    // the document no longer listens on is a green gate over a dead feature.
    var BOUND_BUTTON = 'left';

    function drawGraph() {
        var laidOut = withInventedTargets(nodes, links);
        noteNeighbors(links);
        buildMetricRank(laidOut);
        SHAPE_MAP = parseShapeMap(cfgText('KindShape', ''));

        applyBackgroundAttribute();

        graph = ForceGraph3D()(byId('fg'))
            .backgroundColor(backgroundClearColor())
            // The library paints its own control hint into the container. It
            // is user-visible text this repository did not write and cannot
            // translate, and every user-visible string belongs in
            // Config/strings.psd1 - so it is off, and the status bar says the
            // same thing from there.
            .showNavInfo(false)
            .nodeRelSize(cfgNumber('NodeSize', 14))
            .nodeOpacity(cfgNumber('NodeOpacity', 0.95))
            .nodeColor(colorFor)
            .nodeLabel(labelFor)
            .linkColor(linkColorFor)
            .linkOpacity(cfgNumber('EdgeOpacity', 0.42))
            .linkWidth(cfgNumber('EdgeWidth', 1.0))
            .linkDirectionalArrowLength(cfgNumber('ArrowSize', 4))
            .linkDirectionalArrowRelPos(1)

            // Moving marks along each link. The one thing on this page that
            // says which way a link POINTS without a reader chasing an
            // arrowhead around a rotation, and the reason the default is two
            // rather than one: a single mark on a long link is off it more
            // often than on it.
            .linkDirectionalParticles(cfgNumber('ParticleCount', 2))
            .linkDirectionalParticleSpeed(cfgNumber('ParticleSpeed', 0.006))
            .linkDirectionalParticleWidth(cfgNumber('ParticleWidth', 1.6))
            .linkDirectionalParticleColor(function () { return cfgText('ParticleColor', '#7fd4ff'); })

            .onNodeHover(onHover)
            .onBackgroundClick(clearSelection)

            // The simulation is BOUNDED, and that is not a performance tweak.
            // The library stops on a timer that defaults to fifteen seconds,
            // which is longer than any gate here waits and longer than a reader
            // will watch a graph drift - so "fit the view when the layout
            // settles" never happened at all. Found by looking at the picture:
            // the drawing sat small and off-centre in the middle of the frame,
            // and the canvas-growth ratio it produced was 3.07 rather than the
            // 3.95 the fitted view gives.
            //
            // Ticks rather than milliseconds, so the same payload settles the
            // same way on a fast machine and a slow one. Warmup runs before the
            // first paint, so the opening view is a laid-out graph rather than
            // a knot unwinding.
            .warmupTicks(cfgNumber('WarmupTicks', 80))
            .cooldownTicks(cfgNumber('CooldownTicks', 160))

            .graphData({ nodes: laidOut, links: links.slice() });

        // Which button opens an item's actions. Bound to ONE of the two
        // handlers rather than to both with a branch inside, so a report built
        // for one gesture does not carry a listener for the other.
        BOUND_BUTTON = cfgText('NodeActionButton', 'left') === 'right' ? 'right' : 'left';
        if (BOUND_BUTTON === 'right') { graph.onNodeRightClick(selectNode); }
        else { graph.onNodeClick(selectNode); }

        applyScene(graph);
        applyControls(graph);

        // The canvas is sized from the container EXPLICITLY. Left to itself the
        // library opened a 1280x900 drawing buffer inside an 859px-tall box and
        // never corrected it, so the bottom of every graph was outside its own
        // element and the fit was computed against the wrong aspect. Measured
        // by reading canvas.width off the page, not inferred.
        sizeToContainer();
        window.addEventListener('resize', sizeToContainer);

        // The opening view fits what there is. Without it the camera sits at a
        // fixed distance and a small graph is a few pixels in the middle of a
        // dark rectangle - which is both unreadable and, measurably, a page the
        // canvas-growth floor can barely tell from a blank one.
        //
        // TWICE, and the first one is the load-bearing half. Fitting only when
        // the layout settles means the view is unfitted for as long as the
        // cooldown lasts - and a check that screenshots the page a second after
        // it loads is measuring that, not the fitted view. Warmup has already
        // run by the time graphData returns, so there is a laid-out graph to
        // fit immediately; the second fit is for the drift after it.
        fitView();
        graph.onEngineStop(fitView);

        upgradeDrawing(laidOut.length);

        startLabels(graph);
        publishResolved();
        publishLive();
        publishHover();
    }

    // Geometry can only be built from constructors the library has already
    // USED, and the library builds its first meshes in its own render loop
    // rather than while graphData returns. So the harvest waits for a frame in
    // which they exist, and then setting nodeThreeObject rebuilds every item as
    // the mapping says.
    //
    // Found by measuring rather than by reasoning: harvesting immediately after
    // graphData succeeded in a standalone probe that had waited a second, and
    // silently failed in the real page, where it ran synchronously. The
    // symptom was the correct one - a page that drew the library's own spheres
    // and reported no resolved shapes at all - because harvestConstructors
    // returns false rather than throwing when there is nothing to take.
    //
    // BOUNDED, so a payload that will never produce a mesh does not spin
    // forever: an empty one is skipped outright, and anything else gives up
    // after roughly two seconds of frames and keeps the library's default. A
    // page that draws plain spheres is a worse report; a page in a permanent
    // requestAnimationFrame loop is a worse machine.
    function upgradeDrawing(itemCount) {
        if (!itemCount) { return; }

        var frames = 0;
        (function attempt() {
            if (harvestConstructors(graph.scene())) {
                graph.nodeThreeObject(nodeObjectFor);
                // Fog needs a Color constructor, which only exists once the
                // harvest has run, so the scene is finished here rather than
                // above.
                applyScene(graph);
                // The accessor publishes for itself once its batch is done -
                // see schedulePublish. What is left here is the fit, because
                // custom geometry changes the graph's extent and the view was
                // fitted to spheres.
                window.requestAnimationFrame(fitView);
                return;
            }
            if (++frames > 120) { return; }
            window.requestAnimationFrame(attempt);
        }());
    }

    function sizeToContainer() {
        var box = byId('fg');
        graph.width(box.clientWidth).height(box.clientHeight);
    }

    // Fitting a graph with no EXTENT is not fitting, it is flying into it. A
    // payload of one item - or of items the layout has not separated yet - has
    // a bounding box of zero size, and the fit then puts the camera inside the
    // sphere it was asked to frame: the item fills the frame, looks perfect,
    // and is unclickable, because a ray cast from inside a solid never meets
    // its front face. Found by clicking an 81-point grid over a one-item
    // document and hitting nothing anywhere.
    //
    // So the fit is skipped when there is nothing to fit to. The default camera
    // already frames a single item, and a bounding box that gains extent later
    // gets fitted by the engine-stop pass.
    function fitView() {
        var box = graph.getGraphBbox();
        if (!box) { return; }
        var widest = Math.max(box.x[1] - box.x[0], box.y[1] - box.y[0], box.z[1] - box.z[0]);
        if (widest < cfgNumber('NodeSize', 14)) { return; }

        graph.zoomToFit(0, cfgNumber('FitPadding', 20));

        // The fog is normalised to the graph's extent, and the extent is only
        // known once there is one. Re-applied here rather than only at setup,
        // because this runs again when the layout settles and the extent it
        // settled to is not the extent it started with.
        applyFog(graph);
    }

    function clearSelection() {
        byId('fg-panel').hidden = true;
    }

    function selectNode(node) {
        byId('fg-name').textContent = node.name || node.id;
        byId('fg-where').textContent = node.path
            ? fmt('At', { path: node.path, line: node.startLine || 1 })
            : str('NoFile');

        var actions = byId('fg-actions');
        while (actions.firstChild) { actions.removeChild(actions.firstChild); }
        for (var i = 0; i < NODE_ACTIONS.length; i++) {
            var el = renderAction(NODE_ACTIONS[i], node);
            if (el) { actions.appendChild(el); }
        }

        byId('fg-panel').hidden = false;
    }

    byId('fg-close').addEventListener('click', clearSelection);
