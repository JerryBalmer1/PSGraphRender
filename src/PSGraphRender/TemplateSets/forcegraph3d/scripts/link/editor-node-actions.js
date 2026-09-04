        {
            id: 'open-in-editor',
            label: str('MenuOpenFileLocation'),
            check: function (node) {
                var reason = editorLinkCheck(node);
                if (reason) { return reason; }
                if (isEmbeddedContext()) {
                    return str('ReasonEmbedded');
                }
                return null;
            },
            href: vsCodeUriFor
        },
        {
            id: 'copy-editor-link',
            label: str('MenuCopyEditorLink'),
            // Deliberately without the embedded check: pasting the URI into a
            // run dialog, a launcher or a terminal opens the file whatever the
            // browser is or is not willing to do.
            check: editorLinkCheck,
            run: function (node) {
                copyText(vsCodeUriFor(node));
            }
        },
