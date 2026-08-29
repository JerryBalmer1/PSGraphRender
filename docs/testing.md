# Testing

On-demand. Read this when writing or changing a test. Two facts come before
everything else here: run `./build.ps1`, and never call `Invoke-Pester` or
`Invoke-Build` directly. `docs/HANDOFF.md` states them and says why.

## Running the suite

```powershell
./build.ps1 -Bootstrap      # install InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
./build.ps1                 # default task: Clean, Lint, Build, Test
./build.ps1 -Task PreTag    # the gates that seal an iteration; see below
./build.ps1 -Task Lint      # analyzer only
```

`build.ps1` pins Pester to exactly 6.1.0 and verifies it before handing off.
Pester 5 and Pester 6 disagree on assertion syntax, discovery, and mocking, and
several 5.x versions are usually also installed - a bare `Invoke-Pester` will
silently pick the wrong one and produce results that mean nothing. Dependency
versions live in `Requirements.psd1`, not in `build.ps1`.

**Node is required and the build fails by name without it** - see
`docs/development.md`. **Fixtures are JSON files under
`tests/fixtures/viewmodels/`**, hand-written and schema-valid.

Both were moved here at v0.11.0 from the always-loaded instruction tier that
this repository no longer has. The *prohibition* on calling `Invoke-Pester`
directly did not move with them, because it is violated from outside this file;
it is in `docs/HANDOFF.md`.

## The two gates in the default build

**Coverage.** `CoveragePercentTarget` only *reports*; the `throw` in the `Test`
task is what fails the run. It sat at 74.88% against a target of 75 through
three green builds before that was noticed. Coverage runs against the built
`output/PSGraphRender/PSGraphRender.psm1`, so line numbers in coverage reports
refer to the generated file.

**The browser gate.** `TestBrowser` fails when the harness is not installed,
rather than skipping. `./build.ps1 -Task BootstrapBrowser` installs it once.
Nothing downloads a browser as a side effect of running the build.

## The `PreTag` gate

`./build.ps1 -Task PreTag` runs only the tests tagged `PreTag`, which the
default `Test` task excludes. They are the seals on a *finished* iteration
rather than checks on work in progress: the build should stay green while an
iteration is half done, and the tag should not.

Three `Describe` blocks, all in `tests/PreTag.Tests.ps1`:

- **The tools this repository is pinned to** — the `Requirements.psd1` floor
  agrees with what CI installs, the npm pin agrees with what CI installs, CI
  installs the browser harness before the build that needs it and runs it on
  exactly one leg, and the legs that do not run it say so.
- **The gates that are not allowed to skip** — `node --check` and the browser
  harness are each invoked from a task that *fails* when the tool is absent,
  rather than one that quietly passes.
- **A filtered run that selects no test at all fails.** The guard on the guard.
  It reads `PassedCount + FailedCount` and never `TotalCount`: `TotalCount`
  counts tests *discovered*, and discovery walks the whole `tests/` path before
  the tag filter applies, so it is never zero and a guard written against it
  can never fire — which is what happened for four annotated tags.

Run it before every annotated tag, after the default build is green.

## Pester 6

The suite runs on Pester 6.1.0 exactly. Pester 6 is not Pester 5.

- **Discovery and run happen per file.** Every test file must carry its own
  `BeforeAll` that dot-sources `tests/TestHelpers.ps1` and imports the module.
  Nothing leaks between files — there is no shared setup to lean on.
- Variables shared from `BeforeAll` into `It` need the `$script:` scope.
- **Use hyphenated `Should-*` assertions**, not `Should -Be`. So `Should-Be`,
  `Should-BeGreaterThan`, `Should-NotBeNull`, `Should-ContainCollection`,
  `Should-MatchString`, `Should-HaveType`. The build sets
  `Should.DisableV5 = $true`, so classic `Should -Be` throws rather than
  quietly working.
- **There is no `Should-NotThrow`.** To assert something does not throw, just
  call it — an exception fails the test on its own. Do not wrap it in
  `try`/`catch` and assert in the catch, which passes when the code is broken in
  a different way. `Should-Throw` does exist.
- **`-ForEach @()` or `-ForEach $null` fails discovery**, not the test, unless
  you also pass `-AllowNullOrEmptyForEach`. A `-ForEach` fed from a computed
  collection needs that switch, or an empty result takes down the whole file.
- **Mocks no longer fall through to the real command when a `-ParameterFilter`
  does not match.** In Pester 5 a missed filter called the original; in 6 it
  does not. Verify filters rather than assuming a fallthrough.
