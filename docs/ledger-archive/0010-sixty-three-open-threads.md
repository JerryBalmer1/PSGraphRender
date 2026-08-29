---
id: "0010"
tag: v0.9.0
date: 2026-08-27
prompt_intent: Fix a skills directory that was a copy making false claims, build the gate one of those claims promised, derive the changelog nobody wrote, look at the pages and answer four visual questions that had never been asked of a picture, and total every open thread in both repositories by hand.
personas: [integrator, archivist, skeptic]
open_threads: [0010-t1, 0010-t2, 0010-t3, 0010-t4, 0010-t5, 0010-t6]
closes: [0009-t1]
carries_forward: [0009-t2, 0009-t3, 0009-t4, 0008-t1, 0008-t2, 0008-t3, 0008-t4, 0007-t1, 0007-t3, 0006-t1, 0006-t2, 0006-t3, 0005-t1, 0005-t4, 0004-t2, 0004-t3, 0004-t4, 0003-t1, 0003-t2, 0003-t4, 0002-t1, 0002-t3, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0010 — sixty-three open threads

## What changed

**`tests/LedgerPrune.Tests.ps1`.** A deferred deletion proposal that a second
entry neither applies nor rejects now blocks the annotated tag by name.
`instruction-prune` had promised this since v0.3.0 and it had never existed
here. **Proved falsifiable in both halves before it was trusted** — see below.

**`0009-t1`, applied.** Library code is vendored; the open decision saying
otherwise is struck.

**The five skills are a fork, not a copy**, and each is now true to this
repository. The argument against a sync check is in the skills `README.md` and
is repeated in one paragraph below.

**`CHANGELOG.md`**, derived from nine annotated tags and nine ledger entries,
and saying at the top that it was derived rather than recorded.

**Four screenshots**, taken to answer four questions that had only ever been
answered from source.

**`-Task Samples` already existed.** It landed at v0.8.0 with `tools/shoot.cjs`
and eight committed screenshots, and it already does every fixture through every
backend with counts in a generated index. Nothing was rebuilt. **Minor is for
the pre-tag gate, not for the task.**

## What I learned

### `0007-t2` was closed in `0008` and should not have been

It said: *three things in one drawing are dashed or dotted — a named link kind,
an unresolved target, and an uncertain resolution — and no page carrying all
three has been viewed.* `0008` closed it "on the three that were the question".

**No page carrying all three exists.** Measured, this iteration, in the payloads:

| Payload | named kind | unresolved | uncertain |
| --- | --- | --- | --- |
| `sample-module.json` | 1 `Inherits` | **none** | none |
| `ambiguous.json` | none | 1 | 2 `Ambiguous` |
| `infrastructure.json` | none | 2 | none |
| SqlServerDsc | 7 `Inherits` | 807 | 702 `Ambiguous` |

Only the last carries all three, and it carries them at 532 nodes and 1,271
edges, where two of the three are invisible. **The thread was closed on a page
that did not carry what the thread was about**, and the entry that closed it is
the same entry that reported the style "unrecoverable at 532". Reopened as
`0010-t6`; the original stays closed, because renames never delete and a closed
thread that reopens as a new one is legible where an un-closing is not.

Worth naming plainly: that was the same error as reading a mechanism instead of
running it, made one iteration after writing the skill about it.

### What the pictures showed, and where the prediction was wrong

**Does the foundation layout hold at 532?** It holds and stops meaning
anything. Nothing overlaps, nothing explodes, the layout is deterministic — and
it is a lattice of full-width rows under a uniform fog of edges. The
"most depended-upon at the bottom" semantic is gone: rows are bands eleven wide,
and an edge from row sixteen to row two crosses fourteen of them. The banner
says *"above ~400 the layout stops being readable"* and **the picture proves the
banner right**, which is the most useful thing an honest banner can do.

**Are 702 dashed edges of 1,271 informative or noise?** Noise, confirmed at two
resolutions. At 532 nodes I could not find a dash. What survives density is
**colour**, not line style: the seven gold `Inherits` edges are still findable
in the 532 view, and the orange unresolved edges are unmissable, while every
grey treatment collapses into one grey.

**Is the heat ramp legible at a range it was never tuned against?** **My
prediction was wrong and I am glad I took the picture.** Blast radius on
SqlServerDsc runs 0 to 281 with a median of 1; 36 distinct values; **87% of
nodes fall in the coldest quarter of the ramp.** I predicted, from that
arithmetic, that everything would look the same. It does not: the outliers pop
clearly — half a dozen nodes are unmistakably hot against a cold field, and a
salmon band sits between. The rank-over-distinct-values scale does what its
comment claims. **The honest limit is different from the one I predicted: the
ramp has no middle.** It answers "which are the worst" very well and "is this
one worse than that one" not at all, and 87% of the module is one colour at the
bottom. Opened as `0010-t5`.

**What does 532 past a `NodeLimit` of 400 do?** It degrades honestly and says
so, naming the count, the threshold and the control. That part is the best thing
on the page. **What it does next is the defect**: unchecking "Exported only"
adds the remaining nodes and **does not move the camera**, so the user sees the
same view plus a purple `<script>` node in the corner spraying edges. Clicking
`#fit` afterwards still leaves rows running off both edges. The banner's
instruction — *uncheck to see everything* — does not produce everything.
Opened as `0010-t2`.

### Two unresolved targets are drawn as one node

`infrastructure.json` declares two unresolved records with **different** target
names, `data.aws_ssm_parameter.stripe_key` and `data.aws_kms_key.rds`. The page
draws **one** orange node, labelled `data.aws_kms_key.rds`, with two orange
dotted edges leaving it — so one of the two edges points at a box bearing
somebody else's name. Counted on the canvas: seventeen real nodes and one
invented one. SqlServerDsc, with 807 unresolved records, also draws a single
orange node.

This is the collision the producer fixed at v0.11.0, alive in the renderer's
invented nodes. Observed rather than read: I have not looked at the code that
builds them, deliberately, because that is the next iteration's job and because
looking at a picture was this one's. Opened as `0010-t3`.

### `0008-t1` and `0008-t2` are both still exactly as described

At three device pixels per CSS pixel, `notify-oncall` still covers all but three
letters of `rollout` and still hides the edge between them — so the *fourth*
line treatment is invisible on the one small page that carries it. The
SqlServerDsc sidebar still prints `Test-TargetResource, Test-TargetResource` and
`ConvertFrom-DscResourceInstance, ConvertFrom-DscResourceInstance` in the same
list. Neither fixed; both re-photographed.

### The fork, in one paragraph

**Four of the five skills were never the same document, so a sync check would
have been a gate whose correct state is red.** `subsystem-charter` opened by
naming `Private/EditorLink/` and `Private/Knowledge/`, directories of another
repository. `meta-pattern` writes to `knowledge/patterns/`, which this
repository's own charter forbids. `iteration-close` spent a third of its length
on facets, personas and a reflection pass built for a knowledge store that
exists in exactly one place. `instruction-prune` routed moved text to files that
are not here. Only `gate-falsifiability` is genuinely shared, and only because
it was written repo-neutral on purpose. A checker over documents that describe
different repositories would have had to be defeated by the first honest edit,
and a gate that is correct when red gets deleted. **The fork is taken and the
kept thing is a rule, not a mechanism: a skill copied between these repositories
is reread against the destination before it lands, and anything that turns out
to be about the other one is rewritten or dropped.** The cost is real and
accepted — five files now drift, and an improvement to `iteration-close` in one
will not reach the other. Opened as `0010-t1`.

### The gate was broken twice before it was trusted

Per `gate-falsifiability`, and the proof belongs here rather than in a comment.

| Break | Restored | Red said |
| --- | --- | --- |
| `prune_proposals: [0008-t1]` in `0008`, which `0009` does not close | yes | *entry 0009 neither applied nor rejected prune proposal(s) opened by 0008: 0008-t1. Apply it, or close it with a reason.* |
| `prune_proposals: [0009-t9]` in `0009`, a thread that does not exist | yes | *entry 0009 names prune proposal 0009-t9 in its front matter and nowhere in its body* |

The second break is the one worth keeping: `Should-BeLikeString "0009-t*"`
**passed** on `0009-t9`, because a fake id of the right shape has the right
shape. Only the body check caught it. A gate with one half would have been a
gate that accepts any well-formed lie.

**And the gate has a hole I could not close.** A proposal in the newest entry is
unenforced until a successor exists, because the check compares each entry
against the next one. That is correct — nothing can close a proposal in the turn
it is raised — and it means `0009-t1` sat genuinely unenforced from the moment
it was written until this entry. A project that stops iterating leaves its last
proposal unenforced forever.

## The survey

Read by hand from twenty-six ledger entries. No tooling was written; see
`0010-t4` for why that turned out to be the wrong call for next time.

### Totals

| | PSModuleGraph | PSGraphRender | Both |
| --- | --- | --- | --- |
| entries | 17 | 10 | 27 |
| threads raised | 53 | 35 | **88** |
| closed | 15 | 8 | **23 (26%)** |
| **vanished without being closed** | 1 | 1 | **2** |
| open now | 37 | 26 | **63** |

**Twenty-one of the twenty-three closures happened in the very next entry.** The
other two took two and three. **Nothing has ever been closed after being carried
four times, in either repository, in twenty-seven iterations.**

That is the answer to the question the table was for, and it is not the answer
the question assumed. A thread carried sixteen times is not "the most important
thing in the project" and it is not waiting its turn — **it is in a state the
project has never once recovered from.** The distribution has no tail: closure
is something that happens immediately or not at all.

### Closed, and how long they took

| Repo | Thread | Opened | Closed | Entries |
| --- | --- | --- | --- | --- |
| PMG | 0001-t1, 0001-t2, 0001-t5 | 0001 | 0002 | 1 |
| PMG | 0002-t1, 0002-t2, 0002-t3, 0002-t4 | 0002 | 0003 | 1 |
| PMG | 0001-t3, 0001-t6 | 0001 | 0003 | **2** |
| PMG | 0004-t2, 0004-t3 | 0004 | 0005 | 1 |
| PMG | 0009-t2 | 0009 | 0010 | 1 |
| PMG | 0012-t5 | 0012 | 0013 | 1 |
| PMG | 0010-t1 | 0010 | 0013 | **3** |
| PMG | 0013-t1 | 0013 | 0014 | 1 |
| PGR | 0001-t3, 0001-t4 | 0001 | 0002 | 1 |
| PGR | 0002-t2 | 0002 | 0003 | 1 |
| PGR | 0003-t3 | 0003 | 0004 | 1 |
| PGR | 0004-t1 | 0004 | 0005 | 1 |
| PGR | 0005-t2, 0005-t3 | 0005 | 0006 | 1 |
| PGR | 0007-t2 | 0007 | 0008 | 1 — **and wrongly; see above** |
| PGR | 0009-t1 | 0009 | 0010 | 1 |

### The two that vanished

Neither was closed. Both simply stopped appearing, and **both are invisible to
the mechanism built to prevent exactly this.**

| Thread | Opened | Last seen | What it was | How it went |
| --- | --- | --- | --- | --- |
| PMG `0001-t4` | 0001 | carried by 0002 | *Make the store's write path real.* | No trace after 0002. `Update-KnowledgeStore` exists today, so the work was probably done; nothing says so. |
| PGR `0002-t4` | 0002 | carried by 0003 | *Producer knowledge can be a shape, not a word.* | 0003's **body** says `0003-t2` is "the open half of `0002-t4`". Its **front matter** dropped it silently. The prose knew and the machine half did not. |

**PSModuleGraph's continuity gate cannot see either of these, and it is the gate
whose entire job is to see them.** `LedgerContinuity.Tests.ps1` compares entry N
against `$previous.OpenThreads` — the threads the previous entry *itself
opened* — and never against what the previous entry *carried*. So a thread is
protected for exactly one iteration after it is raised, and becomes silently
droppable forever after. Both vanishings are second-hop drops and both sailed
past a green gate.

This is a sixth instance of
`PSModuleGraph`'s `knowledge/patterns/0017-nothing-could-have-said-otherwise.md`,
found four days after that pattern was written, in the mechanism the pattern's
own accounting depends on. **Not fixed here** — this half of the iteration was a
survey and building a gate inside it would leave no before-and-after. Opened as
`0010-t4`.

### Open now: PSGraphRender, 26

Carried counts are as of this entry.

| Thread | Carried | What it is |
| --- | --- | --- |
| `0001-t1` | 9 | One fixture, one shape, for the golden. |
| `0001-t2` | 9 | The golden has never been compared on another machine. |
| `0001-t5` | 9 | `Get-HashtableValue` exists in both repositories. |
| `0002-t1` | 8 | `plain` never asks configuration for anything structural. |
| `0002-t3` | 8 | `Get-RenderTemplateSet` may not belong on the public surface. |
| `0003-t1` | 7 | Semantic equivalence only checks the dimensions somebody listed. |
| `0003-t2` | 7 | Nothing checks that a backend reads only what the contract promises. |
| `0003-t4` | 7 | Validation at the seam is one place, which cuts both ways. |
| `0004-t2` | 6 | The payload scan reaches one level and cannot see a computed access. |
| `0004-t3` | 6 | The offline measurement is Chromium's failure, not a proxy's. |
| `0004-t4` | 6 | Playwright was measured and nothing else was. |
| `0005-t1` | 5 | The harness says the page loaded, not that it is right. |
| `0005-t4` | 5 | A vendored file names a `.map` that is not vendored. |
| `0006-t1` | 4 | The falsifiability proof has only run on one machine. |
| `0006-t2` | 4 | The tag audit rebuilt four tags with today's toolchain. |
| `0006-t3` | 4 | Three CI legs install a browser; one has never run the harness. |
| `0007-t1` | 3 | The uncertain-edge style does not survive density. **Now photographed.** |
| `0007-t3` | 3 | `TargetCandidates` is a producer fact the contract does not carry. |
| `0008-t1` | 2 | An invented node is drawn on top of a real one. **Re-photographed.** |
| `0008-t2` | 2 | Two sidebar lists print a name twice and mean two nodes. **Re-photographed.** |
| `0008-t3` | 2 | The fill channel is nearly dead on the payload that needs it most — 469 of 532 nodes are one kind. |
| `0008-t4` | 2 | Nothing checks either README. |
| `0009-t2` | 1 | The skills are a copy that lies. **Half addressed: the lies are gone, the drift is not.** |
| `0009-t3` | 1 | A procedure written from memory records what the author remembers. |
| `0009-t4` | 1 | There is no `CHANGELOG.md`. **Addressed; see `0010-t4` for what a derived one cannot claim.** |
| `0010-t1`…`t6` | 0 | This entry. |

### Open now: PSModuleGraph, 37

| Thread | Carried | What it is |
| --- | --- | --- |
| `0001-t7` | **16** | The facet seam in the report. |
| `0003-t1` | 14 | `facet-health` grades itself flatteringly. |
| `0003-t2` | 14 | Coverage conflates unassigned with inapplicable. |
| `0003-t3` | 14 | `structure:external` has no assignments. |
| `0004-t1` | 13 | Should patterns be subjects? |
| `0004-t4` | 13 | `iteration-close` is model-invocable and it pushes. |
| `0005-t1` | 12 | Skill descriptions are unbudgeted. |
| `0005-t2` | 12 | The ceiling's headroom is a guess — currently 223 bytes. |
| `0005-t3` | 12 | Nothing measures whether an on-demand file is read. |
| `0006-t1` | 11 | The http-origin editor-link claim is unverified. |
| `0007-t1` | 10 | Hot and external are nearly the same colour. |
| `0007-t2` | 10 | Should the store hold measurements? |
| `0008-t1` | 9 | Nothing has been trained on the corpus. |
| `0008-t2` | 9 | The section headings are hardcoded. |
| `0008-t3` | 9 | `corpus/` and `gallery/` are outside lint and the charter test. |
| `0009-t1` | 8 | One fixture proves the move. |
| `0009-t3` | 8 | Nothing proves the dependency is really required. |
| `0010-t2` | 7 | A test scoped to a module that no longer holds what it tests still passes. |
| `0011-t1` | 6 | Nobody has asked what a JSON consumer reads. |
| `0011-t2` | 6 | A re-recorded golden only catches accidents. |
| `0012-t1` | 5 | The corpus is a hypothesis with eight instances. |
| `0012-t2` | 5 | `timeout` and `missing` have never executed. |
| `0012-t3` | 5 | Nothing validates a result against its schema. |
| `0012-t4` | 5 | The lock has only been checked by the session that wrote it. |
| `0013-t2` | 4 | The renderer requirement is a floor treated as a pin. |
| `0013-t3` | 4 | An ambiguous edge is drawn like a certain one — closed producer-side. |
| `0014-t1` | 3 | The store gives 32 definitions one subject and one wrong path. |
| `0014-t2` | 3 | The golden's name claims a provenance it lost. |
| `0014-t3` | 3 | JSON and CSV describe the same graph differently. |
| `0015-t1` | 2 | Three whole-document comparisons are skipped and need a decision. |
| `0015-t2` | 2 | Nobody has opened the SqlServerDsc page. **Answered twice now, in `0008` and here, and still carried.** |
| `0016-t1` | 1 | `-Format Html -IncludeUnresolved` cannot render a module that declares a dependency. |
| `0016-t2` | 1 | An error message names a parameter the command does not have. |
| `0016-t3` | 1 | Nothing checks the README. |
| `0017-t1` | 0 | The skills are duplicated with nothing keeping them in sync. **Answered here for one repository.** |
| `0017-t2` | 0 | Seven skills load into every listing and none has been invoked. |
| `0017-t3` | 0 | A procedure written from memory records what the author remembers. |

### What the table says that no single entry could

**Nine of the sixty-three are duplicates across the two repositories** — the same
doubt raised twice under two ids, because nothing looks sideways. `0005-t1`
appears in both; so do the two "a procedure written from memory" threads
(`0017-t3` and `0009-t3`), the two "nothing checks the README" threads, and
`0015-t2`, which was answered in `PSGraphRender`'s `0008` and is still carried in
`PSModuleGraph` because closing it there requires an entry there.

**The oldest open thread in each repository is `t7` and `t1` of entry `0001`** —
raised in the first entry either repository ever wrote, carried sixteen and nine
times. Neither has been worked on. Under the closure distribution above, neither
will be.

**Nothing in the table is a priority signal.** Carry count measures how long ago
something was noticed, and this project has never used it to decide anything.
That is the useful negative result: **if these are to be triaged, the triage has
to be an act, because the accounting will not do it by accumulating.**

## Dimensional impact

Five questions, against the renderer's own seams.

**1. Did this reveal a distinction the contract cannot express yet?** No. The
unresolved-collision defect is a renderer defect; the contract already carries
two distinct `targetName` values and the page merges them.

**2. Is an existing seam doing two jobs?** No.

**3. Did two seams turn out to be the same thing?** No.

**4. Did anything land at a depth the design did not anticipate?** Yes, and it
is a measurement rather than a proposal: the heat ramp's rank scale is defined
over *distinct values* and the legibility question is about *node density*, and
those come apart badly on a payload with 36 distinct values across 532 nodes.
No pair is being proposed for a split; `0010-t5` records it.

**5. Could this classify itself?** Yes, and unhappily. The survey found that the
gate guarding thread continuity cannot see a second-hop drop — a mechanism that
reports success while being structurally unable to report a whole class of
failure, found by the survey that mechanism was supposed to make unnecessary.

### Prune, this iteration

**A move: none.** **A deletion applied: `0009-t1`**, the CDN-versus-vendoring
open decision, struck after four versions as an answered question. **A new
proposal: none** — which means the gate built this iteration has nothing to bite
on next iteration, and its first real test will be whenever a proposal is next
raised.

### Always-loaded bytes

**10,644 / 10,644.** Unchanged. Nothing was added to `CLAUDE.md`.

## What I could not verify

The Skeptic's section. It is never empty.

- **That any of this survives a different screen.** The user's line, adopted and
  it is the largest hole in the iteration. Every visual judgement here is one
  viewport (1600×1000 or 1400×900), one device pixel ratio, one headless
  Chromium, and whatever fonts this machine has. What a wall display does to a
  532-node lattice, or a laptop at 125% scaling, is unmeasured and stays
  unmeasured — and two of the four findings are explicitly about legibility at
  a size. `0006-t1` says the same thing about the falsifiability proof and is
  four iterations old.
- **That the unresolved collision is what it looks like.** Two records with
  different target names, one node on the canvas, counted by eye: seventeen real
  plus one invented. I did not read the code that builds invented nodes, on
  purpose. There is a reading of this where the second node exists and is
  positioned outside the viewport, and the fact that nothing else in that view
  was clipped is evidence against it, not proof.
- **That the survey's arithmetic is right.** Eighty-eight threads counted by
  hand from twenty-six files, cross-checked by two independent routes — summing
  `open_threads` per entry, and reconciling each entry's `closes` plus
  `carries_forward` against the previous entry's full open set. The two agree,
  and both were done by the same reader in one sitting. Opened as `0010-t4`.
- **That "nothing closes after four carries" is a law rather than a shape.**
  Twenty-three closures over twenty-seven entries is a small sample, and it is
  confounded: early entries had few threads and lots of momentum, and the
  repositories have since spent six of seven iterations on verification rather
  than on the backlog. The distribution may be describing the recent prompts
  rather than the threads.
- **That the derived `CHANGELOG` says what the releases actually changed.** It
  was reconstructed from tags and ledgers at v0.9.0 and says so at the top, but
  a reader will not read the disclaimer before the entry. Nothing compares it to
  the diffs, and eight of its nine sections describe work nobody re-examined.
- **That the fork was the right call rather than the cheap one.** The evidence —
  four documents about another repository — is strong for *not syncing* and
  silent on whether these five files should exist in two places at all. The
  alternative nobody costed is one shared skill set in a third location, and it
  was not costed because neither repository has a mechanism for depending on
  one.

## Open threads

1. **[0010-t1] The skills are forked and nothing watches the drift.** Five files
   in two repositories, deliberately divergent as of v0.9.0. The kept rule — a
   copied skill is reread against its destination — is a habit, and this
   iteration is a record of what happens to habits.
2. **[0010-t2] Lifting the node limit does not move the camera, and `#fit` does
   not fit.** The banner says *uncheck to see everything*; unchecking shows the
   same region plus one node in the corner, and clicking `#fit` afterwards
   leaves rows running off both edges at 532.
3. **[0010-t3] Two unresolved targets with different names are drawn as one
   node.** Observed on `infrastructure.json`: two records, one orange node
   bearing one of the two names, two edges leaving it. The same collision the
   producer fixed at v0.11.0, living in the renderer's invented nodes.
4. **[0010-t4] The continuity gate cannot see a thread dropped from
   `carries_forward`, and the survey that found it cannot be repeated.**
   `PSModuleGraph`'s `LedgerContinuity.Tests.ps1` checks only what the previous
   entry itself opened, so a thread is protected for one iteration and silently
   droppable thereafter; two threads went that way. And the survey above took a
   full reading of twenty-six files to produce and is stale the moment the next
   entry lands. Both halves want the same twenty lines of code, and neither was
   written here because this was a survey.
5. **[0010-t5] The heat ramp has no middle.** Rank over distinct values makes the
   outliers pop and leaves 87% of a 532-node payload in one colour at the cold
   end. It answers "which are the worst" and not "is this worse than that", and
   the legend has never been looked at to see whether it says so.
6. **[0010-t6] No page carries all three dashed treatments where they can be
   read.** Reopens what `0008` closed as `0007-t2` on weaker evidence than the
   thread asked for. `sample-module` has no unresolved and no ambiguity;
   `ambiguous` has no named kind; `infrastructure` has neither; SqlServerDsc has
   all three at a density where two of them vanish.

Carried: **[0009-t2]** the skills were a copy that lies — the lies are gone and
the drift is not; **[0009-t3]** a procedure written from memory records what the
author remembers; **[0009-t4]** there was no `CHANGELOG` — there is one now and
it is derived; **[0008-t1]** an invented node is drawn on top of a real one,
re-photographed at 3× and unchanged; **[0008-t2]** two sidebar lists print a
name twice and mean two nodes, re-photographed; **[0008-t3]** the fill channel
is nearly dead where it is needed most — 469 of 532 nodes are one kind, not all
of them as `0008` said; **[0008-t4]** nothing checks either README;
**[0007-t1]** the uncertain-edge style does not survive density — now
photographed at 532 and confirmed; **[0007-t3]** `TargetCandidates` is not in
the contract; **[0006-t1]** the falsifiability proof has only run on one
machine, and so has every picture in this entry; **[0006-t2]** the tag audit
used today's toolchain; **[0006-t3]** one CI leg has never run the harness;
**[0005-t1]** the harness says the page loaded, not that it is right;
**[0005-t4]** a vendored file names a `.map` that is not vendored;
**[0004-t2]** the payload scan reaches one level; **[0004-t3]** the offline
measurement is Chromium's failure, not a proxy's; **[0004-t4]** Playwright was
measured and nothing else was; **[0003-t1]** semantic equivalence only checks
the dimensions somebody listed; **[0003-t2]** nothing checks that a backend
reads only what the contract promises; **[0003-t4]** validation at the seam is
one place, which cuts both ways; **[0002-t1]** `plain` never asks configuration
for anything structural; **[0002-t3]** `Get-RenderTemplateSet` may not belong on
the public surface; **[0001-t1]** one fixture, one shape, for the golden;
**[0001-t2]** the golden has never been compared on another machine;
**[0001-t5]** `Get-HashtableValue` exists in both repositories.

Closed: **[0009-t1]** the CDN-versus-vendoring decision, applied — struck from
`docs/improvements.md` as answered at v0.5.0. First proposal ever closed by the
mechanism, in the iteration that built the mechanism.
