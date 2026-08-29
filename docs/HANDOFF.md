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
is at **1.1.0** while the module is at 0.13.0.

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
