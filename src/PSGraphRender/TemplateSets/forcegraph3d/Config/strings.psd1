@{
    # Every user-visible string. Never markup: the page puts each of these in
    # with textContent, so a tag here would be shown rather than rendered.
    #
    # {token} names are filled at display time by the page, not here.
    #
    # Nothing in this file may name what the payload describes. The renderer
    # knows about items and links and knows nothing about what they are, and
    # neither does the page - a string saying otherwise is a claim this
    # repository cannot make about a payload it has never seen.

    NodesLabel           = 'items'
    LinksLabel           = 'links'
    Generated            = 'Generated {generatedAt}'
    PanelClose           = 'Close'
    Hint                 = 'Drag to rotate, scroll to zoom, click an item for what it is'

    At                   = '{path}:{line}'
    NoFile               = 'No file recorded'

    # Shown instead of the graph, and only then.
    LibraryMissing       = 'The drawing library did not load, so there is nothing to show. The report is assembled with it inside; a document missing it was not assembled completely.'
    TemplateNotice       = 'This is the raw template. It becomes a report when something renders a payload into it.'

    # Item actions. Which of these a document carries is decided when it is
    # assembled, so a report built for one mode contains only that mode's.
    MenuOpenFileLocation = 'Open File Location'
    MenuCopyEditorLink   = 'Copy Editor Link'
    MenuOpenLink         = 'Open Link'
    MenuCopyLink         = 'Copy Link'

    # -- The control panel ---------------------------------------------------
    # Every word the panel shows, including the group headings. partials/graph.html
    # ships one empty <span> per label and no English at all, unlike the 2D
    # backend's sidebar - which has "Order", "Search" and "Kinds" written into
    # its markup and cannot be translated without editing a partial.
    #
    # Nothing here names what the payload describes. `KindsGroup` says
    # "Classifications" rather than anything about what is being classified,
    # for the same reason NodesLabel says "items": the renderer has never seen
    # this payload and may not claim to know what is in it.
    ControlsTitle        = 'Controls'
    ControlsExpand       = 'Show controls'
    ControlsCollapse     = 'Hide controls'

    ViewGroup            = 'View'
    ZoomSpeedLabel       = 'Zoom speed'
    FitLabel             = 'Fit to view'
    AutoRotateLabel      = 'Auto-rotate'

    DepthGroup           = 'Depth'
    FogLabel             = 'Depth falloff'
    GridLabel            = 'Environment'
    FocusLabel           = 'Fly to an item on click'

    DisplayGroup         = 'Display'
    LabelsLabel          = 'Names'
    LabelsUnavailable    = 'Too many items to name them all'
    ParticlesLabel       = 'Direction marks'
    GlowLabel            = 'Glow'

    KindsGroup           = 'Classifications'
    KindsUnclassified    = 'Unclassified'
    KindsInvented        = 'Not in the payload'

    # The environment names, as a reader sees them. The KEYS these correspond
    # to are the GridStyle enum's values; the words are here because the schema
    # is not user-visible text.
    GridNone             = 'None'
    GridFloor            = 'Ground plane'
    GridRoom             = 'Enclosure'

    # Why an action is offered but cannot run. Present and explaining itself
    # rather than absent: an action missing because this item has no file looks
    # identical to a mode that ships no action at all, and those are different
    # facts.
    ReasonNoFile         = 'This item records no file'
    ReasonNoRootPath     = 'The payload states no root path, so there is nothing to open'
    ReasonNoTemplate     = 'LinkHrefTemplate is not set'
    ReasonEmbedded       = 'An embedded viewer cannot follow this link. Copy it instead.'
}
