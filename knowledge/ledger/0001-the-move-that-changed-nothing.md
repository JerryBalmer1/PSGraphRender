---
id: "0001"
tag: v0.1.0
date: 2026-08-26
prompt_intent: Correct two false claims in the charter, give this repository a build it can run, then move the renderer out of PSModuleGraph without renaming one thing - proving it by rendering the same graph through both paths and comparing bytes.
personas: [integrator, skeptic]
open_threads: [0001-t1, 0001-t2, 0001-t3, 0001-t4, 0001-t5]
closes: []
carries_forward: []
prune_proposals: []
supersedes: []
---

# 0001 — the move that changed nothing

## What changed

**The renderer lives here.** Fourteen `.ps1` files and the whole template set
came across from `PSModuleGraph/src/PSModuleGraph/{Private/Html,Assets/Html}`.
`Assets/Html/Templates/` collapsed into `TemplateSets/cytoscape/` and
`Assets/Html/Config/` landed inside it, which is what makes config per-backend
rather than module-level. Seven functions are public; the rest sit under
`Private/{Config,Document,Transport}`.

**Nothing was renamed. Not one function, parameter, setting, string key or
`__GRAPH_*__` token** — including the ones already known to be wrong. That is
not conservatism, it is what makes the proof available:
`tests/Extraction.Golden.Tests.ps1` in PSModuleGraph renders
`tests/fixtures/SampleModule` and compares the document byte for byte against a
golden recorded on the commit before the move. It passes.

**The scaffolding came first, and that ordering was the point.** `build.ps1`
pointed at `PSModuleGraph.build.ps1`, which does not exist here, so every
invocation threw at the last line. Analyzer settings, line-ending policy,
licence and CI were all absent. A safety net added after the fall is not a
safety net.

**PSModuleGraph declares `RequiredModules` and calls across the boundary.**
`Export-PSModuleDependencyGraph -Format Html` keeps its exact signature and
behaviour; `ConvertTo-GraphHtml` and `ConvertTo-ModuleRelativePath` stay there
as the producer side of the seam.

## What I learned

**The comparison found a bug in itself before it found anything else.** The
first golden was rendered from the working tree, where `partials/banner.html`
had CRLF endings while the index had LF — a stale checkout. That golden would
have failed on any fresh clone, and the failure would have looked like the move
breaking something. Re-recorded from `git worktree add` of the pre-move commit,
which is the only version that is reproducible.

**`ConvertTo-Json` emits the platform newline**, so the four embedded JSON blocks
are CRLF on Windows and LF elsewhere while the surrounding document is LF. The
byte comparison normalises exactly three things — timestamp, the absolute path
the render happened at, line endings — and each is a property of the machine or
the moment rather than of the rendering. It normalises the path by reading
`meta.moduleRoot` back out of the document and blanking every occurrence, rather
than naming fields: `moduleBase` carries the same absolute path and a list of
field names would grow every time another appeared.

**The stated public surface was four functions and the real one is seven.**
`ConvertTo-GraphHtml` also calls `ConvertTo-EscapedHtmlJson`,
`ConvertTo-EscapedHtmlText` and `Resolve-HtmlString`, and does its own token
substitution against the assembled template. Exporting them was the only option
that kept the iteration provable; the alternative — moving that work behind the
seam — changes what a producer does and is a proposal, not an edit.

**Collapsing `Templates/` needed more than pointing a default, and the extra is
a design bug.** `Get-HtmlTemplateSet`, `Resolve-HtmlConfiguration` and
`Resolve-HtmlString` each hardcode where the backend lives, independently. In
the old layout `Config/` and `Templates/` were siblings and config was
module-level, so nothing had to agree. Per-backend config exposed it: **adding a
second backend today means editing three `.ps1` files**, which the charter says
is a bug in the design rather than work to be done.

