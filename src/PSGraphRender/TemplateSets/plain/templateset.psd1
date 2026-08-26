@{
    # The second backend, and deliberately a poor one.
    #
    # It exists to prove that adding a backend is a directory: no .ps1 under
    # src/ was edited to make this render. If one ever has to be, that is a bug
    # in the design and belongs in docs/improvements.md rather than in a
    # workaround.
    #
    # It also pays for itself twice. It is genuinely offline-capable - no CDN,
    # no library, no layout engine - which is half of the vendoring decision in
    # CLAUDE.md answered by demonstration. And it cannot have inherited a
    # Cytoscape assumption, because it has never heard of Cytoscape.
    Layout = 'layout.html'

    Slots  = @{
        STYLES = @('styles/base.css')
        TABLES = @('partials/tables.html')
        SCRIPT = @('scripts/bootstrap.js')
    }
}
