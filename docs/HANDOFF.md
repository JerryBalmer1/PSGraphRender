# HANDOFF

**Read this first.** It is the one file that assumes you know nothing about how
this repository is run.

Until v0.12.0 PSGraphRender operated itself: a `CLAUDE.md` read in full before
every session, five skills under `.claude/`, a thread ledger, and a tool that
compiled the threads into `docs/threads.json`. All of that is gone as of
v0.13.0. What it knew that was worth keeping is here or in `docs/`; what it
recorded is in `docs/ledger-archive/`.

Read `docs/constraints.md` early. It lists what this repository has decided
**not** to fix, with the argument for each. Proposing to fix an accepted
limitation without having read it is the most likely way to waste a pass.

## State, as of pass 0043

**Where it is.** v0.13.0, no tag taken this pass. `examples/` now holds six
generated reports — three layouts, a theme pair, a node-link demo — each with
the checked-in viewmodel that produced it, a 1600x900 screenshot, and a
paste-able command that rebuilds it. `README.md` leads with the foundation
screenshot and an Examples table; [`examples/README.md`](../examples/README.md)
is the full index.

**What pass 0043 did here.** Documentation and generated artifacts only. **No
`src/` file was changed**, and no example required one. Configuration reaches
this renderer through a template-set directory, so
[`examples/Build-Examples.ps1`](../examples/Build-Examples.ps1) materialises a
temporary overlay of the shipped `cytoscape` set, edits `Config/settings.psd1`
or `Config/theme.psd1` in it, and passes `-TemplateSetPath`. That is the seam a
third-party backend uses, and it is why generating six variants edited nothing.

**What it found.** One capability gap, logged and not taken: a node link can
only ever be an editor scheme, because `vsCodeUriFor` in
`scripts/editor-link.js` hardcodes `vscode://file/` and no setting names an
alternative. The examples wanted forge links for a report attached to a pull
request and could not have them. See **A node link can only ever be an editor
scheme** in [`docs/improvements.md`](improvements.md) — it is **large**, so it
is logged and stopped on rather than taken.

**Next.** ~~That backlog item wants its own red-first iteration and a version
bump.~~ **Taken by pass 0047 at v0.14.0 — see below.** Nothing else here is
blocked.

### Pass 0045

`PSGraphRender.code-workspace` no longer registers
`../PSModuleGraph` as a workspace folder — the entry is deleted, and harness
backlog 60 is closed.

### Pass 0047

**Where it is.** v0.14.0. The first pass to change `src/` since the handoff.

**What it did.** A node link is declared configuration now. `LinkMode` is an
Enum of `editor` (unchanged behaviour, and the default), `hrefTemplate` (a URL
per node from a template over view-model fields) and `none` (no link at all),
with `LinkHrefTemplate` beside it. Both are declared as data in
`Config/settings.schema.psd1` like every other setting. The backlog item pass
0043 filed is closed; no contract change was needed, because every token
resolves from a field the view model already carries.

**The one thing worth knowing before touching this.** The mode is resolved when
the document is **assembled**, not in the browser. `SlotsBySetting` in
`templateset.psd1` chooses which files fill the node-link slots, so a shipped
report carries one mode's code and not three — which is what lets `none` mean
the scheme construction is absent from the file rather than present and unused.
A report is one self-contained document that gets forwarded, so that
distinction is the whole point rather than a detail.

That is also why the link code is split the way it is.
`tests/LinkMode.Tests.ps1` asserts an `editor`-mode document is byte-identical
to v0.13.0's for the same payload, so code could not move within the assembled
document — only into files re-inserted where it already sat. If you are
tempted to tidy `link/` into one file per mode with a `concat` in `menu.js`,
that test is what will stop you, and it is right to.

**New in the build.** `./build.ps1 -Task TestLinkMode` opens each mode in
Chromium, right-clicks a node and reads the href off the menu — separate from
`TestBrowser`, which asks whether a page came alive rather than whether its
links are the ones configured. `LintJavaScript` now wraps declared fragments
before parsing them; see `FragmentSlots` in `templateset.psd1`.

