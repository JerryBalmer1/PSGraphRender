# The view model contract

On-demand. Read this when changing the view model, or when writing a producer.

## Status: specified

`contract/viewmodel.schema.json` is the boundary. It is JSON Schema, it is
language-neutral, and it is **versioned independently of the module**: the
contract is 1.0.0 while PSGraphRender is 0.3.0, because the contract is the
product and the module is one implementation of it.

`New-RenderDocument` validates every payload against it and refuses a
`meta.contractVersion` major it does not implement, **by name**. A payload that
declares nothing is warned about and rendered: a payload written before the
field existed must still work, which is the same rule that keeps a renamed field
readable.

On Windows PowerShell 5.1 there is no `Test-Json -SchemaFile`, so validation
reports "could not check" rather than "passed". Those are different facts.

This document explains the schema. The schema is the authority.

## What crosses the seam

Four JSON values, substituted into the assembled template. **A producer never
writes these markers** - they are the contract between `New-RenderDocument` and
a backend's markup, and only a backend author sees them:

| Token | Holds |
| --- | --- |
| `/*__DATA__*/ null` | the payload: whatever the backend's scripts expect |
| `/*__META__*/ null` | who and when: name, version, timestamp, root path, stats |
| `/*__CONFIG__*/ null` | the resolved settings and theme |
| `/*__STRINGS__*/ null` | every user-visible string |

`__PAGE_TITLE__` is substituted separately, as escaped text rather than JSON.

The marker names lost their `GRAPH_` prefix in v0.2.0 and no producer sees them
any more - `New-RenderDocument` is the only thing that knows they exist. A
backend author does see them, and writes them into its own markup.

The JavaScript consts those markers feed are still `GRAPH_DATA` and siblings.
Unlike the markers, those reach the output document, so renaming them is not
covered by byte-identity and waits for 0.3.0.

## Nodes and edges are the renderer's own vocabulary

A node has an id, a label, a set of classifications and a set of measurements.
What it *represents* — a function, a Terraform resource, a Cisco interface — is
the producer's business and never reaches this code. Cytoscape's API is nodes
and edges; that is why those words are permitted here and `Module`, `Ast` and
`Manifest` are not.

## Facets classify; metrics measure

A **facet** is a set of paths a subject carries — one classification per
subject, per facet. A **metric** is one number on a scale.

`ColorBy` takes either. `structure` gives one colour per classification; any
metric id present in the payload gives a heat ramp. The registry that renders
the choices is built from the ids the payload carries, so **a new metric is a
producer-side change plus two strings** and no branch in any script.

Heat is **ranked, not scaled**, and the ramp is five discrete bands. The
reasoning, and the measurements behind it, are in
`docs/render-architecture.md`.

## The rename in 1.0.0

| Was | Is | Why |
| --- | --- | --- |
| `meta.moduleName` | `meta.title` | A Terraform payload was filling it with a region. |
| `meta.moduleVersion` | `meta.version` | Nothing being versioned here has to be a module. |
| `meta.moduleRoot` | `meta.rootPath` | It is a path, not a module. |

**A rename never deletes.** The old names stay in the schema marked
`deprecated` with a `since`, the renderer reads the new name and falls back to
the old, and it warns once naming both. A producer emitting the old names still
works and will keep working.

`data.moduleName`, `data.moduleVersion` and `data.moduleBase` were **removed**
rather than renamed. They duplicated `meta`, `moduleBase` was the same string as
`meta.rootPath`, and nothing had ever read any of them. Renaming a duplicate is
agreeing that a reader needs both copies.

## Paths are relative, and `meta` carries the root

Payload paths are relative to `meta.rootPath`; the page rebuilds absolute paths
in the browser, which is how a `file://` link works while the payload stays
portable.

Note that `meta.rootPath` is itself absolute, so "no absolute paths in a shared
report" is already weaker than it sounds. Do not add absolute paths to
`nodes`/`links` on the assumption it makes no difference.

Payload paths are relative to `meta.rootPath`, which is itself absolute.

## Caller tokens versus display-time tokens

**Caller tokens are filled in PowerShell; display-time tokens are filled in the
page.** `{editorLinkHelpCommand}` is configuration and is substituted at render
time. `{count}`, `{name}` and `{origin}` are only known in the browser and are
left for `fmt()`.

A token nobody fills **stays as written** rather than collapsing to nothing, so
the gap shows up.

`editorLinkHelpCommand` is the pattern to copy for anything new. The producer
supplies the string; the renderer interpolates it and learns nothing. The
renderer ships **no default** — a default would be the renderer knowing a
producer's vocabulary — and when nothing supplies one the page uses a second
message that does not mention a command.

## What a producer does

One call.

```powershell
New-RenderDocument -ViewModel $payload -Meta $meta -Strings $strings -Title 'x'
```

That is the whole interface. A producer does not escape anything, does not know
a marker name, does not know where a backend keeps its settings, and does not
choose a backend unless it wants to (`-TemplateSet`, or `-TemplateSetPath` for
one that ships nowhere near here).

Until v0.2.0 it had to do all of that itself, which is why the module exported
seven functions instead of four and why "a producer in Go could drive this" was
aspirational.
