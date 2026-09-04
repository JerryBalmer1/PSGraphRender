    // What a selected item offers, as a registry rather than a branch. The
    // entries are not in this file: the slot below is filled at ASSEMBLY with
    // whichever link mode the document was built for, so a report carries one
    // mode's actions and not three.
    //
    // In `none` mode the slot is filled with an empty list, which is a real
    // answer and not an omission - the panel still opens and still says where
    // the item lives; there is simply nothing in the document that builds a
    // link. That distinction is the whole reason mode is resolved here instead
    // of in the browser: a report is one self-contained file that gets
    // forwarded, and a runtime branch would leave the scheme construction
    // sitting in it, inert but present and readable by anyone the file reaches.
    var NODE_ACTIONS = [
/*__SLOT_NODE_LINK_ACTIONS__*/
    ];

    // An entry becomes an anchor when it hands a URI to another application and
    // a button when it does something here. Both, rather than one styled to
    // look like the other: an anchor is what a reader can middle-click, copy or
    // open in a new tab, and a button that fakes it takes all three away.
    function renderAction(action, node) {
        var reason = action.check ? action.check(node) : null;
        var text = typeof action.label === 'function' ? action.label(node) : action.label;

        if (reason) {
            // Present and explaining itself, rather than absent. An action
            // missing because this item has no file looks identical to a mode
            // that ships no action at all, and those are different facts.
            var disabled = document.createElement('span');
            disabled.textContent = text;
            disabled.title = reason;
            disabled.setAttribute('aria-disabled', 'true');
            return disabled;
        }

        if (action.href) {
            var uri = action.href(node);
            if (!uri) { return null; }

            var anchor = document.createElement('a');
            anchor.textContent = text;
            // Assigned to the PROPERTY, never interpolated into markup. That is
            // what makes this safe rather than merely escaped: the token values
            // inside the URI are percent-encoded so a label cannot change the
            // URL's shape, and there is no attribute here for a quote to escape
            // from even if one survived.
            anchor.href = uri;
            anchor.rel = 'noopener';
            if (action.afterClick) {
                anchor.addEventListener('click', function () { action.afterClick(node); });
            }
            return anchor;
        }

        var button = document.createElement('button');
        button.type = 'button';
        button.textContent = text;
        button.addEventListener('click', function () { action.run(node); });
        return button;
    }

    // Copying works where launching does not - an embedded viewer swallows a
    // custom scheme without a prompt and without an error - so the copy action
    // exists in its own right rather than as a fallback.
    function copyText(text) {
        if (!text) { return; }
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text);
        }
    }
