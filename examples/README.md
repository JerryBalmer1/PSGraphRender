# Examples

Eight generated reports, every one of them committed here with the input that
produced it, a screenshot, and the exact command that rebuilds it. Nothing in
this directory was hand-edited after generation.

Plus a **[variant catalogue](threed/catalog.html)** for the 3D backend, added at
v0.16.0 and grown at v0.17.0: twenty-two labelled looks in five families, each
one overlay of declared settings away from the default. See
[below](#the-variant-catalogue).

Open any `.html` file straight from a clone — the reports are self-contained.
There is no build step, no server and no network fetch: every library each
backend needs is vendored into the document itself.

Every command below is run **from the repository root**.

| Example | What it shows | Artifacts | Regenerate |
| --- | --- | --- | --- |
| **Foundation layout** | The opening view. Vertical, with what everything rests on sunk to the bottom — `Get-HashtableValue` at the foot, the module file at the top. | [html](layouts/foundation.html) · [input](input/ecosystem-viewmodel.json) · [png](layouts/foundation.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only foundation` |
| **Test order layout** | Dependencies first, `longest-path` ranked. The order to test things in: nothing in a step depends on anything in a later step. | [html](layouts/testorder.html) · [input](input/ecosystem-viewmodel.json) · [png](layouts/testorder.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only testorder` |
| **Call flow layout** | Callers first, left to right, `network-simplex` ranked. The arrow stays on the callee. | [html](layouts/callflow.html) · [input](input/ecosystem-viewmodel.json) · [png](layouts/callflow.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only callflow` |
| **Theme — shipped** | The palette the module ships: one colour per classification, from `Config/theme.psd1`. | [html](theme/default.html) · [input](input/ecosystem-viewmodel.json) · [png](theme/default.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only default` |
| **Theme — contrast** | The same viewmodel and the same layout under a different [`theme-contrast.psd1`](input/theme-contrast.psd1). Node colours change, and `Reads`/`Validates` links become dashed in their own colours. No code changed. | [html](theme/contrast.html) · [input](input/ecosystem-viewmodel.json) · [png](theme/contrast.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only contrast` |
| **Node links — editor** | `LinkMode = 'editor'`. Right-click a node for *Open File Location* and *Copy Editor Link*, built from `meta.rootPath` plus the node's own `path` and `startLine`. The links here are inert on purpose — see below. | [html](links/editor-links.html) · [input](input/links-viewmodel.json) · [png](links/editor-links.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only links` |
| **Node links — GitHub** | `LinkMode = 'hrefTemplate'` with `LinkHrefTemplate` set to a `blob/main/{relativePath}#L{line}` URL. The same payload and the same layout as the row above; one setting different, and the links are live. | [html](links/forge-links.html) · [input](input/links-viewmodel.json) · [png](links/forge-links.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only forge` |
| **Three dimensions** | A different **backend**, not a different setting: the `forcegraph3d` template set draws the same viewmodel as the three layout rows above with a force simulation in three dimensions. Click an item for what it is and where it lives; the links are the same live GitHub URLs as the row above. Since v0.16.0 it also draws a **shape per classification**, glows, fogs and moves — hover an item to light what it connects to. | [html](threed/forcegraph3d.html) · [input](input/ecosystem-viewmodel.json) · [png](threed/forcegraph3d.png) · [catalogue](threed/catalog.html) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only threed` |

Rebuild all eight with `pwsh -NoProfile -File examples/Build-Examples.ps1`, and
the catalogue with `-Variant all`.

## The three layouts are the module's own list

`foundation`, `testorder` and `callflow` are not a selection made for this
directory. They are the complete value set of the `DefaultFlow` setting, as
declared in
[`Config/settings.schema.psd1`](../src/PSGraphRender/TemplateSets/cytoscape/Config/settings.schema.psd1),
and they match the `FLOW_LAYOUT` table in
[`scripts/render.js`](../src/PSGraphRender/TemplateSets/cytoscape/scripts/render.js)
one for one. If a fourth layout is ever added, this directory is short an
example and the two sources say so.

## Why the editor example does not open anything, and the GitHub one does

`meta.rootPath` in [`links-viewmodel.json`](input/links-viewmodel.json) is the
literal string `REPLACE-WITH-YOUR-CLONE-PATH`, so the editor links in
[`editor-links.html`](links/editor-links.html) are inert placeholders. That is
deliberate: an absolute path baked into a committed artifact names the machine
that generated it, and these files are meant to be read from a clone by someone
who is not its author.

To see live editor links, put your own clone path in that field and rebuild:

```powershell
pwsh -NoProfile -File examples/Build-Examples.ps1 -Only links
```

The action then emits `vscode://file/<your path>/<node path>:<line>:1`.

[`forge-links.html`](links/forge-links.html) has no such problem, and that is
the point of it. `hrefTemplate` mode never reads `meta.rootPath` at all: a URL
is built from each node's own relative path, which is a fact about the
repository rather than about anyone's disk. So its links work from a committed
file, on anyone's machine, and the placeholder above stays exactly where it is.

The two pages differ by one setting. Which mode a report is built with is
decided when the document is **assembled**, not in the browser — so
`forge-links.html` contains no `vscode://` construction at all, and a report
built with `LinkMode = 'none'` contains no link machinery of any kind. See
[`Config/settings.schema.psd1`](../src/PSGraphRender/TemplateSets/cytoscape/Config/settings.schema.psd1)
for the two settings and
[`templateset.psd1`](../src/PSGraphRender/TemplateSets/cytoscape/templateset.psd1)
for the `SlotsBySetting` block that does the choosing.

## The row that changes the backend rather than a setting

Every row but the last varies **configuration**: a flow, a theme file, a link
mode. The last one varies the **backend**, and it is the only row that does.

The same payload renders through
[`forcegraph3d`](../src/PSGraphRender/TemplateSets/forcegraph3d/) with no
producer involved, no contract change and no `.ps1` edit anywhere — a template
set is a directory, and that claim is what this row is evidence for. Put
[`layouts/foundation.png`](layouts/foundation.png) and
[`threed/forcegraph3d.png`](threed/forcegraph3d.png) beside each other: twenty-four
items and thirty-four links, drawn twice, from one file neither backend wrote.

It is deliberately **not** feature-parity with the reference backend. There is no
sidebar, no filtering and no focus mode — the sidebar is Cytoscape-backend
machinery, and a second elaborate backend would prove the seam while hiding any
defect in it behind its own machinery. What it does carry is the whole link-mode
registry: all three modes, resolved at assembly, with the same five tokens.

Two things differ from the rows above and both are honest consequences rather
than omissions. It has no `-Flow`, because `DefaultFlow` is a cytoscape setting
and this backend has no views to choose between. And its page is about 1.4 MB
against roughly 620 KB, because the library it vendors is larger.

**Its appearance changed at v0.16.0 and this picture is the record of that.**
Until then it drew one geometry in one flat colour per classification, and the
row said so. It now draws a shape per classification with a declared fallback,
lights items rather than only colouring them, fogs by depth, moves marks along
its links, and highlights an item's neighbours on hover — all of it declared
configuration, and all of it one overlay away from something else in
[the catalogue](#the-variant-catalogue).

## The variant catalogue

[`threed/catalog.html`](threed/catalog.html) — **twenty-two labelled looks** for
the `forcegraph3d` backend, in five families:

| Family | What it varies | Members |
| --- | --- | --- |
| **A** | the origins, and the shape channel | A0 – A5 |
| **B** | colour, mood, and what the graph sits in | B1 – B6 |
| **C** | connectors | C1 – C4 |
| **D** | interaction | D1 – D4 |
| **E** | composed looks | E2 – E3 |

**`A0` is the default** — what `New-RenderDocument -TemplateSet forcegraph3d`
produces with no overlay at all — so every other variant is a diff from a fixed
origin, and `tests/ForceGraph3DLook.Tests.ps1` asserts the committed `A0.html`
is byte-identical to a fresh no-overlay render.

**`A5` is the default it replaced**, kept whole rather than described, so the
change v0.17.0 made can be looked at instead of read about. A0 and A5 draw the
same payload through the same generator, which makes the difference between the
two pictures exactly what that release changed and nothing else.

**`E1` is not here, because it won.** "Nebula — the recommended look" was
v0.16.0's answer to "make it look modern"; v0.17.0 moved its treatments into
[`Config/theme.psd1`](../src/PSGraphRender/TemplateSets/forcegraph3d/Config/theme.psd1),
added the environment and the control panel, and `A0` is what it draws now. A
row for it would be a second picture of the default. **The coordinate is retired
rather than reused** — a label is a thing you point with, and a pointer that
quietly starts meaning something else is worse than one that is gone.

Any variant can still become the default the same way, by moving its values into
that file, which is the point of writing them as overlays rather than as forks.

Every variant is **one overlay of declared settings** and nothing else. A
variant that needed a script edit would not be a variant, it would be a fork,
and the whole claim of v0.16.0 is that this backend's look is configuration.

```powershell
pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant all   # all twenty-two
pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant B5    # one of them
pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant all -SkipShots
```

`-Variant` takes a label rather than a `ValidateSet`, because the labels live in
[`threed/variants.psd1`](threed/variants.psd1) and a set on the parameter would
be a second place they were written down. An unknown label is refused by name,
listing the ones that exist.

**The catalogue page is generated, never written.** `Build-Examples.ps1` reads
that table, builds each document, screenshots it through
[`tools/shoot.cjs`](../tools/shoot.cjs) at 1280×900 with the network blocked,
and regenerates `catalog.html` from the same rows — always from the whole table,
even when one variant was built, because a page rebuilt from only what a run
touched would silently drop every row it did not. So a variant is in the
catalogue because it is in the table, and drift is not prevented by discipline;
it is impossible.

**All twenty-two draw the same payload**, `input/ecosystem-viewmodel.json`, so
the only difference between any two pictures is the overlay named under them.

### What a screenshot cannot show

The **D family is interaction** — a zoom speed, a hover mode, which button opens
an item's actions — and none of that photographs. Its pictures show the parts
that do (the tooltip, the highlight, the labels, and since v0.17.0 the control
panel) and its captions carry the rest. Open the pages to use them.

**The panel is the part worth opening a page for.** Every picture in the
catalogue except `A5` and `D4` shows it, but a screenshot of a slider is a
picture of a slider — what it does is change the scene while you watch, and the
browser gate is what asserts that rather than the catalogue.

### Why it costs 31 MB on disk, and where the packed cost actually goes

Twenty-two documents that each inline the same 1.3 MB vendored library — 31 MB
of HTML. They delta-compress against each other almost perfectly, so that part
is nearly free: the whole repository packs to **20.1 MiB** after v0.17.0, up
from 10.6 MiB at v0.16.0.

**And the growth is not the HTML.** It is the 22 screenshots — 8.3 MB of PNG,
which is already-compressed data and deltas against nothing — plus the
operator's design references under `claude-examples/`. Three documents of
inlined HTML that share no history with anything here. Worth stating because
finding 68 in the harness ledger recorded the on-disk figure as "seven times the
real cost", and that ratio holds for the documents and not for the pictures.

Recorded here rather than hidden, the same way the 126 KB → 607 KB cost of
vendoring was.

## How a setting reaches the renderer

`New-RenderDocument` has no `-Setting` parameter, by design. Configuration
reaches PSGraphRender only through a **template-set directory**, so every
variant above is produced by copying the shipped `cytoscape` set to a temporary
directory, editing the one data file it needs — `Config/settings.psd1` for
layout, `Config/theme.psd1` for appearance — and passing that directory as
`-TemplateSetPath`.

That is the same seam a third-party backend uses, which is the point:
generating these examples never edited the renderer.
[`Build-Examples.ps1`](Build-Examples.ps1) does exactly that. Which backend it
copies is a field on each row, defaulting to `cytoscape`.

## Determinism

The documents are byte-for-byte reproducible: `generatedAt` is a field in the
committed input rather than a clock reading, so rebuilding produces an
identical file. Two consecutive builds of `callflow.html` were verified to have
the same SHA-256.
