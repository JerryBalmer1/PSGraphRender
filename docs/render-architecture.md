# PSGraphRender architecture

Read this before planning any work here. Do not read the templates to work out
the design; the design is in this file.

This charter inherits from `docs/html-architecture.md` in PSModuleGraph, where
this subsystem was designed and built. Where the two disagree, this one wins and
that one is out of date.

## Target

**A producer written in any language can drive this renderer.**

Done means: a JSON file conforming to `contract/viewmodel.schema.json`, produced
by a Go program that has never heard of PowerShell, renders a complete
interactive report. No field is named for a producer, no setting is named for a
producer, and no code path branches on which producer wrote the payload.

The check is concrete and belongs in the suite: `tests/fixtures/viewmodels/`
holds hand-written payloads with no PowerShell origin, and the suite renders
every one of them without importing anything.

## The seam

**`New-RenderDocument` is the seam, and it faces outward.** It exists as of
v0.2.0; before that the charter described an interface the code did not have.

Above it: producers. `ConvertTo-GraphHtml` in PSModuleGraph is the first one —
it knows what a dependency graph is, converts one to a view model, and hands it
over. A second producer is a second program, not a second function here.

Below it: everything in this repository. It receives a view model, a template
set and a resolved configuration, and has no idea what any of it means.

What may cross the seam, in both directions:

| Crosses | Does not cross |
| --- | --- |
| nodes, edges, facets, metrics | functions, classes, modules, ASTs |
| ids, labels, paths, line numbers | PowerShell types, `.psd1` payloads |
| caller-supplied strings with `{tokens}` | the name of a producer's command, hardcoded |
| `meta.contractVersion` | `meta` fields the renderer branches on by producer |

`editorLinkHelpCommand` is the pattern to copy for anything new. The producer
supplies the string; the renderer interpolates it and learns nothing. The
renderer ships **no default** for it — a default would be the renderer knowing a
producer's vocabulary — and when nothing supplies one the page uses a second
message that does not mention a command.

**Caller tokens are filled in PowerShell; display-time tokens are filled in the
page.** `{editorLinkHelpCommand}` is configuration and is substituted at render
time. `{count}`, `{name}` and `{origin}` are only known in the browser and are
left for `fmt()`. A token nobody fills stays as written rather than collapsing
to nothing, so the gap shows up.

## File layout

```
PSGraphRender/
  contract/
    viewmodel.schema.json       THE product. Versioned separately.
    examples/*.json             one per contract feature, all schema-valid
  src/PSGraphRender/
    PSGraphRender.psd1
    PSGraphRender.psm1
    Public/                     NOT recursive; export list derives from names
      New-RenderDocument.ps1    <- the seam
      Show-RenderDocument.ps1
      Get-RenderTemplateSet.ps1
      Test-RenderViewModel.ps1
    Private/                    recursive; a new subfolder needs no registration
      Config/                   Resolve-*, Test-RenderSettingValue, constraints
      Document/                 escaping, path building, token substitution
      Transport/                loopback probing, browser launch
    TemplateSets/
      cytoscape/                the reference backend, not a privileged one
        templateset.psd1
        layout.html
        partials/*.html
        styles/*.css
        scripts/*.js
        Config/
          settings.psd1
          settings.schema.psd1
          theme.psd1
          strings.psd1
  tests/
    fixtures/viewmodels/*.json  hand-written. No producer runs to make these.
  knowledge/ledger/             ledger ONLY. The store stays in PSModuleGraph.
  docs/
```

**`Public/` is not enumerated recursively and the manifest's `FunctionsToExport`
is an explicit list.** A helper in `Public/` is exported by accident; a new file
not added to the manifest builds clean and is unavailable at runtime.

## The rule that pays for it

> **Adding a backend, a setting, or a theme value must require editing data
> files only.** If it requires editing a `.ps1`, the design is wrong. Report
> that as a bug; do not work around it.

