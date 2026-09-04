        {
            id: 'open-link',
            label: str('MenuOpenLink'),
            // No embedded-context check, unlike the editor action. That check
            // exists because a custom scheme never reaches the OS from inside a
            // webview; an http(s) URL is exactly what an embedded viewer CAN
            // open, so refusing it there would disable the one case that works.
            check: nodeLinkCheck,
            href: nodeLinkUriFor
        },
        {
            id: 'copy-link',
            label: str('MenuCopyLink'),
            check: nodeLinkCheck,
            run: function (node) {
                copyText(nodeLinkUriFor(node));
            }
        },
