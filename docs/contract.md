# The view model contract

On-demand. Read this when changing the view model, or when writing a producer.

## Status: described, not yet specified

`contract/viewmodel.schema.json` does not exist. This document describes the
shape the renderer accepts **today**, derived from the one producer that exists,
and it is not a specification: it has no version, nothing validates against it,
and a producer that follows it exactly may still hit a field the renderer reads
and this file forgot.

Writing the schema is on the extraction checklist in
`docs/render-architecture.md`. Until it lands, treat everything here as a
report on the current state.

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

## Paths are relative, and `meta` carries the root

Payload paths are relative to `meta.moduleRoot`; the page rebuilds absolute
paths in the browser, which is how a `file://` link works while the payload
stays portable.

Note that `meta.moduleRoot` is itself absolute, so "no absolute paths in a
shared report" is already weaker than it sounds. Do not add absolute paths to
`nodes`/`links` on the assumption it makes no difference.

`meta.moduleName`, `meta.moduleVersion` and `meta.moduleBase` are producer
vocabulary sitting in the contract. They are on the checklist.

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
