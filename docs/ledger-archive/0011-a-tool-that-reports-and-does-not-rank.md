---
id: "0011"
tag: v0.10.0
date: 2026-08-27
prompt_intent: Give this repository the continuity gate it never had, recover the thread it lost, replace the hand survey with a tool that reports and refuses to rank, and propose a verdict on all thirty-two open here.
personas: [integrator, archivist, skeptic]
open_threads: [0011-t1, 0011-t2, 0011-t3]
closes: [0010-t4, 0009-t2, 0009-t3, 0001-t1]
carries_forward: [0001-t2, 0001-t5, 0002-t1, 0002-t3, 0003-t1, 0003-t2, 0003-t4, 0004-t2, 0004-t3, 0004-t4, 0005-t1, 0005-t4, 0006-t1, 0006-t2, 0006-t3, 0007-t1, 0007-t3, 0008-t1, 0008-t2, 0008-t3, 0008-t4, 0009-t4, 0010-t1, 0010-t2, 0010-t3, 0010-t5, 0010-t6]
recovers_threads: [0002-t4]
supersedes_threads: [0002-t4]
prune_proposals: []
supersedes: []
---

# 0011 — a tool that reports and does not rank

## What changed

**`tests/Ledger.Tests.ps1`** — renamed from `LedgerPrune`, because it is no
longer only about prunes. It now checks thread continuity, which this repository
has never checked at all.

**[0002-t4] is recovered and immediately retired.** It was carried by `0003` and
gone from `0004`; entry `0003`'s **prose** says `0003-t2` is *"the open half of
`0002-t4`"* and its front matter dropped the id without a word. It is recovered
so that the record says what happened, and superseded by `0003-t2` in the same
entry, which is what `0003` meant and did not write down. **It is not
continuous** — seven entries have no opinion about it.

**`tools/threads.ps1`** reads any number of ledger directories and writes
`docs/threads.json`, committed and diffable like a corpus record. **94 threads
raised, 70 open, 24 closed.**

**Four verdicts applied** — one supersession and three merges. **Thirty-two
proposed and twenty-eight left for a ruling.**

**Minor**, for the tool.

## What I learned

**The tool and the hand survey agree, and the two places they differ are both
real.** `0010` counted 88 raised and 63 open by hand; the tool says 94 and 70.
The 6 is `0010`'s own threads minus the one it closed, which the hand count was
taken before. The 7 is that, plus **the two vanished threads, which the hand
table listed separately as "vanished" and the tool counts as open** — correctly,
under the rule this iteration implements: a thread survives until something
explicitly closes or supersedes it, and nothing ever did. The reconciliation is
exact in both directions, which is the only reason to trust either.

**Writing the tool second was the right order and the diff proves it.** `0010-t4`
argued the survey should be done by hand first so there would be a
before-and-after. There is one: the hand pass produced the closure distribution
that decides what the tool must *not* do, and a tool written first would have
shipped a `staleness` column nobody had yet measured to be meaningless.

**So the tool reports and does not decide, and the comment at the top says why
at length.** No score, no priority, no staleness flag, sorted by repository and
id and nothing else. `0010` measured what carry count predicts and the answer
was nothing — twenty-one of twenty-three closures happened in the very next
entry, and none has ever happened after four carries. **A number that rises
every iteration and has never once decided anything is not a signal, and putting
it in code would make it look like one.** `carries` is emitted because it is a
fact about the record; what it means is the reader's problem. `0011-t2`.

**The one line comes from the entry that raised the thread, not from a later
gloss.** Later mentions get shorter and drift — `0003-t2` is glossed in one
entry as *"narrowed, not closed"*, which describes its history and not the
thread. Every one of the 94 produced a summary; none is empty.

**Turning the gate on found `0002-t4` immediately, by name and by entry:**

> thread(s) left the ledger without being closed, superseded or recovered:
> `0002-t4` (dropped by `0004`)

**And a merge across repositories still cannot be expressed.** Three of the four
verdicts applied here retire an id whose survivor lives in `PSModuleGraph`, and
`NNNN-tN` names no repository, so the survivor is named in prose. That is
precisely the arrangement in which `0002-t4` was lost. `0011-t3`.

## The verdicts