A new schema *type* is not a new setting and may need a validator — `ColorList`
did, as every other type in that switch did when it was added. The distinction
holds: types are machinery, settings are data.

## Gravity, and the measurements behind it

`scripts/foundation.js` assigns layers itself. It is not dagre, and this was
measured in both directions before it was chosen.

No dagre ranker bounds the width of a layer, and that is the whole problem.
`longest-path` pins every node with no dependencies to one extreme layer: on
PSModuleGraph that was 29 of 62 nodes in a single row, drawn at 11:1 and
illegible once fitted to a window. `network-simplex` only reached 24. Bounding
the layer and letting the layer count grow takes the same graph to 10 layers of
7 at 1.3:1.

**Do not "simplify" this back to a ranker.** The other views still use dagre and
should.

- **Layer capacity is derived from the container's aspect** unless
  `FoundationLayerCapacity` pins it. Width is capacity × stepX and height is
  (count / capacity) × stepY, so setting their ratio to the container's gives
  the capacity directly. A fixed number would be wrong on either a laptop or a
  wall display, and one setting per screen size is not a design.
- **Layer 0 is the foundation and takes the largest y.** Cytoscape's y grows
  downward, so `layers.length - 1 - at` is what puts it at the bottom.
  Inverting that puts the foundation in the air; it is the bug to watch for.
- **The arrowhead follows the reading direction.** Foundation reads bottom to
  top, so the arrow sits on the source end: it means "this one first, then the
  one it points at". Only `callflow` keeps the arrow on the callee.
- **The layout table is `FLOW_LAYOUT` in `scripts/render.js`.** A new view is
  one entry. Do not add a branch beside it.
- **Fitting is floored at `MinReadableZoom`.** A graph large enough to fit only
  at 15% is a graph nobody can read; past the floor the view stops shrinking and
  the reader pans. A legible part beats an illegible whole.
- **Nothing may leave the starting view to the markup.** The radios carry no
  `checked` attribute; `controls.js` sets it from config. A `checked` in the
  partial would make editing the `.psd1` silently do nothing.

## Facets and metrics

**A facet CLASSIFIES** — a set of paths a subject carries. **A metric MEASURES**
— one number on a scale. `ColorBy` takes either: `structure` gives one colour
per classification, and any metric id in the payload gives a heat ramp. The
registry that renders the choices is built from the ids the payload carries, so
a new metric is a producer-side change plus two strings, and no branch in any
script.

**Heat is ranked, not scaled.** Blast radius is heavily skewed: on PSModuleGraph
one node scores 30 and 73% of nodes score three or less, so a linear ramp paints
almost everything the coldest colour and answers no question. Rank spreads the
ramp across the values that actually occur. The cost is real — colour stops
being proportional, and two adjacent ranks can look far apart — which is why the
raw number is in the Details panel and why the legend labels its ends with
actual values rather than "low" and "high".

**The ramp is five discrete bands, not an interpolation.** A continuous blend
across a dark canvas mostly reads as noise, and a reader comparing two nodes
wants "hotter", not "3% hotter". Every stop stays light enough to carry the
near-black node label.

**A heatmap is two facets crossed with a count.** Rows are the paths of one
facet, columns the paths of another, cells the number of subjects carrying both.
That is the whole definition and it needs no data beyond what a `facets` block
already carries. Stating it is the deliverable here; implementing it is out of
scope until a facet exists that a reader would want crossed with `structure`.

## Looks like a bug, but is not

**`Show-RenderDocument` always opens the OS default handler, never an editor** —
even when the session is running inside one. Opening the report in an editor
shows the HTML source, so the user reaches for a preview extension. Every one of
those is a webview, and a webview sandboxes custom-scheme navigation, so the
page's own "Open File Location" action is dead in exactly that environment.

**This reverses an earlier implementation that preferred the editor.** It has
been optimised in both directions already; do not do it a third time.

