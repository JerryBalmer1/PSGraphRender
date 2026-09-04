# Examples

Six generated reports, every one of them committed here with the input that
produced it, a screenshot, and the exact command that rebuilds it. Nothing in
this directory was hand-edited after generation.

Open any `.html` file straight from a clone — the reports are self-contained.
There is no build step, no server and no network fetch: Cytoscape and dagre are
vendored into the document itself.

Every command below is run **from the repository root**.

| Example | What it shows | Artifacts | Regenerate |
| --- | --- | --- | --- |
| **Foundation layout** | The opening view. Vertical, with what everything rests on sunk to the bottom — `Get-HashtableValue` at the foot, the module file at the top. | [html](layouts/foundation.html) · [input](input/ecosystem-viewmodel.json) · [png](layouts/foundation.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only foundation` |
| **Test order layout** | Dependencies first, `longest-path` ranked. The order to test things in: nothing in a step depends on anything in a later step. | [html](layouts/testorder.html) · [input](input/ecosystem-viewmodel.json) · [png](layouts/testorder.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only testorder` |
| **Call flow layout** | Callers first, left to right, `network-simplex` ranked. The arrow stays on the callee. | [html](layouts/callflow.html) · [input](input/ecosystem-viewmodel.json) · [png](layouts/callflow.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only callflow` |
| **Theme — shipped** | The palette the module ships: one colour per classification, from `Config/theme.psd1`. | [html](theme/default.html) · [input](input/ecosystem-viewmodel.json) · [png](theme/default.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only default` |
| **Theme — contrast** | The same viewmodel and the same layout under a different [`theme-contrast.psd1`](input/theme-contrast.psd1). Node colours change, and `Reads`/`Validates` links become dashed in their own colours. No code changed. | [html](theme/contrast.html) · [input](input/ecosystem-viewmodel.json) · [png](theme/contrast.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only contrast` |
| **Node links** | Right-click a node for *Open file location* and *Copy editor link*. Both are built from `meta.rootPath` plus the node's own `path` and `startLine`. | [html](links/editor-links.html) · [input](input/links-viewmodel.json) · [png](links/editor-links.png) | `pwsh -NoProfile -File examples/Build-Examples.ps1 -Only links` |

Rebuild all six with `pwsh -NoProfile -File examples/Build-Examples.ps1`.

## The three layouts are the module's own list

`foundation`, `testorder` and `callflow` are not a selection made for this
directory. They are the complete value set of the `DefaultFlow` setting, as
declared in
[`Config/settings.schema.psd1`](../src/PSGraphRender/TemplateSets/cytoscape/Config/settings.schema.psd1),
and they match the `FLOW_LAYOUT` table in
[`scripts/render.js`](../src/PSGraphRender/TemplateSets/cytoscape/scripts/render.js)
one for one. If a fourth layout is ever added, this directory is short an
example and the two sources say so.

## Why the links example does not open anything

`meta.rootPath` in [`links-viewmodel.json`](input/links-viewmodel.json) is the
literal string `REPLACE-WITH-YOUR-CLONE-PATH`, so the editor links in the
committed report are inert placeholders. That is deliberate: an absolute path
baked into a committed artifact names the machine that generated it, and these
files are meant to be read from a clone by someone who is not its author.

To see live links, put your own clone path in that field and rebuild:

```powershell
pwsh -NoProfile -File examples/Build-Examples.ps1 -Only links
```

The action then emits `vscode://file/<your path>/<node path>:<line>:1`. The
scheme is the renderer's and is not configurable today — see
[`docs/improvements.md`](../docs/improvements.md) for the open item on making
node links choose between an editor scheme and an href template.

## How a setting reaches the renderer

`New-RenderDocument` has no `-Setting` parameter, by design. Configuration
reaches PSGraphRender only through a **template-set directory**, so every
variant above is produced by copying the shipped `cytoscape` set to a temporary
directory, editing the one data file it needs — `Config/settings.psd1` for
layout, `Config/theme.psd1` for appearance — and passing that directory as
`-TemplateSetPath`.

That is the same seam a third-party backend uses, which is the point:
generating these examples never edited the renderer.
[`Build-Examples.ps1`](Build-Examples.ps1) is 150 lines and does exactly that.

## Determinism

The documents are byte-for-byte reproducible: `generatedAt` is a field in the
committed input rather than a clock reading, so rebuilding produces an
identical file. Two consecutive builds of `callflow.html` were verified to have
the same SHA-256.