**Examples.** Seven now. `examples/links/forge-links.html` is the report 0043
wanted and could not have: the same payload as `editor-links.html`, one setting
different, and live GitHub links from a committed file.

### Pass 0049

**Where it is.** v0.15.0. Three rendering backends.

**What it did.** Added `forcegraph3d`: a `3d-force-graph` (three.js) template
set that draws the same contract 1.1.0 payload in three dimensions. **No `.ps1`
under `src/` was edited to add it**, `TemplateSets/index.psd1` is untouched and
`cytoscape` stays the default, and both existing backends render byte-identically
to the base commit. That is the whole claim of the template-set design, and
until this pass its only witness was `plain` — which `docs/constraints.md` says
outright is *trivial enough to prove less than it looks*.

**The one thing worth knowing before touching this.** Four defects in it were
found by **running the page and looking at it**, and none of them was visible in
the source:

- The library's tooltip inserts a **string** as markup and appends an
  **element** as itself, so a producer's label goes in as an element carrying it
  in `textContent`. Safe by construction, not by an escaper.
- Its layout stops on a **fifteen-second timer** by default — longer than any
  gate here waits — so "fit the view when the layout settles" never fitted
  anything. The simulation is bounded in ticks now.
- It opened a **1280x900 canvas inside an 859px box** and never corrected it, so
  the bottom of every graph was outside its own element. Sized from the
  container explicitly.
- `#fg-notice` sets `display`, which **beats the user agent's
  `[hidden]{display:none}`**, so a hidden `inset: 0` element became an invisible
  sheet across the viewport that swallowed every click on the canvas. Eighty-one
  grid clicks hit nothing before `elementFromPoint` named it.

If you add a fourth backend that draws into a canvas, that last one is the trap:
any element you both style with `display` and hide with `hidden` is still there.

**The contract did not change and the stop never fired.** Whether the library
*requires* positional input or *computes* it was read out of the vendored bundle
before a line of the backend was written: it consults `fx`/`fy`/`fz` when a node
states one, and computes a position from a spherical lattice when it does not.
Consuming coordinates is a capability, not a demand — so the open decision about
backends declaring required contract fields stays open and untouched.

**Its `CanvasGrowth` floor is 2, and that is not a weaker standard.** This
backend draws lit spheres and thin lines where the reference draws filled boxes
with labels, so its measured ratios are 3.50 to 6.49 rather than 12.2. Two sits
1.75x below the thinnest case observed; the reference's 4 sits 1.84x below its
own thinnest of 7.34. Same daylight, different digit. The thinnest case is also
the first measured value between 4 and 12.2, which thread `0006-t2` records as
the gap that made the requirement untested against a sparse payload.

**New in the build.** `./build.ps1 -Task TestLinkMode` now runs its five
behaviours against **every** backend that declares link modes, discovered from
the manifests. ~~Where each backend's actions are reached is a map in that task —
and that map is a second place a backend's shape is written down, which is
logged in `docs/improvements.md` rather than left as a silent trade. It is there
because `cytoscape/templateset.psd1` could not move this pass.~~ *That map is
gone as of pass 0050; see below.*

**Examples.** Eight. `examples/threed/forcegraph3d.html` is the first that
varies the backend rather than a setting: the same payload the three layout rows
draw, rendered by a different directory.

### Pass 0052

**Where it is.** v0.17.0. The 3D report has depth, menus, and the composed look
as what it ships.

