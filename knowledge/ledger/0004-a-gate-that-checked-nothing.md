---
id: "0004"
tag: v0.4.0
date: 2026-08-26
prompt_intent: Make a broken backend visible - syntax-check the JavaScript, check that a backend reads only what the contract promises, and take the headless browser work as far as the CDN decision allows before stopping on it.
personas: [integrator, skeptic]
open_threads: [0004-t1, 0004-t2, 0004-t3, 0004-t4]
closes: [0003-t3]
carries_forward: [0002-t1, 0002-t3, 0003-t1, 0003-t2, 0003-t4, 0001-t1, 0001-t2, 0001-t5]
prune_proposals: []
supersedes: []
---

# 0004 — a gate that checked nothing

## What changed

**Two tasks run `node --check`.** `LintJavaScript` over every `.js` in every
backend; `LintDocument` over the inline `<script>` blocks of a rendered
document, which is the form a browser receives. Neither skips when `node` is
missing. Fourteen scripts and three assembled blocks parse.

**`Requirements.psd1` gained a `Tools` section.** The Node floor is pinned where
the module versions are, `build.ps1` skips it when installing modules, and
`ci.yml` installs a version a pre-tag test asserts is not below the floor.

**`tests/BackendContract.Tests.ps1` compares what a backend reads against what
the contract declares.** It follows a direct alias of `DATA` or `META`, because
the reference backend opens with `var meta = META || {}` and reads
`meta.rootPath` four files later.

**Three of a producer's commands and a producer's module name left the shipped
backend.** `partials/template-notice.html` named `PSModuleGraph`, two of its
commands and one of its source paths; `partials/cdn-guard.html` told the reader
to run a third; two script comments named a fourth.

**`PreTag` no longer reports success against zero tests**, and `CLAUDE.md` is
11,223 bytes with the ceiling ratcheted to match.

**The headless smoke test is not here.** It was built far enough to measure and
then stopped, because finishing it requires the vendoring decision. See below.

## What I learned

**The check that existed passed because it was written in the language of one
known mistake.** `Module.Quality.Tests.ps1` looked for the literal
`PSModuleGraphEditorLink`. Checklist line 211 — "No producer vocabulary
anywhere" — has been ticked since `0.1.0`, and for three iterations a shipped
partial told the reader to run `Get-PSModuleDependencyGraph -Path
./src/PSModuleGraph`. This is `0003`'s lesson about `KIND_HEX` arriving a third
time, and the fix is the same one: look for the SHAPE. Verb-Noun found all four
in one run, and allowing only commands PowerShell itself ships keeps
`Import-PowerShellDataFile` in the Config headers where it is honest.

**A gate can be believed for four tags without ever running.** `./build.ps1
-Task PreTag` printed "Pre-tag gates passed. Safe to tag." while no test in the
repository carried the tag: a filtered Pester run that selects nothing succeeds.
This was found while writing the rule that a lint gate must fail rather than
skip, which is the same failure in a different place, and it was in the task
whose entire job is to be a gate.

**Per-file parsing and assembled parsing are different questions and neither
subsumes the other.** Each of the fourteen scripts parses alone, which does not
establish that the splice does; the assembled check covers only the files a
`templateset.psd1` names, so a script nobody wired up would go unchecked. Both,
or the claim is smaller than it sounds.

**One level of aliasing is the difference between a real check and a vacuous
one.** A scan for `DATA.` and `META.` alone finds six accesses across two
backends. Following `var meta = META || {}` and `var data = DATA` finds the rest
— and the same pass has to reject `el.data.name` in `elements.js`, which is
Cytoscape's element store and appears in the same file as a real `data.metrics`.
Requiring nothing before the alias name separates them.

**Not installing the tool was the wrong instinct and so was installing it
silently.** `-Bootstrap` installs PowerShell modules; it deliberately does not
install Node. A build script that puts a runtime on a developer's machine
without being asked is not a build script, and a gate that skips because the
runtime is absent is not a gate. Failing by name with an install line in the
message is the only option that is both.

**The headless probe answered the question it was built to answer and then
stopped.** Measured in Playwright 1.49.1 against Chromium: `plain` comes alive
with no network at all — 0 external requests, 0 console errors, 17 table rows
for a 17-node payload. `cytoscape` with network reports 17 in the header, 0
console errors and three painted canvases, in about 3.5 seconds. `cytoscape`
without network shows the CDN guard, makes two failed requests and produces two
console errors and no node count — which is the same signature a genuinely
broken script produces. That is the block, and it is the one predicted.

