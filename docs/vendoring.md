# Vendoring

On-demand. Read this before adding, replacing or removing a third-party file
under a backend's `vendor/`, and when `tests/Vendor.Tests.ps1` goes red.

`docs/development.md` states the rule in a paragraph. This file is the
provenance, the reasoning and the procedure.

## What is vendored

Third-party files live under `src/PSGraphRender/TemplateSets/<set>/vendor/` and
belong to **that backend, not to the module**. Two backends vendor anything
today, and neither knows what the other vendored:

| Backend | File | Package | Version | Licence |
| --- | --- | --- | --- | --- |
| `cytoscape` | `cytoscape.min.js` | `cytoscape` | 3.34.2 | MIT |
| `cytoscape` | `cytoscape-dagre.min.js` | `cytoscape-dagre` | 4.0.0 | MIT |
| `forcegraph3d` | `3d-force-graph.min.js` | `3d-force-graph` | 1.80.0 | MIT |

**`cytoscape.min.js` is the graph.** `scripts/render.js` calls
`cytoscape({ container: ... })` to build the view in `#cy`, and every element,
style and interaction in the report goes through it. It draws into a canvas,
which is why this backend's smoke check cannot be a DOM assertion — see
`docs/development.md`.

**`cytoscape-dagre.min.js` is the layered layout.** It registers a `dagre`
layout with Cytoscape, which `render.js` runs for the call-flow and test-order
views with a `rankDir` and a `ranker` per view. The foundation view is placed by
`scripts/foundation.js` instead, because no dagre ranker can bound how wide a
layer gets; the reasoning is at the top of that file.

**There is no third file for dagre or graphlib.** `cytoscape-dagre.min.js`
bundles both, and the manifest records that as **verified by inspection of the
built bundle, not assumed from the package name**. The distinction is the whole
value of the note: a package named after a dependency is not evidence that it
ships one, and the cost of guessing wrong is a page that loads and lays out
nothing.

**`3d-force-graph.min.js` is the whole of `forcegraph3d`** — the drawing, the
camera, the pointer interaction and the force simulation that decides where
items go. `scripts/graph.js` calls `ForceGraph3D()` on `#fg` and hands it the
payload's nodes and links; nothing else in that backend draws anything.

**And there is no second file for three.js**, which is the same question
`cytoscape-dagre` raised and had to be answered the same way — by reading the
built bundle, because `3d-force-graph`'s package metadata lists `three` as an
ordinary dependency and that says nothing about what its `dist/` ships. It is
inside: the file carries the `__THREE__` global three.js registers itself under,
the *"Multiple instances of Three.js being imported"* warning that exists only
in three.js's own source, `WebGLRenderer`, `PerspectiveCamera`, `BufferGeometry`,
`MeshLambertMaterial`, the `meshphong_vert` shader chunk and a reference to a
`mrdoob/three.js` issue. It makes no `require()` call and imports nothing. **A
second file here would put a second copy of three.js in the page**, which is
what that warning exists to report.

**It ends with no `sourceMappingURL`**, so this backend does not inherit the
accepted limitation below. Its claim to need nothing survives a developer-tools
session.

### What is NOT in that bundle, and what v0.16.0 did about it

The same question had to be asked a second time when that backend grew a look,
and the answer is not symmetrical — some of what a modern 3D scene wants is in
the file and some of it is not. **Read from the bytes and confirmed in a
browser before a line was written**, because a capability claim about this
library had been wrong before and the requirement-direction gate exists for
exactly that.

| Wanted | In the bundle? | What was found |
| --- | --- | --- |
| custom node objects | yes | `nodeThreeObject`, and a mesh in the scene to take constructors from |
| link particles | yes | `linkDirectionalParticles` and its four companions |
| camera speed | yes | `controls()` returns a live TrackballControls with `zoomSpeed` |
| hover and right-click | yes | `onNodeHover`, `onNodeRightClick`, `onBackgroundRightClick` |
| emissive materials | yes | `MeshLambertMaterial.emissive`, `emissiveIntensity` |
| depth fog | **class gone, support intact** | `FogExp2` appears only as the `isFogExp2` flag; `fogDensity` and `fogColor` uniforms are present |
| **post-processing bloom** | **no** | `UnrealBloomPass` and `ShaderPass` appear **zero** times; `postProcessingComposer()` holds only a render pass |

