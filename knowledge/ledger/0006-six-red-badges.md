---
id: "0006"
tag: v0.6.0
date: 2026-08-27
prompt_intent: Replace the machine-derived canvas threshold with a comparison each run calibrates itself, then make CI run for the first time and report what breaks rather than fixing forward past it.
personas: [integrator, skeptic]
open_threads: [0006-t1, 0006-t2, 0006-t3]
closes: [0005-t2, 0005-t3]
carries_forward: [0005-t1, 0005-t4, 0004-t2, 0004-t3, 0004-t4, 0003-t1, 0003-t2, 0003-t4, 0002-t1, 0002-t3, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0006 — six red badges

## What changed

**`MinScreenshotBytes` became `CanvasGrowth`.** A ratio against the same backend
rendering an empty payload, rendered and measured in the same run on the same
machine, rather than a byte count taken from one laptop. Viewport and
`deviceScaleFactor` are pinned in the Playwright context and echoed into the
report.

**CI ran.** It never had: `shell: ${{ matrix.powershell }}` on a step is not
valid, so **every run since v0.2.0 failed as "workflow file issue" before a
single job started.** Six red badges nobody read, while three ledgers recorded
that CI was wired.

**Five defects, all of which required a second machine to see.** Listed below.

**The browser harness runs on `ubuntu-latest` only**, configured rather than
omitted: the other two legs run `WithoutBrowser`, which runs every other gate
and then prints by name that this one did not.

**The four tags sealed by a pre-tag gate that could not fail were all green.**

## What I learned

**The number that decided this iteration's first half showed up in its second.**
The canvas ratio was replaced because a byte constant belongs to the machine
that measured it. Then Ubuntu ran the same check on the same document and drew
**59,961 bytes where this machine drew 53,971** — an 11% drift, on an assertion
that had been written as a fixed 15,000. The empty render compressed to exactly
4,413 on both, which is what makes the ratio stable while the absolute is not.

**CI failing before it starts is invisible from every direction I looked.** The
run list says `failure`. The jobs API returns an empty array. `gh run view`
says "this run likely failed because of a workflow file issue" and stops. The
logs endpoint returns nothing, because there are no logs. What names the line is
`gh workflow run`, whose 422 body carries the parser error verbatim — a
validation path, reached by trying to *use* the thing rather than to read about
it.

**Five defects, and every one was invisible on the machine that wrote it.**

| What broke | Why it could not be seen here |
| --- | --- |
| `shell:` on a step | the file is only parsed by GitHub |
| `BootstrapBrowser` before `-Bootstrap` | the modules were already installed |
| npm looked for beside node | Unix keeps it a level up under `lib/` |
| `-Include` with `-LiteralPath` | does not filter on 5.1; the scan silently WIDENED there |
| `[System.IO.Path]::GetRelativePath` | .NET Core 2.0 only, absent on 5.1 |

The fourth is the one worth keeping: a check whose *scope* depended on which
PowerShell ran it, reporting `module` out of a comment and `Enum` out of a
schema type. It is the "exclusion that quietly grows" failure arriving through
a runtime difference rather than through an edit.

**A unit test was starting a real process on every tag.**
`Show-RenderDocument` used `Start-Process` on Windows and the call operator on
macOS and Linux, so the mock covered one platform of three. On Ubuntu the suite
ran `xdg-open` for real, printed six "not found" lines looking for a text
browser, and failed. One seam is one thing a test can intercept.

**I fixed the wrong thing first, on a message that pointed nowhere near the
cause.** Pester 6 reports an exception escaping a `BeforeAll` as "a 'break' or
'continue' statement with a label that does not match any enclosing loop escaped
from your code" (pester/pester#2669). There WAS a `continue` in that file. It
was fine. The restructure was reverted once `GetRelativePath` turned out to be
the cause, because a change made for a reason that turned out to be wrong should
not survive on the grounds that it also works.

**The four tags were green, and the vacuous gate was hiding nothing.** Each
checked out in its own worktree and built with the build script that tag
shipped:

| Tag | default task | tests | PreTag selected |
| --- | --- | --- | --- |
| v0.1.0 | GREEN | 47 / 0 | 0 |
| v0.2.0 | GREEN | 94 / 0 | 0 |
| v0.3.0 | GREEN | 98 / 0 | 0 |
| v0.4.0 | GREEN | 107 / 0 | 3 |

The gate was empty at three of the four and unfireable at all four, and nothing
was behind it. Worth knowing, and it is not the same as the gate having worked.

## What I could not verify

The Skeptic's section. It is never empty.

- **That a green CI proves the gates would catch anything there.** It proves
  they execute on three runners. The falsifiability proof — break a script,
  blank the canvas, watch the harness go red — has only ever been run on this
  machine, and "the harness can fail" is a property of a machine until it is
  demonstrated on that machine. The user's own line, adopted. Opened as
  `0006-t1`.
- **That the tag audit says what it appears to.** Four tags were rebuilt with
  TODAY's node, TODAY's Pester 6.1.0 and TODAY's PSScriptAnalyzer, on this
  machine only. It establishes that the code at those tags passes its own gates
  now; it does not establish that it did then, and it says nothing about the two
  CI legs those tags never reached.
- **That the ratio of four is right.** It is a number chosen to have daylight
  around two measurements, 12.2 and 13.6. Nothing has been rendered that is
  legitimately sparse — a two-node payload might draw little enough to fall
  under it, and the failure would read as "the view is blank" when it was
  correct. Opened as `0006-t2`.
- **That the empty render is a floor rather than a coincidence.** It compressed
  to 4,413 bytes on both machines, which is reassuring and is also two samples.
  A backend whose empty state draws a grid, a watermark or an axis would have a
  floor close to its drawn state and the ratio would quietly stop discriminating.
- **That the Windows PowerShell 5.1 leg is now trustworthy rather than merely
  passing.** Two of the five defects were 5.1-only and were found in the first
  two runs it ever completed. That rate suggests more, not fewer: this leg has
  now run four times in total and every earlier tag was sealed without it.
  Opened as `0006-t3`.
- **That the browser cache works.** Three runs missed it and the fourth was the
  first that could have populated it. Nobody has seen a cache hit.
- **That one browser leg is enough.** The argument is that the page does not
  vary by which PowerShell produced it, and the page is produced by PowerShell,
  so the argument is doing real work rather than none. It would fail if a
  PowerShell difference ever reached the document — which is exactly what the
  contract, the escaping and the config resolvers are supposed to prevent, and
  what nothing compares across legs.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**11,223 / 11,223.** Unchanged.

## Open threads

1. **[0006-t1] The harness has been proved able to fail on one machine.** A
   green CI says the gates execute there. Nothing has broken a script in CI and
   watched it go red.
2. **[0006-t2] The growth ratio has never met a legitimately sparse payload.**
   Four, against measurements of 12.2 and 13.6, with nothing rendered between.
3. **[0006-t3] Two of five defects were 5.1-only, on a leg that has run four
   times.** The rate is the finding. Every tag before v0.6.0 was sealed without
   that leg ever executing.

Carried: **[0005-t1]** the harness says the page loaded, not that it is right;
**[0005-t4]** a vendored file names a `.map` that is not vendored; **[0004-t2]**
the payload scan reaches one level and cannot see a computed access;
**[0004-t3]** the proxy case is still unmeasured — a 200 carrying a block page
is not `ERR_FAILED`, and vendoring makes it moot for the libraries while leaving
it unmeasured for anything else; **[0004-t4]** Playwright is still the only
harness measured, and `plain` would run under jsdom at a fiftieth of the weight;
**[0003-t1]** semantic equivalence only checks the dimensions I listed;
**[0003-t2]** narrowed, not closed; **[0003-t4]** validation at the seam is one
place, which cuts both ways; **[0002-t1]** `plain` never asks configuration for
anything structural; **[0002-t3]** `Get-RenderTemplateSet` may not belong on the
public surface; **[0001-t1]** one fixture, one shape, for the golden;
**[0001-t2]** the golden has never been compared on another machine — closed in
substance by CI, kept open because nothing compares the DOCUMENT across legs;
**[0001-t5]** `Get-HashtableValue` exists in both repositories.

Closed: **[0005-t2]** the blank-canvas threshold was one measurement on one
machine — closed by making it a comparison the run performs; the drift it
predicted turned out to be 11% between two machines. **[0005-t3]** nothing had
run these gates outside this machine — closed by three legs, and by five defects
that only a second machine could show.
