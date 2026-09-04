    // vscode://file/{path}:{line}:{column}. Kept separate from the action that
    // navigates to it, so the construction can be exercised without handing the
    // browser a URI and launching an editor.
    //
    // The path carries no leading slash: on Windows it starts with the drive
    // letter, and on POSIX an editor expects vscode://file/Users/... rather
    // than a doubled slash. encodeURI leaves / and : alone while escaping
    // spaces, which are common in Windows paths.
    var LINK_MODE_EDITOR = 'editor';

    function vsCodeUriFor(node) {
        var abs = absolutePathFor(node);
        if (!abs) { return null; }
        var line = node.startLine || 1;
        return 'vscode://file/' + encodeURI(abs.replace(/^\/+/, '')) + ':' + line + ':1';
    }

    // Shared by the launch and copy actions. The launch adds the embedded check
    // on top; copying works in an embedded viewer, which is exactly when it is
    // the only thing that does.
    function editorLinkCheck(node) {
        if (!node.path) { return str('ReasonNoFile'); }
        if (!meta.rootPath) { return str('ReasonNoRootPath'); }
        return null;
    }
