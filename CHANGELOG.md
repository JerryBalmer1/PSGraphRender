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
`docs/ledger-archive/` is the primary source and this is a reader's index to it.
Those entries were written under a resident workflow that was removed at
v0.13.0; they are a record, not a process.

## [Unreleased]

## [0.16.0] - 2026-09-04

The 3D backend grows a look, an options surface and a labelled catalogue.
**MINOR**: new setting types are added — twenty-six of them — and a new build
task, both of which this repository's own rule (`docs/HANDOFF.md`) calls minor.
No contract change, no `.ps1` under `src/` edited, and `cytoscape`, `plain` and
`index.psd1` byte-identical to v0.15.1.

### Added

- **Shape per classification.** `KindShape` maps a producer's classifications to
  geometry, with `NodeShapeFallback` for the ones it does not name and
  `UnresolvedShape` for an item the renderer invented. Eight shapes:
  sphere, box, octahedron, tetrahedron, icosahedron, cone, cylinder, torus.
- **Size by metric.** `NodeSizeMetric` and `NodeSizeMetricMax` scale an item by
  rank over distinct values of any metric the payload carries. Empty by default:
  the renderer does not know what a producer's metrics mean.
- **`isExported` and `links[].resolution` are drawn.** Two fields the viewmodel
  has always carried and nothing rendered. `ExportedEmphasis` picks a channel;
  `LinkResolutionColor` colours a link by the producer's own word for its
  confidence, and only `Ambiguous` by default — it is the one value that means
  *the producer was not sure*.
- **Glow, depth and environment.** `GlowStrength`, `GlowSize`, `GlowOpacity`,
  `FogDensity`, `FogColor`, `BackgroundStyle`, `BackgroundGlowColor`,
  `ToneMappingExposure`.
- **Link particles.** `ParticleCount`, `ParticleSpeed`, `ParticleWidth`,
  `ParticleColor` — the one thing on the page that says which way a link points
  without a reader chasing an arrowhead around a rotation.
- **Interaction as configuration.** `ZoomSpeed`, `RotateSpeed`, `HoverMode`,
  `HoverTooltip`, `NodeActionButton`, `ShowLabels`, `LabelMaxNodes`.
- **`./build.ps1 -Task TestLook`** and `tests/browser/look.cjs`, a third browser
  gate, driven by a **`LookProbe`** block each backend declares for itself
  beside `Smoke` and `LinkProbe`. It exists because neither of the other two can
  see a look: both are satisfied by a page that draws every item as the same
  blue ball, which is what this backend did while both were green.
- **`examples/threed/catalog.html`** — nineteen labelled variants in five
  families, generated from `examples/threed/variants.psd1` by
  `examples/Build-Examples.ps1 -Variant all`. `A0` is the default and is
  asserted byte-identical to a no-overlay render. The page is never hand-written.

### Changed

- **The canvas-growth floor moves 2 → 2.25**, re-measured over three runs
  because this view is no longer still after it settles — particles move the
  drawn byte count by about 5%. Every ratio went up (thinnest 4.03, was 3.50),
  so the floor was raised to keep the same 1.8× of daylight the manifest
  argued for rather than inheriting a number that no longer tracked the drawing.
- **`LinkProbe.Button` follows `NodeActionButton`.** The page binds one handler
  rather than both, so a probe pressing the other button opens nothing — which
  is the correct failure, and better than a gate that stays green while the
  shipped document listens elsewhere.
- **`examples/threed/forcegraph3d.html` and its screenshot** regenerate under
  the new default. Every other example is byte-identical.

### Fixed

- **Hover highlighting reported nothing while visibly highlighting.** The
  tooltip published the hover state again, with no set, and landed after the
  handler that computed one. Found by the new browser gate on its first run; a
  DOM-only check would have gone green over it.

### Notes

- **There is no post-processing bloom and there will not be one.**
  `UnrealBloomPass` and `ShaderPass` are absent from `3d-force-graph@1.80.0`,
  verified by inspection of the bytes; the composer it exposes holds only a
  render pass. Adding one means vendoring **a second copy of three.js**, which
  is what that bundle's own *"Multiple instances of Three.js being imported"*
  warning exists to report. The glow is geometry instead — an emissive core in
  an additively-blended back-face shell. **No file was vendored in this
  release.** `docs/vendoring.md` records the whole capability inspection.
