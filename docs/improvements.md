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


> **Before proposing to fix something, read [`constraints.md`](constraints.md).**
> It lists what this repository has decided to live with and why. Those are
> not backlog: they were raised as threads, ruled on, and retired as
> accepted rather than deferred. Disagreeing with one is a proposal, not an
> edit.

## Open

### There is no CHANGELOG — **closed in 0.9.0**

`CHANGELOG.md` exists and says at the top that it was derived from the tags
and the ledger rather than recorded at the time. *Ledger `0009-t4`.*

### An invented node is drawn on top of a real one — **fixed in 0.12.0**

It had never been laid out. The layout places the visible set, so a node
revealed afterwards had no position and sat at the origin. Two other threads
were the same fact. *Ledger `0008-t1`, closed in `0013`.*

### Two sidebar lists print a name twice and mean two nodes — **fixed in 0.12.0**

It did not need the payload after all: a shared name carries the shortest
trailing run of path segments that separates it. *Ledger `0008-t2`, closed in
`0013`.*

### Nothing gates a defect a person can see — **large, logged not taken**

Four visual defects were found by opening the page and five fixes were verified
the same way. The browser harness says the page came alive; nothing it can
assert would have gone red for any of them.

The check that would catch the whole placement family is one sentence — *after
clicking each selector this backend declares, no two visible nodes share a
position* — and about sixty lines beside `tests/browser/smoke.cjs`, which must
not acquire reasons to change. It cannot go in that file and it cannot name
`#show-unresolved` in a shared harness, so it needs a declaration in
`templateset.psd1`. **That is a data shape, which the charter says to log and
stop on.** *Ledger `0013-t2`.*

### The link probe names each backend's selectors in the build task — **closed in 0.15.1**

`./build.ps1 -Task TestLinkMode` carries a `$LINK_PROBE` map: per backend, the
element to click in, the button that opens its actions, and the container they
land in. `tests/browser/link-mode.cjs` reads them off the job, so the harness
stays backend-agnostic — but the map itself is **a second place a backend's shape
is written down**, which is exactly the defect the `Smoke` block was invented to
remove from `tests/browser/smoke.cjs`.

~~It belongs in each `templateset.psd1`, beside `Smoke`, for the same reason
`Smoke` is there. It is not there because putting it there means editing
`cytoscape/templateset.psd1`, and pass 0049's no-regression control is that
`cytoscape` does not move at all. The task throws by name for a backend it does
not know how to reach, so a fourth backend cannot arrive with its modes silently
unchecked — but that is a guard against forgetting, not the fix.~~

*Found while adding the third backend, pass `0049`.*

**Closed by pass 0050 at v0.15.1, and the count was wrong: there were three
copies, not two.** `tests/browser/link-mode.cjs` also carried a `DEFAULTS`
object — `{ canvas: '#cy', menu: '#node-menu', button: 'right', ready: '#cy
canvas' }` — so cytoscape's shape was written down in the harness as well, and
any backend whose job said nothing was driven against cytoscape's fallbacks. The
entry above saw the map and not the fallbacks, which is what finding a duplicate
by looking at one of its copies costs.

`LinkProbe` now sits beside `Smoke` in every backend that declares
`SlotsBySetting.LinkMode`, and reaches the harness whole and verbatim exactly as
`Smoke` does. `$LINK_PROBE` is gone, `DEFAULTS` is gone, and `Canvas`, `Menu`,
`Button` and `Ready` are required — missing means failing by name. Two fallbacks
remain and neither names anything: `Open` falls back to `Menu`, which is a
relationship between two fields the job did supply, and `Hover` to no wait at
all.

**The guard survives, inverted.** It fired for a backend absent from the map; it
now fires for a manifest that declares link modes and no `LinkProbe`, naming the
manifest and the missing key. `tests/LinkProbe.Tests.ps1` turns that red at build
time rather than forty seconds into a browser run, and it derives the selectors
it forbids in the harness **from the manifests**, so a fourth backend's shape is
covered the day it is declared instead of the day somebody remembers to add it.

**A fourth backend was demonstrated rather than argued.** A scratch copy of
`cytoscape` declaring link modes and no probe failed the build by name in two
seconds, before a browser started; the same directory with a `LinkProbe` block
ran all five link-mode cases green. Fifteen cases, one data edit, no `.ps1` and
no harness change.

