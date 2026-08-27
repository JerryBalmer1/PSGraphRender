---
name: iteration-close
description: Close an iteration of PSGraphRender — stage and commit deliberately, record the pattern, charter any new subsystem, propose a prune, write the ledger entry, then build green, tag annotated, and push with --follow-tags.
when_to_use: At the end of any prompt cycle in this repository, once the work itself is done and before reporting back. Also invocable by name as /iteration-close.
---

# iteration-close

The eight actions that end an iteration, in order. They were prose scattered
across three sections of `CLAUDE.md`, and one of them — staging and committing —
was written down nowhere at all. A ritual performed from memory erodes at the
edges first: the tag stops being annotated, the push forgets `--follow-tags`,
the ledger entry gets four words.

**The rules for commits live in the Commit section of `CLAUDE.md`. This file
holds the ritual, not the rules.** Do not restate them here; read them there.

## Dependencies

| Step | Invokes | Why there |
| --- | --- | --- |
| 4 | `meta-pattern` | Before the ledger, so the ledger can cite the pattern id. |
| 5 | `subsystem-charter` | Only when a new child area appeared. A charter is part of the change it describes and belongs in the same commit range. |
| 6 | `instruction-prune` | Before the ledger, because the ledger reports the line count and carries the proposal. |

`meta-pattern` and `instruction-prune` are leaves. `subsystem-charter` invokes
`meta-pattern`. Nothing invokes `iteration-close`.

## The order

**1. `git status --short`, and read it.**
Never blind `git add -A`. Stage path by path. If something unexpected is in the
list — a generated report, a coverage file, a scratch script — say so in the
response before staging it, and decide deliberately whether it belongs in the
commit, in `.gitignore`, or deleted.

**2. One logical change per commit.**
If a file carries two unrelated changes, split them, reconstructing an
intermediate state if that is what it takes. A commit that has to be described
with "and" is two commits.

**3. Write the message as the failure prevented.**
`Fail the build when coverage is below target`, not `Add coverage threshold
check`. The body says why — the threshold nobody had watched fail was not a
threshold. Subject imperative, under ~70 characters, no trailing period.

**4. Invoke `meta-pattern`.**
Its output lands in **`PSModuleGraph`'s** `knowledge/patterns/`, because
`knowledge/` here holds only `ledger/` and that is deliberate. Do it before the
ledger so the ledger can cite the pattern id, and name both ids - the pattern
takes the sibling repository's next ledger number, not this one's.

**5. Invoke `subsystem-charter` — only if a new child area appeared.**
The trigger is a directory under `src/PSGraphRender/Private/` reaching three
files, a new backend under `TemplateSets/`, or any new top-level directory.
**Nothing enforces it here** - there is no charter test in this repository - so
this step is a reminder rather than a red build. If nothing new appeared, skip
it and say so in one clause; do not invent a charter to have something to
report.

**6. Invoke `instruction-prune`.**
Every iteration, without exception. It returns the always-loaded byte count and
either a move it made, a deletion proposal, or "no". All three go into the
ledger. **A move it applies in-turn; a deletion it only proposes.**

**7. Write the ledger entry.**
`knowledge/ledger/NNNN-slug.md`. **There is no schema for it here** - the
shape is held by the entries themselves and by the entry you are following, so
read the previous one before writing. Five body sections; `closes` and
`carries_forward` accounting for **every** thread the previous entry left open,
which is its `open_threads` plus its `carries_forward`; `prune_proposals`
naming any thread that is a prune. Record the always-loaded
byte count from step 6. The method is below.

**8. Build green, pass the pre-tag gates, then tag, then push.**

```powershell
./build.ps1
./build.ps1 -Task PreTag
git tag -a v0.X.Y -m "<one line: what this iteration made possible>"
git push --follow-tags
```

`PreTag` runs the tests the default build deliberately excludes: the seals on a
*finished* iteration rather than checks on work in progress. Today that is
twelve: the tool pins, the two gates that are not allowed to skip, the guard on
the guard, and - since v0.9.0 - a prune proposal a second iteration ignored,
which blocks the tag by name. The build stays green while an iteration is half
done; the tag does not.

Never `Invoke-Pester` or `Invoke-Build` directly — `build.ps1` is the only
supported entry point and the only thing that pins Pester 6.1.0.

**The tag is last, and it is always `-a`.** An untagged iteration is an
iteration that cannot be found again, and a lightweight tag carries no message,
no author, and no date of its own. Version bump per the pre-1.0 rule in
`CLAUDE.md`: patch for a normal implementation, minor when a template set, a
setting type, a build task or a contract field is added, major when the view
model contract changes shape. **The contract is versioned separately from the
module** and moves on its own rules.

## What failure looks like here

- A commit whose diff contains a file nobody mentioned. That is step 1 skipped.
- A ledger entry with an empty or apologetic "What I could not verify". There is
  always something; if nothing comes to mind, the entry was written too fast.
- A local tag with no matching remote tag. `git push` without `--follow-tags`
  leaves the release marker on one machine.
- Steps 4–6 reported as done with no file produced. `meta-pattern` legitimately
  produces nothing when the two-scale bar is unmet, and `instruction-prune`
  legitimately answers "no" — but say which, and why.
- A ledger entry with no always-loaded byte count. It is the metric now, and a
  number missing from one entry breaks the only trend anyone can read.

## The four personas

Working modes, not costumes. The value is that each asks a different question
first, and the ledger names which were used so the lens is visible.

- **Taxonomist** - designing or changing a contract field, a setting, or a
  registry entry. *What does this distinction let someone do that they could not
  do before?*
- **Archivist** - writing to the store. *Will this parse and make sense to a
  reader in another language who has never seen this repo?*
- **Integrator** - connecting a payload to a backend. *What is the smallest
  seam that does this without either side learning about the other?*
- **Skeptic** - invoked last, always. *What did we assert without evidence?*

## The reflection pass

Five questions at the end of every implementation, answered in the ledger's
**Dimensional impact** section. **"No" is a complete answer and is the expected
answer most of the time** - a reflection pass that finds something every time is
a pass that is inventing things.

**The evidence rule.** A "yes" to question 1, 2 or 3 **must name two specific
payloads, settings or backends** that the current design cannot tell apart, or
that the proposed split would separate. **No pair, no proposal - the answer is
"no".** Naming the pair converts "did you notice anything" into "show me the
thing", and a reader can check it in ten seconds.

**A proposal you withdraw is a successful reflection pass, not a failed one.** A
pass that never retracts is a pass that only ratchets, and a design that only
grows is one nobody can hold in their head.

The five questions are asked here against the renderer's own seams, because the
facets they were written for live in `PSModuleGraph`:

1. Did this reveal a distinction the contract cannot express yet?
2. Is an existing seam doing two jobs?
3. Did two seams turn out to be the same thing?
4. Did anything land at a depth the design did not anticipate - a setting that
   needed a type, a backend that needed a field?
5. Could this classify itself? A rule that applies to the file stating it is
   worth saying out loud.

Then, before the tag: **entry N must close or carry forward every thread entry
N-1 left open.** `closes` and `carries_forward` in the front matter, thread ids
of the form `0001-t5`. **Nothing checks that here.** `tests/LedgerPrune.Tests.ps1`
enforces prune proposals and nothing else; the continuity of open threads is a
convention held by hand, and `PSModuleGraph`'s equivalent gate has a blind spot
of its own - see `0010-t4`. Do the accounting anyway, and do it against the full
set the previous entry left open, which is its `open_threads` **plus** its
`carries_forward`.