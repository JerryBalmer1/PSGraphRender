# PSGraphRender

**A generic, data-driven report renderer.** It takes a graph as JSON and writes
one self-contained interactive HTML page.

**The producer can be written in any language.** The boundary is
[`contract/viewmodel.schema.json`](contract/viewmodel.schema.json) — JSON
Schema, versioned independently of this module, currently **1.1.0**. Anything
that can emit JSON matching it can drive this renderer: Python, Go, a shell
script with `jq`, a paste into a text editor. PowerShell is what this
implementation is written in, not what it renders.

**PSModuleGraph is one consumer, not the owner.** It happens to be the first
one and it is where this code was extracted from, and none of that is visible
here. This repository has never parsed a PowerShell module, cannot import one,
and nothing in it may learn how. If you are reading this because you found it
underneath PSModuleGraph: the dependency points the other way, and it is a
dependency on a schema.

## The one rule

> **The renderer knows about nodes and edges. It knows nothing about what they
> are.**

A node has an id, a label, a set of classifications and a set of measurements.
Whether it represents a function, a Terraform resource, a Python class or a
Cisco interface is the producer's business and never reaches this code. Where
answering a question would need that knowledge, the renderer **renders less
instead** — a report that omits a panel is correct; one that special-cases a
producer's vocabulary has failed at the only thing it exists for.

