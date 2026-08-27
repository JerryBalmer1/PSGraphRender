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

### The skills directory is a copy that makes false claims here - **medium**

All five skills in `.claude/skills/` are byte-identical to `PSModuleGraph`'s
with nothing keeping them in sync. Four claims in them are false in this
repository: `tests/Private/SubsystemCharter.Tests.ps1` does not exist,
`knowledge/NAMING.md` does not exist, `docs/html-architecture.md` is named
`docs/render-architecture.md`, and the version rule talks about facets in a
repository with none. A fifth is worse - `instruction-prune` says a deferred
deletion proposal is blocked by `tests/PreTag.Tests.ps1`, and this
repository's `PreTag.Tests.ps1` has no such gate, so `prune_proposals` is
unenforced here. A shared source, a sync test, or a deliberate fork with the
differences stated - all three are decisions. *Ledger `0009-t2`.*

### No skill here has ever been invoked - **small**

Measured across v0.5.0 to v0.8.0: every iteration closed correctly from
`CLAUDE.md` and from memory, and no skill body was loaded.
`instruction-prune` was invoked for the first time in `0009`. Not an argument
for deleting any of them - a procedure followed correctly from memory is the
good case - but nothing here has been read under the conditions it was
written for, and `0005-t1` still says the descriptions are unbudgeted.

### There is no CHANGELOG - **small**

Eight annotated tags and no `CHANGELOG.md`. `PSModuleGraph` has one. The
ledger carries everything, and a ledger entry is written for the next
implementer rather than for a consumer of the module. *Ledger `0009-t4`.*

### An invented node is drawn on top of a real one — **medium**

With unresolved shown, the orange node the renderer invents lands on the node
that referenced it. On the six-node `ambiguous` fixture `notify-oncall` occludes
all but three letters of `rollout`, and hides its own dotted edge, which is why
the fourth line treatment is still unseen. Not a density effect. *Ledger
`0008-t1`, found by looking at a screenshot.*

### Two sidebar lists print a name twice and mean two nodes — **medium**

The cycle list and the test order list read `Test-TargetResource,
Test-TargetResource` on SqlServerDsc. Node ids have been distinct since the
producer's v0.11.0; these lists show labels, and a label is a name. Whatever
distinguishes them has to come from the payload, so it is not purely a script
change. *Ledger `0008-t2`.*

### The uncertain-edge style does not survive density — **large**

Unmistakable at six nodes: two dashed faded arrows to two boxes with the same
label read as "either of these" without explanation. At 532 nodes the edges are
a grey crosshatch and 702 dashed out of 1,271 cannot be recovered from the
drawing. The encoding is correct and the channel is saturated. What carries it at
that size is the Details panel count. Changing it means choosing another channel,
which is a design decision about the report's mental model. *Ledger `0007-t1`,
measured in `0008`.*

### The fill channel is dead on the payload that needs it most — **medium**

All 469 SqlServerDsc functions are one kind, so `ColorBy = structure` paints one
colour on the only real module anyone has rendered. A metric ramp is one click
away and is not what the page opens in. Whether the default should depend on
what the payload contains is a decision. *Ledger `0008-t3`.*

### Nothing checks the README — **small**

Seven code blocks, run once by hand before it shipped. Two byte counts in it
drift the next time a library is vendored, and the whole thing is a claim about
current behaviour written by whoever just changed it. *Ledger `0008-t4`.*

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

### Nothing runs the page — **closed in 0.5.0**

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

That last line was the block and the vendoring decision removed it: the
libraries ship inside the backend, so an offline `cytoscape` page is a working
page and a red harness means one thing. `TestBrowser` runs both backends against
both fixtures with the network blocked, and it was proved able to fail before it
was trusted — see `knowledge/ledger/0005`.

What it still does not do is judge. It says the page loaded, the counts match
and something was drawn. It says nothing about whether the foundation layout is
correct, whether the heat ramp ranks properly, or whether focus mode does what
it claims.

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

`CLAUDE.md` targets 10,000 bytes and weighs 10,644, down from 13,659 at v0.1.0.
"Traps that survived the move" and gravity's reasoning moved down a tier in
v0.2.0. What is left that could follow: "Build and test" belongs in
`docs/testing.md` and "Commit" in `docs/development.md`, which is roughly the
remaining gap between them.

Do not touch "The core constraint", "The contract is the product", or "A
template set is a rendering backend" - those are true before the work is known,
which is the test.

### `Show-RenderDocument` may not belong here — **large, and already open**

Listed under **Open decisions** at the foot of this file. It launches browsers,
probes
loopback ports and reads user agents, none of which is rendering. Raise it
before resolving it.

## Noticed, not logged as work

- CI had never executed a single step before v0.6.0. `shell: ${{ matrix.powershell }}`
  on a step is not valid - `matrix` is not a recognised named-value there - so
  every run since v0.2.0 failed as "workflow file issue" before any job started.
  Six red badges nobody read, and every "CI is wired" note in the ledgers
  described a file that could not run. What made it findable was
  `gh workflow run`, whose 422 names the line; nothing in the runs API does.
- A report is 607 KB, up from 126 KB, and every reader pays it. That was the
  price of vendoring and it was accepted deliberately; it is recorded here
  because nobody has asked a reader whether they noticed.
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

## Open decisions

Moved out of `CLAUDE.md` at v0.8.1 - they are backlog, not something an agent
needs to be true before it starts. The rule stayed up there, because it is
violated from outside this file: **do not resolve one of these unilaterally as
part of an unrelated change - raise it first.**

- **Should library code be vendored instead of loaded from a CDN?** The page
  claims to be self-contained and is not: Cytoscape and dagre come from
  jsdelivr with SRI hashes, guarded by `partials/cdn-guard.html`. A second
  backend adds more. Vendoring makes the page genuinely offline-capable and
  makes it large.
- **Should a backend be able to declare required contract fields?** Today every
  backend must cope with every payload. A declaration would let a 3D backend
  demand coordinates, at the cost of a payload that renders in one backend and
  not another.
- **Should `Show-RenderDocument` stay in this repository?** It launches
  browsers, probes loopback ports and reads user agents, none of which is
  rendering. It moved here because the charter said so; that may have been the
  wrong seam.
