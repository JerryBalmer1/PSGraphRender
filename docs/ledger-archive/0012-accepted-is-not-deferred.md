---
id: "0012"
tag: v0.11.0
date: 2026-08-27
prompt_intent: Apply every ruled verdict, move the accepted limitations out of the thread list into a document that says they are deliberate, and take the push out of every file that can be followed.
personas: [archivist, integrator, skeptic]
open_threads: [0012-t1, 0012-t2, 0012-t3]
closes: [0003-t2, 0009-t4, 0004-t3, 0001-t2]
carries_forward: [0002-t3, 0005-t1, 0006-t1, 0006-t2, 0007-t1, 0008-t1, 0008-t2, 0008-t4, 0010-t2, 0010-t3, 0010-t6, 0011-t1, 0011-t2, 0011-t3]
accepts_threads: [0001-t5, 0002-t1, 0003-t1, 0003-t4, 0004-t2, 0004-t4, 0005-t4, 0006-t3, 0007-t3, 0008-t3, 0010-t1, 0010-t5]
prune_proposals: []
supersedes: []
---

# 0012 — accepted is not deferred

## What changed

**`docs/constraints.md`.** Twelve limitations this repository has decided to
have, each with the argument that retired it. They are out of the thread list.

**`accepts_threads`**, a third retiring verb. **Accepted is not closed**: closed
means the question is answered, accepted means it is not and never will be, and
a reader is entitled to tell them apart. `tools/threads.ps1` reports it as its
own status and refuses to fold it into `closed`.

**No document here can publish by being followed.** The push left
`iteration-close` step 8 and `CLAUDE.md`; `tests/Instructions.Tests.ps1` fails by
file and line if it returns.

**The heat ramp comment says what was measured rather than what was intended**,
which is the reasoning behind the ruling and not a footnote to it.

**Twenty-eight verdicts applied.** Four closed, twelve accepted, twelve carried
as work.

**`CLAUDE.md` is 10,410 bytes**, down from 10,644, paying for the publishing
rule with a move.

**Minor**, for the thread-state shape and the skill.

## What I learned

**Applying the triage is where its cost shows up.** Proposing sixty-eight
verdicts took one pass of reading. Applying them took a schema field, a change
to two gates and a tool, a new document, and twelve paragraphs of argument that
did not exist before — because **an Accept is not a state change, it is a piece
of writing.** "We choose to live with this" is worth nothing without the
reason, and the reason was in a ledger entry that nobody proposing a fix would
have opened. That asymmetry is the answer to whether this is a habit: see below.

**The comment was the actual defect in the heat ramp, and the ruling named it.**
It said rank *"spreads the ramp across the values that actually occur"* and
stopped — true, and an intention rather than a measurement. Values are not
nodes: 36 distinct values across 532 nodes puts 87% of them in the coldest
quarter. It took a screenshot to notice, six versions after the comment was
written, and the comment now carries both numbers and the date they were taken.
**The algorithm is accepted; the page implying something it does not do is
`0012-t1`.**

**A prune duplicated its source instead of moving it.** Moving the Pester-pin
reasoning out of `CLAUDE.md` put a second copy into `docs/testing.md`, which
already held it — the exact *"leave a pointer, not a summary"* failure,
committed while performing the procedure that warns about it. One `sed -n` on
the destination caught it inside the turn. The destination now records that it
happened, because a near-miss nobody writes down is a near-miss that recurs.

**Four Closes were answered and never struck, and one of them by seven
entries.** `[0003-t2]` — *nothing checks a backend reads only what the contract
promises* — was satisfied by `tests/BackendContract.Tests.ps1` at **v0.4.0**.
The entry that built that test did not close the thread that asked for it, and
seven entries carried it afterwards.

### What would have caught that earlier, and is it worth building

**A thread naming an artefact could be checked against that artefact.**
`[0003-t2]` names a test that did not exist and then did; `[0001-t7]` in
`PSModuleGraph` names `docs/html-architecture.md`, a file that stopped existing
at v0.9.0 and was carried nine more times; `[0009-t4]` names a `CHANGELOG.md`
that was absent and now is not. **Three of the four stale Closes would have been
caught by one rule: if a thread's text names a path, and the path's existence
has flipped since the thread was raised, say so.** That is perhaps twenty lines
on top of `tools/threads.ps1`, which already extracts each thread's sentence,
and it would have reported `[0001-t7]` as suspect nine iterations before a human
did. The fourth — `[0004-t3]`, the proxy — names no path and would have been
missed, which is the honest limit: it went stale because vendoring removed the
network, and nothing textual connects those two facts.

**Is it worth building? Yes, and only because it does not decide anything.** The
distinction that matters is the one this iteration has been careful about
everywhere else: a check that says *"this thread names a file that has appeared
since you raised it"* reports a fact, and a reader rules on it. That is the same
contract `threads.ps1` already keeps, and it is why the answer differs from the
one about ranking — a staleness *score* would be a heuristic pretending to be a
signal, while a path that exists or does not is neither. **The argument against
is real and is about cost of habit rather than cost of build**: a triage pass is
cheap once and expensive as a ritual, and this project has now spent parts of
three iterations on its own accounting. **A once-per-pass hint that costs
nothing to ignore is the cheap version; a scheduled triage is the expensive
one.** Build the hint, do not schedule the pass. Not this iteration and not
proposed as a thread, because it is an answer to a question you asked rather
than a doubt I am carrying.

## The verdicts applied

**Closed** — answered and never struck: `[0003-t2]`, `[0009-t4]`, `[0004-t3]`,
`[0001-t2]`.

