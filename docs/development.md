# Development

On-demand. Read this when changing the module's shape — a file, a command, the
build — not before every session.

## Layout

```
src/PSGraphRender/
  PSGraphRender.psd1     FunctionsToExport is an EXPLICIT list
  Public/                flat; NOT enumerated recursively
  Private/               recursive; a new subfolder needs no registration
    Config/              Resolve-*, Test-RenderSettingValue, constraints
    Document/            escaping, path building, token substitution
    Transport/           loopback probing, browser launch
    Get-HashtableValue.ps1
  TemplateSets/
    cytoscape/           the reference backend, not a privileged one
```

**`Public/` is flat and the manifest's `FunctionsToExport` is explicit.** Those
two rules work together. A helper dropped into `Public/` would be exported by
accident if the list were derived; a new command that nobody adds to the list
builds clean and is unavailable at runtime. `tests/Module.Quality.Tests.ps1`
asserts the exported set matches the list, so the second failure is loud.

`Private/` is enumerated recursively, so a new subfolder is a directory and not
a build change.

## Adding a command

1. One file per function under `Public/` or the right `Private/` subfolder.
2. If it is public, add it to `FunctionsToExport` **and** to the expected list
   in `tests/Module.Quality.Tests.ps1`. The test exists to make the omission
   loud rather than mysterious.
3. Resolve assets from `$script:ModuleRoot`, never `$PSScriptRoot`. See the trap
   list in `CLAUDE.md` — this is the one that only breaks in the built module.

## Adding a setting, a colour, or a string

Data files only, under `TemplateSets/<name>/Config/`. If it needs a `.ps1`, the
design is wrong: report it, do not work around it. A new schema *type* is not a
new setting and may legitimately need a validator in
`Private/Config/Test-HtmlSettingValue.ps1`.

## Adding a backend

A directory under `TemplateSets/`. `Get-RenderTemplateSet -Path` takes a
caller-supplied directory, so a second backend is data.

**This is not yet true of the default.** `Get-RenderTemplateSet` and
`Resolve-RenderConfiguration` each hardcode `TemplateSets/cytoscape` separately,
and nothing makes the two agree. See `docs/improvements.md`.

## The build

```powershell
./build.ps1                 # Clean, Lint, Build, Test
./build.ps1 -Task PreTag    # the extra gates that seal an iteration
./build.ps1 -Bootstrap      # install the pinned dependencies first
```

`Build` concatenates `Private/**` (sorted by full path) then `Public/*` into a
generated `.psm1`, copies the manifest and `TemplateSets/`, and sets
`$script:ModuleRoot` at the top of the generated file.

Dependency versions live in `Requirements.psd1` and nowhere else. CI hashes it
to key the module cache.

## PSModuleGraph resolves this module from a sibling checkout

PSGraphRender is not on the gallery, so PSModuleGraph's build cannot
`Install-Module` it. Its `Dependencies` task looks in two places, in order:

1. `$env:PSGRAPHRENDER_MODULE_PATH` — a directory holding `PSGraphRender/`.
2. `../PSGraphRender/output` — the sibling checkout, built.

It **throws** if neither answers, rather than falling through to whatever is
already on `PSModulePath`. A build that passes because of what happened to be
imported in the session is a build that says nothing.

Building here before building there is the working order. The failure message
names both candidates, so it does not need to be remembered.