- **`BackgroundStyle` ships `flat`, which is not the prettier answer.** A
  gradient is in the canvas-growth floor's picture of an *empty* render as well
  as a drawn one, so it does not move that ratio, it removes it: 3.79 → 1.05,
  and a gradient two steps per channel from flat still scored 1.14. The
  environment is `B1` and `B2` in the catalogue, and `Config/theme.psd1` carries
  the measurement so promoting it later is a decision rather than an
  inheritance.
- **`KindShape` is a `String` and should be a `ShapeMap`.** Adding a schema type
  needs a validator under `src/`, and a backend is a directory. Logged in
  `docs/improvements.md` as a proposal rather than absorbed by a `.ps1` edit.


## [0.15.1] - 2026-09-04

The link probe becomes backend data, and the duplicate turned out to have three
copies rather than two.

### Changed

- **`LinkProbe` in each backend's `templateset.psd1`, beside `Smoke`.** Where a
  browser clicks to reach a node's actions is now declared by the backend that
  has those actions, and `./build.ps1 -Task TestLinkMode` reads it off the
  manifest it already imports. The `$LINK_PROBE` map in the build task is gone.
  It was **a second place a backend's shape was written down**, which is exactly
  what the `Smoke` block exists to prevent, and it was logged rather than fixed
  at v0.15.0 because pass 0049's no-regression control was that `cytoscape` did
  not move at all.
- **`tests/browser/link-mode.cjs` names no backend selector.** Its `DEFAULTS`
  object held cytoscape's canvas, menu, ready selector and mouse button, so any
  backend whose job omitted a field was driven against cytoscape's shape — a
  **third** copy the backlog entry had not counted, found by deriving the check
  from the manifests instead of from the entry. `Canvas`, `Menu`, `Button` and
  `Ready` are required and missing fails by name. `Open` still falls back to
  `Menu` and `Hover` to no wait, and neither of those names anything.
- **The throw-by-name guard, inverted.** It fired for a backend absent from the
  map; it fires for a manifest declaring link modes and no `LinkProbe`, naming
  the manifest and the missing key, before a browser starts.

### Added

- **`tests/LinkProbe.Tests.ps1`.** Every backend declaring
  `SlotsBySetting.LinkMode` declares a usable `LinkProbe`; no probe map in the
  build task; no declared selector in the harness, **derived from the manifests**
  so a fourth backend is covered the day it is declared; and the block is
  invisible to assembly, asserted by rendering with it stripped and carrying its
  own red-capability in a `Slots` edit that does move the document.

**No rendered byte moved.** `LinkProbe` is a top-level key and
`Get-RenderTemplateSet` reads `Layout`, `Slots` and `SlotsBySetting` only. All
three backends render byte-identically to v0.15.0, the editor-mode byte gate in
`tests/LinkMode.Tests.ps1` is untouched, and the ten `TestLinkMode` cases are the
same ten with the same results.

*Ledger `0050`.*
## [0.15.0] - 2026-09-04

A third rendering backend, and the seam held.

### Added

- **`forcegraph3d`, a template set that draws in three dimensions.** It reads
  contract 1.1.0 unchanged, and **no `.ps1` under `src/` was edited to add it** —
  which is the claim `plain` could only half support, because `plain` renders a
  table and could not have inherited a Cytoscape assumption. This one has a
  library, a canvas, its own vendoring question and all three link modes.
  `cytoscape` remains the default; `TemplateSets/index.psd1` is untouched and so
  are both existing backends, asserted byte-for-byte by
  `tests/ForceGraph.Tests.ps1`.
- **No contract change, and the question was asked before any code was
  written.** Whether the library *requires* positional input or *computes* it
  was established from the vendored bundle: the simulation consults `fx`/`fy`/
  `fz` when a node states one and computes a position from a spherical lattice
  when it does not. Consuming coordinates is a capability it offers, not an
  input it demands, so the open decision about backends declaring required
  contract fields stays open and untouched.
- **All three link modes, with token parity asserted rather than intended.**
  `LinkMode` and `LinkHrefTemplate` are declared in this backend's own schema
  with the same enum and the same `editor` default. The five tokens are checked
  against the reference backend's own resolver rather than a list retyped in a
  test, so a token that arrives in one backend and not the other is red.
- **`3d-force-graph` 1.80.0, vendored, MIT.** One file: three.js is inside it,
  verified by inspection of the built bundle rather than assumed from the
  package's dependency list. It ends with no `sourceMappingURL`, so this backend
  does not inherit the accepted limitation `0005-t4` carries for
  `cytoscape-dagre`.