**Three consequences, and each is a decision rather than a workaround.**

**`THREE` is not a global.** The UMD wrapper exports `ForceGraph3D` and nothing
else, so `new THREE.BoxGeometry(...)` is not available. `scripts/shapes.js`
takes `Mesh`, `MeshLambertMaterial`, `Color`, `BufferGeometry` and the position
attribute's constructor off a mesh the library has already made, and builds
every other geometry from explicit vertices. **That is also why the shapes are
vertex arrays rather than three.js geometry classes**: the bundle is
tree-shaken, and `OctahedronGeometry`, `TetrahedronGeometry`,
`IcosahedronGeometry` and `TorusGeometry` are not in it at all. Reading
constructors off instances would have reached four shapes; vertices reach all
eight and depend on nothing tree-shaking can remove.

**Fog is duck-typed.** `scripts/scene.js` hands the scene an object carrying
`isFogExp2`, a `Color` and a `density`, because that is precisely what the
renderer reads. three.js tests capability with `isXxx` flags rather than
`instanceof` so that objects from elsewhere work; this uses that deliberately.

**There is no bloom, and there will not be one.** `UnrealBloomPass` ships as an
ES module that imports `three`, so vendoring it means vendoring **a second copy
of three.js** — the thing the bundle's own *"Multiple instances of Three.js
being imported"* warning exists to report — and takes the page from 1.4 MB to
roughly 2 MB. So the glow is geometry instead: an emissive core inside an
additively-blended back-face shell, per item. It occludes correctly against
things in front of it and costs one extra mesh rather than three full-frame
passes. **What it cannot do is bleed across the frame the way a real bloom
does, and that is the trade.** `Config/theme.psd1` says so where a reader
setting `GlowStrength` will see it.

## Why they are not loaded from a CDN

**Because the browser gate runs with the network blocked, and a harness that can
reach a CDN has not tested what it thinks it tested.**

`tests/browser/smoke.cjs` routes `http://**` and `https://**` to `route.abort()`
and fails any case that attempted an external request, naming the URLs it tried.
It blocks by host rather than with `context.setOffline`, because the document
under test *is* a `file:` URL and offline mode kills that too.

The deciding measurement was not size. Before v0.5.0 an offline `cytoscape` page
and a broken `render.js` produced **the same signature** — console errors and no
node count — so a red harness meant two things and could not tell them apart.
Vendoring removed one of them, on the day the harness shipped. The cost is
recorded rather than hidden: a report went from 126 KB to 607 KB and every
reader pays it.

It is not a setting. Two code paths and two test matrices, so that a reader can
receive a report they cannot identify, is not a trade this repository takes.

## How they are pinned

**`vendor/vendor.psd1` is the provenance, and a vendored blob without one is
worse than a CDN link** — the link at least says where it came from. It is data,
read with `Import-PowerShellDataFile`, never executed. Each entry carries `Name`,
`Package`, `Version`, `Url`, `Integrity` and `License`.

The files were fetched from jsDelivr, version-pinned in the path:

```
https://cdn.jsdelivr.net/npm/cytoscape@3.34.2/dist/cytoscape.min.js
https://cdn.jsdelivr.net/npm/cytoscape-dagre@4.0.0/dist/cytoscape-dagre.min.js
https://cdn.jsdelivr.net/npm/3d-force-graph@1.80.0/dist/3d-force-graph.min.js
```

`Integrity` is a Subresource Integrity `sha384-` digest over the whole file.
**These are a continuation of a check that already existed, not a new claim**:
they are the same hashes the `<script integrity=...>` attributes carried before
v0.5.0, when the page still fetched the libraries.

