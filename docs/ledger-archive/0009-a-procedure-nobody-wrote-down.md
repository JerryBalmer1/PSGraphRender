---
id: "0009"
tag: v0.8.1
date: 2026-08-27
prompt_intent: Record the one procedure this repository has performed three times and never written down, add the question to the improvement loop that would have caught it, and pay for the line by moving a section that was never needed before the work began.
personas: [archivist, skeptic]
open_threads: [0009-t1, 0009-t2, 0009-t3, 0009-t4]
closes: []
carries_forward: [0008-t1, 0008-t2, 0008-t3, 0008-t4, 0007-t1, 0007-t3, 0006-t1, 0006-t2, 0006-t3, 0005-t1, 0005-t4, 0004-t2, 0004-t3, 0004-t4, 0003-t1, 0003-t2, 0003-t4, 0002-t1, 0002-t3, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: [0009-t1]
supersedes: []
---

# 0009 — a procedure nobody wrote down

## What changed

**`.claude/skills/gate-falsifiability/SKILL.md`.** Break the gate deliberately,
confirm red, restore, and put the break and the message in the ledger. Three of
the four worked examples in it happened here.

**One line in the improvement loop** — a fifth question: did I follow a
procedure I have followed before, and is it written down? If not, log a
proposal; do not write the skill in the same pass.

**`## Open decisions` moved down a tier** to `docs/improvements.md`, because the
line did not fit. The one rule that is violated from outside that file stayed
behind as two sentences.

**The ceiling is 10,644**, down from 11,223.

The pattern the skill rests on is in `PSModuleGraph` —
`knowledge/patterns/0017-nothing-could-have-said-otherwise.md`. `knowledge/`
here holds only `ledger/` and that has not changed.

**Patch.** Instructions moved. Nothing behaves differently.

## What I learned

**The tier had zero headroom, which is what a ratchet is supposed to produce,
and the trade it forced was a good one.** `CLAUDE.md` was 11,223 against a
ceiling of 11,223 — the exact state where the next addition has to argue for
itself. `## Open decisions` failed the tier test plainly: three questions nobody
has to hold in their head before starting work, one of which was already
duplicated in `docs/improvements.md` under a heading saying so. What an agent
does need before it starts is the rule — do not resolve one of these
unilaterally as part of an unrelated change — and that stayed. **579 bytes net
after adding the question**, and the target of 10,000 is closer than it has been
since v0.1.0.

**One of the three open decisions has been answered for four versions and was
still being loaded into every session as an open question.** *"Should library
code be vendored instead of loaded from a CDN?"* — vendored at v0.5.0, and the
same paragraph names `partials/cdn-guard.html`, which that iteration deleted.
Every session since has read a live question about a settled thing and a
pointer to a file that is gone. Moved verbatim rather than corrected, because a
move loses nothing and a deletion has to wait; opened as `0009-t1` and named in
`prune_proposals`.

**The four gate proofs were four different acts, and three of them are ours.**
The pre-tag guard needed its *filter* broken rather than its code, because the
code was fine and the question was whether anything ran — `Filter.Tag` set to a
tag nothing carries produced `123 discovered, 123 not run`. The browser harness
needed two breaks, because a parse error kills the page and a blank canvas does
not, and only the second break measured the canvas at all: 53,971 bytes drawn
against 4,413 blank, with the deliberate break landing on 4,413 exactly. The
lint tasks came back **green** on `thisFunctionDoesNotExist()` — fourteen
scripts parse, because a runtime error is syntactically perfect — and that was
the exercise finding the boundary rather than failing. Writing one paragraph
covering all three would have averaged them, and the averaging is the error.

**No skill in this directory has been invoked.** Checked, not assumed: the four
iterations from v0.5.0 to v0.8.0 each closed correctly — ledger entry, prune
report, byte count, annotated tag — from `CLAUDE.md` and from memory.
`instruction-prune` was invoked for the first time in this iteration, and only
because a prune was genuinely needed in the same turn.

**And this directory is a copy that lies.** All five skills are byte-identical
to `PSModuleGraph`'s with nothing keeping them in sync, and four claims in them
are false here: `tests/Private/SubsystemCharter.Tests.ps1` does not exist,
`knowledge/NAMING.md` does not exist, `docs/html-architecture.md` is
`docs/render-architecture.md`, and the version rule talks about facets in a
repository that has none. A fifth is quieter and worse — `instruction-prune`
says a deferred deletion proposal is blocked by `tests/PreTag.Tests.ps1`, and
**this repository's `PreTag.Tests.ps1` has no such gate.** The `prune_proposals`
field in this very entry is therefore unenforced. That is the pattern this
iteration wrote up, arriving inside the document describing it.

## Dimensional impact

Five questions. Facets live in `PSModuleGraph`; here the questions are answered
against the renderer's own seams.

**1. Did this reveal a dimension that does not exist yet?** No. Nothing was
classified.

**2. Is an existing seam doing two jobs?** No.

**3. Did two seams turn out to be the same thing?** No.

**4. Did anything land at a depth the design did not anticipate?** No.

**5. Could this classify itself?** Only in the sense that the pattern recorded
this iteration applies to the file recording it — see the unenforced
`prune_proposals` above.

### Prune, this iteration

**A move: `## Open decisions`**, from `CLAUDE.md` to `docs/improvements.md`. The
rule stayed; the three questions went. **A deletion proposal: `0009-t1`** — the
CDN-versus-vendoring decision, answered at v0.5.0, still written as open.

### Always-loaded bytes

**10,644 / 10,644**, down from 11,223 with the ceiling ratcheted to match. The
target in `CLAUDE.md` is 10,000.

## What I could not verify

The Skeptic's section. It is never empty.

- **That a skill written by whoever just performed the procedure records what
  they actually did.** The user's line, adopted. The three proofs here were
  reconstructed from ledger entries `0004`, `0005` and `0006`, written at
  varying distance from the act, and nothing distinguishes the ones written the
  same day from the ones written after. Opened as `0009-t3`.
- **That `gate-falsifiability` is right about the fourth gate.** The version
  gate is in the other repository and I read its ledger rather than running it.
  Its lesson — that passing both directions does not mean catching the case that
  prompted it — is the sharpest claim in the file and the only one I did not
  observe.
- **That any skill here will ever be invoked.** Four iterations, none loaded,
  and this one adds a fifth to a listing that costs something whether or not it
  is used. `0005-t1` has said skill descriptions are unbudgeted since v0.4.0 and
  nothing measures it. Opened as `0009-t2`.
- **That the four false claims are all of them.** Found by reading the copy for
  paths and mechanisms and checking each against this tree. Nothing checks them,
  and the divergence started this iteration by design when
  `gate-falsifiability` was written with every cross-reference naming its
  repository.
- **That this repository has a release history anyone can read.** There is no
  `CHANGELOG.md` here at all, across eight annotated tags. The ledger carries
  everything, and a ledger entry is written for the next implementer rather than
  for a consumer. Opened as `0009-t4`.
- **That moving `## Open decisions` costs nothing.** A move loses nothing from
  the repository and it does lose something from the session: those three
  questions were read before every task and are now read only by somebody who
  opens the backlog. That is the trade the tier test asks for, taken
  deliberately, and if one of them is resolved unilaterally in the next few
  iterations this is why.

## Open threads

1. **[0009-t1] An open decision that was answered at v0.5.0 is still written as
   open.** Library code is vendored; `partials/cdn-guard.html` was deleted in
   the same iteration and the paragraph still cites it. Strike it, or record
   what remains open about it. **A prune proposal.**
2. **[0009-t2] Five skills are a byte-identical copy of another repository's,
   four of their claims are false here, and none has ever been invoked.** One of
   the false claims is a `PreTag` gate that does not exist, which leaves this
   entry's own `prune_proposals` field unenforced.
3. **[0009-t3] A procedure written from memory records what the author remembers
   doing.** Three gate proofs reconstructed from ledger entries of varying
   distance from the act.
4. **[0009-t4] There is no `CHANGELOG.md`.** Eight annotated tags, and the only
   readable history is a ledger written for the next implementer rather than for
   a consumer.

Carried: **[0008-t1]** an invented node is drawn on top of a real one;
**[0008-t2]** two sidebar lists print a name twice and mean two nodes;
**[0008-t3]** the fill channel is dead on the payload that needs it most;
**[0008-t4]** nothing checks either README; **[0007-t1]** the uncertain-edge
style does not survive density; **[0007-t3]** `TargetCandidates` is not in the
contract; **[0006-t1]** the falsifiability proof has only run on one machine —
now the closing trap in the skill that names it; **[0006-t2]** the tag audit
rebuilt four tags with today's toolchain; **[0006-t3]** three legs install half
a gigabyte of browser and one has never run the harness; **[0005-t1]** skill
descriptions are unbudgeted, and there are now five; **[0005-t4]** a vendored
file names a resource that is not vendored; **[0004-t2]** the payload scan
reaches one level; **[0004-t3]** the offline measurement is Chromium's failure,
not a proxy's; **[0004-t4]** Playwright was measured and nothing else was;
**[0003-t1]** semantic equivalence only checks the dimensions I listed;
**[0003-t2]** narrowed, not closed; **[0003-t4]** validation at the seam is one
place, which cuts both ways; **[0002-t1]** `plain` never asks configuration for
anything structural; **[0002-t3]** `Get-RenderTemplateSet` may not belong on the
public surface; **[0001-t1]** one fixture, one shape, for the golden;
**[0001-t2]** the golden has never been compared on another machine.
