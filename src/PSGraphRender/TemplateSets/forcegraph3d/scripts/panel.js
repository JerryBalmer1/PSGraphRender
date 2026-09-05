    // The control panel: what a reader can move without re-rendering.
    //
    // ITS ONE CONTRACT. Every control here adjusts at RUNTIME the same thing a
    // setting in Config/ decides at RENDER TIME, and each one opens at the
    // position that setting shipped. So a reader who drags a slider and a
    // caller who writes a value are changing one thing rather than two, and
    // "what does this document do" has one answer whichever end you read it
    // from. Spot-check SC2 is that assertion, driven against a scratch set
    // with the settings flipped.
    //
    // WHAT IT DELIBERATELY IS NOT. It is not the 2D backend's sidebar moved
    // across. That sidebar is a column beside the drawing with its labels
    // written into the markup in English; this is a collapsible card over the
    // drawing whose every word comes from Config/strings.psd1. The 3D view has
    // one thing worth looking at and it fills the frame - a permanent column
    // would spend a fifth of the picture on chrome that is read once.
    //
    // WHERE IT LIVES, AND THE DEFECT THAT DECIDED IT. In #fg-stage, beside the
    // canvas rather than inside it: ForceGraph3D empties the container it is
    // handed, so a panel nested in #fg is deleted the instant the graph
    // initialises. That is not a hypothetical - ShowLabels = 'always' shipped
    // at v0.16.0 with its label layer inside #fg and never drew a label, and
    // this panel vanishing the same way is how it was found.
    //
    // NO STRING IN THIS FILE IS SHOWN TO ANYBODY. Every visible word is
    // str(...), and every one of them is set with textContent.

    function panelReady() {
        var root = byId('fg-controls');
        if (!root) { return; }

        var mode = cfgText('ShowControlPanel', 'open');
        if (mode === 'none') {
            // Absent rather than hidden. A report built for a wall display or
            // for print has no reader to press anything, and chrome nobody can
            // use is chrome in the way.
            root.remove();
            return;
        }

        fillPanelText();
        buildKindFilters();
        wirePanel();
        setCollapsed(mode === 'collapsed');
        root.hidden = false;
        publishLive();
    }

    // -- text --------------------------------------------------------------

    function setText(id, key) {
        var el = byId(id);
        if (el) { el.textContent = str(key); }
    }

    function fillPanelText() {
        setText('fg-controls-title', 'ControlsTitle');
        setText('fg-g-view', 'ViewGroup');
        setText('fg-l-zoom', 'ZoomSpeedLabel');
        setText('fg-fit', 'FitLabel');
        setText('fg-rotate', 'AutoRotateLabel');
        setText('fg-g-depth', 'DepthGroup');
        setText('fg-l-fog', 'FogLabel');
        setText('fg-l-grid', 'GridLabel');
        setText('fg-l-focus', 'FocusLabel');
        setText('fg-g-display', 'DisplayGroup');
        setText('fg-l-labels', 'LabelsLabel');
        setText('fg-l-particles', 'ParticlesLabel');
        setText('fg-l-glow', 'GlowLabel');
        setText('fg-g-kinds', 'KindsGroup');

        // The environment choices. The VALUES come from the page's own
        // vocabulary of buildable grids, and each one's word comes from
        // strings.psd1 - so a grid this build cannot draw is never offered,
        // and a grid it can draw is never offered without a name.
        var select = byId('fg-grid');
        if (!select) { return; }
        var choices = [
            { value: 'none', key: 'GridNone' },
            { value: 'floor', key: 'GridFloor' },
            { value: 'room', key: 'GridRoom' }
        ];
        for (var i = 0; i < choices.length; i++) {
            if (choices[i].value !== 'none' && !isBuildableGrid(choices[i].value)) { continue; }
            var option = document.createElement('option');
            option.value = choices[i].value;
            option.textContent = str(choices[i].key);
            select.appendChild(option);
        }
    }

    // -- the classification filters ----------------------------------------
    //
    // One row per classification the PAYLOAD carries, built from the data. No
    // list, no vocabulary, nothing in this file that knows what a kind is -
    // the same rule colorFor and shapeFor are built on. An item the renderer
    // INVENTED gets a row of its own, because it is not a classification and
    // filtering it with one would be the page claiming a producer sent it.
    function buildKindFilters() {
        var host = byId('fg-kinds');
        var section = byId('fg-g-kinds-section');
        if (!host) { return; }
        while (host.firstChild) { host.removeChild(host.firstChild); }

        var buckets = kindBuckets();
        for (var i = 0; i < buckets.length; i++) { host.appendChild(kindRow(buckets[i])); }

        // A payload with one bucket has nothing to filter, and a group of one
        // checkbox that can only ever empty the page is a control that offers
        // a mistake. An empty payload has none at all.
        if (section) { section.hidden = buckets.length < 2; }
    }

    function kindRow(bucket) {
        var label = document.createElement('label');
        label.className = 'fg-check';

        var box = document.createElement('input');
        box.type = 'checkbox';
        box.checked = true;
        // The BUCKET KEY, so a check can find a row without knowing how a
        // classification becomes one.
        box.setAttribute('data-bucket', bucket.key);
        box.addEventListener('change', function () {
            setKindHidden(bucket.key, !box.checked);
        });

        var text = document.createElement('span');
        // A classification is free text from a producer, so it goes in as
        // textContent and never as markup - the same property the tooltip and
        // the labels have. The two synthetic buckets take their words from
        // strings.psd1 instead, because they are the renderer's own idea and
        // not a producer's.
        if (bucket.invented) { text.textContent = str('KindsInvented'); }
        else if (!bucket.kind) { text.textContent = str('KindsUnclassified'); }
        else { text.textContent = bucket.kind; }

        label.appendChild(box);
        label.appendChild(text);
        return label;
    }

    // -- wiring ------------------------------------------------------------
    //
    // Each control is set to what CONFIG says BEFORE its listener is attached,
    // so the opening position is the shipped value rather than whatever the
    // markup's min happened to be - and attaching after means setting it does
    // not fire the handler and re-apply a value that is already applied.

    function wirePanel() {
        var toggle = byId('fg-controls-toggle');
        if (toggle) {
            toggle.addEventListener('click', function () {
                setCollapsed(byId('fg-controls').getAttribute('data-collapsed') !== 'true');
            });
        }

        bindRange('fg-zoom-speed', 'fg-zoom-speed-out', cfgNumber('ZoomSpeed', 0.9), 2, setZoomSpeed);
        bindRange('fg-fog', 'fg-fog-out', cfgNumber('FogDensity', 0.0016), 4, setFogDensity);
        bindRange('fg-glow', 'fg-glow-out', 1, 2, setGlowScale);

        var fit = byId('fg-fit');
        if (fit) { fit.addEventListener('click', fitNow); }

        var rotate = byId('fg-rotate');
        if (rotate) {
            rotate.addEventListener('click', function () {
                var on = rotate.getAttribute('aria-pressed') !== 'true';
                rotate.setAttribute('aria-pressed', on ? 'true' : 'false');
                setAutoRotate(on);
            });
            // Off the LIVE state rather than off CONFIG, because drawGraph has
            // already applied the setting by now and the button has to agree
            // with the camera rather than with the file.
            rotate.setAttribute('aria-pressed', isAutoRotating() ? 'true' : 'false');
        }

        var grid = byId('fg-grid');
        if (grid) {
            grid.value = gridStyle();
            grid.addEventListener('change', function () { setGridStyle(grid.value); });
        }

        var focus = byId('fg-focus');
        if (focus) {
            focus.checked = cfgBool('FocusOnClick', true);
            focus.addEventListener('change', function () { setFocusOnClick(focus.checked); });
        }

        var labels = byId('fg-labels-on');
        if (labels) {
            labels.checked = labelsVisible();
            // Disabled rather than absent when the payload is over the ceiling,
            // and it SAYS why. A missing switch and a switch that does nothing
            // look the same to a reader; a disabled one with a reason does not.
            labels.disabled = !labelsPossible();
            if (!labelsPossible()) { labels.parentNode.title = str('LabelsUnavailable'); }
            labels.addEventListener('change', function () { setLabelsVisible(labels.checked); });
        }

        var particles = byId('fg-particles');
        if (particles) {
            particles.checked = cfgNumber('ParticleCount', 2) > 0;
            particles.addEventListener('change', function () {
                // Back to the CONFIGURED count rather than to one. Turning a
                // thing off and on again should give back what was there, and
                // a page that restored a different number would be a page that
                // quietly overrode its own theme.
                setParticleCount(particles.checked ? cfgNumber('ParticleCount', 2) : 0);
            });
        }
    }

    function bindRange(inputId, outputId, value, places, apply) {
        var input = byId(inputId);
        if (!input) { return; }
        var output = byId(outputId);

        function show() {
            if (output) { output.textContent = Number(input.value).toFixed(places); }
        }

        input.value = value;
        show();
        input.addEventListener('input', function () {
            apply(Number(input.value));
            show();
        });
    }

    function setCollapsed(collapsed) {
        var root = byId('fg-controls');
        var toggle = byId('fg-controls-toggle');
        var body = byId('fg-controls-body');
        if (!root) { return; }
        root.setAttribute('data-collapsed', collapsed ? 'true' : 'false');
        if (body) { body.hidden = collapsed; }
        if (toggle) {
            toggle.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
            // The button's accessible name says what pressing it will DO,
            // which is the opposite of the current state.
            toggle.setAttribute('aria-label', str(collapsed ? 'ControlsExpand' : 'ControlsCollapse'));
        }
        publishLive();
    }

    // What a check can read about the panel, for the same reason #fg-resolved
    // exists: whether a control is THERE and whether it is OPEN cannot be read
    // off a screenshot, and a panel is the one part of this page whose whole
    // job is to be interactive.
    function panelState() {
        var root = byId('fg-controls');
        if (!root) { return { present: false }; }
        return {
            present: true,
            collapsed: root.getAttribute('data-collapsed') === 'true',
            controls: root.querySelectorAll('input, select, button').length
        };
    }