**The instrument was repaired before anything that would have blinded it, and
that ordering is the whole reason this was one pass.** The canvas floor
screenshotted `#fg` and divided by the same selector in an empty render, so
anything painted in that rectangle sat in the numerator and the denominator
together: the same drawing scored 4.32 on a flat ground and **1.05 under a
vignette**, below the 2.25 that shipped, on a page drawing perfectly.
`styles/base.css` had carried that warning as prose since v0.15.0 and nothing
turned the sentence into a check — finding 67. `smoke.cjs` now compares the two
pictures against each other: the fraction of the rectangle whose pixels differ
by more than 12/255 on any channel. A background is identical in both, so it
contributes nothing and cancels. `CanvasGrowth` is **gone** from `forcegraph3d`
rather than left beside the new key, and a test asserts its absence — two floors
on one selector is two answers to one question, and the stale one is the one
nobody re-measures. It still gates `cytoscape`, where an empty render really is
nearly blank, and `smoke.cjs` now *measures* that precondition instead of
assuming it.

**Every feature in the second half was unshippable under the old floor.** That
is not a claim about tidiness: `BackgroundStyle = 'vignette'` was measured and
rejected at v0.16.0 for exactly this reason, and it is the default now. Nothing
about the appetite for risk changed — the gate changed.

**What the graph sits in.** A `GridStyle` environment family — `none`, `floor`,
`room` — built from the graph's own bounding box, so it fits any payload. Scene
geometry and not a CSS backdrop, because it has to turn with the camera: a
perspective floor painted in CSS looks right in a screenshot and reads as broken
the instant a reader drags. Built from **quads rather than lines**, and forced
rather than chosen — the vendored bundle draws every link as a cylinder, so
there is no `Line` constructor anywhere in the live scene to harvest. The same
tree-shaking limit that made the shape vocabulary explicit vertices.

**Menus in the HTML, which is what the operator asked for.** A collapsible panel
over the canvas: zoom speed, fit, auto-rotate; depth falloff, environment,
click-to-focus; names, direction marks, glow; and one checkbox per
classification the payload carries. Its contract is that every control adjusts
at runtime what a setting in `Config/` decides at render time, and nothing
writes back into `CONFIG` — runtime changes are overrides beside it, so
"declared" and "changed by a reader" stay two facts. Every word it shows comes
from `strings.psd1`; the markup ships no English, which is the half the 2D
sidebar gets wrong.

**It found a shipped feature that had never worked.** `ForceGraph3D` *empties*
the container it is handed, so anything nested inside `#fg` is gone the moment
the graph initialises. `ShowLabels = 'always'` shipped at v0.16.0 with
`#fg-labels` inside `#fg` and never drew a single label — the layer was deleted
before `startLabels` looked for it, `getElementById` returned null, and the
function returned silently. `D3` and `E2` in the catalogue were pictures of the
feature not happening, captioned as though it were. It was found by the control
panel disappearing the same way. There is now an `#fg-stage`: the library gets a
container with nothing else in it, and everything drawn over the canvas is a
sibling. The smoke gate still captures `#fg`, which is now exactly the drawing
and no chrome.

**E1 won and left the table.** "Nebula — the recommended look" is now what `A0`
draws, so its row would be a second picture of the default. Its coordinate is
**retired rather than reused**: a label is a thing the operator points with, and
a pointer that quietly starts meaning something else is worse than one that is
gone. `A5` is the v0.16.0 default kept whole, so the promotion can be looked at
rather than read about.

**What it could not do, and said so.** Focus is the camera and the fog, not
depth of field — a real focus pull needs a post-processing pass and the vendored
bundle ships no `BokehPass`, so adding one means a second copy of three.js.
Auto-rotate is turned by hand because the controls the library builds are
`TrackballControls`, which has no `autoRotate` among its own keys. Both read off
the vendored bytes rather than from documentation.

### Pass 0051

**Where it is.** v0.16.0. Three rendering backends, and the third one now has a
look a caller can change without editing it.

**What it did.** Twenty-six settings on `forcegraph3d`: geometry per
classification with a declared fallback, size by any metric the payload carries,
glow, fog, environment, particles, tone mapping, camera speed, hover mode,
tooltip content, which button opens an item's actions, and label visibility.
`isExported` and `links[].resolution` are drawn for the first time. **No
contract change and no `.ps1` under `src/`** — every distinction is driven by a
field the viewmodel already carried or by configuration, and every setting reuses
a schema type that already existed.

