# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**The view model contract is versioned separately from the module.** It is at
**1.1.0**, it lives in `contract/viewmodel.schema.json`, and its version travels
in every payload's `meta.contractVersion`. A module release does not imply a
contract release, or the reverse.

**This file was written at v0.9.0, from the annotated tags and the ledger.**
Everything before that date is reconstructed: the entries below say what each
release changed, and they were derived rather than recorded at the time. For why
a change was made, and for what could not be verified about it,
`knowledge/ledger/` is the primary source and this is a reader's index to it.

## [Unreleased]

## [0.9.0] - 2026-08-27

### Added

- **A sample gallery you can look at.** `./build.ps1 -Task Samples` renders
  every payload under `tests/fixtures/viewmodels/` through every backend in
  `TemplateSets/`, plus a generated `index.html` listing node counts, link
  counts and which backend produced each. `-ExtraPayload` renders a payload too
  large to commit. The pages are not committed; screenshots are, under
  `docs/samples/`.
- **`tests/LedgerPrune.Tests.ps1`**, a pre-tag gate. A deferred deletion
  proposal that a second iteration neither applies nor rejects now blocks the
  annotated tag by name. `instruction-prune` had claimed this enforcement since
  v0.3.0 and it had never existed here.

### Changed

- **The five skills in `.claude/skills/` are a fork, not a copy.** They were
  byte-identical to `PSModuleGraph`'s and made five claims that were false in
  this repository. Each is now true to this one. See the skills `README.md` for
  the argument against a sync check.

*Ledger `0010`.*

## [0.8.1] - 2026-08-27

### Added

- **`.claude/skills/gate-falsifiability/`.** Break the gate deliberately,
  confirm red, restore, and record the break and the message in the ledger —
  written down after being reconstructed from scratch four times.
- A fifth question in the improvement loop: did I follow a procedure I have
  followed before, and is it written down?

### Changed

- **`## Open decisions` moved from `CLAUDE.md` to `docs/improvements.md`** to
  pay for that question. The always-loaded tier went 11,223 → 10,644 bytes and
  the ceiling ratcheted to match.

*Ledger `0009`.*

## [0.8.0] - 2026-08-27

### Added

- **A README.** It was one line. The first paragraph now says that the producer
  may be written in any language and that the contract is
  `contract/viewmodel.schema.json`.
- **`-Task Samples` and `tools/shoot.cjs`**, with eight committed screenshots
  under `docs/samples/`.

*Ledger `0008` records what opening the pages actually showed, including the
parts that do not work.*

## [0.7.0] - 2026-08-27

### Added

- **Contract 1.1.0: `links[].resolution`**, optional. A string the producer
  picks to say how confidently it tied an edge to its target. **Absent means
  NOT STATED**, which is a different fact from any value it could carry, and the
  renderer treats it that way.
- **`StyleMap`, a setting type.** An arbitrary key to a small style descriptor,
  validated on its property names and never on its keys — so the renderer never
  learns what a resolution value means. `theme.psd1` carries the map.
- **The Details panel counts uncertain links** touching the selection, when the
  payload says anything about resolution.
- **`tests/fixtures/viewmodels/ambiguous.json`**, a fixture that is not
  PowerShell.

*Ledger `0007`.*

## [0.6.0] - 2026-08-27

### Fixed

- **CI ran for the first time.** `shell: ${{ matrix.powershell }}` on a step is
  not valid, so every run since v0.2.0 had failed as a workflow-file issue
  before a single job started — six red badges while three ledger entries
  recorded that CI was wired.
- Four more defects that needed a second machine to see: the browser bootstrap
  ordering, where npm lives on Unix, `-Include` with `-LiteralPath` silently
  widening a scan on PowerShell 5.1, and `[System.IO.Path]::GetRelativePath`
  being absent there.
- A unit test was starting a real browser process on non-Windows platforms.

### Changed

- **`MinScreenshotBytes` became `CanvasGrowth`**, a ratio against the same
  backend's empty render rather than a byte constant measured on one machine.
  Ubuntu drew 59,961 bytes where this machine drew 53,971.

*Ledger `0006`.*

## [0.5.0] - 2026-08-26

### Added

- **The libraries are inside the report.** `cytoscape@3.34.2` and
  `cytoscape-dagre@4.0.0` are vendored under the backend and inlined into the
  document. Measured headless with `http` and `https` blocked: zero external
  requests, zero console errors. A report goes from 126 KB to 607 KB.
- **`vendor/vendor.psd1`** records source URL, version, licence and the SRI hash
  each file was verified against; `tests/Vendor.Tests.ps1` recomputes them.
- **`TestBrowser`** runs the page in headless Chromium with the network blocked.
  What "alive" means is declared per backend in `templateset.psd1`.

### Removed

- `partials/cdn-guard.html`. The half of its message that can still be true
  moved into `bootstrap.js`, where its text is data.

### Fixed

- **The pre-tag zero-test guard now fires.** It could not before: `TotalCount`
  counts tests *discovered*, so a filter matching nothing reported 123
  discovered, 123 not run, and the guard passed. Four tags were sealed by it.

*Ledger `0005`.*

## [0.4.0] - 2026-08-26

### Added

- **`LintJavaScript` and `LintDocument`**, both running `node --check` — over
  every backend script, and over the inline `<script>` blocks of a rendered
  document. Neither skips when `node` is missing; both fail by name.
- **`Requirements.psd1` gained a `Tools` section**, pinning the Node floor where
  the module pins live, with a pre-tag test asserting CI does not go below it.
- **`tests/BackendContract.Tests.ps1`** compares what a backend reads against
  what the contract declares.

### Fixed

- **A producer's name and three of its commands left the shipped backend.** The
  existing check looked for one literal string; looking for the *shape* —
  Verb-Noun — found all four in one run.

*Ledger `0004`.*

## [0.3.0] - 2026-08-26

### Added

- **`contract/viewmodel.schema.json` at 1.0.0**, versioned independently of the
  module. Every entry point validates against it.

### Changed

- **`KIND_HEX` is gone**, and so are the two more instances that writing the
  check against it found. A hardcoded list of node kinds in a script is the
  taxonomy moved into code.
- **The payload renamed**: `meta.moduleName` → `title`, `moduleVersion` →
  `version`. `GRAPH_DATA` and its three siblings became `DATA`, `META`, `CONFIG`
  and `STRINGS`.
- **Byte-identity with the pre-extraction golden was forfeited and replaced**
  with a semantic comparison. It could not survive a deliberate rename.

*Ledger `0003`.*

## [0.2.0] - 2026-08-26

### Added

- **`New-RenderDocument`.** One call takes a view model, a meta block and a
  template set name, and returns a document.
- **`TemplateSets/plain`**, a static HTML table with no library and no canvas —
  a second backend, added to prove the first two were a seam rather than a
  description of one.
- **`tests/fixtures/viewmodels/infrastructure.json`**, hand-written and about
  hosts and services rather than about any module.

### Changed

- **A backend's location is stated once.** `Resolve-RenderTemplateSetPath` is
  the seam.
- **Everything renamed** — five public functions, three private helpers, two
  asset directories — under a golden that had to stay byte-identical throughout.

*Ledger `0002`.*

## [0.1.0] - 2026-08-26

### Added

- **The renderer lives here.** Fourteen `.ps1` files and the whole template set
  moved out of `PSModuleGraph`, with a golden recorded from a detached worktree
  of the commit before the move proving the document was byte-for-byte
  unchanged.
- `build.ps1`, the task graph, and the test suite came first, deliberately.
- `PSModuleGraph` declares `RequiredModules` and calls across the boundary.

*Ledger `0001`.*