**The served root is inferred by walking ancestors, and a 200 is not enough.**
Nothing can ask a static server what it serves, so `Resolve-LoopbackDocumentUrl`
requests the path the file would have under each ancestor, nearest first. A 200
says a resource exists there, not that it is ours — something answering 200 to
every path would otherwise capture the browser — so the first 120 characters of
the body are compared with the file.

**Only the `127.0.0.1` literal is ever probed.** Not `localhost`, which can
resolve to a v6 address a server is not bound to; not `0.0.0.0`; not a LAN
address. An explicit `-BaseUrl` is the caller's decision and is used as given.

**An action that hands a URI to another application must use `href`, never `run`
with `window.location`.** Chrome discards a scripted navigation to a custom
scheme in total silence — the handler runs, the URI is correct, and nothing
happens — while a link the user clicked is the supported route. Because a
refused or unregistered scheme reports nothing back either, any such action
needs a non-scheme fallback beside it; `Copy Path` is that fallback.

**The page rebuilds absolute paths in the browser** from `meta.rootPath`, which
is how a `file://` link works while payload paths stay relative. Note that
`meta.rootPath` is itself absolute, so "no absolute paths in a shared report" is
already weaker than it sounds. Do not add absolute paths to `nodes`/`links` on
the assumption that it makes no difference.

## Extraction checklist

Extraction from PSModuleGraph is iteration 0.1.0 and has not happened yet. The
checklist below tracks both halves: moving the subsystem across unchanged, and
then making the result producer-neutral rather than merely relocated.

- [x] No producer vocabulary anywhere  (`Module`, `Ast`, `PSModuleGraph`)
      (ticked prematurely at 0.1.0; four producer command names and a producer
      module name were still in shipped markup and comments until 0.4.0)
- [x] Token contract named generically (not `__GRAPH_*__`)
- [x] Public functions named without `Graph` or `PSModule`
- [x] All user-visible strings externalised to `strings.psd1`  (scripts done;
      `partials/template-notice.html` keeps its own text on purpose — it is
      shown only when nothing was substituted, so `STRINGS` is `null` by
      definition and a string cannot come from a file that was not read)
- [x] All colours externalised to `theme.psd1`  (kind and link colours moved in 0.3.0; structural greys remain in `render.js`)
- [x] `contract/viewmodel.schema.json` exists and every entry point validates against it
- [x] Suite renders a hand-written fixture with no producer installed
- [x] `TemplateSets/` holds the reference backend and code privileges none of them
- [x] A second backend exists and proves the seam
- [ ] CLAUDE.md pruned toward 10,000; ceiling ratcheted to match  (13,659 at
      0.1.0, 11,301 at 0.2.0, 11,223 at 0.4.0 — the ratchet works, the target
      is not reached)
- [x] Every backend script parses, and the assembled document parses  (0.4.0)
- [x] Something runs the page  (0.5.0, headless, network blocked, both
      backends, both fixtures — proved able to fail before it was trusted)
- [x] CI executes at all  (0.6.0. It never had: `shell: ${{ matrix.powershell }}`
      on a step made every run since 0.2.0 fail before any job started)
- [x] The page is genuinely self-contained  (0.5.0; the libraries live under
      the backend, not the module)
- [x] The settings schema is data — `settings.schema.psd1`, not a hashtable
      in a `.ps1`
- [x] The view model contract is data — `contract/viewmodel.schema.json`, not
      a `.psd1` and not a hashtable in a `.ps1`
- [x] No partial over 250 lines
- [x] Template set resolvable from a caller-supplied directory

## Decisions made and why

Append only. Each entry two or three sentences. Do not re-litigate these.

Entries dated before the extraction were inherited from
`docs/html-architecture.md` and are not repeated here — that log stands. New
entries start below.