- **`Assert-MockCalled` is gone.** Use `Should-Invoke` / `Should-NotInvoke`.
- Coverage runs against the built `output/PSGraphRender/PSGraphRender.psm1`, not
  `src/`, so line numbers in coverage reports refer to the generated file.
  `CoverageGutters` was removed in Pester 6 — do not add it back.

### The verified assertion list

**These are the `Should-*` assertions Pester 6.1.0 actually exports.** Enumerated
from the installed module, not remembered. **If an assertion is not on this list,
check before writing it** - `Should-Not-BeNullOrEmpty` and then
`Should-NotBeNullOrEmpty` were both invented and both caught at runtime, twice in
one session, and neither exists.

```
Should-All                   Should-Any                   Should-Be
Should-BeAfter               Should-BeBefore              Should-BeCollection
Should-BeEmptyString         Should-BeEquivalent          Should-BeFalse
Should-BeFalsy               Should-BeFasterThan          Should-BeGreaterThan
Should-BeGreaterThanOrEqual  Should-BeHashtable           Should-BeLessThan
Should-BeLessThanOrEqual     Should-BeLikeString          Should-BeNull
Should-BeSame                Should-BeSlowerThan          Should-BeString
Should-BeTrue                Should-BeTruthy              Should-ContainCollection
Should-HaveParameter         Should-HaveType              Should-Invoke
Should-MatchString           Should-NotBe                 Should-NotBeEmptyString
Should-NotBeLikeString       Should-NotBeNull             Should-NotBeSame
Should-NotBeString           Should-NotBeWhiteSpaceString Should-NotContainCollection
Should-NotHaveParameter      Should-NotHaveType           Should-NotInvoke
Should-NotMatchString        Should-Throw
```

To re-derive it after a Pester upgrade:

```powershell
Get-Command -Module Pester -Name 'Should-*' | Select-Object -ExpandProperty Name | Sort-Object
```

Note what is **not** there: no `Should-NotThrow` (just call the code - an
exception fails the test on its own), and **no `Should-NotBeNullOrEmpty`**. For
"not null" use `Should-NotBeNull`; for "not an empty string" use
`Should-NotBeEmptyString`. They are two assertions here, not one.

**Piping an empty array sends nothing down the pipeline.** `@() | Should-NotBeNull`
fails, because the assertion never receives a value at all - it is not asserting
about the array, it is asserting about nothing. This reads as a product bug and
is not one. **Compare, do not pipe:**

```powershell
($null -eq $value) | Should-BeFalse      # right
$value | Should-NotBeNull                # wrong when $value may be @()
```

The same trap applies to any assertion fed from a collection that might be
empty. `@($x).Count | Should-Be 0` is the safe form for asserting emptiness.

A terminating error thrown inside a `BeforeAll` surfaces as a confusing
"a 'break' or 'continue' statement ... escaped from your code" failure on the
whole `Describe`, not as the underlying exception. When a `Describe` fails that
way, call the code under test directly to find the real error.

## The fixture is a payload, not a module

`tests/fixtures/viewmodels/*.json` is what this suite renders. Each file is a
view model on disk and nothing more: no producer runs to make one, and none may.
`sample-module.json` was lifted out of a render taken on the last commit before
the extraction, with the wall-clock stamp and the absolute path it happened at
replaced by fixed values - those describe one run, not a payload.

That provenance is a compromise and worth knowing about. The charter's checklist
still asks for a fixture that was *hand-written*, with no producer anywhere in
its history, because a payload derived from a render can only ever contain
shapes that producer already emits. Until one exists, this suite proves the
renderer needs no producer at runtime, not that it needs none in principle.

## No test here may import a producer

`PSModuleGraph`, or anything else that knows what the nodes mean, stays out of
this suite. A test that reaches for a real dependency graph to get something to
render has re-coupled the two repositories at the only place the coupling was
removed, and it will keep passing long after the seam has rotted.

Fixtures are JSON under `tests/fixtures/viewmodels/`, and
`tests/Render.FromViewModel.Tests.ps1` asserts no producer is loaded before it
asserts anything else. That first assertion is not ceremony: without it the rest
of the file could pass because something else in the session happened to import
one.

## The extraction's acceptance test lives in the other repository

`tests/Extraction.Golden.Tests.ps1` in PSModuleGraph renders its sample module
and compares the document byte for byte against a golden recorded before the
renderer moved out. It normalises three things and no more: the timestamp, the
absolute path the fixture was rendered from, and line endings — `ConvertTo-Json`
emits the platform newline, so the four embedded JSON blocks are CRLF on Windows
and LF elsewhere.

If it goes red, find the cause. Re-recording the golden turns the one artifact
that can detect a regression into a description of it.