### What `tests/Vendor.Tests.ps1` guarantees

It enumerates backends, skips any with no `vendor/` directory, and asserts:

- **`has a backend that vendors something to check`** — the collection every
  other assertion loops over is not empty. An empty one passes them all, which
  is the failure mode of the whole file, so it is stated as its own test.
- **`records where every vendored file came from`** — the set of `Name`s in the
  manifest equals the set of files in `vendor/` other than `vendor.psd1`,
  **in both directions**. A file with no entry is the blob-with-no-provenance
  case being prevented; an entry with no file is a manifest describing something
  that is not there.
- **`states a source URL, a version and a licence for each`** — `Url` starts
  `https://`, `Version` looks like a version, `License` is non-blank, and `Url`
  contains `@<Version>/`. The last is the one that earns its place: the version
  in the URL and the version in the entry are two statements of one fact, so a
  manifest documenting a file nobody fetched fails here.
- **`matches every file against the hash it was verified with`** — recomputes
  sha384 over the bytes on disk and compares with `Integrity`, failing by name
  as `<set>/vendor/<file> does not match its recorded Subresource Integrity
  hash`. This runs on every build. It is what makes replacing a file, changing
  its version and changing its hash one act rather than three that can drift.
- **`names every vendored file in the template set manifest`** — every entry
  appears as `vendor/<name>` in a slot of that set's `templateset.psd1`. See
  below for what goes wrong without it.

A second `Describe` bounds the exclusion these files get from every other scan.
`Test-VendorPath` in `tests/TestHelpers.ps1` is that rule, stated once: **a path
segment named exactly `vendor`**, not a file with the word in its name, not a
directory that merely starts with it. Four scans use it — the two `node --check`
tasks, the producer-vocabulary checks and the classification check — because
none of what they look for means anything in minified code this repository did
not write. The tests assert that what is skipped **equals** what the manifests
declare, and that the scan still reads the backend's own scripts, so the
exclusion can neither quietly widen nor swallow everything. An exclusion nobody
bounds is how the producer-vocabulary check missed four things for three tags.

## Updating one

`tools/Update-Vendor.ps1` does it. It never touches a file no manifest lists,
and it never edits a vendored file's contents: whole-file replacement,
hash-verified, or nothing.

```powershell
./tools/Update-Vendor.ps1 -Verify
./tools/Update-Vendor.ps1 -Update -Name cytoscape.min.js -PinVersion 3.35.0
./tools/Update-Vendor.ps1 -Update -Name cytoscape.min.js -WhatIf
./tools/Update-Vendor.ps1 -Verify -Root /path/to/a/scratch/clone
```

`-Name` takes the manifest's `Name` — the file name, not the `Package`. `-Root`
names a checkout to work in and defaults to this one; it exists so the tool can
be aimed at a scratch copy and **made to go red there**, because a checker
nobody has watched fail is not yet a checker.

- **`-Verify`** re-hashes every file listed in every vendor manifest, compares
  with the recorded `Integrity`, names every file that mismatches or is missing,
  and exits nonzero if any failed. The suite's check without the suite.
- **`-Update [-Name <name>] [-PinVersion <version>]`** fetches the entry's `Url`
  — or that URL with the version substituted, when `-PinVersion` is given — to a
  temp file, computes its integrity, then replaces the vendored file and
  rewrites that entry's `Version`, `Url` and `Integrity` **together, in one
  operation**. Those three are one fact and the tests treat them as one.
- It **refuses on a download failure**, and it **refuses when `-PinVersion`
  asked for a new version and the bytes hash to the value already recorded** —
  that means the fetch did not deliver what was asked for, and writing a new
  version number over unchanged bytes would make the manifest lie.
- **`-WhatIf` is honoured on every state-changing action.**

Commit the file and the manifest together. A file replaced without its manifest
entry fails the build by name, which is the design and not an inconvenience.

### The manual fallback

The formula is in the manifest header and is the whole of what the tool
automates. Fetch `Url`, then:

