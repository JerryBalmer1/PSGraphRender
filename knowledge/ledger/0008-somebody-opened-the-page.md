---
id: "0008"
tag: v0.8.0
date: 2026-08-27
prompt_intent: Write the README this repository has never had, add a task that renders every fixture through every backend, and then actually look at the pages four threads have been asking about.
personas: [archivist, integrator, skeptic]
open_threads: [0008-t1, 0008-t2, 0008-t3, 0008-t4]
closes: [0007-t2]
carries_forward: [0007-t1, 0007-t3, 0006-t1, 0006-t2, 0006-t3, 0005-t1, 0005-t4, 0004-t2, 0004-t3, 0004-t4, 0003-t1, 0003-t2, 0003-t4, 0002-t1, 0002-t3, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0008 — somebody opened the page

## What changed

**A README.** It was one line. The first paragraph now says the producer may be
written in any language, that the boundary is `contract/viewmodel.schema.json`,
and that PSModuleGraph is one consumer rather than the owner.

**`-Task Samples`.** Every fixture through every backend into `output/samples/`,
with a generated index. `-ExtraPayload` renders something too large to commit.

**`tools/shoot.cjs`** takes the pictures, and eight of them are committed under
`docs/samples/`. The pages are not.

**Nothing behaves differently.** No contract edit, no fix to anything logged.

## What I learned

**The style works at six nodes and does not work at 532.** This is the answer to
`0007-t1` and it is not the answer I would have written from the source.

At six nodes the ambiguity is not merely visible, it is *readable as a
statement*: `rollout` has two dashed, faded arrows going to two different boxes
both labelled `restart`, and a person sees "this call could be either of these"
without being told. That is the finding drawn.

At 532 nodes the edges are hairlines in a grey crosshatch. Dashes are present
and I had to hunt for them. **702 of 1,271 edges being uncertain is not
recoverable from the drawing** — the page does not look like a page where more
than half the relationships are guesses. The encoding is correct and the channel
is saturated. What carries it at that size is the Details panel count added in
`0007`, which is a per-node number and survives any density.

**Three line treatments are distinguishable, and I could only get three of four
onto one page.** Solid grey (unclassified), gold dashed (`Inherits`, a named
link kind) and faded grey dashed (`Ambiguous`) are unmistakable from each other
— colour separates the two dashed ones, and opacity separates them again. The
fourth, a dotted orange edge to an invented node, is still unseen for the reason
below. `0007-t2` closes on the three that were the question.

**Two defects, found by looking, neither fixed here.**

An invented unresolved node is **drawn on top of a real one**. In the
`ambiguous` fixture with unresolved shown, the orange `notify-oncall` box sits
over `rollout` and occludes all but three letters of it — and hides its own
dotted edge, which is why the fourth treatment is still unseen. Opened as
`0008-t1`.

The cycle list and the test-order list **print the same name twice with nothing
to tell the two apart**. SqlServerDsc's sidebar reads
`Test-TargetResource, Test-TargetResource` and
`Compare-DscParameterState, Compare-DscParameterState`. Since the producer's
v0.11.0 those are genuinely different nodes with different ids; the lists show
labels, and a label is a name. Opened as `0008-t2`.

**`NodeLimit` degrades well and says so.** 532 past a limit of 400 opens
filtered to exported functions with a banner naming the number, the threshold
and the checkbox that lifts it. Nothing about that needed changing, which is
worth recording because every other thing I looked at did.

**The shipped theme is one producer's, and the page shows it.** A payload using
`Task` and `Policy` renders entirely in `KindColorFallback` — correct, since the
map is data and the keys are the producer's, and visually flat. Worse on a real
module: SqlServerDsc's 469 functions are all `Function`, so the fill channel
carries nothing at all on the payload that most needs help. The README now says
this; opened as `0008-t3` because saying it is not the same as solving it.

**Every code block in the README was run before it shipped**, which caught two
things a careful read would not have. `New-RenderDocumentPath -BasePath` is
mandatory and the draft omitted it. The minimal-payload claim — "only `id` is
required on a node" — is true, and renders with a warning about the missing
`contractVersion` that the README does not mention.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the README is true of anything but this commit.** The user's own line,
  adopted: a README is a claim about current behaviour written by whoever just
  changed it, and nothing tests it. I ran seven blocks; nothing will run them
  again. The byte figures in it — 602 KB, 5.7 KB — are from one machine and one
  vendored bundle and will drift silently. Opened as `0008-t4`.
- **That "any language" has been demonstrated.** It is argued from the schema
  being JSON Schema and from no fixture describing a PowerShell module. Nothing
  outside PowerShell has ever produced a payload for this renderer, and the
  README's Python example is illustrative — the `pwsh` half of it was run, the
  Python half was not written.
- **That the density judgement is not a screenshot artefact.** 1440x900 at
  deviceScaleFactor 2, the fit-to-window zoom the page chooses, one theme. A
  reader who zooms in sees individual dashes perfectly well. The claim that
  survives is about the view the page opens in, which is the view most readers
  see and never leave.
- **That the two defects are the only ones there.** I looked at four pictures
  properly and skimmed four. `plain` was checked for bytes and not read.
- **That the samples are reproducible.** Six of eight are, from a clean
  checkout. The SqlServerDsc pair needs a payload generated in another
  repository from a vendored module, and the procedure in `docs/samples/README.md`
  was followed once, by me, on this machine.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**11,223 / 11,223.** Unchanged. The README is on-demand.

## Open threads

1. **[0008-t1] An invented node is drawn on top of a real one.** The unresolved
   node lands on the node that referenced it, occluding it and its own edge.
   Seen on a six-node fixture, so it is not a density effect.
2. **[0008-t2] Two lists print a name twice and mean two different nodes.** The
   cycle list and the test order list show labels. Ids have been distinct since
   the producer's v0.11.0; the sidebar has not caught up.
3. **[0008-t3] The fill channel is dead on the payload that needs it most.** All
   469 SqlServerDsc functions are one kind, so `ColorBy = structure` paints one
   colour. A metric ramp is a click away and is not the default.
4. **[0008-t4] Nothing checks the README.** Seven code blocks, run once, by
   hand. Two byte counts in it will drift the next time a library is vendored.

Carried: **[0007-t1]** the style is calibrated against one density — measured
here and found to fail at the top of the range, kept open because the fix is a
design decision; **[0007-t3]** the count says how many, never how many of what;
**[0006-t1]** the falsifiability proof has only run on one machine;
**[0006-t2]** the growth ratio has never met a legitimately sparse payload;
**[0006-t3]** two of five defects were 5.1-only; **[0005-t1]** the harness says
the page loaded, not that it is right — narrowed considerably today, by a person
rather than a gate; **[0005-t4]** a vendored file names a `.map` that is not
vendored; **[0004-t2]** the payload scan reaches one level; **[0004-t3]** the
proxy case is unmeasured; **[0004-t4]** Playwright is still the only harness
measured; **[0003-t1]** semantic equivalence only checks the dimensions I
listed; **[0003-t2]** narrowed, not closed; **[0003-t4]** validation at the seam
is one place; **[0002-t1]** `plain` never asks configuration for anything
structural; **[0002-t3]** `Get-RenderTemplateSet` may not belong on the public
surface — the README now documents it as public, which raises the cost of
changing that; **[0001-t1]** one fixture, one shape, for the golden;
**[0001-t2]** nothing compares the document across legs; **[0001-t5]**
`Get-HashtableValue` exists in both repositories.

Closed: **[0007-t2]** no page carrying all three line treatments had been
viewed. One has. They are distinguishable, and the fourth treatment turned out
to be hidden by `0008-t1` rather than by nobody looking.
