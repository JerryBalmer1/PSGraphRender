        {
            id: 'open-in-vscode',
            // An external target has no definition inside this module, so the
            // path recorded against it is the CALL SITE. Opening that is still
            // useful, but calling it "file location" would be a lie about what
            // the page knows - the definition is exactly what static analysis
            // could not resolve.
            label: function (node) {
                return node.data('kind') === 'External'
                    ? str('MenuOpenCallSite') : str('MenuOpenFileLocation');
            },
            check: function (node) {
                var reason = editorLinkCheck(node);
                if (reason) { return reason; }
                if (isEmbeddedContext()) {
                    return str('ReasonEmbedded');
                }
                return null;
            },
            href: vsCodeUriFor,
            // The navigation itself reports nothing either way, so the click
            // starts a watch for the one observable signal there is.
            afterClick: function (node) {
                attemptEditorLaunch(vsCodeUriFor(node), reportNoLaunch);
            }
        },
        {
            id: 'copy-editor-link',
            label: str('MenuCopyEditorLink'),
            // Deliberately without the embedded check: pasting the URI into the
            // Run dialog, Spotlight or a terminal opens the file whatever the
            // browser is or is not willing to do.
            check: editorLinkCheck,
            run: function (node) {
                copyText(vsCodeUriFor(node));
            }
        },