## What I could not verify

The Skeptic's section. It is never empty.

- **That a page that parses is a page that runs.** This is the whole gap and
  `node --check` does not close it. A script can parse perfectly and throw on
  the first line, reference an element that is not in the layout, or leave the
  canvas empty. Everything the suite asserts is still text PowerShell produced.
  The user's own line, adopted: a smoke test that asserts three things means the
  page loaded, not that the foundation layout is correct, that the heat ramp
  ranks properly, or that focus mode does what it claims. Opened as `0004-t1`.
- **That the payload scan finds what it claims to.** It is a regex. `DATA[key]`
  is invisible to it, `node.severity` is one level past where it reaches, and a
  backend that assigns the payload through a function return rather than a `var`
  declaration escapes the alias step entirely. A test records the first of those
  by asserting the scan finds nothing in a computed access, which makes the gap
  executable rather than a comment, and does nothing about the other two.
  Opened as `0004-t2`.
- **That Verb-Noun is the right net for producer commands.** It found four real
  ones. It would miss a producer whose commands are not PowerShell — a Python
  producer's `render_graph()` is a producer command and this check cannot see it
  — and it would fire on English prose that happens to read `Show-Something`.
  The allow-list is "a command PowerShell itself ships", which is a real
  principle rather than a list, and it is still a net with a shape.
- **That `LintDocument` covers what it appears to.** It renders ONE fixture
  through each backend. A slot filled only for a payload with a field this
  fixture lacks assembles differently and is never parsed. The check is over the
  document that one payload produces, not over the template.
- **That the measurements behind the CDN gate generalise.** Three runs on one
  machine, one browser engine, one payload of seventeen nodes. The 3.5 seconds
  is not a CI number, and the offline behaviour is Chromium's `ERR_FAILED`
  rather than a corporate proxy's, which may return a 200 carrying an error page
  and defeat the guard entirely. Opened as `0004-t3`.
- **That Playwright is the right dependency.** It is the one I measured. Nothing
  was measured against Puppeteer, and `plain` needs no browser at all — jsdom
  would run it — so the 509 MB of browser binaries buys exactly one backend.
  Opened as `0004-t4`.
- **That CI is actually green.** Both new tasks and the CI Node step have run on
  one Windows machine. The Ubuntu leg and the Windows PowerShell 5.1 leg have
  never seen them, and 5.1 is where `Test-Json -SchemaFile` is already absent.

### Prune, this iteration

A move: three rules in "Token discipline" said one thing in seven lines and now
say it in five; "Gravity" restated that it was an invariant twice. A deletion
proposal: none.

### Always-loaded bytes

**11,223 / 11,223.** Down from 11,301, having first gone up by 187 for the Node
rule and then been paid for. The ceiling followed.

## Open threads

1. **[0004-t1] Parsing is not running.** Both new gates establish that the
   JavaScript is syntactically valid. Nothing establishes that a browser can
   execute it, and the harness that would is blocked on the vendoring decision.
2. **[0004-t2] The payload scan reaches one level and cannot see a computed
   access.** `DATA[key]` and `node.severity` both pass it.
3. **[0004-t3] The offline measurement is Chromium's failure, not a proxy's.** A
   proxy that returns a 200 carrying a block page would leave `cytoscape`
   undefined the same way, but a proxy that returns a 200 carrying *something
   parseable* would not, and nobody has tried one.
4. **[0004-t4] Playwright was measured; nothing else was.** 509 MB of browser
   binaries serves one of two backends. `plain` would run under jsdom at about
   a fiftieth of the weight.

Carried: **[0003-t1]** semantic equivalence only checks the dimensions I listed;
**[0003-t2]** now narrowed rather than closed — see `0004-t2`; **[0003-t4]**
validation at the seam is one place, which cuts both ways; **[0002-t1]** `plain`
never asks configuration for anything structural; **[0002-t3]**
`Get-RenderTemplateSet` may not belong on the public surface; **[0001-t1]** one
fixture, one shape, for the golden; **[0001-t2]** the golden has never been
compared on another machine; **[0001-t5]** `Get-HashtableValue` exists in both
repositories.

Closed: **[0003-t3]** nothing syntax-checks the JavaScript — closed by
`LintJavaScript` and `LintDocument`, and the thread it becomes (`0004-t1`) is a
smaller one, because "does it parse" and "does it run" were one question before
and are two now.