- **An eighth example**, and the first that varies the backend rather than a
  setting: the same payload the three layout rows use, drawn by `forcegraph3d`
  with the live GitHub link template. `examples/Build-Examples.ps1` takes the
  backend as a field per row, defaulting to `cytoscape`.

### Changed

- **`./build.ps1 -Task TestLinkMode` runs its five behaviours against every
  backend that declares link modes**, discovered from the manifests rather than
  named. `tests/browser/link-mode.cjs` takes its selectors from the job and
  separates what OPENED from where the actions ARE — without that split, correct
  `none` behaviour is indistinguishable from a click that landed on nothing.
  Defaults are what the file always used, so `cytoscape` is driven exactly as
  before and stayed green throughout.
- **`STRINGS` joined the byte gate.** `tests/LinkMode.Tests.ps1` asserts that an
  `editor`-mode document is byte-identical to the base commit's for the same
  payload, and `Get-DocumentCode` removed the whole `STRINGS` block before that
  comparison — acceptance B's carve-out for `vscode://` prose is exactly that
  block, and one helper served both. Every user-visible string in the renderer
  was therefore invisible to the strongest gate here: v0.14.0 added three
  strings and proved them additive by reading the diff, which is the thing the
  gate exists to replace. `STRINGS` is now compared the way `CONFIG` already
  was — an existing key may not change value, only additions are permitted, and
  the three added keys are pinned by value as well as by name. `Get-DocumentCode`
  is unchanged; widening it would turn acceptance B red against correct work.
  Tests only. Nothing a consumer installs changed.

*Ledger `0049` and `0048` in the AI.Agent.Claude.PowerShellModuleBuilder harness.*

## [0.14.0] - 2026-09-04

Link mode. A node link is configuration now, not a hardcoded scheme.

### Added

- **`LinkMode`**, an Enum setting of `editor`, `hrefTemplate` and `none`,
  defaulting to `editor`, with **`LinkHrefTemplate`** beside it. Declared as
  data in `Config/settings.schema.psd1` like every other setting: no new
  validator type was needed, because `Enum` and `String` were already there.
  `hrefTemplate` resolves `{relativePath}`, `{path}`, `{id}`, `{label}` and
  `{line}` — every one a field the view model already carries, so the contract
  did not move. Closes the **large** item logged in `docs/improvements.md` and
  the backlog entry pass 0043 filed, which wanted forge links for a report
  attached to a pull request and could not have them.
- **`SlotsBySetting` in `templateset.psd1`**, which is how the mode is chosen.
  A setting's value selects which files fill a slot, so the mode is resolved
  when the document is **assembled** rather than by a branch in the browser. A
  report is one self-contained file that gets forwarded, so `none` has to mean
  the scheme construction is not in the document — not that something declines
  to call it. A backend declaring no `SlotsBySetting`, such as `plain`, is
  unaffected.
- **`./build.ps1 -Task TestLinkMode`** and `tests/browser/link-mode.cjs`. It
  opens each mode in Chromium, right-clicks a node and reads the href off the
  menu the registry built. Separate from `TestBrowser`, which asks whether a
  page came alive; this asks whether its links are the ones configured. It
  drives the UI rather than reaching into the page, because a hook for tooling
  would be a global in every shipped report.
- **`tests/LinkMode.Tests.ps1`**, including a no-regression control that builds
  a fresh clone at the previous release and asserts an `editor`-mode document
  is byte-identical to it for the same payload.
- **`examples/links/forge-links.html`**, a seventh example: the same payload
  and layout as `editor-links.html` with one setting different, and links that
  work from a committed file. `hrefTemplate` never reads `meta.rootPath`, so
  the placeholder that keeps a machine path out of the committed artifact stays
  exactly where it was.
- **`menuAt` in `tools/shoot.cjs`**, a real right-click, so both link examples
  now show the open context menu instead of a graph that says nothing about
  links.
- **`FragmentSlots` in `templateset.psd1`**, read by `LintJavaScript`. The
  link-mode action parts are runs of array elements and do not parse alone;
  they are wrapped in the shape their manifest names before `node --check` sees
  them. Declared by slot rather than by listing paths, so a fourth mode's parts
  arrive checked.

### Changed