**The third gate exists because the first two could not see a look.**
`-Task TestBrowser` establishes a page came alive and `-Task TestLinkMode` that
its links go where configuration said. Both were green over a backend that drew
every item as the same blue ball. `-Task TestLook` reads a `LookProbe` block the
backend declares for itself, and it needs **two kinds of evidence**: the DOM for
what the page *resolved* — a canvas cannot be read — and screenshots for what it
*drew*. Either alone goes green over the other's failure.

**It found two things on its first run, and neither was findable otherwise.**
The hover count was always zero while the drawing was visibly highlighting,
because the tooltip published the hover state again with no set and landed last.
And the fog case asserted equality against a value the page deliberately
normalises by camera distance — replaced with a proportionality check over two
documents, which is the right assertion for anything that scales.

**The prettiest default lost to a gate, and that is the entry worth keeping.**
`BackgroundStyle` was `vignette` until it was measured: a gradient is in the
canvas-growth floor's picture of an *empty* render as well as a drawn one, so it
does not move that ratio, it removes it — 3.79 to 1.05, and a gradient two steps
per channel from flat still scored 1.14. It ships `flat`. The environment is
`B1` and `B2` in the catalogue, and the measurement is in `Config/theme.psd1` so
that promoting it later is a decision rather than an inheritance.

**The catalogue is the delivery vehicle.** Nineteen labelled variants in five
families, each one overlay of declared settings from `A0` — which is the
default, asserted byte-identical to a no-overlay render. `catalog.html` is
generated from `examples/threed/variants.psd1`, always from the whole table, so
a variant is in the catalogue because it is in the table and drift is
impossible. The point of the labels is that "do this, but like that" becomes a
coordinate instead of a paragraph.

### Pass 0050

**Where it is.** v0.15.1. Three rendering backends, and each one now says how to
drive it.

**What it did.** Moved the link probe out of the build task and into the data.
`LinkProbe` sits beside `Smoke` in `cytoscape/templateset.psd1` and
`forcegraph3d/templateset.psd1` — the element to click in, the button that opens
a node's actions, the container they land in, and what must exist first — and
`./build.ps1 -Task TestLinkMode` reads it off the manifest it already imported.
The `$LINK_PROBE` map is gone.

**There were three copies, not two.** The backlog entry that logged this saw the
map in the build task. `tests/browser/link-mode.cjs` also carried a `DEFAULTS`
object holding cytoscape's canvas, menu, ready selector and mouse button, so any
backend whose job said nothing was being driven against cytoscape's shape. That
is the thing worth knowing here: **an entry written from one copy of a duplicate
undercounts it**, and the way the third copy surfaced was deriving the check
from the manifests rather than from the entry.

`Canvas`, `Menu`, `Button` and `Ready` are required now and missing means
failing by name. Two fallbacks remain and neither names anything: `Open` falls
back to `Menu` — a relationship between two fields the job did supply — and
`Hover` to no wait at all. `SETTLE_MS` stays as the harness's own floor, which
is a wait rather than a selector.

**The guard survives, inverted.** It threw for a backend absent from the map; it
throws for a manifest that declares link modes and no `LinkProbe`, naming the
manifest and the key. Demonstrated both ways: a scratch copy of `cytoscape`
without a probe failed the build in two seconds before a browser started, and
the same directory with one ran five link-mode cases green — fifteen cases from
a data edit, with no `.ps1` and no harness change.

**Nothing rendered moved.** `LinkProbe` is a top-level manifest key and
`Get-RenderTemplateSet` reads `Layout`, `Slots` and `SlotsBySetting` only.
`tests/LinkProbe.Tests.ps1` asserts that by stripping the block from a scratch
copy and comparing the two documents, and it carries its own red-capability: a
`Slots` edit to the same fixture does move the document.