### The backlog was not swept when the threads were — **small**

The v0.11.0 triage retired twenty-eight threads and left this file describing
seven of them as open work, including one closed two releases earlier. Nothing
connected a thread's disposition to the backlog entry that describes it. The
thread record that knew every disposition was deleted at v0.13.0, so this file
and `constraints.md` are now the only statement of what was settled. *Ledger
`0013-t5`.*

### The uncertain-edge style does not survive density — **large**

Unmistakable at six nodes: two dashed faded arrows to two boxes with the same
label read as "either of these" without explanation. At 532 nodes the edges are
a grey crosshatch and 702 dashed out of 1,271 cannot be recovered from the
drawing. The encoding is correct and the channel is saturated. What carries it at
that size is the Details panel count. Changing it means choosing another channel,
which is a design decision about the report's mental model. *Ledger `0007-t1`,
measured in `0008`.*

### The fill channel is dead on the payload that needs it most — **accepted at 0.11.0**

That is the module, not the renderer: 469 of 532 nodes are one kind. Choosing
a different channel at density would be the renderer deciding what the data
means. The argument is in `docs/constraints.md`. *Ledger `0008-t3`.*

### Nothing checks the README — **small**

Seven code blocks, run once by hand before it shipped. Two byte counts in it
drift the next time a library is vendored, and the whole thing is a claim about
current behaviour written by whoever just changed it. *Ledger `0008-t4`.*

### `Get-HashtableValue` exists in both repositories — **accepted at 0.11.0**

Duplicating fifteen lines is cheaper than re-coupling two repositories. The
argument is in `docs/constraints.md`. *Ledger `0001-t5`.*

### A backend can still assume a shape the contract does not promise — **accepted at 0.11.0**

A static scan of dynamic access has a ceiling and this is where it is. The
argument is in `docs/constraints.md`. *Ledger `0004-t2`.*

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
was trusted — see `docs/ledger-archive/0005`.

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

### `Show-RenderDocument` may not belong here — **large, and already open**

Listed under **Open decisions** at the foot of this file. It launches browsers,
probes
loopback ports and reads user agents, none of which is rendering. Raise it
before resolving it.

### One backend draws and the other proves nothing about it — **closed in 0.15.0**

Two backends shipped from v0.2.0 and `docs/constraints.md` records, as `0002-t1`,
why the count overstated the evidence: **`plain` is trivial enough to prove less
than it looks.** It renders a table, asks configuration for nothing structural,
and could not have inherited a Cytoscape assumption because it has never heard
of Cytoscape. Its triviality is what makes it a control — and it is also what
makes "a template set is a rendering backend" a claim with one witness.

**This entry is written at its closure, and nothing is struck above it, because
nothing was here to strike.** The work was **large** — a new directory, new
tests, a vendored dependency — and under the size rules a large item is logged
and stopped on. It was not logged: it lived on the operator's list as item 2,
outside this file, from before v0.14.0 until pass 0049 took it. The gap is the
point of recording it this way. A large item held somewhere this file cannot see
is one that reads, from here, as an item nobody has thought about.

**Closed by pass 0049 at v0.15.0: `forcegraph3d`.** A `3d-force-graph`
(three.js) template set that reads the same contract 1.1.0 payload and draws it
in three dimensions. **No `.ps1` under `src/` was edited**, `TemplateSets/index.psd1`
is untouched, and `cytoscape` and `plain` render byte-identically to the base
commit — asserted, not asserted-to-have-been-checked, by
`tests/ForceGraph.Tests.ps1`.

**The contract stop never fired, and the question was put to the artifact rather
than to a guess.** Whether the library *requires* positional input or *computes*
it decides whether this backend needs a coordinate field, which would have been
a contract change and therefore a decision nobody had made. Read out of the
vendored bundle: the simulation consults `fx`/`fy`/`fz` when a node states one
and computes a position from a spherical lattice when it does not. Consuming
coordinates is a capability it offers, not an input it demands — so the open
decision below about backends declaring required contract fields stays open,
untouched, and is now a question with one worked example against it.

