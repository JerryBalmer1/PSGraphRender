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

    # Why an action is offered but cannot run. Present and explaining itself
    # rather than absent: an action missing because this item has no file looks
    # identical to a mode that ships no action at all, and those are different
    # facts.
    ReasonNoFile         = 'This item records no file'
    ReasonNoRootPath     = 'The payload states no root path, so there is nothing to open'
    ReasonNoTemplate     = 'LinkHrefTemplate is not set'
    ReasonEmbedded       = 'An embedded viewer cannot follow this link. Copy it instead.'
}
