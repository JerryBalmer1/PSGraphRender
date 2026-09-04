        {
            id: 'copy-editor-links',
            label: function () { return str('SelectionActionCopyLinks'); },
            check: function (selected) {
                if (selected.filter(function (n) { return !editorLinkCheck(n); }).empty()) {
                    return str('ReasonNoFile');
                }
                return null;
            },
            run: function (selected) {
                var uris = [];
                selected.forEach(function (n) {
                    if (!editorLinkCheck(n)) { uris.push(vsCodeUriFor(n)); }
                });
                copyText(uris.join('\n'));
            }
        },