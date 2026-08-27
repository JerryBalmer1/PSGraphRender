---
id: "0013"
tag: v0.12.0
date: 2026-08-27
prompt_intent: Fix the four visual defects as a set, take the legend with them, and build the path hint the last entry argued for.
personas: [integrator, archivist, skeptic]
open_threads: [0013-t1, 0013-t2, 0013-t3, 0013-t4]
closes: [0008-t1, 0008-t2, 0010-t2, 0010-t3, 0012-t1]
carries_forward: [0002-t3, 0005-t1, 0006-t1, 0006-t2, 0007-t1, 0008-t4, 0010-t6, 0011-t1, 0011-t2, 0011-t3, 0012-t2, 0012-t3]
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0013 — four defects, one cause

## What changed

**Three of the four were the same bug and none of the three said so.** A node
made visible after the first paint had never been through a layout, so it sat at
the origin — where the top-left node of the drawing already is.

- `[0008-t1]` saw one invented node covering a real one.
- `[0010-t3]` saw two unresolved targets as a single node.
- `[0010-t2]` saw the camera refuse to move when *Exported only* was unchecked.

**Filter, lay out, fit is one act now**, called wherever the visible set changes
by decision: the two boxes under Filters, the kind boxes, the flow radios,
`#fit`, and the first paint. The search box still filters alone.

**`[0008-t2]`** — a name shared by more than one node carries the shortest
trailing run of path segments that separates it from the others.

**`[0012-t1]`** — the colour encoding is stated under the radios that choose it.

**`tools/threads.ps1` reports a path flip**, and `docs/threads.json` carries the
record. It reports; it still does not decide.

**A gate reads values out of `strings.psd1`** and refuses six words the charter
forbids. Nothing had ever read a value in that file.

**Ten screenshots**, five before-and-after pairs in `docs/samples/`, every
before rendered from a worktree at `v0.11.0`.

**Minor.** `docs/threads.json` gained a data shape and the page's behaviour
changed.

## What I learned

**`[0010-t3]` was not a correctness bug and could not be fixed on its own.** It
was ruled first and separately on the reasoning that two unresolved records
naming different targets are two nodes, and that the renderer had the producer's
v0.11.0 identity collision on its own side of the seam. It does not.
`elements.js` has keyed its invented nodes on `'external:' + targetName` since
the extraction, and the probe confirms two nodes with two ids — at the same
coordinates, because neither had ever been placed. **The picture was read
correctly and the diagnosis inferred from it was wrong**, which is the shape the
whole iteration turned out to have.

So it went in with the other two rather than in its own commit. Splitting one
change across three commits to preserve an ordering that rested on a wrong cause
would have made the history less true, not more.

**The stress case does not move, and the number that was expected to move was
the wrong number.** SqlServerDsc's 807 unresolved records carry **89 distinct
target names**, and the renderer has always drawn 89 nodes for them — `Write-Verbose`
alone accounts for 217 records. What moved is that 371 of the 532 nodes now have
a position when *Exported only* is unchecked, instead of one heap at the corner.

**`[0012-t1]` was false as written and true as meant.** The legend has said
*"shaded by rank, not by size — the number is in Details"* since **before
v0.1.0**. It is the last block of a sidebar that scrolls, eight blocks below the
COLOUR BY radios. So the fix is not to add a sentence but to put it where the
choice is made; the legend keeps its copy for a reader who reaches it. A caveat
somebody has to scroll to has not been made.

**The banner named the producer's domain in the one message every large payload
shows on load.** *"This module has {count} nodes … filtered to exported
functions"* — from the extraction until now, in a repository whose first rule is
that it does not know what a module is. And *"Uncheck 'Exported only' to see
everything"* promised a view `MinReadableZoom` refuses to give, which is the
second half of `[0010-t2]` and is accepted behaviour, not a defect.

**Nothing could have caught it, and the reason is written in the code that
stopped it.** `Get-BackendSourceFile` carries a comment saying the classification
scan once read every `.psd1` in the tree, reported `module` out of a comment and
`Enum` out of a schema type, and was narrowed to `.js`/`.css`/`.html` to stop
the false alarms. **The narrowing took the true positive with it.** The new gate
is the narrow version that can come back: values only, and the charter's own six
words rather than the fixture kinds — `output`, `policy`, `calls` and
`references` are all classifications a fixture carries *and* ordinary English,
so a fixture-derived check would be red in its correct state and would be
suppressed. Proved by putting *"This module has"* back: one failure, naming the
file, the key and the word.

**The hint corrected the argument that asked for it.** `0012` argued for a
path-flip check and estimated it would have caught three of the four stale
Closes. Run, it catches **one**. `[0003-t2]` and `[0004-t3]` name no path in any
sentence; `[0001-t7]` names `docs/html-architecture.md`, which the same entry
said had left `PSModuleGraph` at v0.9.0 — **and it has not.** The file is there,
tracked, and nothing emits `nodes[].facets`, so the oldest thread in the project
was struck at v0.15.0 for a reason that was not true. It is recovered in
`PSModuleGraph`'s `0020`.

That is three of that paragraph's four claims wrong, in a section arguing that
memory is not evidence, written from memory. **The correction did not come from
what the hint found; it came from having to run it.**

