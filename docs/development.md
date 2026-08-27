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
./build.ps1                 # Clean, Lint, LintJavaScript, Build, LintDocument, Test
./build.ps1 -Task PreTag    # the extra gates that seal an iteration
./build.ps1 -Bootstrap      # install the pinned PowerShell modules first
```

**Node is required and the build fails without it.** `-Bootstrap` installs
PowerShell modules and deliberately does not install tools: a build script that
silently puts a runtime on a developer's machine is not a build script. Install
Node 18 or later yourself, from <https://nodejs.org> or `winget install
OpenJS.NodeJS.LTS`, and the floor is pinned under `Tools` in
`Requirements.psd1`.

Three tasks use it, and none skips when it is absent. `LintJavaScript` runs
`node --check` over every `.js` in every backend except `vendor/`.
`LintDocument` renders a fixture through every backend and runs `node --check`
over the inline `<script>` blocks of the result, which is what the browser
actually receives. Each catches what the other cannot: the first covers files no
`templateset.psd1` names, the second covers the splice.

`TestBrowser` loads every backend's render of every fixture in headless
Chromium with `http` and `https` blocked, and fails on a console error, a count
that does not match the payload, or a view that drew nothing. It needs a browser
and the install is explicit:

```powershell
./build.ps1 -Task BootstrapBrowser   # npm install, then Chromium (~500 MB)
```

Parsing is not running: a script can parse perfectly and throw on its first
line. `node --check` cannot see that and this can.

What "alive" means is declared per backend, as data, in `templateset.psd1` under
`Smoke` — the harness names no selector and knows no backend. A backend with no
`Smoke` block fails the task rather than being skipped. Cytoscape draws into a
canvas, so a DOM assertion cannot tell a graph from a blank rectangle; its
`MinScreenshotBytes` compares a PNG of `#cy` against a floor measured between a
drawn view and an empty one.

## Vendored libraries

`TemplateSets/<name>/vendor/` holds third-party files, named in
`templateset.psd1` like any other asset and inlined into the document, so a
report needs no network. They belong to the backend, not the module: a backend
needing a different library brings its own and nothing above it knows.

`vendor/vendor.psd1` records each file's source URL, version, licence and the
SRI hash it was verified against. `tests/Vendor.Tests.ps1` recomputes every hash
on every run, so replacing a file without updating the manifest fails the build.
To update one, fetch the URL, compare the hash **before** replacing the file,
and change file, version and hash in one commit. Never edit a vendored file:
the hash is the only thing that makes a re-download checkable.

Four scans over backend files skip `vendor/` — the two `node --check` tasks, the
producer-vocabulary checks and the classification check. The rule is one path
segment named exactly `vendor`, in `Test-VendorPath`, and
`tests/Vendor.Tests.ps1` asserts what is skipped equals what the manifests
declare, so the exclusion cannot quietly widen.

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

## Traps that survived the move

Moved down a tier from `CLAUDE.md` at v0.2.0. Every one of these cost a round
in the original repository, and none of them is stylistic - but none is true
before the work is known either, which is what the always-loaded tier is for.


These cost a round each in the original repository. They are not stylistic.

- **Token substitution uses `[string]::Replace()`, never the `-replace`
  operator.** `-replace` is regex. Both the embedded JSON and the CSS contain
  `$` and `\`, which the regex engine treats as substitution patterns and eats.
  The result is subtly corrupted output rather than an error.
- **Template parts are read verbatim and must not end with a trailing newline.**
  Stripping one on read is indistinguishable from deleting a deliberately blank
  last line, and ten of the shipped parts have one.
- **Embedded JSON escapes `<` as `\u003c`**, so a `</script>` inside a path or
  a label cannot terminate the script block.
- **HTML is written UTF-8 without a BOM.** A BOM ahead of `<!DOCTYPE html>` can
  put a browser into quirks mode.
- **Resolve assets from `$script:ModuleRoot`, never `$PSScriptRoot`.**
  `$PSScriptRoot` is per-file: under the dev loader a file in a subfolder sees
  that subfolder, while in the built module the same code has been concatenated
  into a `.psm1` at the module root. Either loader works and the other breaks,
  and the break only shows up in the built module.
- **`Import-PowerShellDataFile` needs `-ErrorAction Stop`.** A `.psd1` that will
  not parse raises a **non-terminating** error, so without it the `catch` never
  runs and a broken config falls back in total silence.
- **`isEmbeddedContext()` checks the user agent for `Electron/` and that check
  is not redundant.** An editor preview pane is genuinely top-level, is served
  over `file:`, and reports no ancestor origins, so the frame check, the
  `vscode-webview:` check and the `ancestorOrigins` check all pass it as a
  normal browser. It is not one. Before concluding a browser is blocking a
  custom scheme, read `navigator.userAgent` in the Diagnostics block.