## What this is

A **generic, data-driven report renderer.** It takes a view model as JSON and
writes a single self-contained interactive HTML page. It was extracted from
PSModuleGraph, where it lived under `Assets/Html/` and `Private/Html/`.

Four exported commands: `Get-RenderTemplateSet`, `New-RenderDocument`,
`New-RenderDocumentPath`, `Show-RenderDocument`.

`./build.ps1` is the only entry point. **Never call `Invoke-Pester` or
`Invoke-Build` directly** — a bare `Invoke-Pester` runs whichever version the
session happened to have and produces results that mean nothing. The browser
gate needs `./build.ps1 -Task BootstrapBrowser` once; it fails rather than
skipping, deliberately.

## Contract

`contract/viewmodel.schema.json` is the boundary and it is the product. It is
JSON Schema, language-neutral, and **versioned independently of the module**: it
is at **1.1.0** while the module is at 0.16.0.

Change protocol:

1. **Every entry point validates against it** and fails loudly on a mismatch.
   A renderer that quietly tolerates a malformed payload teaches producers to
   emit malformed payloads.
2. **The schema is not PowerShell.** No `.psd1`, no `PSTypeName`, no serialised
   objects. The test is concrete: **if a Python or Go producer would have to
   reshape its data to satisfy it, the schema is wrong.** That is the only
   falsifiable statement of this repository's central claim, which is why it is
   written here rather than left implied.
3. **Additive changes bump minor; shape changes bump major.** A field gained is
   minor. A field renamed, removed, or given a new type is major, and the old
   name survives as an alias with a `since` marker. **Removal is not an
   operation this contract has** — that rule starts at 1.0.0, and the three
   `data.module*` fields `docs/contract.md` records as removed were removed
   before it applied.
4. **`contractVersion` travels in `meta` and the renderer reads it.** A payload
   that declares a major the renderer does not implement is refused by name, not
   rendered on a guess. A payload that declares nothing is warned about and
   rendered: absent is not the same as wrong.

A contract change is a proposal, never an edit made in passing. Do not bump the
schema without a consumer-driven reason.

## Boundaries

**The renderer knows about nodes and edges. It knows nothing about what they
are.** Everything else follows from that one rule.

- **It never parses a module.** It has never imported one and nothing in it may
  learn how. The producer handing it a view model could be written in Go or
  Python and this repository would not be able to tell.
- **It never learns producer kinds.** Forbidden below the public surface — in
  code, comments, file names, setting names, string keys **and test names** —
  are `Module`, `PSModule`, `Ast`, `PSModuleGraph`, `Manifest`, `Cmdlet`; the
  name of any command belonging to a producer; and any hardcoded list of node
  kinds (`function`, `class`, `enum`, …). Permitted, because they are this
  repository's own domain: `Node`, `Edge`, `Link`, `Graph`, `Layout`, `Facet`,
  `Metric`. `tests/NoProducerKinds.Tests.ps1` holds the enforced list.
- If answering a question would require knowing what the data means, **render
  less instead.** A report that omits a panel is correct. A renderer that
  special-cases one producer's vocabulary has failed at the only thing it exists
  for.
- **Vendored files are never hand-edited.** Whole-file replacement, hash
  verified, or nothing. See `docs/vendoring.md`.
- **No test may import PSModuleGraph, or any producer.** A suite that reaches
  for a real dependency graph to get something to render has re-coupled the two
  repositories at the only place the coupling was removed.
- **Adding a backend, or a setting, must not require editing a `.ps1`.** If it
  does, the design is wrong: report it as a bug, do not work around it.

## Version ledger

