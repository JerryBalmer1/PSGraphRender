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

    var graph = null;

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
    // in its own colour because it is not a classification: no producer sends
    // it.
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

    // The hover label, as an ELEMENT rather than a string, and that is not a
    // style preference. The library's tooltip does
    //     "string" == typeof content ? tooltipEl.html(content) : ... append(content)
    // so a string is inserted as markup and an element is appended as itself. A
    // label is free text from a producer and one of them eventually contains a
    // bracket, so it goes in as an element whose textContent carries it - safe
    // by construction rather than by an escaper this file would have to get
    // right. Read out of the vendored bundle, not assumed.
    function labelFor(node) {
        var el = document.createElement('div');
        el.textContent = node.name || node.id;
        return el;
    }

    function drawGraph() {
        graph = ForceGraph3D()(byId('fg'))
            .backgroundColor(cfgText('PageBackground', '#0d1117'))
            // The library paints its own control hint into the container. It
            // is user-visible text this repository did not write and cannot
            // translate, and every user-visible string belongs in
            // Config/strings.psd1 - so it is off, and the status bar says the
            // same thing from there.
            .showNavInfo(false)
            .nodeRelSize(cfgNumber('NodeSize', 6))
            .nodeOpacity(cfgNumber('NodeOpacity', 0.95))
            .nodeColor(colorFor)
            .nodeLabel(labelFor)
            .linkColor(function () { return cfgText('EdgeColor', '#6b7785'); })
            .linkOpacity(cfgNumber('EdgeOpacity', 0.5))
            .linkWidth(cfgNumber('EdgeWidth', 0.8))
            .linkDirectionalArrowLength(cfgNumber('ArrowSize', 3))
            .linkDirectionalArrowRelPos(1)
            .onNodeClick(selectNode)
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

            .graphData({ nodes: withInventedTargets(nodes, links), links: links.slice() });

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
        // The canvas is sized from the container EXPLICITLY. Left to itself the
        // library opened a 1280x900 drawing buffer inside an 859px-tall box and
        // never corrected it, so the bottom of every graph was outside its own
        // element and the fit was computed against the wrong aspect. Measured
        // by reading canvas.width off the page, not inferred.
        sizeToContainer();
        window.addEventListener('resize', sizeToContainer);

        fitView();
        graph.onEngineStop(fitView);
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