```powershell
'sha384-' + [Convert]::ToBase64String(
    [Security.Cryptography.SHA384]::Create().ComputeHash(
        [IO.File]::ReadAllBytes($path)))
```

Compare with `Integrity` **before** replacing the file. Then change `Version`,
`Url` and `Integrity` in the same commit.

## The sourceMappingURL a vendored file names and does not ship

`cytoscape-dagre.min.js` ends with a `sourceMappingURL` comment naming
`cytoscape-dagre.min.js.map`, which is **not vendored**. Accepted deliberately;
carried in `docs/constraints.md` as `0005-t4`. Three facts decide it:

- The reference is **relative**, so it resolves against wherever the document
  sits rather than reaching for a CDN.
- It is fetched **only when developer tools are open**. No reader of a report
  ever requests it.
- **Removing it would invalidate the hash.** The comment is inside the bytes the
  `Integrity` digest covers, so stripping it means the vendored file is no
  longer what upstream published, and the one thing that makes a re-download
  checkable is gone. That is a worse trade.

So the page's claim to need nothing is one developer-tools session away from
being tested, and that is the accepted side. **Do not strip the comment.**

### Why the 3D backend's page is twice the size

`examples/threed/forcegraph3d.html` is about 1.4 MB against roughly 620 KB for
the cytoscape rows beside it. The library is larger, it contains a whole 3D
engine, and that is the price of the view. It is recorded here rather than
hidden, the same way the 126 KB → 607 KB cost of vendoring at v0.5.0 was.

## A backend that vendors nothing is not a failure

**`plain` vendors nothing, by design.** It renders tables into the DOM, needs no
library and no layout engine, and it is the one backend that never had a
vendoring question to answer. `Vendor.Tests.ps1` skips a backend with no
`vendor/` directory rather than failing it, and says so where it skips.

Its triviality is the point — see `docs/constraints.md`. A backend that could
not have inherited a Cytoscape assumption is what makes the offline half of the
vendoring decision a demonstration rather than an argument.

## Where a new template set registers its vendored files

Three places. Missing any one of them is a distinct failure with a distinct
symptom:

1. **The file** goes in `src/PSGraphRender/TemplateSets/<set>/vendor/<file>`,
   and nowhere else. `Test-VendorPath` matches a segment named exactly `vendor`,
   so `vendored/`, `myvendor/` and `scripts/vendor-notes.js` are all read as
   this repository's own code by every scan, and a minified library put in one
   of them will fail checks written for source nobody vendored.
2. **An entry under `Files` in
   `src/PSGraphRender/TemplateSets/<set>/vendor/vendor.psd1`**, with `Name`,
   `Package`, `Version`, `Url`, `Integrity` and `License`. **Every file in that
   directory needs an entry and every entry needs its file** — the tests check
   both directions, so a file with no entry and an entry with no file each fail
   by name.
3. **A slot in `src/PSGraphRender/TemplateSets/<set>/templateset.psd1`** naming
   it as `vendor/<file>` in that slot's ordered list. `cytoscape` uses a slot
   called `VENDOR`; the name is the backend's to choose, and the test only asks
   that some slot names the file. **A vendored file no slot names never reaches
   the document, and the page goes blank with the library missing.**

   The order within a slot is the order the contents are concatenated in, and it
   matters: `cytoscape-dagre` registers its layout only if `window.cytoscape` is
   already defined when it runs, so listing an extension before the library it
   extends silently registers nothing.

Nothing above the backend has to know about any of this. A backend needing a
different library brings its own `vendor/` and its own manifest.

## Vendored files are never hand-edited

Not to strip a comment, not to fix a bug, not to shave bytes. **The files are
byte-identical to what the hash covers.** The moment one is edited, the manifest
describes something that was never published anywhere, and nothing can tell a
local edit from a compromised download — which is the entire property the hash
exists to provide.

A change a library needs is an upstream change, a version bump, or a patch the
backend's own code applies at runtime. It is never an edit in `vendor/`.
