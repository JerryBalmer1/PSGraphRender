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

### A backend can still assume a shape the contract does not promise — **small**

Was medium. `tests/BackendContract.Tests.ps1` scans each backend's scripts for
`DATA.<field>` and `META.<field>`, follows a direct alias of either, and fails
naming the field and the file when the schema does not declare it.

What is left is what a regex cannot see. `DATA[fieldName]` is invisible to it,
and a test in that file records the gap by asserting the scan finds nothing in a
computed access — the limitation is executable rather than a comment. A nested
read (`node.severity`) is also outside it: the scan reaches one level.

### Nothing runs the page — **medium, and blocked**

Closed in part. `LintJavaScript` runs `node --check` over every backend script
and `LintDocument` runs it over the inline blocks of a rendered document, which
is the form a browser receives. Neither skips when node is absent.

Parsing is not running. A page can parse perfectly and still throw on load, and
the suite still asserts only on text PowerShell produced. A headless harness was
built far enough to measure, in Playwright 1.49.1 against Chromium: `plain`
comes alive with no network at all (0 external requests, 0 console errors, 17
table rows for a 17-node payload); `cytoscape` online reports 17 nodes, 0
console errors and three painted canvases in about 3.5 seconds; `cytoscape`
offline shows the CDN guard and produces two console errors and no node count —
the same signature a genuinely broken script produces.

That last line is the block. It cannot be finished until the vendoring question
under "Open decisions" in `CLAUDE.md` is answered, and it is not this
repository's to answer.

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

`CLAUDE.md` targets 10,000 bytes and weighs 11,223, down from 13,659 at v0.1.0.
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
  Measured, for whoever decides it: the two libraries are 481 KB minified, and
  a report is 126 KB, so vendoring makes every report roughly five times its
  present size.
- A user-visible string still lives in markup rather than `strings.psd1`, and
  for once it has a reason. `partials/template-notice.html` is shown only when
  the template was never filled in - the case where `STRINGS` is the literal
  `null` the substitution left behind. A string cannot come from a file that
  was not read. Checklist line 214 should say so rather than reading as debt.
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
