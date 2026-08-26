# CLAUDE.md — working rules for PSGraphRender

Guidance for an agent editing this repository. It covers only what is easy to
get wrong here. General PowerShell practice is assumed and not repeated.

**This file is the always-loaded tier and is read in full before every session
does anything at all.** Everything in it earns that cost by being true before
the work is known. Detail needed only while performing a specific task lives
on-demand — see "Everything else, and where it lives" at the foot of this file.

## What this repository is

A **generic, data-driven report renderer.** It takes a view model as JSON and
writes a single self-contained interactive HTML page. It was extracted from
PSModuleGraph, where it lived under `Assets/Html/` and `Private/Html/`.

**It does not know what a PowerShell module is.** It has never parsed one, it
cannot import one, and nothing in it may learn how. The producer that hands it a
view model could be written in Go or Python and this repository would not be
able to tell.

## The core constraint

**The renderer knows about nodes and edges. It knows nothing about what they
are.**

That is the whole rule and everything else here follows from it. A node has an
id, a label, a set of classifications and a set of measurements. What it
*represents* — a function, a Terraform resource, a Python class, a Cisco
interface — is the producer's business and never reaches this code.

Forbidden below the public surface, in code, comments, file names, setting
names, string keys and test names:

- `Module`, `PSModule`, `Ast`, `PSModuleGraph`, `Manifest`, `Cmdlet`
- the name of any command belonging to a producer
- any hardcoded list of node kinds (`function`, `class`, `enum`, …)

Permitted, because they are this repository's own domain: `Node`, `Edge`,
`Link`, `Graph`, `Layout`, `Facet`, `Metric`.

If answering a question would require knowing what the data means, **render less
instead.** A report that omits a panel is correct. A renderer that special-cases
one producer's vocabulary has failed at the only thing it exists for.

## The contract is the product

`contract/viewmodel.schema.json` is the boundary. It is JSON Schema, it is
language-neutral, and it is versioned independently of the module.

1. **Every entry point validates against it** and fails loudly on a mismatch.
   A renderer that quietly tolerates a malformed payload teaches producers to
   emit malformed payloads.
2. **The schema is not PowerShell.** No `.psd1`, no `PSTypeName`, no serialised
   objects. The test is concrete: **if a Python or Go producer would have to
   reshape its data to satisfy it, the schema is wrong.** This mirrors the rule
   on `knowledge/` in PSModuleGraph and for the same reason.
3. **Additive changes bump minor; shape changes bump major.** A field gained is
   minor. A field renamed, removed, or given a new type is major, and the old
   name survives as an alias with a `since` marker. Removal is not an operation
   this contract has.
4. **`contractVersion` travels in `meta` and the renderer reads it.** A payload
   that declares a major version the renderer does not implement is refused by
   name, not rendered on a guess.

## A template set is a rendering backend

`Get-RenderTemplateSet -Path` already takes a directory. That parameter is the
backend seam and it exists before there is a second backend.

- **`TemplateSets/<name>/` is one backend.** `templateset.psd1`, a layout, its
  partials, its styles, its scripts. Cytoscape is the reference implementation
  and is not privileged in code.
- **Adding a backend must not require editing a `.ps1`.** If it does, the design
  is wrong. Report that as a bug; do not work around it.
- **Every backend consumes the same view model.** A backend that needs a field
  no other backend needs is asking for a contract change, which is a proposal,
  not an edit.

## The rule that pays for the config split

> **Adding a setting must require editing data files only.** If it requires
> editing a `.ps1`, the design is wrong. Report that as a bug; do not work
> around it.

Four data files per backend, under `TemplateSets/<name>/Config/`:

| File | Holds | Never holds |
| --- | --- | --- |
| `settings.psd1` | current values | descriptions, ranges |
| `settings.schema.psd1` | type, default, range, group, description, constraints | current values |
| `theme.psd1` | colours, fonts, spacing | behaviour |
| `strings.psd1` | every user-visible string | markup |

Settings are behaviour: what the page does. Theme is appearance: what it looks
like. When a value could be either, ask which one a user would change to alter
*what happens* versus *how it reads*.

## Gravity

**What everything rests on goes at the bottom, and the report opens that way.**

This is a standing invariant inherited from PSModuleGraph, not a preference and
not a default someone picked. A directed graph has a direction whether or not
the layout admits it: the things with the most inbound edges are the things
everything else is built on, and a reader looking for what to trust, what to
test first, or what breaks the most if it changes is looking for exactly those.

The rules and the measurements behind them are in `docs/render-architecture.md`.
Two are stated here because they are violated from outside that document:

- **`DefaultFlow` ships as `foundation` and stays `foundation`.** Changing which
  view a report opens in is a deliberate decision, and this one is made.
- **The foundation view lays itself out; it is not dagre.** This was measured in
  both directions before it was chosen. Do not "simplify" it back to a ranker.

Extend gravity to anything that gains a spatial arrangement. A second view that
stacks the other way costs the reader more than it gains.

## Build and test

```powershell
./build.ps1                 # Clean, Lint, Build, Test — the entry point
./build.ps1 -Task PreTag    # the extra gates that seal a finished iteration
```

**Never call `Invoke-Pester` or `Invoke-Build` directly.** `build.ps1` pins
Pester to exactly 6.1.0 and verifies it; several 5.x versions are usually also
installed, and Pester 5 and 6 disagree on assertion syntax, discovery and
mocking, so a bare `Invoke-Pester` produces results that mean nothing.

**No test in this repository may import PSModuleGraph, or any producer.** A
suite that reaches for a real dependency graph to get something to render has
re-coupled the two repositories at the only place the coupling was removed.
Fixtures are JSON files under `tests/fixtures/viewmodels/`, hand-written and
schema-valid. `docs/testing.md` holds the Pester 6 rules.

