@{
    # Current values for behaviour settings: what the report does.
    # Appearance lives in theme.psd1. Types, ranges and descriptions live in
    # settings.schema.psd1. See docs/render-architecture.md.
    #
    # This file is DATA, read with Import-PowerShellDataFile and never executed.
    # Expressions, variables and commands will not run here.

    # 'editor' is the reference backend's default and stays the default here, so
    # the two answer the same way when nobody has decided. Changing this is a
    # deliberate decision about who the report is FOR, and it is one line.
    LinkMode         = 'editor'

    # Only read when LinkMode is hrefTemplate. Empty rather than an example
    # URL: a plausible-looking default is one somebody ships by accident.
    LinkHrefTemplate = ''

    # How long the layout runs, in simulation ticks. Ticks rather than seconds
    # so the same payload settles the same way on any machine. Warmup happens
    # before the first paint; cooldown is what a reader watches.
    #
    # The library's own default stops on a fifteen-second timer, which is longer
    # than a reader waits and longer than any check here runs - so a view that
    # fits itself when the layout settles never fitted at all.
    WarmupTicks      = 80
    CooldownTicks    = 160

    # -- Camera ------------------------------------------------------------
    # Both BELOW the library's own defaults (1.2 and 1.0), and both for the
    # same measured reason: this view is a cloud of items in depth rather than
    # a plane, so a reader spends most of their time making small corrections
    # to an angle they nearly have. At the library's zoom speed one wheel notch
    # crosses most of the useful range and the correction becomes an overshoot
    # in the other direction.
    #
    # 0.9 is a deliberate small reduction rather than a dramatic one: the
    # complaint the default earns is "slightly too eager", and a value that
    # answered it with 0.3 would trade one wrong feel for another.
    ZoomSpeed        = 0.9
    RotateSpeed      = 0.85

    # -- Hover -------------------------------------------------------------
    # What passing the pointer over an item does.
    #
    # 'neighbors' rather than 'node', and that is the one default here chosen
    # against the quieter option. In three dimensions the question a reader
    # actually has about an item is what it is CONNECTED to, and every link
    # crosses every other one from most angles - so "which lines are this
    # item's" is genuinely unanswerable by looking. Highlighting the item alone
    # answers a question nobody had.
    HoverMode        = 'neighbors'

    # What the tooltip says. 'labelAndKind' because the label alone repeats
    # what the panel says on click, and the classification is the one fact that
    # is otherwise only available as a colour - which a reader has to have
    # learnt the legend for, and this page has no legend.
    #
    # Not the file path: a path is long, it is already one click away in the
    # panel, and a tooltip that reflows the pointer's own neighbourhood is
    # worse than one that does not.
    HoverTooltip     = 'labelAndKind'

    # -- Pointer -----------------------------------------------------------
    # Which button opens an item's actions. 'left' is what this backend has
    # always used and it stays: the reference backend opens a context MENU on
    # right-click, and this one opens a PANEL, which is a different gesture
    # with a different expectation. Right-drag is also how the library pans, so
    # a right-click here is one small movement away from a pan the reader
    # meant.
    #
    # The LinkProbe block in templateset.psd1 reads THIS value, so the gate
    # drives whatever ships rather than whatever was true when it was written.
    NodeActionButton = 'left'

    # -- Labels ------------------------------------------------------------
    # 'hover' rather than 'always', and this is a density decision rather than
    # a taste one. Labels are DOM elements positioned over the canvas from
    # projected coordinates, so every one of them costs a layout on every
    # frame, and a graph of any size becomes a wall of text through which the
    # drawing is not visible. 'always' is there for the small graph where it is
    # genuinely better, and E2 in the catalogue is what it looks like.
    ShowLabels       = 'hover'

    # And the ceiling that keeps 'always' from being a trap. Above this many
    # items the page falls back to hover labels and says nothing about it,
    # because the alternative is a reader who set one option and got an
    # unreadable page with no way to know why.
    #
    # 60 is where a 1280x900 frame stops having room: at 24 items the labels
    # are separated, at 60 they touch, and past that they overlap each other
    # faster than they cover the graph.
    LabelMaxNodes    = 60
}