**Proposed. Applied: one supersession and three merges, nothing else.** Sorted
by what a reader wants first inside each bucket.

### Fix — small, clear, worth a pass

| Thread | Carried | Why |
| --- | --- | --- |
| `0010-t3` | 0 | **Two unresolved targets with different names are drawn as one node.** The identity defect the producer closed at v0.11.0, alive on this side of the seam, in output a person looks at. Your call, taken. |
| `0008-t1` | 2 | An invented node is drawn on top of a real one, hiding the edge between them — so the fourth line treatment cannot be seen on the only small page that carries it. Blocks `0010-t6`. |
| `0010-t2` | 0 | Lifting the node limit does not move the camera and `#fit` does not fit. The banner says *uncheck to see everything* and unchecking shows the same region. |
| `0008-t2` | 2 | Two sidebar lists print a name twice and mean two different nodes. Ids have been distinct since v0.11.0; the lists show labels. |
| `0010-t6` | 0 | No payload carries all three dashed treatments where they can be read. One eight-node fixture fixes it, and it is the only way `0007-t2` was ever going to be answerable. |
| `0007-t1` | 3 | The style is calibrated against one density, and 532 nodes proved it does not survive. **Its own iteration, not folded in** — the contract field is right and the encoding is wrong; colour is what survives. Your call, taken. |
| `0008-t4` | 2 | Nothing checks either README. The code blocks are runnable and a test could run them; six numbers in one of them are measurements. |
| `0005-t1` | 5 | The harness asserts the page loaded, not that it is right. `0010`'s screenshots are the manual version of this and they found three defects, which is the argument. Its own pass. |
| `0006-t2` | 4 | The growth ratio has never met a legitimately sparse payload. Render a two-node one and find out whether it falls under 4. |
| `0002-t3` | 8 | `Get-RenderTemplateSet` may not belong on the public surface. Pre-1.0, so deciding is cheap now and expensive later. Fix means *decide*, either way. |

### Accept — a real limitation this project chooses to have

| Thread | Carried | Why it is a constraint rather than debt |
| --- | --- | --- |
| `0008-t3` | 2 | The fill channel is nearly dead on SqlServerDsc — 469 of 532 nodes are one kind. **That is the module, not the renderer.** Colouring by something else at density would be the renderer deciding what the data means. |
| `0007-t3` | 3 | The count says how many and never how many of what. Exposing candidates needs a contract field, and the contract is not edited to make a panel richer. |
| `0010-t1` | 0 | The skills are forked and nothing watches the drift. The fork was chosen with the argument written down; drift is its price, and a checker over documents about different repositories is a gate whose correct state is red. |
| `0001-t5` | 9 | `Get-HashtableValue` exists in both repositories. Sharing fifteen lines means one repository depending on the other, which is the coupling the split removed. |
| `0002-t1` | 8 | `plain` is trivial enough to prove less than it looks. Its triviality is what makes it a control. |
| `0003-t1` | 7 | Semantic equivalence only checks the dimensions somebody listed. Every comparison is a chosen list; that is the technique, not a defect in this instance of it. |
| `0003-t4` | 7 | Validation at the seam is one place, which cuts both ways. One place is the design. |
| `0004-t2` | 6 | The payload scan reaches one level and cannot see a computed access. A static scan of dynamic access has a ceiling and this is it. |
| `0004-t4` | 6 | Playwright was measured and nothing else was. One browser engine is the budget. |
| `0005-t4` | 5 | A vendored file names a `.map` that is not vendored. Relative, fetched only with developer tools open, and stripping it invalidates the SRI hash. |
| `0006-t1` | 4 | The falsifiability proof has only run on one machine. **Flagged — you may want this as a Fix**: a CI job that breaks a gate and asserts red is buildable. It is Accept here because a gate that deliberately fails in CI is a gate whose red stops meaning one thing. |
| `0006-t3` | 4 | Two of five defects were 5.1-only on a leg that has run four times. Time fixes this and nothing else does. |

### Close — no longer true, superseded, or answered and never struck