| Version | What it marks |
| --- | --- |
| `v0.12.0` | the last release operated by the resident agentic workflow |
| `handoff-begin-2026-08-29` | annotated tag on `v0.12.0`'s commit, `4a367c6`. Everything before it was operated by the in-repo thread-ledger process; everything after is operated plan-by-plan from the harness project |
| `v0.13.0` | this handoff. Vendor tooling added, resident workflow removed, knowledge archived |
| `v0.14.0` | link mode: a node link is configuration rather than a hardcoded scheme. First `src/` change since the handoff |
| `v0.15.0` | a third backend, `forcegraph3d`. The first evidence that a template set is a rendering backend that does not come from a trivial one |
| `v0.15.1` | the link probe becomes backend data. `LinkProbe` beside `Smoke`; neither the build task nor the browser harness names a selector any more |
| `v0.16.0` | the 3D backend's look becomes configuration. Twenty-six settings, a third browser gate (`LookProbe`), and a nineteen-variant catalogue generated from its own table |
| `v0.17.0` | the canvas floor learns to see through a painted background, and the 3D report gets an environment, a control panel, and the composed look as its default |

The module version and the contract version move independently. For the module:
**patch** for a normal implementation, **minor** when a template set, a setting
type, a build task, or a contract field is added, **major** when the view model
contract changes shape.

Every release is an **annotated** tag (`git tag -a`) — a lightweight tag carries
no message, no author and no date of its own. The tag is the last action, after
the default build is green and `./build.ps1 -Task PreTag` passes.

**No history rewriting on anything pushed.** No amend, no rebase, no force.

## How it is operated now

Plan-by-plan, from the `AI.Agent.Claude.PowerShellModuleBuilder` harness
project, under its **decision 0010**. Work happens on a `pass-NNNN-*` branch;
after a green pass the agent fast-forwards `main` with ancestry verified by
`git merge-base --is-ancestor`, never forced, and pushes the tags the pass
prompt names. No history rewrites, no `Publish-Module`, no force pushes.

There is no resident agent process in this repository any more. Nothing here
reads instructions before starting; the pass prompt is the instruction.

What the deleted workflow enforced, and what now has to be carried by whoever
is working:

- **A gate that has only ever been green is indistinguishable from a gate that
  cannot go red.** Reading the gate is not evidence: in every recorded instance
  the source looked correct and what was wrong was a fact about the runtime the
  source does not contain. Break the thing the gate **guards** — not the gate —
  run it, read the *message* and not just the colour, restore, and confirm green
  again. Record the exact break and the exact message somewhere dated and
  attributable; a commit message is the surviving place for that.
- **Proving a gate can go red is not proving it goes red for the input you care
  about.** The version gate was proved in both directions and still could not
  catch the drift that prompted it, because `RequiredModules` declares a
  *floor*: it refuses anything below and accepts everything above, and the drift
  was upward. Prove both; where you can only prove the first, say so.
- **A falsifiability proof that comes back green is a finding, not a failure** —
  it has located the gate's real boundary, and the boundary is what you write
  down. `node --check` reported fourteen scripts parsing when one had been given
  a call to a function that does not exist, because a runtime error is
  syntactically perfect.
- **A harness that asserts two things needs two breaks.**
- **`Invoke-Pester` inside `Invoke-Pester` inherits the outer run's
  configuration**, so a probe written that way measures the outer filter. Run
  the probe in a child process. `tests/PreTag.Tests.ps1` carries this as a
  comment where it bites.
- **Commits:** read `git status --short` and stage path by path, never
  `git add -A`. One logical change per commit — a commit that needs "and" to
  describe is two. The message states the failure prevented, not the change
  made: `Fail the render when the payload declares an unknown contract major`,
  not `Add contract version check`.
- **Commit and push after every task, in every pass.** A task is not done
  until its commit is on the remote. This is not a preference about tidiness:
  work that lives only in a working tree is invisible to `git status` as
  *progress*, indistinguishable from work not started, and unrecoverable by
  anyone but the process holding it. Pass 0052 was stopped by its operator on
  finding twenty-three files of finished, unpushed work, and the root cause
  was an authoring defect — the prompt's task spine had been compressed and
  the cadence line every prompt from 0047 to 0051 carried was dropped. So the
  rule lives here rather than in a prompt: **no future prompt's brevity
  overrides it**, and a prompt that omits it has not repealed it.

