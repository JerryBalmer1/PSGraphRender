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

### `Get-HashtableValue` exists in both repositories — **small**

A twenty-line strict-mode-safe accessor. Four moved functions need it and ten
functions in PSModuleGraph still do, so the extraction copied it rather than
moving it. It carries no domain knowledge, so the duplication is safe today and
will drift.

### A backend can still assume a shape the contract does not promise — **medium**

`contract/viewmodel.schema.json` closes half of 0002-t4: `plain` reading
`DATA.nodes` is now licensed, because the contract requires `nodes`.

The other half is open. Nothing checks that what a backend reads is what the
contract guarantees. A backend reading `DATA.rows`, or `node.severity`, would
render blank against every conforming payload and no test would notice. The
shape of the check is: extract the payload accesses out of a backend's scripts
and assert every one is a property the schema declares.

### Nothing syntax-checks the JavaScript — **medium**

A malformed script fails only in a browser, and `render.js` was restructured by
about a hundred lines in v0.3.0 with nothing able to say whether it still
parses. A brace-balance check was written and thrown away: it cannot parse a
regex literal, so it fired on the pre-change golden as well as the new output,
and a check that reports a false positive on known-good output is worse than
none.

The honest answers are a real parser (a dependency, on a build that currently
needs only PowerShell) or a headless browser (much more). Neither is small.

### The stronger no-producer-kinds check is weak in practice — **small**

`NoProducerKinds.Tests.ps1` renders a payload of invented classifications and
asserts the document outside the payload is unchanged. That would catch a
PowerShell-side branch on a kind — but no backend does PowerShell-side work, so
today it can only pass. What it is really guarding is the seam, which is worth
guarding; it should not be read as covering the browser, where `KIND_HEX` itself
lived.

### A second golden for an awkward graph — **small**

`tests/fixtures/viewmodels/infrastructure.json` covers the shapes the golden
never sees: an apostrophe and an angle bracket in one label, a path with a
space, a two-node cycle, a metric at range. It is asserted against, but not
recorded as a golden, so a change in how any of those renders is caught only by
the specific assertions written for it.

### The instruction tier is still above its stated ceiling — **small**

`CLAUDE.md` says 10,000 bytes and weighs 11,301, down from 13,659 at v0.1.0.
"Traps that survived the move" and gravity's reasoning moved down a tier in
v0.2.0. What is left that could follow: "Build and test" belongs in
`docs/testing.md` and "Commit" in `docs/development.md`, which is roughly the
remaining gap between them.

Do not touch "The core constraint", "The contract is the product", or "A
template set is a rendering backend" - those are true before the work is known,
which is the test.

### `Show-RenderDocument` may not belong here — **large, and already open**

Listed under "Open decisions" in `CLAUDE.md`. It launches browsers, probes
loopback ports and reads user agents, none of which is rendering. Raise it
before resolving it.

## Noticed, not logged as work

- The renderer claims to be self-contained and is not - but only in one
  backend. `cytoscape` still pulls Cytoscape and dagre from jsdelivr; `plain`
  reaches no host at all and a test asserts it. Half the vendoring decision in
  `CLAUDE.md` is now answered by demonstration: an offline reader has a view.
  Whether the DEFAULT backend should be offline-capable is the half that is
  still open.
- `PSMissingModuleManifestField` fires on the `.psd1` extension alone and cannot
  tell a backend's `settings.psd1` from a module manifest. Excluded for
  `TemplateSets/` only, in the Lint task rather than in
  `PSScriptAnalyzerSettings.psd1`, so the rule still guards the real manifest.
- A few structural greys are still literals in `render.js` - the dimmed fill,
  the focus highlight, the selected border. They are not classifications and no
  producer influences them, so they are appearance the renderer owns. Worth
  moving to `theme.psd1` eventually; not the same problem as `KIND_HEX`.
- `PSModuleGraph`'s manifest sat at `ModuleVersion = '0.1.0'` through six
  annotated tags. Corrected to `0.7.0` during the extraction, but nothing
  enforces the agreement between the manifest and the tag.
