    // No node link at all. Not a disabled action and not a link that goes
    // nowhere: in this mode nothing in the document constructs a URI, because
    // the files that know how were never assembled into it.
    //
    // That is the whole reason mode is resolved at assembly rather than in the
    // browser. A report is one self-contained file that gets forwarded, and a
    // runtime branch would leave the scheme construction sitting in it - inert,
    // but present, and readable by anyone the file reaches. "The action absent,
    // not stubbed" has to mean absent from the artifact.
    //
    // This file therefore defines nothing. The node-action slot is empty for
    // this mode, so nothing calls what is not here, and absolutePathFor in
    // link/common.js is not assembled either, because in this mode nothing
    // needs a path rebuilt.
    var LINK_MODE_NONE = 'none';
