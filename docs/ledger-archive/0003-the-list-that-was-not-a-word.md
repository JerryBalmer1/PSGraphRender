---
id: "0003"
tag: v0.3.0
date: 2026-08-26
prompt_intent: Move a hardcoded list of node kinds out of a backend script and write the check that would have found it, then declare the contract those scripts were assuming and rename the payload fields and JavaScript consts that reach the document - giving up byte-identity and replacing it with something.
personas: [taxonomist, integrator, skeptic]
open_threads: [0003-t1, 0003-t2, 0003-t3, 0003-t4]
closes: [0002-t2]
carries_forward: [0002-t1, 0002-t3, 0002-t4, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0003 — the list that was not a word

## What changed

**`KIND_HEX` is gone.** `bootstrap.js` held
`{ Function, Class, Enum, Script, External }` mapped to hex colours from the
extraction until now — a hardcoded list of one producer's node kinds, the third
item in the charter's forbidden list, sitting in the renderer for two
iterations. It is `KindColor` in `theme.psd1` on a new `ColorMap` schema type.

**Writing the check found the same shape twice more.** `render.js` styled
`edge[kind = "Inherits"]` with a literal colour, `sidebar.js` drew a legend row
for it, and `elements.js` defaulted an unclassified link to `'CommandReference'`.
All three are data now.

**`contract/viewmodel.schema.json` exists**, at 1.0.0 while the module is at
0.3.0. `New-RenderDocument` validates every payload and refuses a major it does
not implement, by name.

**The payload renamed.** `meta.moduleName` → `title`, `moduleVersion` →
`version`, `moduleRoot` → `rootPath`, with the old names still read and warned
about. `data.moduleName`, `data.moduleVersion` and `data.moduleBase` were
removed rather than renamed: nothing had ever read them.

**`GRAPH_DATA` and its three siblings became `DATA`, `META`, `CONFIG`,
`STRINGS`**, matching what `plain` already used.

**Byte-identity was forfeited and replaced.**
`Extraction.Semantic.Tests.ps1` compares the pre-rename document with the new
one through a rename map. The byte comparison is re-recorded and still runs.

## What I learned

**A check written in the language of the last mistake finds only that mistake.**
Every producer-vocabulary check before this one looked for words in PowerShell
source, in function names, in file names. `KIND_HEX` was a JavaScript object
literal whose *keys* were the vocabulary, and it sat in plain sight through two
iterations of looking for exactly this.

**The weak check earned its place on the first run.** A string-matching test
that can only find vocabulary someone happened to put in a fixture is a poor
instrument, and it immediately found three more instances nobody had reported.
The "stronger" test — render a payload of invented classifications and assert
the document is unchanged — passes trivially, because no backend does any
PowerShell-side work with a kind. The weak one is doing the work.

**`External` is not the same problem and nearly got fixed as though it were.**
No producer emits it; the renderer invents it for targets a payload names but
does not contain. Its colour became its own theme value rather than a
`KindColor` entry, because sitting in a map beside four PowerShell kinds is
precisely what made the map read as renderer vocabulary in the first place.

**Two verification instruments were built and thrown away, and both failures
were the same failure.** A JavaScript brace-balance check fired on the
*pre-change* golden, because it cannot parse a regex literal. A positional line
diff reported 78% of lines changed when three keys were removed from a
pretty-printed JSON block, because an insertion shifts everything after it. In
both cases the instrument was measuring its own limitations. What survived
compares parsed objects and line *multisets*.

**The contract caught something on its first day.** A test was passing
`[pscustomobject]@{ label = '...' }` to check escaping — a payload with no
`nodes` at all. It rendered happily for two iterations and the schema refused it
immediately.

**`Resolve-RenderMeta` read `.PSObject.Properties` off an `[ordered]@{}` and got
`Count`, `Keys`, `Values` and `IsReadOnly`.** The render succeeded. The document
embedded all four as `meta`, and nothing failed — the golden was re-recorded
against it before I looked at what I had recorded. Serialising a dictionary as
though it were an object is silent, and the only thing that caught it was
reading the output.

## What I could not verify

The Skeptic's section. It is never empty.

- **That semantic equivalence proves what byte-identity proved.** It does not,
  and cannot. I chose what "the same facts" means — nodes, links, configuration,
  strings, element structure, visible text — so it catches a difference only in
  a dimension I thought to compare. Anything varying outside that list passes.
  Byte-identity had no such gap and no such flexibility, and this is a real loss
  taken deliberately. Opened as `0003-t1`.
- **That the schema is right rather than merely derived.** Every field came from
  a payload that already renders, which is the correct method and a narrow one:
  two fixtures, one of which I wrote knowing what this renderer accepts. A third
  producer will need a field neither has and will discover the schema is a
  description of two examples.
- **That validation happens where it should.** `New-RenderDocument` validates
  once for every backend, which is why `plain` stays naive. But nothing checks
  that what a backend READS is what the contract PROMISES: a backend reading
  `DATA.rows` would render blank against every conforming payload and no test
  would notice. That is the half of `0002-t4` still open. Opened as `0003-t2`.
- **That `KIND_HEX` is the last one.** The check that found it matches
  classifications that appear in a fixture. A producer vocabulary word nobody
  put in a fixture is invisible to it, and so is any assumption that is a shape
  rather than a word — which is how this one survived two iterations of looking.
- **That the JavaScript still parses.** `render.js` was restructured by about a
  hundred lines and nothing in either repository syntax-checks JavaScript. The
  tests assert on the rendered text, not on whether a browser could run it. The
  balance checker that would have said something was discarded for reporting a
  false positive on known-good output. Opened as `0003-t3`.
- **That the deprecated-name fallback works for a real producer.** It is tested
  with a hand-built payload. No producer emits the old names any more, because
  the only producer was updated in the same iteration — so the alias path has
  never been exercised by anything that did not exist to exercise it.
- **That `plain` staying naive was the right call.** The argument is that
  validation at the seam is one place rather than two, and that the contract now
  licenses what `plain` assumes. The counter-argument is that a backend which
  validates would catch a payload the seam let through — and since the seam is
  the only validator, a bug there is a bug everywhere. Opened as `0003-t4`.

### Prune, this iteration

A move: none. A deletion proposal: none. `CLAUDE.md` is unchanged at 11,301
bytes; the prune toward 10,000 stays on the checklist.

### Always-loaded bytes

**11,301 / 11,301.** Unchanged.

## Open threads

1. **[0003-t1] Semantic equivalence only checks the dimensions I listed.** Six
   of them. A change outside all six passes, and the list has no principle
   behind it beyond "what seemed to matter".
2. **[0003-t2] Nothing checks a backend reads only what the contract promises.**
   The schema declares the shape; no test compares a backend's payload accesses
   against it. This is the open half of `0002-t4`.
3. **[0003-t3] Nothing syntax-checks the JavaScript.** A malformed script fails
   only in a browser. The honest answers are a real parser or a headless
   browser, and neither is small.
4. **[0003-t4] Validation at the seam is one place, which cuts both ways.** A
   backend that validated would catch what the seam let through. Today a bug in
   `Test-RenderViewModel` is a bug for every backend at once.

Carried: **[0002-t1]** `plain` never asks configuration for anything structural,
so a backend needing real layout could still find a hardcode it never touched;
**[0002-t3]** `Get-RenderTemplateSet` may not belong on the public surface;
**[0002-t4]** producer knowledge can be a shape rather than a word — half closed
by the contract, half open as `0003-t2`; **[0001-t1]** one fixture, one shape,
for the golden; **[0001-t2]** the golden has never been compared on another
machine; **[0001-t5]** `Get-HashtableValue` exists in both repositories.

Closed: **[0002-t2]** a hand-written fixture is not a second producer — closed
not by getting a second producer but by the schema, which is the thing a second
producer would have needed and which no longer depends on my imagination for its
shape.
