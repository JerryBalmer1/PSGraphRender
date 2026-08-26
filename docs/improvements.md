# Improvements

On-demand. The kaizen backlog and the size rules that decide what may be taken
unprompted.

## Size rules

**Small** — one file, no contract change, no new user-visible behaviour. Take it
inside an unrelated iteration.

**Medium** — several files, or a new test, but nothing a caller can see. Take it
as its own iteration.

**Large** — anything that changes the view model contract, a data shape, or the
user's mental model. **Logged and stopped on, never taken unprompted.** That
boundary is what keeps this from becoming scope creep.

Every entry says which it is. An entry with no size is an entry nobody has
thought about yet.

---

## Open

### The default backend is hardcoded in two places — **medium**

`Get-HtmlTemplateSet` resolves `TemplateSets/cytoscape` and
`Resolve-HtmlConfiguration` resolves `TemplateSets/cytoscape/Config`, each
independently, and nothing makes the two agree. `Resolve-HtmlString` hardcodes
the same config path a third time.

**This is the rule that pays for the config split, failing.** Adding a second
backend means editing three `.ps1` files, which the charter says is a bug in the
design rather than work to be done. It was invisible in the old layout, where
`Config/` and `Templates/` were siblings under `Assets/Html/` and config was
module-level rather than per-backend. Collapsing `Templates/` into
`TemplateSets/cytoscape/` made config per-backend, which is what the charter
asks for, and exposed the coupling.

The fix is one resolver that answers "where is backend N", called by all three.
Whether the config path is derived from the template set path or declared in
`templateset.psd1` is the decision to make.

### A producer has to escape and substitute for itself — **large**

`ConvertTo-GraphHtml` calls `ConvertTo-EscapedHtmlJson`,
`ConvertTo-EscapedHtmlText` and `Resolve-HtmlString`, then does its own
`[string]::Replace` against the assembled template. Those three functions are
public only because of that.

The charter's seam is `New-RenderDocument`, taking a view model and returning a
document. It would shrink the public surface from seven to about four and make
"a producer written in Go can drive this" mean something — today such a producer
would have to reimplement the escaping and the four token names.

Large: it changes what a producer does, so it is a proposal, not an edit.

### `Get-HashtableValue` exists in both repositories — **small**

A twenty-line strict-mode-safe accessor. Four moved functions need it and ten
functions in PSModuleGraph still do, so the extraction copied it rather than
moving it. It carries no domain knowledge, so the duplication is safe, but two
copies drift.

### Producer vocabulary that survived the move — **medium**

Deliberately untouched so the extraction could be proved by byte-identity.
Iteration 2's work:

- `Get-PSModuleGraphAsset`, `Get-PSModuleGraphAssetPath` — function names.
- `$script:ModuleRoot is not set. Both PSModuleGraph.psm1 loaders...` — an error
  message in `Get-PSModuleGraphAssetPath` naming a module that is not this one.
- `$request.UserAgent = 'PSModuleGraph'` in `Resolve-LoopbackDocumentUrl`.
- `__GRAPH_DATA__`, `__GRAPH_META__`, `__GRAPH_CONFIG__`, `__GRAPH_STRINGS__` —
  the token contract. Renaming these is a contract change, so it is **large**,
  and the old names have to survive as aliases.
- `meta.moduleName`, `meta.moduleVersion`, `meta.moduleBase`, `meta.moduleRoot`
  — producer vocabulary in the payload. Also a contract change.
- `Get-HtmlTemplateSet`, `Resolve-HtmlConfiguration`, `New-GraphReportPath`,
  `Show-GraphDocument` — public names carrying `Html` or `Graph` where the
  charter names `Get-RenderTemplateSet`, `New-RenderDocument` and friends.

### The view model fixture is derived, not hand-written — **medium**

`tests/fixtures/viewmodels/sample-module.json` was lifted out of a real render
and had its timestamp and absolute path replaced. It proves the renderer needs
no producer *at runtime*. It cannot prove the renderer accepts a payload no
producer would have emitted, because every shape in it came from one.

A genuinely hand-written fixture — a graph of three nodes describing something
that is not code at all — is the checklist item.

### The instruction tier is 37% over its stated ceiling — **medium**

`CLAUDE.md` says 10,000 bytes and weighs 13,659. The gate in
`tests/Instructions.Tests.ps1` is set at the measured weight so it is a real
ratchet rather than an aspiration. Iteration 2 prunes toward 10,000:
"Traps that survived the move" belongs in `docs/development.md` and is most of
the overage; gravity is stated both here and in the charter, and the charter is
the authority.

Do not touch "The core constraint", "The contract is the product", or "A
template set is a rendering backend" — those are true before the work is known,
which is the test.

### `Show-RenderDocument` may not belong here — **large, and already open**

Listed under "Open decisions" in `CLAUDE.md`. It launches browsers, probes
loopback ports and reads user agents, none of which is rendering. Raise it
before resolving it.

---

## Noticed, not logged as work

- The renderer claims to be self-contained and is not: Cytoscape and dagre come
  from jsdelivr with SRI hashes. This is an open decision in `CLAUDE.md`, not a
  backlog item.
- `PSModuleGraph`'s manifest sat at `ModuleVersion = '0.1.0'` through six
  annotated tags. Corrected to `0.7.0` during the extraction, but nothing
  enforces the agreement between the manifest and the tag.