- **`Get-RenderTemplateSet` takes `-Configuration`**, and `New-RenderDocument`
  resolves the settings before assembling rather than after. Some slots depend
  on a setting's value, so the configuration has to exist first. Omitting it
  still works and resolves from the template-set path.
- **`scripts/editor-link.js` split into `scripts/link/`**, one file per mode
  plus the shared `common.js`. The two editor menu entries, the selection
  action and the diagnostics row became slots filled at the positions they
  already occupied — the byte-identity control above is why the code could not
  simply move.
- **`Module.Quality.Tests.ps1` walks `SlotsBySetting`** as well as `Slots`, so
  files reachable only through a setting's value are still asserted to ship.

### Fixed

- **`{relativePath}` escaped its own separators.** `encodeURIComponent` over a
  whole path yields `src%2FPublic%2FWidget.ps1`, which is right for a query
  value and wrong for the one thing that token exists for: a forge URL of the
  shape `/blob/main/{relativePath}` resolves to nothing with `%2F` in it. Each
  token now escapes for its own shape — a path by segment, everything else
  whole. Found by the browser probe before the feature shipped, on the example
  this release adds.

## [0.13.0] - 2026-08-29

The handoff. This repository no longer operates itself.

### Added

- **`tools/Update-Vendor.ps1`**, the tool the vendor manifests always described
  in prose. `-Verify` re-hashes every file a manifest lists and names every one
  that disagrees, not the first; `-Update [-Name] [-PinVersion]` fetches to a
  temporary file, hashes *that*, and only then replaces the file and rewrites
  the entry's `Version`, `Url` and `Integrity` together. It refuses a failed
  download, and refuses a `-PinVersion` whose bytes hash to the value already
  recorded — writing a new version number over unchanged bytes would make the
  manifest lie. It rewrites the manifest textually, three lines inside the
  matched entry, because a round trip through `Import-PowerShellDataFile` would
  delete the comment header that is most of that file's value. `-WhatIf` is
  honoured, an entry `Name` containing a path separator is refused, and the
  file on disk is re-hashed after the copy before the manifest is allowed to
  claim its hash.
- **`docs/vendoring.md`** — provenance for both cytoscape libraries, why they
  are vendored rather than linked, what `tests/Vendor.Tests.ps1` guarantees, the
  `sourceMappingURL` caveat, and the three places a new template set has to
  register a vendored file.
- **`docs/HANDOFF.md`** — the entry point. What this is, the contract and its
  change protocol, the boundaries, the version ledger, how the repository is
  operated now, and the seventeen threads that were open when the ledger was
  archived.
- **`handoff-begin-2026-08-29`**, an annotated tag on v0.12.0's commit. It marks
  the boundary: everything before it was operated by the in-repo thread-ledger
  process, everything after is operated plan-by-plan from the harness project.

### Removed

- **`CLAUDE.md`, `.claude/`, `docs/threads.json`, `tools/threads.ps1`,
  `tests/Ledger.Tests.ps1` and `tests/Instructions.Tests.ps1`.** The resident
  agentic workflow. The suite goes 127 to 122 passing and 15 to 9 not-run,
  which is exactly `Instructions.Tests.ps1`'s five tests and `Ledger.Tests.ps1`'s
  six `PreTag` tests, and nothing else. No assertion about the renderer changed.

### Changed

- **`knowledge/ledger/` is now `docs/ledger-archive/`**, moved with `git mv` so
  its history follows. Thirteen post-mortems, plus a README saying they are a
  record and not a live process.
- **`ModuleVersion` corrected from `0.11.0` to `0.13.0`.** It was bumped for
  every tag through v0.11.0 and missed at v0.12.0, so the manifest has been a
  version behind the tag for one release. `docs/improvements.md` already carried
  the general observation that nothing enforces the agreement between the
  manifest and the tag; this is that gap, occurring here.
- **`docs/testing.md` describes the `PreTag` gate correctly.** It said "today
  that is one test — an open prune proposal", which named the only `PreTag` test
  this release deletes and omitted the three in `tests/PreTag.Tests.ps1` that
  survive. It would have shipped 100% wrong about a gate.
- Every surviving pointer into deleted machinery was repointed or removed:
  `README.md`, `docs/constraints.md`, `docs/development.md`,
  `docs/improvements.md`, `docs/render-architecture.md`, `docs/samples/README.md`,
  `PSGraphRender.build.ps1`, `scripts/foundation.js` and a comment in
  `tests/NoProducerKinds.Tests.ps1`. Historical citations of ledger entries were
  repointed to the archive rather than deleted: they are still true, and the
  entries they cite still exist.

