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