**Accepted**, retired to `docs/constraints.md`: `[0001-t5]`, `[0002-t1]`,
`[0003-t1]`, `[0003-t4]`, `[0004-t2]`, `[0004-t4]`, `[0005-t4]`, `[0006-t3]`,
`[0007-t3]`, `[0008-t3]`, `[0010-t1]`, `[0010-t5]`.

**Carried as work** — twelve Fix verdicts plus this repository's `0011` threads,
which have no verdict because they were raised after the triage. `[0006-t1]` is
among them because you overruled the Accept, and the reason stands up: a CI job
that breaks a gate, asserts the red, restores and reports itself green is
unambiguous, and my objection was to a job whose own red meant two things, which
is not the job you described.

## Dimensional impact

Five questions, against this repository's own seams.

**1. Did this reveal a distinction the design could not express?** Yes, and it
was built. **Accepted** and **closed** are different facts and the ledger had
one word for both. The pair that forces it: `[0009-t4]`, struck because a
CHANGELOG now exists, and `[0005-t4]`, retired because a vendored file really
does name a `.map` that is not shipped and always will. Recording both as
`closes` tells a reader the second was solved.

**2. Is an existing seam doing two jobs?** No — `tests/Ledger.Tests.ps1` was
split from one Describe into two last iteration and both are still one subject.

**3. Did two seams turn out to be the same thing?** No.

**4. Did anything land at a depth the design did not anticipate?** Yes: an
accepted constraint needs somewhere to live that is not the backlog, because a
backlog entry reads as work. `docs/constraints.md` is that place and it is new.

**5. Could this classify itself?** Yes. `docs/constraints.md` records that
nothing measures whether an on-demand file is read — and it is an on-demand
file whose whole purpose is to be read before somebody proposes a fix.

### Prune, this iteration

**A move: the build and test procedure**, from `CLAUDE.md` to
`docs/development.md` and `docs/testing.md`, leaving the prohibition on calling
`Invoke-Pester` directly because that one is violated from outside the file it
moved to. It paid for the publishing rule, which breached the ceiling by 140
bytes. **A deletion proposal: none.**

### Always-loaded bytes

**10,410 / 10,410**, down from 10,644, ceiling ratcheted to match. The target is
10,000.

## What I could not verify

The Skeptic's section. It is never empty.

- **That twenty-eight verdicts applied in one pass are twenty-eight decisions.**
  Your line, and it is sharper applied than proposed: **a Close applied to a
  thread nobody re-read is indistinguishable from a thread dropped**, which is
  what the gate was fixed for one entry ago — and the gate cannot tell them
  apart, because both look like an id leaving the open set with a word attached.
  I re-read all four Closes against the file each names. The twelve Accepts I
  re-read far enough to write a paragraph each, which is a weaker check than it
  sounds: writing a justification is what confirmation bias is for. `0012-t3`.
- **That `docs/constraints.md` changes anybody's behaviour.** Its entire purpose
  is to be read *before* a proposal, and the only thing pointing at it is a
  blockquote in `docs/improvements.md`. The thread saying nothing measures
  whether an on-demand file is read was accepted into this very file.
- **That the publishing gate covers what it claims.** It reads `CLAUDE.md`,
  `.claude/**`, `docs/**` and the root `*.md`, matches `\bgit\s+push\b`, and
  deliberately exempts `knowledge/` and `CHANGELOG.md` — records, which have to
  be able to name what they removed. A ledger entry is still a document in the
  repository, so the hole is real and stated.
- **That the heat-ramp numbers generalise.** 36 distinct values and 87% in the
  coldest quarter are one metric on one module at one moment, read off one
  screenshot at one device pixel ratio. The comment now says "measured on
  SqlServerDsc" rather than implying a property of the algorithm, which is the
  correction; it is not a claim about other payloads.
- **That accepting twelve things is not just a tidier way of dropping them.**
  The test would be somebody later disagreeing with one and finding the argument
  waiting for them, and nothing has been through that yet.

## Open threads

1. **[0012-t1] The legend does not say that colour is rank rather than
   magnitude.** The ramp is accepted and the page implying proportionality is
   not. Strings and theme, ruled, and left as work rather than folded into an
   applying pass.
2. **[0012-t2] `docs/constraints.md` is a document that only works if it is read
   first.** One blockquote points at it, nothing enforces it, and the constraint
   about unread on-demand files is inside it.
3. **[0012-t3] Twenty-eight verdicts were applied in one pass**, and a Close
   applied without re-reading is indistinguishable, to every mechanism here,
   from a thread dropped.

Carried: **[0002-t3]** `Get-RenderTemplateSet` may not belong on the public
surface; **[0005-t1]** the harness says the page loaded, not that it is right;
**[0006-t1]** the falsifiability proof has only run on one machine — ruled Fix,
its own iteration; **[0006-t2]** the growth ratio has never met a sparse
payload; **[0007-t1]** the style is calibrated against one density — ruled Fix,
its own iteration, with the three other visual defects; **[0008-t1]** an
invented node is drawn on top of a real one; **[0008-t2]** two lists print a
name twice; **[0008-t4]** nothing checks either README; **[0010-t2]** lifting
the node limit does not move the camera; **[0010-t3]** two unresolved targets
are drawn as one node; **[0010-t6]** no page carries all three dashed
treatments readably; **[0011-t1]** the verdicts were proposed in one pass;
**[0011-t2]** the tool reports and the temptation to rank it will recur;
**[0011-t3]** a merge across repositories has no id grammar.