*No ledger entry. That is the point of this release; `docs/worklog/v0.13.0.md`
is where the reasoning went instead.*

## [0.12.0] - 2026-08-27

### Fixed

- **A node revealed after the first paint is laid out.** The layout places the
  visible set, so anything hidden when it last ran had no position at all and
  sat at the origin, under the top-left node of the drawing. Ticking *Show
  unresolved* dropped every invented node on the same spot; unchecking *Exported
  only* on a 532-node payload put 371 nodes in one corner and left the camera
  where it was. Filter, lay out, fit is one act now, and every control that
  changes the visible set by decision calls it.
- **A name shared by more than one node is told apart.** The test-order steps
  and the cycle box printed labels, so `restart` in one step and `restart` in
  the next read as one node listed twice. A shared name now carries the shortest
  trailing run of path segments that separates it, elided in the middle past
  three, and a name only one node has is untouched.
- **The scale banner no longer names the producer's domain or promises a view
  the page will not give.** It said *"This module has {count} nodes"* and
  offered to *"see everything"*; past `MinReadableZoom` the drawing stops
  shrinking and the reader pans.
- **The legend's unclassified-edge row stopped calling every unlabelled edge a
  call**, and the border-width row counts dependents rather than callers.

### Added

- **The colour encoding is stated under the COLOUR BY radios.** The legend has
  said colour is rank rather than magnitude since before v0.1.0 - as the last
  block of a sidebar that scrolls, eight blocks below the choice that needs it.
- **`tools/threads.ps1` reports a path flip**: a thread names a path, and
  whether that path exists is not what it was when the thread was raised. Two
  booleans and the direction between them. No score and no ordering, which is
  the only reason it belongs in a tool that refused to rank on carry count.
- **A gate reads the values in `strings.psd1`** against the six words the
  charter forbids. Nothing had ever read a value in that file.
- **Five before-and-after screenshot pairs** in `docs/samples/`, every before
  rendered from a worktree at v0.11.0.

*Ledger `0013`.*

## [0.11.0] - 2026-08-27

### Added

- **`docs/constraints.md`** - twelve limitations this repository has decided to
  have, each with the argument that retired it, out of the thread list.
  **Accepted is not closed**: closed means the question is answered, accepted
  means it is not and never will be. `accepts_threads` is a third retiring verb
  in the ledger and `tools/threads.ps1` refuses to fold it into `closed`.

### Changed

- **No document here can publish by being followed.** `git push` left the
  `iteration-close` skill and `CLAUDE.md`, and `tests/Instructions.Tests.ps1`
  fails by file and line if it returns. Publishing is the operator's.
- **The heat-ramp comment says what was measured rather than what was
  intended.** Rank over distinct values puts 87% of a 532-node payload in the
  coldest quarter; the comment said it *"spreads the ramp across the values
  that actually occur"* and stopped.

*Ledger `0012`.*

## [0.10.0] - 2026-08-27

### Added

- **`tools/threads.ps1`** reads any number of ledger directories and writes
  `docs/threads.json` - id, repository, opened at, carries, status and one
  line per thread, shaped like a corpus record and committed for the same
  reason. **It reports and does not decide**: no score, no priority, no
  staleness heuristic. Ledger `0010` measured what carry count predicts and
  the answer was nothing.
- **Thread continuity is checked here for the first time.**
  `tests/Ledger.Tests.ps1` compares an entry against every thread still open
  rather than against the ones the previous entry raised, and understands
  `supersedes_threads` and `recovers_threads`. `0002-t4` was lost at entry
  `0004` and is recovered.

*Ledger `0011`.*

## [0.9.0] - 2026-08-27

### Added

- **A sample gallery you can look at.** `./build.ps1 -Task Samples` renders
  every payload under `tests/fixtures/viewmodels/` through every backend in
  `TemplateSets/`, plus a generated `index.html` listing node counts, link
  counts and which backend produced each. `-ExtraPayload` renders a payload too
  large to commit. The pages are not committed; screenshots are, under
  `docs/samples/`.
- **`tests/LedgerPrune.Tests.ps1`** (renamed `Ledger.Tests.ps1` at v0.10.0), a
  pre-tag gate. A deferred deletion
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
