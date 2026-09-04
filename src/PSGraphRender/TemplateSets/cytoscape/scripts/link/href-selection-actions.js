        {
            id: 'copy-links',
            label: function () { return str('SelectionActionCopyLinks'); },
            check: function (selected) {
                if (selected.filter(function (n) { return !nodeLinkCheck(n); }).empty()) {
                    return str('ReasonNoFile');
                }
                return null;
            },
            run: function (selected) {
                var uris = [];
                selected.forEach(function (n) {
                    if (!nodeLinkCheck(n)) { uris.push(nodeLinkUriFor(n)); }
                });
                copyText(uris.join('\n'));
            }
        },