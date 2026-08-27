---
id: "0007"
tag: v0.7.0
date: 2026-08-27
prompt_intent: Carry the producer's edge resolution through the contract and draw it differently, as a theme decision the renderer looks up rather than a list of values it knows.
personas: [integrator, skeptic]
open_threads: [0007-t1, 0007-t2, 0007-t3]
closes: []
carries_forward: [0006-t1, 0006-t2, 0006-t3, 0005-t1, 0005-t4, 0004-t2, 0004-t3, 0004-t4, 0003-t1, 0003-t2, 0003-t4, 0002-t1, 0002-t3, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0007 — a doubt with nowhere to go

## What changed

**Contract 1.1.0: `links[].resolution`, optional.** A string the producer picks.
**Absent means NOT STATED**, which is a different fact from any value it could
carry, and the renderer never defaults it to the confident one.

**`StyleMap`, a setting type.** An arbitrary key to a small style descriptor.
`EdgeResolutionStyle` in `theme.psd1` maps a resolution to `LineStyle` and
`Opacity`; cytoscape draws `Ambiguous` dashed at 0.45 and `plain` declares none.

**The Details panel counts uncertain links** touching the selection, when any
are styled, and shows nothing otherwise.

**A fixture that is not PowerShell.** `tests/fixtures/viewmodels/ambiguous.json`
— tasks, policies, yaml files, two definitions of `restart` — so the check that
the renderer has not learned a producer's word for doubt has something to fail
against.

## What I learned

**The keys are data and the property names are not, and that is one rule seen
from two sides.** `EdgeResolutionStyle`'s keys are never validated: validating
them would put a list of one producer's resolution words back inside the
renderer, which is `KIND_HEX` a fifth time. `LineStyle` and `Opacity` are
validated hard, because they are *this renderer's* words for how a line looks
and a typo in one would otherwise draw nothing at all, silently. The test that
matters is the one that feeds it `Ambiguous`, `Vermutet` and `推定` and expects
all three to pass.

**The style rules had to be spliced after the link-kind rules, not before.**
`LinkColor` already draws a named kind dashed. An edge that is both classified
and uncertain now reads as uncertain, because Cytoscape resolves by declaration
order and the resolution rules are declared later. Writing them earlier would
have produced a page where the answer depended on which classification a
producer happened to send.

**The harness drew it, which is not the same as the test asserting it.** The new
fixture renders in headless Chromium at **ratio 7.34 against a required 4** —
six nodes, six links, three of them dashed and half-transparent. Every other
fixture sits at 12.2–13.6. This is the sparsest payload the growth check has ever
met, which is the case `0006-t2` says has never been tried; it passes with less
margin than anything before it, and the margin is still nearly double.

**A test wrote the wrong signature three times before I read the function.**
`Test-RenderSettingValue` takes `-Value` and `-Entry` and returns `IsValid`; I
wrote `-Name` and `.Ok` from memory. Cheap here because the suite is fast, and
the same class of error as predicting from code rather than measuring — the
thing the producer's `0014` was written about.

**A `Set-Content -Encoding UTF8` stripped a BOM and the analyzer caught it.**
`strings.psd1` holds non-ASCII, `PSUseBOMForUnicodeEncodedFile` fired, and the
build went red on a file whose visible diff was three lines. Worth keeping: a
lint rule that fires on an encoding change nobody can see in a diff is a lint
rule earning its place.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the style reads correctly at any ratio other than the two tried.** The
  user's own line, adopted. It was designed against SqlServerDsc's 702 of 1,271
  and checked against a fixture's 2 of 6. A page where 5 of 600 edges are dashed
  may hide them; one where 600 of 600 are may be unreadable as a whole. Nobody
  has looked at either. Opened as `0007-t1`.
- **That dashed at 0.45 is distinguishable from the other things dashed means
  here.** `LinkColor` draws a named kind dashed in its own colour, `Unresolved`
  is dotted, and now uncertainty is dashed and faded. Three line treatments in
  one drawing, and no one has viewed a page carrying all three at once. Opened
  as `0007-t2`.
- **That the Details count is the number a reader wants.** It says how many
  links touching this node the payload declined to tie down. It cannot say how
  many candidates each had, because the contract does not carry that and
  inventing a second field was explicitly out of scope. A reader who sees
  "3 of 7" still does not know whether that means two possibilities or thirty.
  Opened as `0007-t3`.
- **That absent really is treated as not-stated everywhere.** Asserted at the
  payload boundary: a fixture with no `resolution` key produces a document with
  no `"resolution"` string in it. `elements.js` turns absence into `''` at
  runtime, which matches no generated selector — checked by reading, not by a
  browser assertion on a specific edge.
- **That `plain` is unaffected rather than merely silent.** It declares no
  `EdgeResolutionStyle`, renders the new fixture, and passes its smoke block. It
  draws a table and has no lines, so there is nothing for the mechanism to do
  there — which means this iteration's second backend tested nothing about it.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**11,223 / 11,223.** Unchanged.

## Open threads

1. **[0007-t1] The style is calibrated against one density.** Designed for 702
   of 1,271 and checked at 2 of 6. Neither the sparse nor the saturated case has
   been looked at by a person.
2. **[0007-t2] Three things in one drawing are dashed or dotted.** A named link
   kind, an unresolved target, and now an uncertain resolution. No page carrying
   all three has been viewed.
3. **[0007-t3] The count says how many, never how many of what.** The candidate
   count is a producer fact contract 1.1.0 does not carry. Adding
   `links[].candidates` is a proposal, not an edit.

Carried: **[0006-t1]** the falsifiability proof has only run on one machine;
**[0006-t2]** the growth ratio had never met a sparse payload — narrowed here to
7.34 on six nodes, not closed, because nobody has rendered one that legitimately
falls under 4; **[0006-t3]** two of five defects were 5.1-only on a leg that has
run four times; **[0005-t1]** the harness says the page loaded, not that it is
right; **[0005-t4]** a vendored file names a `.map` that is not vendored;
**[0004-t2]** the payload scan reaches one level and cannot see a computed
access; **[0004-t3]** the proxy case is still unmeasured; **[0004-t4]**
Playwright is still the only harness measured; **[0003-t1]** semantic
equivalence only checks the dimensions I listed; **[0003-t2]** narrowed, not
closed; **[0003-t4]** validation at the seam is one place, which cuts both ways;
**[0002-t1]** `plain` never asks configuration for anything structural — and did
not this iteration either; **[0002-t3]** `Get-RenderTemplateSet` may not belong
on the public surface; **[0001-t1]** one fixture, one shape, for the golden;
**[0001-t2]** nothing compares the document across legs; **[0001-t5]**
`Get-HashtableValue` exists in both repositories.