**2026-08-26 — Nodes and edges are this renderer's own vocabulary, not producer
vocabulary.** The parent charter's Target said a finished renderer would carry
"no reference to nodes, edges, modules, or ASTs", and that conflates two
different things. Cytoscape's API is nodes and edges; renaming them would be a
rename across roughly two thousand lines of JavaScript with no way to verify
behaviour was unchanged, which is the half-rename the parent log already
rejected twice. What must not survive is *domain* vocabulary — `Module`, `Ast`,
`PSModuleGraph`, and any hardcoded list of node kinds.

**2026-08-26 — A template set directory is a rendering backend, and the seam
already existed.** `Get-RenderTemplateSet -Path` was written to take a
caller-supplied directory before there was a second caller. Moving the shipped
set under `TemplateSets/cytoscape/` makes a second backend a directory rather
than a code change, which is the same test as `NODE_ACTIONS` and `FLOW_LAYOUT`.

**2026-08-26 — The view model contract is JSON Schema, not a `.psd1`.** The
point of the extraction is that a Go or Python producer can drive this renderer,
and a contract expressed in PowerShell data format would make that a translation
exercise. This is the same rule that governs `knowledge/` in PSModuleGraph and
it is here for the same reason.

**2026-08-26 — `knowledge/` here holds only `ledger/`.** The facets, subjects
and assignments classify PowerShell code, which is precisely what this
repository must not know about. Mirroring the store would re-couple the two at
the level the extraction was meant to separate.

**2026-08-26 — Extraction is verified by byte-identity, and nothing else ships
in that iteration.** A pure move can be proved correct by rendering the same
graph through both paths and comparing bytes with the timestamp normalised. That
proof is only available if nothing is renamed at the same time, which is why the
renames wait for the following iteration and are verified structurally instead.

**2026-08-26 — `New-RenderDocument` is the seam and it now exists.** The
charter said the seam faced outward while the actual interface was seven
functions and four marker names a producer had to know, so a producer in
another language would have had to reimplement the escaping before rendering
anything. One call takes a view model, a meta block, strings and a title. The
escapers and the two resolvers went back to private and the public surface is
four.

**2026-08-26 — A backend's location is stated once, and its name is data.**
Three functions each resolved `TemplateSets/cytoscape` independently, which
made a second backend three code edits and the rule that pays for the config
split a dead letter. `Resolve-RenderTemplateSetPath` is the only answer now;
`TemplateSets/index.psd1` names the default and discovery is enumerating
directories with a manifest. A backend name in a `.ps1` is a test failure.

**2026-08-26 — The second backend is deliberately poor.** `TemplateSets/plain`
is a static table with no CDN, no library and no layout engine. A good second
backend would have been a worse test: what is being proved is that the seam
holds for something that shares none of the reference backend's assumptions,
and the cheapest way to be sure of that is to build something that could not
have inherited any. It also makes the offline half of the vendoring decision a
demonstration rather than an argument.

**2026-08-26 — Renames keep byte-identity; payload fields do not.** Function,
parameter and file names and the `__*__` markers are consumed before the
document exists, so the golden covers a rename of any of them and a red golden
during a rename means something else changed. The JavaScript consts and the
`meta.module*` fields DO reach the document, which is why they wait for 0.3.0
and the structural-equivalence check the schema will need anyway.

**2026-08-26 - A hardcoded list of node kinds survived two iterations in
JavaScript.** `bootstrap.js` held `KIND_HEX = { Function, Class, Enum, Script,
External }` from the extraction until 0.3.0. Every producer-vocabulary check
looked for words in PowerShell source or function names; this was an object
literal whose KEYS were the vocabulary. The lesson is not "add JavaScript to
the grep" - it is that a check written in the language of the last mistake
finds only that mistake.

**2026-08-26 - `External` and `Unresolved` are the renderer's own words and
stay.** No producer emits either; the renderer invents both for targets a
payload names but does not contain. `UnresolvedColor` is its own theme value
rather than a `KindColor` entry, because sitting in a map beside four
PowerShell kinds is what made the whole map read as renderer vocabulary.

