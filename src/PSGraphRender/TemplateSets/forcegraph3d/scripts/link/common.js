    // Payload paths are relative on purpose - a report gets attached to a PR,
    // and absolute paths carry the author's username. The root comes back from
    // the meta block, so absolute paths are rebuilt only here, in the browser,
    // at the moment they are needed.
    function absolutePathFor(node) {
        var rel = node.path;
        if (!rel) { return null; }
        var root = meta.rootPath;
        if (!root) { return null; }
        var joined = root.replace(/[\\/]+$/, '') + '/' + rel;
        return joined.replace(/\\/g, '/');
    }

    // An embedded viewer - a preview pane, a notebook output cell, a webview -
    // sandboxes the page, so a custom scheme never reaches the OS. Nothing in
    // the page can change that. It can at least say so, rather than presenting
    // a link that does nothing.
    //
    // Not named for any one product, because it is not specific to one: a
    // preview served over http://127.0.0.1 has the same problem and nothing
    // about that URL says "webview".
    function isEmbeddedContext() {
        // A report opened in a real browser is never framed. Any embedding at
        // all means custom-scheme navigation is unreliable, and this catches
        // every host without sniffing for any one of them.
        //
        // Identity comparison against window.top is same-origin safe; it is
        // reading top's PROPERTIES that throws cross-origin.
        try {
            if (window.top !== window.self) { return true; }
        }
        catch (err) {
            // A throw here can only mean an exotic embedding. Treat it as embedded.
            return true;
        }

        if (location.protocol === 'vscode-webview:') { return true; }

        // An editor preview pane runs the page in the editor's own Electron
        // renderer. It is top-level and served over file:, so neither the frame
        // check above nor the scheme check sees it - and yet a custom scheme
        // never reaches the OS from there, because the Electron host swallows
        // it without a prompt and without an error.
        //
        // The user agent is the only signal that separates this from a real
        // browser: a browser never reports Electron/. Matched generically
        // rather than on any one product name, because every Electron host has
        // the same problem.
        if (/\bElectron\//.test(navigator.userAgent)) { return true; }

        try {
            // Still worth checking: catches a TOP-LEVEL webview, which the
            // frame check above cannot see.
            var origins = location.ancestorOrigins;
            for (var i = 0; origins && i < origins.length; i++) {
                if (origins[i].indexOf('vscode-webview') === 0) { return true; }
            }
        }
        catch (err) {
            // ancestorOrigins is Chromium-only; absence is not evidence either way.
        }
        return false;
    }
