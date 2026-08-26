---
id: "0002"
tag: v0.2.0
date: 2026-08-26
prompt_intent: Fix the backend resolution I reported rather than worked around, build New-RenderDocument, add a deliberately trivial second backend to prove the first two worked, and do every rename the last iteration deferred - all of it under a golden that must stay byte-identical throughout.
personas: [integrator, skeptic]
open_threads: [0002-t1, 0002-t2, 0002-t3, 0002-t4]
closes: [0001-t3, 0001-t4]
carries_forward: [0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0002 — the seam that was a description

## What changed

**A backend's location is stated once.** `Resolve-RenderTemplateSetPath` is the
only thing that answers where a backend lives; the two config resolvers take a
template set root and append `Config/` themselves. `TemplateSets/index.psd1`
names the default and discovery is enumerating directories that contain a
`templateset.psd1`. **No `.ps1` under `src/` names a backend**, and a test
asserts it.

**`New-RenderDocument` exists.** One call takes a view model, a meta block, a
strings hashtable, a title and an optional backend. The escapers,
`Resolve-RenderString` and `Resolve-RenderConfiguration` went back to private.
Public surface: four.

**`TemplateSets/plain`** is a static HTML table with no CDN, no library and no
layout engine. Adding it required editing no `.ps1` under `src/`.

**Everything renamed.** Five public functions, three private helpers, two asset
resolvers, one parameter, and the four `__GRAPH_*__` markers. The golden was
byte-identical after every one.

**`tests/fixtures/viewmodels/infrastructure.json`** is hand-written and
describes Terraform. It renders through both backends.

## What I learned

**The charter was describing an interface the code did not have.** "The seam
faces outward" was written about `New-RenderDocument`, which did not exist,
while the actual interface was seven functions and four marker names a producer
had to know. That is not a documentation lag - it is the kind of statement that
reads as true to everyone who has not tried to write a second producer, which is
everyone.

**The trivial backend was the expensive part, and worth it.** Two things only
showed up because something had to render that was not Cytoscape.
`PSMissingModuleManifestField` fires on the `.psd1` extension alone and flagged
a backend whose `settings.psd1` is legitimately empty - so the Lint task now
excludes that one rule for `TemplateSets/` and nowhere else. And the
`plain` backend forced the question of what a backend does when it has no
behaviour settings at all, which nothing had asked.

**Writing the test for "no backend name in shipped code" was harder than the
rule it enforces.** The first version matched bare words and failed on four
things, none of them real: two doc-comment lines explaining the bug the test
prevents, an `.EXAMPLE` showing a caller how to name a backend, and the word
"plain" in ordinary English. Stripping comments first and matching only quoted
literals and path fragments is what makes it about code. The same lesson landed
again in the node-kind test, where `output` is both a Terraform kind and the
name of this repository's build directory - narrowed to comparisons, because
what breaks a producer is code that ASKS whether something is of a kind.

**Hand-writing the fixture found a real thing the renames missed.**
`New-RenderDocumentPath` took `-ModuleName` and fell back to the file stem
`'module'`: producer vocabulary in a parameter on the public surface, in a
function that builds a path and does not know what it is naming. Nothing in the
rename table caught it because the table listed functions.

**Byte-identity survived every rename, exactly as predicted, and that mattered
more than it sounds.** Sixteen renames across two repositories, each verified
in seconds by rendering one fixture and diffing. It turned "did I miss a call
site" from a review problem into a build problem.

## What I could not verify

The Skeptic's section. It is never empty.

- **That `plain` is a hard enough second backend.** It renders a table. It has
  no layout, no interaction, no theme beyond five colours, and it never asks
  the configuration for anything structural. **A backend that needed real
  layout could still find a hardcode `plain` never touches** - the arrow
  direction table, the zoom floor, the flow registry are all still shaped by
  one implementation's needs and nothing has pulled against them. Opened as
  `0002-t1`.
- **That the golden proves the renames.** It proves the reference backend
  renders one fixture identically. A rename that broke `plain`, or broke a code
  path that fixture does not reach, would not show up there - the rest of the
  suite is what covers that, and it is 94 tests against a module of about 900
  lines.
- **That `infrastructure.json` is what a Terraform producer would emit.** I
  wrote it, and I know what this renderer accepts. A real producer would
  discover fields I did not think to include and would find this file's shape
  convenient in ways that prove nothing. It is a better test than
  `sample-module.json` because no producer made it; it is not the same as a
  second producer existing. Opened as `0002-t2`.
- **That the cycle test tests the cycle.** It asserts both security groups
  appear in the document. `plain` renders a table and would pass that with any
  edge list at all; the assertion that would actually fail on a bad layout is
  that the test terminates, and a test that hangs does not report, it just
  stops. The reference backend's layout runs in the browser and nothing here
  executes it.
- **That the public surface is right at four.** It is four because that is what
  one producer needs. `Get-RenderTemplateSet` is public and arguably should not
  be - nothing outside this module calls it now that `New-RenderDocument`
  exists. Opened as `0002-t3`.
- **That excluding `PSMissingModuleManifestField` for `TemplateSets/` costs
  nothing.** It is the only rule silenced and only for data files, but the
  reasoning is "this rule cannot tell a backend's config from a manifest",
  which is an argument about one rule made while looking at one false positive.
- **That no producer vocabulary is left in code.** Verified by grep for three
  specific words and by two tests that look for backend names and node kinds. A
  fourth kind of producer knowledge - an assumption about what a payload
  contains rather than a word - would pass all of it. `plain` reading
  `DATA.nodes` and `DATA.links` is exactly that, and it is in the one backend
  written to prove the seam. Opened as `0002-t4`.

### Prune, this iteration

A move, and it was scheduled: "Traps that survived the move" to
`docs/development.md` whole, and gravity's reasoning to the charter that was
already the authority on it. 13,659 bytes to 11,301. A deletion proposal: none.

### Always-loaded bytes

**11,301 / 11,301.** Ratcheted down from 13,659. Still above the 10,000
`CLAUDE.md` claims in its own prose; `docs/improvements.md` names what could
follow it down and what must not.

## Open threads

1. **[0002-t1] `plain` is trivial enough to prove less than it looks.** It never
   asks the configuration for anything structural, so a backend needing real
   layout could still hit a hardcode it never touched. The arrow table, the zoom
   floor and the flow registry are all still shaped by one implementation.
2. **[0002-t2] A hand-written fixture is not a second producer.** I wrote
   `infrastructure.json` knowing what this renderer accepts. The shapes it does
   not contain are the shapes I did not think of.
3. **[0002-t3] `Get-RenderTemplateSet` may not belong on the public surface.**
   Nothing outside this module calls it now that `New-RenderDocument` resolves
   the backend itself. Four may still be one too many.
4. **[0002-t4] Producer knowledge can be a shape, not a word.** Every check is
   for vocabulary. `plain` reads `DATA.nodes` and `DATA.links`, which is an
   assumption about the payload that no grep would ever find.

Carried: **[0001-t1]** one fixture, one shape, for the golden; **[0001-t2]** the
golden has never been compared on another machine; **[0001-t5]**
`Get-HashtableValue` exists in both repositories.

Closed: **[0001-t3]** the default backend hardcoded in three places;
**[0001-t4]** a producer escaping and substituting for itself.