| Thread | Carried | Why |
| --- | --- | --- |
| `0003-t2` | 7 | *Nothing checks a backend reads only what the contract promises.* `tests/BackendContract.Tests.ps1` has done exactly that since v0.4.0. **Answered seven entries ago and never struck** — the `0009-t1` case again, and the clearest instance in the list. |
| `0009-t4` | 1 | *There is no `CHANGELOG.md`.* There is, as of v0.9.0. |
| `0004-t3` | 6 | *The offline measurement is Chromium's failure, not a proxy's.* Vendoring at v0.5.0 removed every request the page makes, so there is nothing left for a proxy to fail. **Flagged** — a future backend that fetches something re-raises it, and you may prefer Accept. |
| `0001-t2` | 9 | *The golden has never been compared on another machine.* The golden is not in this repository and has not been since the extraction; the file and its test are `PSModuleGraph`'s. **Flagged** — this is arguably a cross-repository merge with no target, which is `0011-t3`. |

### Applied

| Retired | Becomes | Why |
| --- | --- | --- |
| `0002-t4` | superseded by `0003-t2` | What entry `0003` said in prose and did not write down. Recovered first so the gap is on the record. |
| `0001-t1` | `PSModuleGraph` `0009-t1` | *One fixture, one shape.* Same golden, same doubt, two ids; the artefact is there. |
| `0009-t3` | `PSModuleGraph` `0017-t3` | *A procedure written from memory.* Identical text, and the pattern store it rests on is there. |
| `0009-t2` | split | The *"copy that lies"* half is done — the five skills are true to this repository as of v0.9.0. The *"none has ever been invoked"* half is `PSModuleGraph` `0017-t2`. |

### `0010-t5` — the heat ramp has no middle. Argued both ways.

**For Accept.** Rank over distinct values is not a bug and the comment above it
predicted this exact trade in advance: colour stops being proportional so that
the tail stays visible. The picture shows it working — the outliers pop on a
532-node payload whose median is 1 and whose maximum is 281, which is the
question the metric exists to answer (*what breaks if this changes*). Every
panel that shows a node also shows the raw number, so the ordering that colour
cannot express is one click away and always exact. A ramp that spread evenly
across *nodes* rather than values would put half of SqlServerDsc in the middle
band and make "worst" mean nothing. **The limitation is inherent to encoding a
skewed distribution in five colours, and five colours is the right number for a
person.**

**For Fix.** The claim in the code is *"rank spreads the ramp across the values
that actually occur"*, and on this payload it does not: 36 distinct values,
87% of nodes in the coldest quarter. The scale is over values and the reader
looks at nodes, and nobody noticed the difference until a picture was taken —
which means the comment is describing an intention rather than a measurement.
There is a cheap middle: rank over *nodes* with the top decile held back, or a
sixth ramp stop, or a legend that says what the bands mean. And the legend has
never been looked at, so the mitigation everything rests on — *the raw number is
always shown* — is itself unverified.

**Where I land, weakly: Accept, and Fix the legend instead.** The ramp is doing
the job it was designed for; what is missing is the page telling the reader that
colour is rank and not magnitude. That is a strings-and-theme change, not an
algorithm change. I would not argue hard against Fix.

## Dimensional impact

Five questions, against this repository's own seams.

**1. Did this reveal a distinction the contract cannot express yet?** No. The
tool reads ledgers; the contract is not involved.

**2. Is an existing seam doing two jobs?** Yes, and it was split:
`LedgerPrune.Tests.ps1` had become the file where anything about the ledger
went. It is `Ledger.Tests.ps1` with two Describes, and the prune gate is
unchanged.

**3. Did two seams turn out to be the same thing?** No — but two *threads* did,
three times, and the mechanism for saying so is prose.

**4. Did anything land at a depth the design did not anticipate?** Yes: a thread
id has no repository in it, so a cross-repository merge cannot be stated. Named
as `0011-t3` rather than proposed as a change, because widening the id grammar
touches every entry in both stores.

**5. Could this classify itself?** The tool counts its own repository's threads
and this entry adds three to them. It does not treat them differently, which is
the correct answer and worth having checked.

### Prune, this iteration

A move: none. A deletion proposal: none. The verdict set proposes four closures,
which are threads rather than instruction text and so are not prunes.

### Always-loaded bytes

**10,644 / 10,644.** Unchanged.

## What I could not verify

The Skeptic's section. It is never empty.