## Traps that survived the move

These cost a round each in the original repository. They are not stylistic.

- **Token substitution uses `[string]::Replace()`, never the `-replace`
  operator.** `-replace` is regex. Both the embedded JSON and the CSS contain
  `$` and `\`, which the regex engine treats as substitution patterns and eats.
  The result is subtly corrupted output rather than an error.
- **Template parts are read verbatim and must not end with a trailing newline.**
  Stripping one on read is indistinguishable from deleting a deliberately blank
  last line, and ten of the shipped parts have one.
- **Embedded JSON escapes `<` as `\u003c`**, so a `</script>` inside a path or
  a label cannot terminate the script block.
- **HTML is written UTF-8 without a BOM.** A BOM ahead of `<!DOCTYPE html>` can
  put a browser into quirks mode.
- **Resolve assets from `$script:ModuleRoot`, never `$PSScriptRoot`.**
  `$PSScriptRoot` is per-file: under the dev loader a file in a subfolder sees
  that subfolder, while in the built module the same code has been concatenated
  into a `.psm1` at the module root. Either loader works and the other breaks,
  and the break only shows up in the built module.
- **`Import-PowerShellDataFile` needs `-ErrorAction Stop`.** A `.psd1` that will
  not parse raises a **non-terminating** error, so without it the `catch` never
  runs and a broken config falls back in total silence.
- **`isEmbeddedContext()` checks the user agent for `Electron/` and that check
  is not redundant.** An editor preview pane is genuinely top-level, is served
  over `file:`, and reports no ancestor origins, so the frame check, the
  `vscode-webview:` check and the `ancestorOrigins` check all pass it as a
  normal browser. It is not one. Before concluding a browser is blocking a
  custom scheme, read `navigator.userAgent` in the Diagnostics block.

## Commit

**Read `git status --short` before staging, and stage path by path.** Never
`git add -A`.

One logical change per commit. A commit that has to be described with "and" is
two commits.

**The message states the failure prevented, not the change made.** `Fail the
render when the payload declares an unknown contract major`, not `Add contract
version check`.

Every iteration ends pushed, with `--follow-tags`. The tag is annotated (`-a`)
and is the last action, after the build is green.

**No history rewriting on anything pushed.** No amend, no rebase, no force.

## Every iteration ends with a ledger entry

Not optional and not "when significant". An implementation that produces no
`knowledge/ledger/<id>-<slug>.md` did not happen.

`knowledge/` here holds **only** `ledger/`. The facets, subjects and assignments
stay in PSModuleGraph: they classify PowerShell code, which is exactly the thing
this repository must not know about. Do not mirror that store here.

Versioning: **patch** for a normal implementation, **minor** when a template
set, a setting type, or a contract field is added, **major** when the view model
contract changes shape.

The **Skeptic** section — "What I could not verify" — is never omitted, never
empty, and never "nothing". There is always something.

## Improvement loop

**Every iteration leaves this repository slightly better shaped than it found
it, and writes down what it noticed but did not do.**

"Better shaped" has a local definition here: **closer to a renderer a producer
in another language could drive without changing anything.** Every pass asks, in
this order:

1. **Does this know something it should not?** Producer vocabulary in code,
   comments, file names, setting names or string keys is the improvement.
2. **Is this a decision or is it data?** If adding a setting requires editing a
   `.ps1`, that is a bug in the design — report it, do not work around it.
3. **Would a second one of these be one entry?** The registries — `NODE_ACTIONS`,
   `SELECTION_FACTS`, `SELECTION_ACTIONS`, `FLOW_LAYOUT`, and now the template
   set list — exist because the answer was no and became yes. New surfaces join
   them rather than sitting beside them as branches.
4. **What does the checklist in the charter still say is open?**

**Large — anything that changes the contract, a data shape, or the user's mental
model — is logged and stopped on, never taken unprompted.** That boundary is
what keeps this from becoming scope creep.

## Token discipline

1. Read `docs/render-architecture.md`, not the templates, when planning.
2. Never rewrite an asset file wholesale to change part of it. Targeted edits.
3. Never re-derive the architecture. It is written down. To disagree, propose an
   amendment in one paragraph and wait — do not silently build to a different
   design.
4. Do not restate the plan before starting. The prompt is the plan.
5. One architectural delta paragraph, then code. No plan documents, no phased
   roadmaps, no summaries of what you are about to do.
6. Do not add comments explaining what the architecture document already
   explains. Link to it.
7. When something is ambiguous, ask one specific question. Do not implement both
   options, and do not implement the safer one and mention the other.

**This file has a byte ceiling of 10,000 and `tests/Instructions.Tests.ps1`
enforces it.** The ceiling follows the tier down and never back up: raising it
needs a ledger entry saying why, and "we needed more room" is not why. A prune
is a move down a tier, not a deletion.

## Everything else, and where it lives

These are **on-demand**: read the one the work touches, not all of them.

| File | Read it when |
| --- | --- |
| `docs/render-architecture.md` | anything in `TemplateSets/` or `Private/`. The authority, including gravity's measurements and the decision log. |
| `docs/contract.md` | changing the view model, or writing a producer. |
| `docs/testing.md` | writing or changing a test. Pester 6 is not Pester 5. |
| `docs/development.md` | changing the module's shape — a file, a command, the build. |
| `docs/improvements.md` | the kaizen backlog and the size rules that decide what may be taken. |

## Open decisions

Not settled. Do not resolve one of these unilaterally as part of an unrelated
change — raise it first.

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