Two design rules that were kept in the always-loaded tier precisely because they
get violated from outside the document that argues them:

- **`DefaultFlow` ships as `foundation` and stays `foundation`.** Which view a
  report opens in is a settled decision, not a preference.
- **The foundation view lays itself out; it is not dagre.** Measured in both
  directions before it was chosen. Do not "simplify" it back to a ranker.

Both follow from gravity: **what everything rests on goes at the bottom, and the
report opens that way.** `docs/render-architecture.md` has the mechanics; that
sentence is the reason they are the way round they are, and the file already
warns that inverting them is the bug to watch for.

Two more that the docs state positively and never negatively:

- **The four config files, by what they must never hold.** `settings.psd1`:
  current values, never descriptions or ranges. `settings.schema.psd1`: type,
  default, range, group, description, constraints — never current values.
  `theme.psd1`: colours, fonts, spacing — never behaviour. `strings.psd1`: every
  user-visible string — never markup. When a value could be a setting or a
  theme, ask which one a user would change to alter *what happens* versus *how
  it reads*.
- **New behaviour joins a registry as one entry, rather than sitting beside it
  as a branch.** The registries are `NODE_ACTIONS`, `SELECTION_FACTS`,
  `SELECTION_ACTIONS`, `FLOW_LAYOUT` and the template-set list. Each exists
  because "would a second one of these be one entry?" was answered no, and then
  became yes.

## Open

Seventeen threads were open in `docs/threads.json` when it was deleted. Their
full raising text is in `docs/ledger-archive/`, under the entry whose number
prefixes the id.

| Id | What it is about |
| --- | --- |
| `0002-t3` | `Get-RenderTemplateSet` may not belong on the public surface. Nothing outside the module calls it now that `New-RenderDocument` resolves the backend itself, but the README documents it as public, which raised the cost of removing it. |
| `0005-t1` | The browser harness asserts the page *loaded*, not that it is *right*. Whether the foundation layout is correct, whether the heat ramp ranks properly and whether focus mode does what it claims are unverified by anything. |
| `0006-t1` | The harness has been proved able to fail on one machine only. Nobody has broken a script in CI and watched it go red. |
| `0006-t2` | The `CanvasGrowth` ratio has never met a legitimately sparse payload. The requirement is 4x against measured values of 12.2 and 13.6, with nothing in between, so a genuinely thin graph could be reported as a blank canvas. |
| `0007-t1` | The uncertain-edge style is calibrated against one graph density. Neither the sparse nor the saturated end has been looked at by a person. Logged **large** in `docs/improvements.md`: changing the channel is a design decision about the report's mental model. |
| `0008-t4` | Nothing checks the README. Its code blocks were run once by hand; two byte counts in it drift whenever a library is vendored. |
| `0010-t6` | No single page carries all three dashed-line treatments where a reader can compare them. Only the 532-node payload has all three, at a density where two are invisible. |
| `0011-t1` | Thirty-two thread verdicts were proposed in one pass by the person who raised most of the threads. |
| `0011-t2` | The deleted `threads.ps1` deliberately did not rank threads, because **carry count was measured against every closure in the project and predicts nothing** — twenty-one of twenty-three closures happened in the very next entry, and nothing ever closed after four carries. Kept here because the measurement is the only thing that stopped a staleness column being added. |
| `0011-t3` | A thread merged across the two repositories has no id grammar: `NNNN-tN` names no repository. Nine ids collided between the two. |
| `0012-t2` | `docs/constraints.md` only works if it is read first, and nothing enforces reading it. The link at the top of this file is the current answer. |
| `0012-t3` | Twenty-eight verdicts were applied in one pass. A Close applied without re-reading the thread is indistinguishable from a thread silently dropped. |
| `0013-t1` | Search plus a structural checkbox can still strand a node: the layout runs over the visible set, so clearing a search after ticking a checkbox brings nodes back at positions from a layout that never included them. The residual of the v0.12.0 placement fix, one interaction deeper. |
| `0013-t2` | No automated gate can see any of the four visual defects fixed at v0.12.0. The check that would catch the placement family is one sentence — after clicking each selector the backend declares, no two visible nodes share a position — but it needs a new declaration in `templateset.psd1`, which is a data shape, so it is logged and stopped on. |
| `0013-t3` | The strings gate refuses six words and `strings.psd1` still assumes a call graph: three metric hints and a menu label say "call" about edges the payload never classified. A word list is not a rule. |
| `0013-t4` | The shared-label qualifier has never met a payload with duplicate names and no paths; it falls through to the node id, which on a real module is eighty characters in a 340px sidebar. |
| `0013-t5` | Retiring a thread did not retire the backlog entry describing it, so `docs/improvements.md` presented seven already-settled threads as open work. |