**Twenty-seven tests broke, all of them tests of moved code.** Four test files
came across with the functions they exercise. Two assertions in
`Export-PSModuleDependencyGraph.Html.Tests.ps1` were about what shipped beside
the producer rather than about the producer, and belong here.

**How the dependency resolves at dev time is a decision, so it was made
explicitly.** PSModuleGraph's build gained a `Dependencies` task that looks at
`$env:PSGRAPHRENDER_MODULE_PATH` then `../PSGraphRender/output`, and **throws**
rather than falling through to whatever is on `PSModulePath`. A build that
passes because of what happened to be imported in the session is a build that
says nothing.

## What I could not verify

The Skeptic's section. It is never empty.

- **That byte-identity on one fixture proves the move.** It proves it for one
  shape of graph: nine nodes, five links, two classes, one enum, nine unresolved
  targets. It exercises no cycle, no metric at the top of its range, no label
  needing escaping, no path with a space in it. A second fixture with a
  deliberately awkward shape would cost little and is not here. Opened as
  `0001-t1`.
- **That the golden is reproducible anywhere but this machine.** It has been
  rendered on Windows, on one checkout, once. The three normalisations are an
  argument that it should survive Linux and a fresh clone; CI has not run.
  Opened as `0001-t2`.
- **That `tests/fixtures/viewmodels/sample-module.json` proves producer
  independence.** It proves the renderer needs no producer *at runtime*. It was
  lifted out of a real render, so every shape in it is a shape that producer
  already emits — it cannot prove the renderer would accept a payload describing
  something that is not code. The checklist still asks for a hand-written one.
- **That 71.56% line coverage means the moved code is tested.** The suite that
  came across covers transport and config well and the document path through one
  fixture render. The target is set at 70 because that is what the suite
  reaches, not because 70 is a standard anyone defends.
- **That `Show-GraphDocument`'s tests still test the right thing here.** They
  mock the probe and assert on what gets opened. They passed unchanged, which is
  either evidence the move was clean or evidence they were never touching the
  boundary that moved.
- **That the seven-function public surface is stable.** It is seven because of
  what one producer happens to call, not because seven things belong on a
  boundary. A second producer would probably need a different set, which is the
  argument for `New-RenderDocument` and against this shape.
- **That nothing else in PSModuleGraph reached into the moved code.** The
  dependency scan was a name-by-name grep over function definitions. A call
  built from a string, or a name shared with something else, would not show up.

### Prune, this iteration

A move: none — `CLAUDE.md` gained nothing. A deletion proposal: none.

### Always-loaded bytes

**13,659 / 13,659.** The ceiling is set to the measured weight, not to the
10,000 the file's own prose claims. That number was asserted before the file
existed and has never once been true; a gate set to an aspiration is a red test
that gets deleted. This establishes the baseline. The ratchet governs what
happens next, and what happens next is that iteration 2 prunes it — logged on
the charter's checklist and in `docs/improvements.md` with the candidates named.

## Open threads

1. **[0001-t1] One fixture, one shape.** Byte-identity is proved for a graph
   with no cycle, no escaping-hostile label and no metric at range. The cheapest
   honest next step is a second golden from a deliberately awkward fixture, not
   a bigger assertion on this one.
2. **[0001-t2] The golden has never been compared on another machine.** Three
   normalisations are an argument that it survives Linux and a fresh clone. CI
   has not run in either repository since the split.
3. **[0001-t3] The default backend is hardcoded in three places.** The rule that
   pays for the config split is currently failing: a second backend is three
   `.ps1` edits. Reported rather than worked around, as the charter requires.
4. **[0001-t4] A producer escapes and substitutes for itself.** Three of the
   seven public functions exist only because `ConvertTo-GraphHtml` does work
   that `New-RenderDocument` would do behind the seam. A producer written in Go
   would have to reimplement all of it.
5. **[0001-t5] `Get-HashtableValue` now exists in both repositories.** Copied
   rather than moved, because ten functions in PSModuleGraph still need it. It
   carries no domain knowledge, so the duplication is safe today and will drift.