**A path check that answers has to know how a ledger writes a path.** The first
version returned nothing for `[0001-t7]` because ledger `0001` has no blank line
after its last thread and the item extractor required one — a result
indistinguishable, downstream, from a thread that names no path. It also read
`vscode:`, `file:` and `.ps1` as paths, and resolved a bare `SubsystemCharter.Tests.ps1`
against the repository root, reporting absent at both ends for a file that has
never moved. Each was found by looking at all fifteen results rather than at the
one flip.

## Dimensional impact

Five questions, against this repository's own seams.

**1. Did this reveal a distinction the design could not express?** Yes, and it
was in the code rather than the data: **the visible set is an input to the
layout**, and nothing said so. Three threads described three symptoms of that
one fact over five entries without any of them naming it. It is in
`docs/render-architecture.md` under Gravity now.

**2. Is an existing seam doing two jobs?** Yes — `applyFilters` was both "decide
what is on the page" and "the only thing a control calls". Split:
`applyStructuralFilters` is the act; `applyFilters` is the half the search box
needs.

**3. Did two seams turn out to be the same thing?** Yes, three threads did. See
above.

**4. Did anything land at a depth the design did not anticipate?** Yes. The
label qualifier needed a depth, not a flag: two vendored copies of one file
agree for four path segments and differ at a version directory.

**5. Could this classify itself?** Yes, uncomfortably. The hint's whole purpose
is catching a claim about a file that nobody checked, and building it caught one
in the entry that argued for it.

### Prune, this iteration

**A move: none.** Nothing was added to the always-loaded tier. **A deletion
proposal: none.**

### Always-loaded bytes

**10,410 / 10,410**, unchanged. The target is 10,000.

## What I could not verify

The Skeptic's section. It is never empty.

- **That any of this would be caught if it broke again.** Not one of the four
  defects is reachable by a gate, and neither is any of the five fixes. The
  browser harness says the page came alive; every defect here was found by a
  person looking at a picture and every fix is verified the same way. A second
  harness — "after clicking each selector this backend declares, no two visible
  nodes share a position" — would have caught all three placement threads and is
  about sixty lines. It is also a new key in `templateset.psd1`, which is a data
  shape, which the charter says to log and stop on. `0013-t2`.
- **That the search exception is safe.** It is safe for the case that motivated
  it and not in general: search, then tick a checkbox, and the layout runs over
  the search-filtered set; clear the search and the nodes it had hidden come
  back at positions from a layout that did not include them. Same defect, one
  interaction deeper. `0013-t1`.
- **That the strings gate rules on the right words.** Six, from the charter.
  `MetricDependentsHint` still says *"things that call this directly"*,
  `MetricDependenciesHint` says *"things this calls directly"*, and
  `MenuOpenCallSite` says *"Open Call Site"* — all of which assume the edges are
  calls, which is what `LegendCalls` was changed for. A word list is not a rule.
  `0013-t3`.
- **That the qualifier works on a payload the fixtures do not have.** Every
  fixture with duplicate names also has paths. A payload with duplicates and no
  paths falls through to the id, and for SqlServerDsc an id is eighty
  characters. Never rendered. `0013-t4`.
- **That any visual judgement here generalises.** One headless Chromium, one
  1600×1000 viewport, this machine's fonts, and a device pixel ratio chosen per
  pair. Two of the four defects are about legibility at a size, so they were
  verified in the exact conditions that would hide a regression at another one.
  `0011-t1`, accepted at v0.11.0, and this is the entry where it bites hardest.
- **That the label qualifier is legible rather than merely correct.** Step 1 of
  SqlServerDsc's test order now runs to three wrapped lines where it ran to one,
  because four of its first nine names are ambiguous. It was looked at and
  judged an improvement over four identical names; nobody who has to use it has
  said so.

## Open threads

1. **[0013-t1] Search and a checkbox together can still strand a node.** The
   layout runs over the visible set, and search-hidden nodes are outside it, so
   clearing the search after ticking a box brings nodes back at positions from
   a layout that did not include them. The same defect this entry closed, one
   interaction deeper.
2. **[0013-t2] No gate can see any of these four defects or any of the five
   fixes.** Every one was found by a person looking at a picture. The harness
   that would catch the placement family needs a new declaration in
   `templateset.psd1`, which is a data shape and is logged rather than taken.
3. **[0013-t3] The strings gate refuses six words and the file still assumes a
   call graph.** Three metric hints and a menu label say "call" about edges the
   payload never classified, which is exactly what `LegendCalls` was changed
   for. A word list is not a rule.
4. **[0013-t4] The label qualifier has never met a payload with duplicate names
   and no paths.** It falls through to the id, which on a real module is eighty
   characters in a 340px sidebar. No fixture produces the case.

Carried: **[0002-t3]** `Get-RenderTemplateSet` may not belong on the public
surface; **[0005-t1]** the harness says the page loaded, not that it is right;
**[0006-t1]** the falsifiability proof has only run on one machine — ruled Fix,
its own iteration; **[0006-t2]** the growth ratio has never met a sparse
payload; **[0007-t1]** the uncertain-edge style is calibrated against one
density; **[0008-t4]** nothing checks either README; **[0010-t6]** no page
carries all three dashed treatments readably — `ambiguous` now carries two of
them cleanly and still has no named-kind edge; **[0011-t1]** every picture is
one browser at one device pixel ratio; **[0011-t2]** the tool reports and the
temptation to rank it will recur; **[0011-t3]** a merge across repositories has
no id grammar; **[0012-t2]** `docs/constraints.md` only works if it is read
first; **[0012-t3]** twenty-eight verdicts were applied in one pass.