`0011-t1`, `0011-t3`, `0012-t3` and `0013-t5` are about the thread machinery
itself and are moot now that it is gone; they are listed because a reader
counting seventeen against the archive should find all seventeen.

### Pending, raised from outside this repository

**`src/PSGraphRender/PSGraphRender.psd1` cannot be imported directly.** The
manifest's `RootModule` names `PSGraphRender.psm1`, which the build generates
into `output/` and which does not exist in `src/`, so:

    Import-Module ./src/PSGraphRender/PSGraphRender.psd1

fails with *"no valid module was found in any module directory"*. Verified in
pass 0025 of the AI.Agent.Claude.PowerShellModuleBuilder harness; the two
sibling modules built to the same pattern, PSGraphRenderToHtml and
PSTerraformGraph, both carry a committed dev loader at
`src/<Name>/<Name>.psm1` and both import cleanly from source. This repository
does not.

The fix is a committed dev-loader psm1 that **dot-sources** `Private/**` then
`Public/*` and exports the same list as the manifest — dot-sources rather than
concatenates, so `$script:ModuleRoot` means the same thing under both loaders
and a template or culture directory resolves either way. The harness's
`powershell-module-scaffold` skill now carries the pattern.

**Not applied here.** Pass 0025 was scoped to leave this repository's code
untouched, and this is a change to shipped source rather than a note. It is
recorded so the next pass that may touch PSGraphRender does not rediscover it.
Until then, import the built module from `output/`.

### What our only consumer is still carrying about us

From the PSModuleGraph half of the same record. These are that repository's
threads and are fixed there, but each is about this seam:

- **PSModuleGraph's `RequiredModules` floor on PSGraphRender is treated as a
  pin.** It refuses any version below the floor and accepts every version above
  it, including one that broke the goldens. This is how the renderer's releases
  reach its only consumer, and it is the live risk in every release here.
- **Nothing proves PSModuleGraph really requires PSGraphRender.** Both modules
  are loaded in the same session throughout that suite, so a call that should
  cross the boundary and does not would still pass.
- **The `vscode://` editor-link claim is unverified** when the report is served
  from `http://127.0.0.1:PORT` rather than `file://`. That is
  `Show-RenderDocument`'s loopback path.
- **The extraction golden that is effectively this repository's acceptance test
  claims a provenance it lost**, and three whole-document comparisons there are
  skipped pending a decision.

### Consumers to come

- **PSGraphRenderToHtml** — a battery for this renderer. A stub today: a
  README and nothing else.
- **PSTerraformGraph** — a second producer, and the first one that is not
  PowerShell. It is the real test of the producer-agnosticism boundary above:
  everything this renderer refuses to know about modules is what makes a
  Terraform producer possible without changing anything here. Also a stub.

Neither exists yet. When the second producer arrives, the contract stops being a
claim and starts being a measurement.
