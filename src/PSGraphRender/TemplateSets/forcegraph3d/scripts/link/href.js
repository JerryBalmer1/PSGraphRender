    // A node link as a URL built from a template, for a report that will be
    // read somewhere the files are not. The editor scheme answers "open this on
    // MY machine"; this answers "show me this where it lives" - a forge, a wiki,
    // a build viewer - and those are different questions, which is why the mode
    // is configuration rather than a guess about the reader.
    var LINK_MODE_HREF_TEMPLATE = 'hrefTemplate';

    // The tokens a template may name, and where each comes from. Everything
    // here is a field the view model ALREADY carries: contract 1.1.0 is not
    // edited to make a link richer, and adding a token that needs a new field
    // is a contract change and therefore a decision, not a template edit.
    //
    // The same five the reference backend resolves, deliberately, and
    // tests/ForceGraph.Tests.ps1 reads THAT backend's table and requires every
    // entry to appear here. A template written for one backend that silently
    // lost a token in the other would be a link nobody clicked reporting
    // nothing, and the parity is asserted rather than intended.
    //
    // {path} is the payload's own bytes and {relativePath} is the URL-shaped
    // form of the same value. They differ on exactly the payloads that matter:
    // a producer on Windows emits 'src\Public\Widget.ps1', and a forge URL
    // needs forward slashes. Keeping both means a template can ask for either
    // without the renderer deciding which one a producer meant.
    //
    // Each token encodes ITSELF, because a path and a label are different
    // shapes and one encoder cannot be right for both. {relativePath} keeps its
    // separators and escapes each segment; everything else is a single opaque
    // value and is escaped whole.
    var LINK_TOKENS = {
        '{relativePath}': function (node) { return encodePathSegments(urlPathFor(node)); },
        '{path}': function (node) { return encodeURIComponent(node.path || ''); },
        '{id}': function (node) { return encodeURIComponent(node.id || ''); },
        '{label}': function (node) { return encodeURIComponent(node.name || ''); },
        '{line}': function (node) { return encodeURIComponent(node.startLine || 1); }
    };

    // Separators normalised, and a leading ./ or / dropped. Not a general path
    // library: the contract says path is relative to meta.rootPath, so there is
    // nothing to resolve here - only a spelling to settle.
    function urlPathFor(node) {
        var rel = node.path;
        if (!rel) { return ''; }
        return String(rel).replace(/\\/g, '/').replace(/^\.?\//, '');
    }

    // Per segment, so the separators survive. encodeURIComponent over the whole
    // path escapes / as %2F, which is correct for a query VALUE and wrong for
    // the thing {relativePath} exists for: a forge URL of the shape
    // .../blob/main/{relativePath} needs real slashes or it resolves to
    // nothing. A segment is still escaped whole, so a space or a quote in a
    // file name cannot change the URL's shape.
    function encodePathSegments(path) {
        return path.split('/').map(encodeURIComponent).join('/');
    }

    function nodeLinkCheck(node) {
        if (!node.path) { return str('ReasonNoFile'); }
        if (!cfgText('LinkHrefTemplate', '')) { return str('ReasonNoTemplate'); }
        return null;
    }

    // Token VALUES are escaped; the template around them is not. The split is
    // deliberate and it is a trust boundary: the template is configuration,
    // written by whoever runs the render, and it has to keep its ://, ? and & to
    // be a URL at all. A node's path and label come from a producer and are
    // never trusted - a label is free text and one of them will eventually
    // contain a quote.
    //
    // What makes this safe rather than merely escaped is one layer down: the
    // result is assigned to an anchor's href PROPERTY in actions.js, never
    // interpolated into markup, so there is no attribute for a quote to escape
    // from. The escaping is what keeps a label from silently changing the URL's
    // shape; the property assignment is what keeps it from becoming markup.
    function nodeLinkUriFor(node) {
        var template = cfgText('LinkHrefTemplate', '');
        if (!template) { return null; }

        var out = template;
        for (var token in LINK_TOKENS) {
            if (Object.prototype.hasOwnProperty.call(LINK_TOKENS, token) && out.indexOf(token) >= 0) {
                // split/join rather than replace: a String replace argument
                // takes $& and friends as substitution patterns, and a path is
                // exactly the sort of value that eventually contains one.
                out = out.split(token).join(LINK_TOKENS[token](node));
            }
        }
        return out;
    }