**What it is deliberately not** is feature parity. No sidebar, no filtering, no
focus mode: those are the reference backend's machinery, and the whole argument
of `0002-t1` is that a second *elaborate* backend proves the seam while hiding a
seam defect behind its own. What it does carry is everything the seam has to
survive — its own `vendor/`, its own four Config files, its own Smoke block, and
the whole link-mode registry with token parity asserted against the reference
backend's own resolver.

### A node link can only ever be an editor scheme — **closed in 0.14.0**

`vsCodeUriFor` in `scripts/editor-link.js` builds `vscode://file/{path}:{line}`
and `NODE_ACTIONS` in `scripts/menu.js` binds to it. The prefix is a literal in
script, so a caller cannot ask for anything else, and there is no setting in
`Config/settings.schema.psd1` that names one.

That makes one obvious use impossible: a report attached to a pull request,
where the reader has no clone and the useful destination is the file **on the
forge** — `https://…/blob/<sha>/<path>#L<line>`. Today such a report has to
ship links that only work on the author's machine, or none.

~~The shape of the answer is probably a settings entry naming a link MODE, with
the editor scheme as its default so nothing changes for existing callers, plus
a template for the href case. It is **large**: it adds a setting, changes what
a node's context menu can do, and touches the one file whose links a reader
clicks — so it is logged and stopped on, not taken unprompted.~~

~~Found by pass 0043 while building `examples/links/`, which wanted forge links
and could not have them. That example ships with a placeholder `rootPath`
instead, and says so.~~ *Wants its own red-first iteration.*

**Closed by pass 0047, and the guess above was right about the shape and wrong
about the mechanism.** `LinkMode` is an Enum of `editor`, `hrefTemplate` and
`none`, defaulting to `editor`, with `LinkHrefTemplate` beside it — declared as
data in `Config/settings.schema.psd1` like every other setting, needing no new
validator type and no contract change.

What the guess missed is that a runtime branch is the wrong place for it. A
report is one self-contained file that gets forwarded, so a mode selected in the
browser would leave every other mode's code sitting in the document — inert, but
present. `none` has to mean the scheme construction is not in the artifact.
So the mode is resolved when the document is **assembled**: `SlotsBySetting` in
`templateset.psd1` picks which files fill the node-link slots, and the shipped
document carries one mode's code and not three.

The constraint that shaped it was the no-regression control: an `editor`-mode
document had to stay byte-identical to v0.13.0's. Code could not move within the
assembled document, only into files re-inserted where it already sat — which is
why `editor-link.js` became `link/common.js` plus `link/editor.js` and the menu
entries, selection action and diagnostics row became slots rather than a
`concat`. `tests/LinkMode.Tests.ps1` asserts that identity on every run.

`examples/links/forge-links.html` is the report pass 0043 wanted and could not
have: the same payload as `editor-links.html`, one setting different, and links
that work from a committed file on anyone's machine.

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

Moved here at v0.8.1 out of the always-loaded instruction tier that this
repository no longer has - they are backlog, not something that has to be true
before the work is known. The rule did not move with them, because it is
violated from outside this file: **do not resolve one of these unilaterally as
part of an unrelated change - raise it first.**

- ~~**Should library code be vendored instead of loaded from a CDN?**~~
  **Answered at v0.5.0 and struck at v0.9.0.** They are vendored, the page
  makes zero external requests measured headless, and
  `partials/cdn-guard.html` - which the question pointed at - was deleted in
  the same iteration. It stayed in the always-loaded tier as a live question
  for four versions. Prune proposal `0009-t1`, applied.
- **Should a backend be able to declare required contract fields?** Today every
  backend must cope with every payload. A declaration would let a 3D backend
  demand coordinates, at the cost of a payload that renders in one backend and
  not another. **Still open, and now with a worked example against it**: the 3D
  backend shipped at v0.15.0 and demanded nothing. Its layout computes positions
  from nodes and links and consults a fixed one only when a node offers it, so
  the case this question was written around turned out not to need the
  mechanism. That is evidence about one library, not an answer — a backend that
  genuinely required a field would still have nowhere to say so.
- **Should `Show-RenderDocument` stay in this repository?** It launches
  browsers, probes loopback ports and reads user agents, none of which is
  rendering. It moved here because the charter said so; that may have been the
  wrong seam.
