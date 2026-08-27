# Sample screenshots

Generated pages are **not** committed — 600 KB each since the libraries were
vendored, regenerated whenever the renderer moves. These are the pictures.

```powershell
./build.ps1 -Task Samples          # writes output/samples/, including index.html
node tools/shoot.cjs <job.json>    # takes the pictures
```

| Picture | Payload | What it shows |
| --- | --- | --- |
| `cytoscape-ambiguous.png` | `ambiguous.json`, 6 nodes | Two definitions of `restart` and a call that could be either. The two dashed, faded edges out of `rollout` are `links[].resolution` of `Ambiguous`. |
| `cytoscape-sample-module.png` | `sample-module.json`, 9 nodes | `KindColor` doing its job — four classifications, four colours — and a gold dashed `Inherits` edge. |
| `cytoscape-infrastructure.png` | `infrastructure.json`, 17 nodes | Hosts and services. No producer wrote it. |
| `cytoscape-sqlserverdsc.png` | 532 nodes, 1,271 links | A real module, and the density case. Not reproducible from a clean checkout — see below. |
| `plain-*.png` | the same four | The other backend. Same payload, a table, 1% of the bytes. |

## The four taken to answer a question

The table above is what the pages look like. These four were taken to settle
a specific open thread, and each one settled it against the answer that was
expected. `knowledge/ledger/0010` says what they showed.

| Picture | The question | What it showed |
| --- | --- | --- |
| `sqlserverdsc-foundation-532.png` | Does the foundation layout hold at 532? It was measured at 62. | It does not break and it stops meaning anything. A lattice of full-width rows under a fog of edges; no line style survives, and only the kind colours still carry. |
| `sqlserverdsc-heat-blastradius.png` | Is the heat ramp legible when the top of the range is far above what it was tuned against? | Yes, for finding the top. Blast radius runs 0 to 281 with half the nodes at 1, and the outliers are unmistakable - but there is no middle, and the 87% at the cold end are one colour. |
| `infrastructure-unresolved.png` | What does an unresolved target actually look like? | Orange node, orange dotted edges, unmissable at 17 nodes. It is also the shot in which two different unresolved targets are drawn as one node. |
| `ambiguous-occlusion.png` | Is `0008-t1` still there? | Yes. `notify-oncall` covers all but three letters of `rollout`, and hides the edge between them. Three device pixels per CSS pixel; not a resolution artefact. |

Reproducing them needs the SqlServerDsc payload for two of the four - see
below - and `tools/shoot.cjs` with a job naming `clicks` for the controls:
`#exported-only` then `#fit` for the 532 view, `#show-unresolved` for the
orange one, and `input[name="colorby"][value="blastRadius"]` for the heat.

## The five pairs

**Every `-before.png` was rendered from a worktree at `v0.11.0`, not from the
working tree**, per `.claude/skills/golden-recording`. A before-shot taken by
reverting an edit is a picture of a reverted edit.

`knowledge/ledger/0013` is what these settled. They are the first change in
this repository verified primarily by eye.

| Pair | Thread | Before | After |
| --- | --- | --- | --- |
| `unresolved-placement-*` | `0010-t3` | One orange node in the top-left corner carrying one of the two names, with two dotted edges leaving it, sitting on `environment`. | Two orange nodes, laid out, each with its own edge. They were always two nodes with two ids - they were never given a position. |
| `occlusion-*` | `0008-t1` | `notify-oncall` covers all but three letters of `rollout` and hides the edge between them. | Both in the bottom row, edge visible. The page also now carries all three line treatments where they can be read. |
| `nodelimit-camera-*` | `0010-t2` | Unchecking "Exported only" leaves the view exactly where it was and adds a single purple blob in the corner - 371 nodes stacked at the origin. | The layout re-runs and the camera moves. It is illegible at 532, which is the accepted constraint in `docs/constraints.md` and not this fix's business. |
| `duplicate-labels-*` | `0008-t2` | Test order reads `drain, window` / `drain, restart` / `restart` - four entries, four different nodes, nothing saying so. | `drain ·api.yaml` / `drain ·web.yaml`, and only where a name is shared. |
| `heat-legend-*` | `0012-t1` | Colour by is followed by nothing; the caveat is in the legend, eight blocks further down a sidebar that scrolls. | The encoding sits under the radios. The same shot carries SqlServerDsc's qualified labels, which is the dense case for the pair above. |

Device pixel ratio differs per pair and is the same on both halves of each:
3 for the two canvases and the small sidebar, 2 for the dense sidebar, 1 for
the 532-node canvas. That is a size decision, not a measurement - and every
judgement made from these inherits one browser, one viewport and this
machine's fonts. `docs/constraints.md`, `0011-t1`.

## The one that is not in the repository

`cytoscape-sqlserverdsc.png` was rendered from a payload PSModuleGraph produced
for SqlServerDsc 17.5.1. The payload is 1.3 MB and is committed nowhere: it
would be megabytes of churn in a history nobody diffs, and it would put a
producer's output inside a repository whose whole claim is that it has no
producer.

To reproduce it, in a PSModuleGraph checkout with the corpus fetched:

```powershell
./gallery/fetch.ps1 -Name SqlServerDsc
$g = Get-PSModuleDependencyGraph -Path ./gallery/modules/SqlServerDsc/17.5.1
$vm = @{
    meta = @{ contractVersion = '1.1.0'; title = 'SqlServerDsc'; version = '17.5.1' }
    data = (Export-PSModuleDependencyGraph -InputObject $g -Format Json -IncludeUnresolved | ConvertFrom-Json)
}
$vm | ConvertTo-Json -Depth 12 | Set-Content sqlserverdsc.json
```

then, here:

```powershell
./build.ps1 -Task Samples -ExtraPayload ../PSModuleGraph/sqlserverdsc.json
```

## What these were for

Four ledger threads all said the same thing: nobody had opened the page. Every
claim about the drawing was about its source. `knowledge/ledger/0008` records
what looking at them actually showed, including the parts that do not work.
