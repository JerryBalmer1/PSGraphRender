---
id: "0005"
tag: v0.5.0
date: 2026-08-26
prompt_intent: Vendor the graph libraries under the backend with recorded provenance, scope the source scans away from them, and land the headless harness that vendoring makes unambiguous - proving it can fail before trusting it.
personas: [integrator, skeptic]
open_threads: [0005-t1, 0005-t2, 0005-t3, 0005-t4]
closes: [0004-t1]
carries_forward: [0004-t2, 0004-t3, 0004-t4, 0003-t1, 0003-t2, 0003-t4, 0002-t1, 0002-t3, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0005 — a report that needs nothing

## What changed

**The libraries are inside the report.** `cytoscape@3.34.2` and
`cytoscape-dagre@4.0.0` live in `TemplateSets/cytoscape/vendor/`, are named in
`templateset.psd1` like any other asset, and are inlined into the document. A
report goes from 126 KB to 607 KB. Measured headless with `http` and `https`
blocked: **zero external requests, zero console errors, seventeen nodes.**

**`vendor/vendor.psd1` records provenance** — source URL, version, licence and
the SRI hash each file was verified against, which are the same hashes the
`<script integrity=...>` attributes carried. `tests/Vendor.Tests.ps1` recomputes
every hash on every run.

**`partials/cdn-guard.html` is gone.** The half of its message that can still be
true — the library did not load, and here is why, rather than a blank page —
moved into `bootstrap.js` where `STRINGS` is substituted, so its text is data.

**Four source scans skip `vendor/`.** The rule is one path segment named exactly
that, in `Test-VendorPath`, and a test asserts what is skipped equals what the
manifests declare.

**`TestBrowser` runs the page.** Headless Chromium, network blocked, both
backends, both fixtures, four cases in about six seconds. What "alive" means is
declared per backend in `templateset.psd1` under `Smoke`.

**The pre-tag zero-test guard now fires.** It did not before; see below.

## What I learned

**The guard added in `0004` could not fire, and only writing the test that was
asked for found it.** `TotalCount` counts tests DISCOVERED, and discovery walks
the whole `tests/` path before the tag filter applies — so with the filter set
to a tag nothing carries it reported **123 discovered, 123 not run**, and the
guard sailed past. `PassedCount + FailedCount` is the number that means
something ran. Reporting "I found it" is not the same as "it is closed", and the
distance between the two was a whole iteration.

**Proving a harness can fail is a different act from watching it pass, and it
found the calibration.** Three deliberate breaks, each restored:

| Break | `node --check` | `TestBrowser` |
| --- | --- | --- |
| `thisFunctionDoesNotExist()` in `bootstrap.js` | **14 scripts parse** | red: *expected 17, found 0*, on both cytoscape cases; both `plain` cases stayed green |
| `elements: []` in `render.js` | passes | red: *`#cy` rendered 4413 bytes of PNG, below the 15000 a drawn view produces* |
| `Filter.Tag` set to a tag nothing carries | n/a | `PreTag` red: *123 discovered, 123 not run* |

The first is the one that matters: a runtime error parses perfectly, so the
gate shipped in `0004` says everything is fine about a page that is dead. The
second only failed because a canvas cannot be read from the DOM.

**A canvas defeats every DOM assertion, and a screenshot does not.** Cytoscape
draws into `<canvas>`; the element count, its dimensions and the header counts
are all identical whether seventeen nodes were drawn or none. A PNG of a flat
colour is small: **53,971 bytes drawn against 4,413 blank**, and the deliberate
break landed on 4,413 exactly, which is the calibration confirming itself.

**`window.cy` was the `<div id="cy">`, not the graph.** Browsers expose elements
with an `id` as globals, so `typeof cy !== 'undefined'` was true, `cy.nodes` was
undefined, and an assertion written on it would have been a test that could
never pass rather than one that could never fail. Worth more than it sounds: the
first probe reported `cyNodes: null` alongside correct counts and read as a
timing problem.

**Two backslashes were eaten in one iteration, in the same way, and one of them
would have disabled the whole exclusion.** `'[\\/]'` written through a tool that
strips a level becomes `'[\/]'`, which is a regex class meaning *slash only* —
so on Windows nothing splits and `vendor` is never found in a path. The other
turned `\b` into a literal backspace character inside a test's regex. Both are
invisible in a diff. The exclusion now splits on `[char]92, [char]47`.

**`npm` could not be invoked as `npm`.** The Windows shim reported
`Unknown command: "pm"`. Running `npm-cli.js` under `node` is the same program
without the wrapper, and it is what the bootstrap does.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the harness tests anything more than "it loaded".** It asserts no
  console errors, counts matching the payload, and something drawn. It says
  nothing about whether the foundation layout is correct, whether the heat ramp
  ranks properly, or whether focus mode does what it claims — the user's own
  line, and it stands. This iteration makes those writable; it does not write
  them. Opened as `0005-t1`.
- **That a PNG byte count means what I say it means.** 15,000 sits between two
  measurements taken on one machine, one viewport, one browser build, at one
  device pixel ratio. A different font, a smaller viewport or a payload of two
  nodes could all land under it, and the failure would read as "the view is
  blank" when it was not. Opened as `0005-t2`.
- **That the vendored files are what upstream shipped.** They match the SRI
  hashes that were already in the layout, which were themselves recorded when
  somebody fetched the files. That is a chain to an earlier fetch, not to the
  publisher — if the original hashes were taken from a compromised download,
  this iteration has faithfully preserved it. Nothing here checks a signature.
- **That the exclusion is right rather than merely bounded.** It is asserted to
  equal what the manifests declare, which is a strong statement about the
  *rule*. It says nothing about whether skipping vendored code is correct: a
  producer name genuinely embedded in a vendored file would now be invisible,
  and that is the trade taken.
- **That CI works.** Every gate here has run on one Windows machine. The Ubuntu
  leg has never installed Chromium with `--with-deps`, the Windows PowerShell
  5.1 leg has never run the harness at all, and the browser cache key is
  untested. Three CI legs now install half a gigabyte of browser and none of
  them has done it once. Opened as `0005-t3`.
- **That inlining 481 KB into the document is free of side effects.** The
  substitution is `[string]::Replace` so `$` and `\` survive, and no slot token
  appears anywhere in either library — checked, not assumed. But
  `cytoscape-dagre.min.js` ends with a `sourceMappingURL` naming a `.map` file
  that is not vendored; it is relative and only fetched with developer tools
  open, and stripping it would invalidate the hash. Opened as `0005-t4`.
- **That a proxy behaves like Chromium's `ERR_FAILED`.** Still unmeasured, and
  carried from `0004`. Vendoring makes it moot for the libraries and leaves it
  unmeasured for anything else a page might ever fetch.

### Prune, this iteration

A move: none. A deletion proposal: `partials/cdn-guard.html`, deleted rather
than moved — everything in it was about a network the report no longer uses,
except one sentence, which became two string keys.

### Always-loaded bytes

**11,223 / 11,223.** Unchanged.

## Open threads

1. **[0005-t1] The harness asserts that the page loaded, not that it is right.**
   Three facts per case. Layout correctness, metric ranking and focus behaviour
   are all still unverified, and are now writable for the first time.
2. **[0005-t2] The blank-canvas threshold is one measurement on one machine.**
   15,000 bytes of PNG between 53,971 and 4,413. A different viewport, font or
   a very small payload could cross it and report a drawn view as blank.
3. **[0005-t3] Nothing has run these gates outside this machine.** Three CI legs
   now install Chromium; none has done so once, and the 5.1 leg has never run
   the harness.
4. **[0005-t4] A vendored file names a resource that is not vendored.**
   `cytoscape-dagre.min.js` carries a `sourceMappingURL`. Harmless and
   unfetched in normal use, and the page's claim to need nothing is one
   developer-tools session away from being tested.

Carried: **[0004-t2]** the payload scan reaches one level and cannot see a
computed access; **[0004-t3]** the offline measurement is Chromium's failure,
not a proxy's; **[0004-t4]** Playwright was measured and nothing else was;
**[0003-t1]** semantic equivalence only checks the dimensions I listed;
**[0003-t2]** narrowed, not closed; **[0003-t4]** validation at the seam is one
place, which cuts both ways; **[0002-t1]** `plain` never asks configuration for
anything structural; **[0002-t3]** `Get-RenderTemplateSet` may not belong on the
public surface; **[0001-t1]** one fixture, one shape, for the golden;
**[0001-t2]** the golden has never been compared on another machine;
**[0001-t5]** `Get-HashtableValue` exists in both repositories.

Closed: **[0004-t1]** parsing is not running — closed by `TestBrowser`, which
runs it. What replaces it is smaller and honest: the page runs, and nobody has
checked that what it draws is correct.