That is why the page's colours, wording and behaviour are all data. See
[Backends](#backends).

## The view model

Two objects: `meta` (provenance and headline figures) and `data` (the graph).

```json
{
  "meta": {
    "contractVersion": "1.1.0",
    "title": "Order stack",
    "version": "3.2.0",
    "generatedAt": "2026-08-27T00:00:00Z",
    "rootPath": "/srv/stack",
    "stats": { "nodes": 3, "links": 2 }
  },
  "data": {
    "nodes": [
      { "id": "svc:api", "name": "api", "kind": "Service", "path": "deploy/api.yaml", "startLine": 9,
        "isExported": true, "metrics": { "blastRadius": 2 } }
    ],
    "links": [
      { "source": "svc:api", "target": "db:orders", "kind": "Reads", "resolution": "Unique" }
    ],
    "unresolved": [
      { "source": "svc:api", "sourceName": "api", "targetName": "notify-oncall" }
    ],
    "metrics": ["blastRadius"],
    "roots": ["svc:api"],
    "leaves": ["db:orders"]
  }
}
```

Only `meta`, `data` and `data.nodes` are required, and only `id` is required on
a node. Everything else is optional, and **absent means not stated** rather
than defaulted:

| Field | What it is |
| --- | --- |
| `nodes[].id` | Unique within the payload. Links reference it. Opaque — the renderer never parses it. |
| `nodes[].name` | The label a reader sees. |
| `nodes[].kind` | One classification. Coloured by `KindColor` in a backend's `theme.psd1`; the renderer knows no kinds. |
| `nodes[].metrics` | One number per measurement id. The ids are the producer's; the page builds its menu from whatever arrives. |
| `links[].resolution` | *Since 1.1.0.* How confidently the producer tied this edge to its target. Absent means **not stated**, which is not the same as certain. Styled by `EdgeResolutionStyle`. |
| `unresolved[]` | Targets the payload names but does not contain. The renderer invents a node for each, in its own vocabulary — no producer sends one. |

`meta.stats` is deliberately unconstrained: headline figures in the producer's
own words, which no backend reads.

The full field list, with the reasoning for each, is in the schema itself.
[`docs/contract.md`](docs/contract.md) is the guide for writing a producer.

## Commands

Four, and a producer needs one of them.

| Command | For |
| --- | --- |
| `New-RenderDocument` | **The seam.** A view model in, a finished document out. The only function that knows the substitution contract exists. |
| `New-RenderDocumentPath` | A timestamped path under `<BasePath>/output/reports`. Convenience, not required. |
| `Show-RenderDocument` | Opens a document with the OS handler — over `http://` when a local server is already serving it, so the page's click-to-source links work. |
| `Get-RenderTemplateSet` | The assembled template with no data in it. For inspecting a backend, or driving substitution yourself. |

### A worked example

Nothing below mentions PowerShell modules, because nothing has to.

```powershell
Import-Module ./output/PSGraphRender/PSGraphRender.psd1

$viewModel = @{
    nodes = @(
        @{ id = 'svc:api';    name = 'api';    kind = 'Service' }
        @{ id = 'svc:cache';  name = 'cache';  kind = 'Service' }
        @{ id = 'db:orders';  name = 'orders'; kind = 'Database' }
    )
    links = @(
        @{ source = 'svc:api'; target = 'db:orders'; kind = 'Reads' }
        @{ source = 'svc:api'; target = 'svc:cache'; kind = 'Reads'; resolution = 'Ambiguous' }
    )
}

$meta = @{
    contractVersion = '1.1.0'
    title           = 'Order stack'
    generatedAt     = (Get-Date).ToString('o')
}

$document = New-RenderDocument -ViewModel $viewModel -Meta $meta -Title 'Order stack'
$path = New-RenderDocumentPath -Name 'order-stack' -BasePath $PWD
[System.IO.File]::WriteAllText($path, $document)
Show-RenderDocument -Path $path
```

That writes a 602 KB self-contained page. The second link is drawn dashed and
faded, because the producer said it could not tie that call to one target and
`EdgeResolutionStyle` in the cytoscape theme says what an `Ambiguous` edge looks
like.

The same payload through the other backend is 5.7 KB:

```powershell
New-RenderDocument -ViewModel $viewModel -Meta $meta -TemplateSet plain
```

**From another language**, write the same two objects to a file and hand it
over. Nothing about the payload is PowerShell-shaped:

```bash
python produce.py > graph.json
pwsh -c '$vm = Get-Content graph.json -Raw | ConvertFrom-Json;
         New-RenderDocument -ViewModel $vm.data -Meta $vm.meta > report.html'
```

## Backends

A backend is a rendering *backend*: a directory under `TemplateSets/` holding a
layout, its partials, styles, scripts and four config files.
`cytoscape` is the reference implementation and is not privileged in code;
`plain` renders the same payload as a table in 1% of the bytes.

```
TemplateSets/<name>/
  templateset.psd1     what to assemble, and the Smoke block the browser gate reads
  layout.html          slots: <!--__SLOT_X__--> and /*__SLOT_X__*/
  partials/  styles/  scripts/
  vendor/              libraries, with vendor.psd1 recording source, version and SHA
  Config/
    settings.psd1        current values - what the page DOES
    settings.schema.psd1 type, default, range, group, description
    theme.psd1           colours, fonts, spacing - what it LOOKS LIKE
    strings.psd1         every user-visible string
```

Two rules pay for that split, and both are enforced by tests:

- **Adding a setting must require editing data files only.** If it needs a
  `.ps1`, that is a bug in the design — report it rather than working around it.
- **Adding a backend must not require editing a `.ps1` either.**
  `New-RenderDocument -TemplateSetPath` takes a directory of your own, so a
  backend does not have to ship here to exist.

`KindColor`, `LinkColor` and `EdgeResolutionStyle` are the shape to copy when
something new needs to look different: a map from *the producer's words* to a
style, where the keys are never validated. Validating them would put a
producer's vocabulary back inside the renderer, which is the thing this
repository exists to prevent.

**The shipped `cytoscape` theme names PowerShell kinds** — `Function`, `Class`,
`Enum`, `Script` — because it was extracted from a PowerShell producer. A
payload using other words renders correctly in the fallback colour and looks
monochrome until you ship a `theme.psd1` of your own. The map being data is the
mechanism; the shipped values are one producer's.

## Seeing it

```powershell
./build.ps1 -Task Samples
```

Renders every fixture through every backend into `output/samples/`, with an
`index.html` listing them and their node and link counts. The pages are not
committed — 600 KB each since the libraries were vendored — but screenshots are,
under [`docs/samples/`](docs/samples/).

A payload too large to commit can be rendered without committing it:

```powershell
./build.ps1 -Task Samples -ExtraPayload /path/to/big.json
```

## Build and test

```powershell
./build.ps1                          # lint, build, test, browser harness
./build.ps1 -Task BootstrapBrowser   # once, to install Chromium
./build.ps1 -Task WithoutBrowser     # everything except the browser leg
```

**Node is required and the build fails by name without it.** The browser
harness runs a real headless Chromium **with the network blocked**, so a page
that quietly needed a CDN fails rather than passing on someone's connectivity.

Never call `Invoke-Pester` or `Invoke-Build` directly: `build.ps1` pins Pester
to exactly 6.1.0 and verifies it, and Pester 5 and 6 disagree about enough that
a bare run produces results that mean nothing.

**No test here may import PSModuleGraph, or any producer.** Fixtures are
hand-written JSON under `tests/fixtures/viewmodels/`, and none of them describes
a PowerShell module.

## Where the reasoning lives

| File | Read it when |
| --- | --- |
| [`docs/render-architecture.md`](docs/render-architecture.md) | working in `TemplateSets/` or `Private/`. The authority, including the decision log. |
| [`docs/contract.md`](docs/contract.md) | changing the view model, or writing a producer. |
| [`docs/testing.md`](docs/testing.md) | writing a test. Pester 6 is not Pester 5. |
| [`docs/development.md`](docs/development.md) | changing the module's shape. |
| [`docs/improvements.md`](docs/improvements.md) | the backlog and the size rules for taking from it. |
| `knowledge/ledger/` | why something is the way it is. One entry per release, including what could not be verified. |

## Licence

MIT. See [LICENSE](LICENSE).