**2026-08-26 - Validation lives at the seam, and `plain` stays naive.** The
question was whether the second backend should validate against the schema. It
should not: `New-RenderDocument` validates once for every backend, so a backend
validating again is duplication with two places to drift. What made `plain`
reading `DATA.nodes` a liability was not that it skipped a check - it was that
nothing guaranteed the field. The contract requires `nodes`, so the directness
is licensed rather than lucky, and a backend assuming something the contract
does not promise is still the open problem.

**2026-08-26 - Semantic equivalence replaces byte-identity, and is weaker.**
Names that reach the document cannot be verified by comparing bytes. What
replaces it parses both documents and compares nodes, links, configuration,
strings, element structure and visible text. Someone chose that list, so it
catches a difference only in a dimension somebody thought to compare. Two
instruments were tried and rejected: a positional line diff (an insertion
shifts every following line, reporting 78% changed for three removed keys) and
a JavaScript brace-balance check (it cannot parse a regex literal and fires on
known-good output).

**2026-08-26 — A gate whose tool is missing fails by name; it never skips.**
`LintJavaScript` and `LintDocument` throw when `node` is absent rather than
passing quietly, and `PreTag` throws when its filter selects no tests — it had
printed "gates passed" against zero tests for four tags. A gate that reports
success for the one environment where it checked nothing is worse than no gate,
because it is believed.

**2026-08-26 — A check written in the language of one known mistake finds only
that mistake.** The producer-vocabulary check looked for the literal
`PSModuleGraphEditorLink` and passed for three iterations while shipped markup
named a producer's module, two of its commands and one of its source paths. The
fix in both this case and `KIND_HEX` was to look for the SHAPE — Verb-Noun for a
command, an object literal's keys for a classification list — rather than for
the word last found.

**2026-08-26 — The libraries are vendored, under the backend rather than the
module.** The deciding number was not size: an offline `cytoscape` page and a
broken `render.js` produced the same signature, so allowing the network would
have made the harness's red ambiguous on the day it shipped — the same defect as
a pre-tag gate that passes on zero tests. A report goes from 126 KB to 607 KB,
which is a large multiplier on a small absolute for something read one at a time
off local disk, and "self-contained" stops being false for anyone behind a
proxy. Not a setting: two code paths and two test matrices to let a reader
receive a report they cannot identify.

**2026-08-26 — A vendored file carries its provenance or it does not ship.**
`vendor/vendor.psd1` records source URL, version, licence and the SRI hash each
file was verified against, and a test recomputes every hash on every run. A blob
with no provenance is worse than a CDN link, which at least says where it came
from. Vendored files are never edited: the hash is the only thing that makes a
re-download checkable.

**2026-08-26 — What "the page came alive" means is declared by the backend.**
The headless harness reads a `Smoke` block out of `templateset.psd1` and names
no selector of its own, because a harness that knew `#c-nodes` would be a second
place a backend's shape is written down. A backend with no `Smoke` block fails
the task rather than being quietly skipped.

**2026-08-27 — A threshold a check cannot re-derive belongs to the machine that
wrote it.** `MinScreenshotBytes = 15000` measured one laptop's viewport, device
pixel ratio, fonts and Chromium build. `CanvasGrowth` compares a drawn view
against the same backend rendering an empty payload, measured in the same run,
so the floor comes from wherever the check is executing. The requirement has
daylight in it — four against a measured twelve — because a ratio that needs
precision is a constant wearing a disguise.

**2026-08-27 — The browser harness runs on one CI leg, and that is configured
rather than omitted.** What a browser does with the page does not vary by which
PowerShell produced it, so three installs buy nothing; every gate that does vary
runs everywhere. The two legs without it run `WithoutBrowser`, which prints by
name that it did not run. Both chains are generated from one task list, so a
gate added to the default cannot go missing from the other.
