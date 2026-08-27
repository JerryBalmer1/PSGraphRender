    // ---- filtering -------------------------------------------------------
    var searchEl = document.getElementById('search');
    var exportedOnlyEl = document.getElementById('exported-only');
    var showUnresolvedEl = document.getElementById('show-unresolved');

    function applyFilters() {
        var term = searchEl.value.trim().toLowerCase();
        var exportedOnly = exportedOnlyEl.checked;
        var showUnres = showUnresolvedEl.checked;
        var enabled = {};
        kinds.forEach(function (k) {
            var box = document.getElementById('kind-' + k);
            enabled[k] = !box || box.checked;
        });

        cy.batch(function () {
            cy.nodes().forEach(function (n) {
                var kind = n.data('kind');
                var visible;
                if (kind === 'External') {
                    visible = showUnres;
                } else {
                    visible = !!enabled[kind];
                    if (visible && exportedOnly && !n.data('isExported')) { visible = false; }
                    if (visible && term && n.data('name').toLowerCase().indexOf(term) === -1) { visible = false; }
                }
                n.toggleClass('hidden', !visible);
            });
            cy.edges().forEach(function (e) {
                var hide = e.source().hasClass('hidden') || e.target().hasClass('hidden');
                e.toggleClass('hidden', hide);
            });
        });
        reapplyFocus();
    }

    // A node the reader can see needs a position from a layout that included
    // it. foundationPositions() places the VISIBLE set - see foundation.js -
    // so a node hidden when the layout last ran has never been placed at all
    // and sits at the origin, which is where the top-left node of the drawing
    // already is.
    //
    // That one fact produced three separate ledger threads, none of which
    // named it: an invented node drawn on top of a real one (0008-t1), two
    // unresolved targets drawn as one node (0010-t3 - they are two nodes with
    // two ids, stacked), and unchecking "Exported only" moving nothing
    // (0010-t2, where 371 of SqlServerDsc's nodes arrived in the same corner).
    //
    // The checkboxes relayout and the search box does not. A checkbox is a
    // decision about which nodes belong on the page and is worth redrawing
    // for; the search box fires on every keystroke, and a graph that
    // rearranges itself mid-word is worse than the defect. Search is also
    // safe: it can only hide nodes a layout has already placed, so it cannot
    // strand one at the origin.
    function applyStructuralFilters() {
        applyFilters();
        runLayout();
        fitVisible();
    }

    searchEl.addEventListener('input', applyFilters);
    exportedOnlyEl.addEventListener('change', applyStructuralFilters);
    showUnresolvedEl.addEventListener('change', applyStructuralFilters);
