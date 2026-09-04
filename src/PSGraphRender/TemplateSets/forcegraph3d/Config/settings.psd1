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
}