- **That thirty-two verdicts written in one pass by the author of most of the
  threads are worth your time.** Your line, adopted, and it is the real risk:
  getting through a list competes with getting it right. The ones I am least
  confident in are flagged in the tables and named again in the response —
  `0004-t3`, `0001-t2`, `0006-t1`, `0002-t3` and the whole of `0010-t5`. The
  Closes I am most confident in are facts about files: `0003-t2` and `0009-t4`
  can be checked in ten seconds each.
- **That the tool agrees with the ledger for the right reasons.** It reconciles
  with the hand count in both directions, and both were produced by the same
  reader. A third route — recomputing the open set from `closes` and
  `carries_forward` alone, which the gate now does — agrees as well, and that is
  the strongest thing available short of somebody else counting.
- **That `docs/threads.json` will stay diffable.** It carries a UTC timestamp to
  the second, so a re-run on an unchanged ledger produces a one-line diff rather
  than none. That was a deliberate trade against dropping the timestamp
  entirely, and it may be the wrong one.
- **That the summaries mean what the threads mean.** They are the first sentence
  after the id in the entry that raised it, extracted by regex. That is the
  thread as its author framed it and not necessarily as it now stands —
  `0009-t2` reads as one doubt and turned out to be two.
- **That recovering `0002-t4` to supersede it is honest rather than tidy.** The
  net effect on the open set is zero and the record now says a thread was lost
  and why. A reader could reasonably see one entry inventing a paper trail for
  another entry's mistake seven versions later.
- **That the continuity gate here matches the one in `PSModuleGraph`.** They are
  the same rule written twice, in two files, in two repositories, with no test
  comparing them — which is `0010-t1` arriving in the first place it could.

## Open threads

1. **[0011-t1] Thirty-two verdicts were proposed in one pass by the author of
   most of the threads.** Seventy exist across both repositories and sixty-eight
   now have an opinion attached that nobody has ruled on.
2. **[0011-t2] The tool reports and the temptation to rank it will recur.** The
   first person to add a `staleness` column will be right that it is easy and
   wrong that it means anything, and the only thing standing in the way is a
   comment.
3. **[0011-t3] A merge across repositories has no id grammar.** `NNNN-tN` names
   no repository, so three merges here are closures with the survivor in prose —
   the same arrangement in which `0002-t4` was lost.

Carried: **[0001-t2]** the golden has never been compared on another machine —
proposed for closure; **[0001-t5]** `Get-HashtableValue` exists in both
repositories; **[0002-t1]** `plain` proves less than it looks; **[0002-t3]**
`Get-RenderTemplateSet` may not belong on the public surface; **[0003-t1]**
semantic equivalence only checks the dimensions somebody listed; **[0003-t2]**
nothing checks a backend reads only what the contract promises — proposed for
closure as answered at v0.4.0; **[0003-t4]** validation at the seam is one
place; **[0004-t2]** the payload scan reaches one level; **[0004-t3]** the
offline measurement is Chromium's failure — proposed for closure; **[0004-t4]**
Playwright was measured and nothing else was; **[0005-t1]** the harness says the
page loaded, not that it is right; **[0005-t4]** a vendored file names a `.map`
that is not vendored; **[0006-t1]** the falsifiability proof has run on one
machine; **[0006-t2]** the growth ratio has never met a sparse payload;
**[0006-t3]** two defects were 5.1-only; **[0007-t1]** the style is calibrated
against one density; **[0007-t3]** the count says how many, never how many of
what; **[0008-t1]** an invented node is drawn on top of a real one;
**[0008-t2]** two lists print a name twice; **[0008-t3]** the fill channel is
nearly dead where it is needed most; **[0008-t4]** nothing checks either README;
**[0009-t4]** there is no `CHANGELOG` — proposed for closure; **[0010-t1]** the
skills are forked and nothing watches the drift; **[0010-t2]** lifting the node
limit does not move the camera; **[0010-t3]** two unresolved targets are drawn
as one node; **[0010-t5]** the heat ramp has no middle; **[0010-t6]** no page
carries all three dashed treatments readably.

Closed: **[0010-t4]** the continuity gate could not see a second-hop drop and
the survey could not be repeated — both halves landed here; **[0009-t2]**,
**[0009-t3]** and **[0001-t1]**, merged rather than answered, each surviving
under a `PSModuleGraph` id named above.
