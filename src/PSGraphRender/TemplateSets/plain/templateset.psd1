@{
    # The second backend, and deliberately a poor one.
    #
    # It exists to prove that adding a backend is a directory: no .ps1 under
    # src/ was edited to make this render. If one ever has to be, that is a bug
    # in the design and belongs in docs/improvements.md rather than in a
    # workaround.
    #
    # It also pays for itself twice. It has no library at all, so it is the one
    # backend that never had a vendoring question to answer. And it cannot have
    # inherited a Cytoscape assumption, because it has never heard of Cytoscape.
    Layout = 'layout.html'

    Slots  = @{
        STYLES = @('styles/base.css')
        TABLES = @('partials/tables.html')
        SCRIPT = @('scripts/bootstrap.js')
    }
    # What "alive" means here. No canvas: this backend puts everything in the
    # DOM, so counting rows is the whole check and there is nothing a
    # screenshot would add.
    Smoke  = @{
        Text               = @{}
        Elements           = @{ '#nodes tbody tr' = 'nodes'; '#links tbody tr' = 'links' }
        Present            = @('#nodes', '#links')
        CanvasGrowth       = @{}
    }
}