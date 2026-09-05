    // Always-on item names, as DOM elements positioned over the canvas from
    // projected coordinates.
    //
    // NOT sprites, and the reason is the injection surface rather than
    // performance. A text sprite is a texture, which means drawing the label
    // into a 2D canvas - and the label is free text from a producer. A DOM
    // element carrying textContent cannot become markup and cannot become
    // anything else either; it is the same property pass 0049 established for
    // the hover tooltip, extended to the second place a producer's string is
    // now shown. Every label on this page is text in an element, in both
    // modes, by construction.
    //
    // It is also the only option that needs nothing new: the usual answer is
    // three-spritetext, which is another vendored file, and building a texture
    // by hand needs a CanvasTexture constructor that is not in the bundle.
    // graph2ScreenCoords is, and it is the library's own documented projection.
    //
    // The cost is real and is why 'hover' is the default: a layout per label
    // per frame. LabelMaxNodes is the ceiling that keeps 'always' from being a
    // trap on a payload nobody sized it for.

    var LABEL_LAYER = null;
    var LABEL_ENTRIES = [];

    function startLabels(graph) {
        var layer = document.getElementById('fg-labels');
        if (!layer) { return; }

        var mode = cfgText('ShowLabels', 'hover');
        var drawn = graph.graphData().nodes;

        // Above the ceiling this falls back to hover labels and says nothing
        // about it. A message would be chrome inside the rectangle the
        // canvas-growth floor measures; the setting's own description is where
        // the behaviour is documented.
        if (mode !== 'always' || drawn.length > cfgNumber('LabelMaxNodes', 60)) {
            layer.hidden = true;
            return;
        }

        LABEL_LAYER = layer;
        layer.hidden = false;
        while (layer.firstChild) { layer.removeChild(layer.firstChild); }

        LABEL_ENTRIES = [];
        for (var i = 0; i < drawn.length; i++) {
            var el = document.createElement('span');
            el.className = 'fg-label';
            // textContent, never innerHTML. Every string on this page is text.
            el.textContent = drawn[i].name || drawn[i].id;
            layer.appendChild(el);
            LABEL_ENTRIES.push({ node: drawn[i], el: el });
        }

        positionLabels(graph);
        // On the library's own tick as well as on a frame loop: the tick fires
        // while the layout is moving and stops when it does, and a label that
        // only followed a frame loop would keep repositioning a graph that had
        // stopped.
        graph.onEngineTick(function () { positionLabels(graph); });

        // The layout stops but the CAMERA does not: a reader drags and every
        // projected position changes with nothing in the simulation moving. So
        // the loop runs on frames too, and does nothing measurable when
        // neither has moved.
        (function follow() {
            positionLabels(graph);
            window.requestAnimationFrame(follow);
        }());
    }

    function positionLabels(graph) {
        if (!LABEL_LAYER) { return; }
        var box = LABEL_LAYER.getBoundingClientRect();
        for (var i = 0; i < LABEL_ENTRIES.length; i++) {
            var entry = LABEL_ENTRIES[i];
            var node = entry.node;
            if (node.x === undefined) { entry.el.style.display = 'none'; continue; }

            var point = graph.graph2ScreenCoords(node.x, node.y, node.z);
            // Behind the camera, or outside the frame. Hidden rather than
            // clamped: a label pinned to the edge names an item the reader
            // cannot see, which is worse than no label.
            if (!point || point.x < 0 || point.y < 0 || point.x > box.width || point.y > box.height) {
                entry.el.style.display = 'none';
                continue;
            }
            entry.el.style.display = '';
            entry.el.style.transform = 'translate(-50%, 0) translate(' + point.x + 'px,' + point.y + 'px)';
        }
    }
