---
name: subsystem-charter
description: Write docs/<subsystem>-architecture.md for a child area of PSGraphRender, stating locally what the parent rules mean there — target, seam, layout, the rule that pays for it, kaizen, checklist, append-only decisions log.
when_to_use: When a directory under src/PSGraphRender/Private/ reaches three files, when a new backend appears under TemplateSets/, or when any new top-level directory appears. Also invoked by iteration-close.
---

# subsystem-charter

`docs/render-architecture.md` is the only charter this repository has, and it
exists because a prompt asked for it once. `Private/Config/` is a subsystem of
identical shape — several files, a shared contract, one seam — and has none. The
intent went downward exactly once, by hand, and then stopped.

This is the propagation rule. Its job is to make the next child area get a
charter without anyone remembering to ask.

**This file is forked from `PSModuleGraph`'s and is not the same document.** The
shape is shared; the triggers, the paths and the enforcement are not. Do not
sync them — see the skills `README.md`.

## Dependencies

`meta-pattern`. A charter that does not record what it inherited is a file
listing. When you write one, the thing you learned about *what the parent rule
meant here* is a candidate pattern — it has been observed at the parent scale
and at this one, which is two.

## Trigger

- A directory under `src/PSGraphRender/Private/` reaching **three files**.
- A **new backend** under `TemplateSets/`. A backend is the one child area this
  repository is designed to acquire more of, and `templateset.psd1` plus four
  config files is already most of a charter's file layout section.
- Any **new top-level directory** in the repository.

Three files is the threshold because two files are a pair and three are a
convention.

**Nothing enforces this.** `PSModuleGraph` has a charter test; this repository
does not, so the trigger is a reminder and a reminder is one tired session from
being missed. If that matters enough to fix, it is a gate, and
`gate-falsifiability` says what proving it costs.

## Output

`docs/<subsystem>-architecture.md`, lowercase, matching the directory name
case-insensitively.

Seven sections, in the shape `render-architecture.md` already proved:

1. **Target** — what "done" means for this subsystem, stated so it can be
   checked. For a backend it is that a second one can be added without editing
   a `.ps1`, and the charter says how you would know.
2. **The seam** — the one function or file that knows both sides, named. What
   may cross it and what may not, in vocabulary terms.
3. **File layout** — a tree, marking what is data and what is code. The four
   config files are data; a setting that needs a `.ps1` edit is the bug this
   whole design exists to make visible.
4. **The rule that pays for it** — one blockquote. The single constraint that
   makes the design worth its cost, phrased so a violation is recognisable.
5. **Kaizen in this subsystem** — the improvement loop, narrowed.
   "Better shaped" must have a local definition or the loop has no direction.
   The repository-wide one is *closer to a renderer a producer in another
   language could drive without changing anything*; say what that means here.
6. **Checklist** — checkboxes, honest about what is unticked. An all-ticked
   checklist on a young subsystem is the tell of a charter written to look
   finished.
7. **Decisions made and why** — append only, dated, two or three sentences each.
   Not to be re-litigated.

## The part that is actually the work

**The charter inherits the parent intent and states it locally. Not a link to
`CLAUDE.md` — a local sentence.**

*The renderer knows about nodes and edges and nothing about what they are* is
the repository rule. Its backend-local form is **"a hardcoded list of link
kinds in a script is `KIND_HEX` again"**; its config-local form is **"a setting
whose valid values are enumerated in a validator instead of in
`settings.schema.psd1` has moved the taxonomy into code"**. Those are different
sentences saying one thing, and writing them out is the whole exercise. A
charter that says "see `CLAUDE.md`" has propagated a pointer, not an intent, and
a pointer is what already existed.

For each parent rule that bears on the subsystem, ask: **what does a violation
of this look like *here*, specifically enough that I would recognise it in a
diff?** If you cannot answer, the rule does not bear on this subsystem and does
not belong in its charter.

## Keep it dense, not short

A charter nobody reads is worse than none, because it looks like coverage. The
guard against that is **saying something local**, not staying under a line
count: a 60-line charter that points back at `CLAUDE.md` five times is padding,
and a 300-line one that states what every parent rule means here is not.

Charters are the **destination** for detail moved out of the always-loaded tier,
so a cap on the on-demand tier directly opposes that move. The budget that
matters is on `CLAUDE.md` — see `.claude/skills/instruction-prune/SKILL.md`.

An empty decisions log with one honest entry beats twelve invented ones. A new
charter starts short because it has no accumulated decisions yet, not because a
rule made it so.
