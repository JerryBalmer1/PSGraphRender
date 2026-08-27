#Requires -Module @{ ModuleName = 'InvokeBuild'; ModuleVersion = '5.11.0' }

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$script:ModuleName = 'PSGraphRender'
$script:SrcRoot = Join-Path (Join-Path $BuildRoot 'src') $ModuleName
$script:OutRoot = Join-Path (Join-Path $BuildRoot 'output') $ModuleName
$script:ManifestPath = Join-Path $SrcRoot "$ModuleName.psd1"
$script:TestsRoot = Join-Path $BuildRoot 'tests'
$script:AnalyzerSettings = Join-Path $BuildRoot 'PSScriptAnalyzerSettings.psd1'

function Resolve-BuildTool {
    <#
    .SYNOPSIS
        A tool the build shells out to, at or above the version Requirements.psd1
        pins, or a throw naming what is missing.
    .DESCRIPTION
        Absent is a failure and so is too old. A gate that runs under whatever
        happens to be on PATH reports on that machine rather than on the code,
        which is the same reason Pester is pinned exactly.
    #>
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Command,
        [Parameter(Mandatory)] [string] $Purpose
    )

    $requirements = Import-PowerShellDataFile -LiteralPath (Join-Path $BuildRoot 'Requirements.psd1') -ErrorAction Stop
    $floor = [version]$requirements.Tools[$Name].MinimumVersion

    $tool = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $tool) {
        # By name, not by skipping. A gate that quietly does nothing when its
        # tool is missing is worse than no gate: it reports success for the one
        # environment where it checked nothing.
        throw ("$Command was not found on PATH, and $Purpose. " +
            "Install $Name $floor or later and re-run - see docs/development.md. " +
            'This task fails rather than skipping, deliberately.')
    }

    $reported = (& $tool.Source --version 2>&1 | Select-Object -First 1) -replace '^v', ''
    $found = $null
    if (-not [version]::TryParse(($reported -split '-')[0], [ref]$found)) {
        throw "$Command --version reported '$reported', which is not a version. Cannot tell whether it meets the $Name floor of $floor."
    }
    if ($found -lt $floor) {
        throw "$Command is $found and Requirements.psd1 pins $Name at $floor or later."
    }

    [pscustomobject]@{ Path = $tool.Source; Version = $found }
}

task Clean {
    if (Test-Path -LiteralPath (Join-Path $BuildRoot 'output')) {
        Remove-Item -LiteralPath (Join-Path $BuildRoot 'output') -Recurse -Force
    }
}

task Lint {
    # Rule configuration lives in PSScriptAnalyzerSettings.psd1 so editors and
    # CI lint identically to this task.
    $templateSets = Join-Path $SrcRoot 'TemplateSets'

    $results = @(
        Get-ChildItem -LiteralPath $SrcRoot -Directory |
            Where-Object { $_.FullName -ne $templateSets } |
            ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Recurse -Settings $AnalyzerSettings }
    )
    $results += @(
        Get-ChildItem -LiteralPath $SrcRoot -File |
            ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $AnalyzerSettings }
    )

    # A backend's four data files are configuration, not a module manifest, and
    # PSMissingModuleManifestField cannot tell the difference - it fires on the
    # .psd1 extension alone. It reported a backend whose settings.psd1 is empty,
    # which is a legitimate thing for a backend with no behaviour to decide.
    #
    # Excluded HERE rather than in PSScriptAnalyzerSettings.psd1, so the rule
    # still guards the one file it is actually about: the module manifest.
    if (Test-Path -LiteralPath $templateSets) {
        $results += @(Invoke-ScriptAnalyzer -Path $templateSets -Recurse -Settings $AnalyzerSettings `
                -ExcludeRule PSMissingModuleManifestField)
    }

    if ($results) {
        $results | Format-Table -AutoSize | Out-String | Write-Host
        throw "PSScriptAnalyzer reported $($results.Count) issue(s)."
    }
}

task LintJavaScript {
    # The renderer's largest component is JavaScript and until now nothing in
    # either repository could tell whether it parsed. render.js was restructured
    # by about a hundred lines in v0.3.0 and the only thing that would have said
    # so is a browser nobody ran.
    #
    # A hand-rolled brace counter was tried first and reported a false positive
    # on known-good output, because it cannot tell a regex literal from a
    # division. The lesson is not to write a better counter.
    $node = Resolve-BuildTool -Name Node -Command node -Purpose 'backend scripts cannot be syntax-checked without it'

    $templateSets = Join-Path $SrcRoot 'TemplateSets'

    # vendor/ is excluded, by a path segment named exactly that and nothing
    # wider. A 435 KB minified bundle parses fine and takes a second to say so,
    # and it is not this repository's syntax to check. tests/Vendor.Tests.ps1
    # asserts the exclusion matches what the backend manifests declare as
    # vendored - an exclusion nobody bounds is how the vocabulary check missed
    # four things for three tags.
    $scripts = @(
        Get-ChildItem -LiteralPath $templateSets -Filter *.js -File -Recurse |
            Where-Object { $_.FullName.Split([char]92, [char]47) -notcontains 'vendor' }
    )
    if ($scripts.Count -eq 0) {
        throw "No .js found under $templateSets. The check found nothing to check, which is not the same as passing."
    }

    $failed = @()
    foreach ($file in $scripts) {
        # --check parses and discards. It reports a SyntaxError with a line and
        # a caret, which is the whole value; nothing here needs to run the file.
        $output = & $node.Path --check $file.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            $relative = $file.FullName.Substring($templateSets.Length).TrimStart('\', '/')
            $failed += "$relative`n$($output -join [Environment]::NewLine)"
        }
    }

    if ($failed) {
        $failed | ForEach-Object { Write-Host $_ }
        throw "node --check rejected $($failed.Count) backend script(s)."
    }

    Write-Build Green "JavaScript: $($scripts.Count) script(s) parse (node $($node.Version))"
}

task LintDocument Build, {
    # The stronger half of the same question. A backend's scripts are spliced
    # into one <script> block, so each file parsing on its own does not settle
    # whether what the browser receives does - and the assembled form is the
    # only one that ever runs. Neither replaces the other: this covers only the
    # files a templateset.psd1 names, and the per-file task covers the rest.
    $node = Resolve-BuildTool -Name Node -Command node -Purpose 'the assembled document cannot be syntax-checked without it'

    Import-Module (Join-Path $OutRoot "$ModuleName.psd1") -Force -ErrorAction Stop

    $fixture = Join-Path $TestsRoot 'fixtures/viewmodels/infrastructure.json'
    $payload = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
    $backends = @(
        Get-ChildItem -LiteralPath (Join-Path $OutRoot 'TemplateSets') -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') }
    )

    $scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-lint-$PID"
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    try {
        $failed = @()
        $blocks = 0
        foreach ($backend in $backends) {
            $document = New-RenderDocument -ViewModel $payload.data -Meta $payload.meta `
                -Title 'lint' -TemplateSet $backend.Name

            # Inline blocks only. A <script src=...> is somebody else's file and
            # is not in this document to be parsed.
            $inline = [regex]::Matches($document, '(?s)<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>')
            foreach ($match in $inline) {
                $blocks++
                $path = Join-Path $scratch "$($backend.Name)-$blocks.js"
                [System.IO.File]::WriteAllText($path, $match.Groups[1].Value)
                $output = & $node.Path --check $path 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $failed += "$($backend.Name) inline block $blocks`n$($output -join [Environment]::NewLine)"
                }
            }
        }

        if ($blocks -eq 0) {
            throw 'No inline script found in any rendered document. Nothing was checked, which is not the same as passing.'
        }
        if ($failed) {
            $failed | ForEach-Object { Write-Host $_ }
            throw "node --check rejected $($failed.Count) assembled script block(s)."
        }

        Write-Build Green "Documents: $blocks assembled block(s) parse, across $($backends.Count) backend(s)"
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

task BootstrapBrowser {
    # EXPLICIT. Nothing installs a browser as a side effect of running the
    # build: 500 MB of Chromium arriving because someone typed ./build.ps1 is
    # not a bootstrap, it is a surprise. TestBrowser fails by name and points
    # here, the same way the node gates fail by name.
    $node = Resolve-BuildTool -Name Node -Command node -Purpose 'the browser harness cannot be installed without it'
    # npm-cli.js under node, not the npm shim. The shim is a .ps1 on Windows
    # and mangles its own arguments under some hosts - it reported
    # 'Unknown command: "pm"' here - and node running the CLI directly is the
    # same program without the wrapper.
    $npmCli = Join-Path (Split-Path -Parent $node.Path) 'node_modules/npm/bin/npm-cli.js'
    if (-not (Test-Path -LiteralPath $npmCli)) {
        throw "npm was not found beside node at $($node.Path). Install a Node distribution that includes npm and re-run."
    }

    $harness = Join-Path $TestsRoot 'browser'
    Write-Build Green "Installing the browser harness into $harness ..."
    Push-Location $harness
    try {
        exec { & $node.Path $npmCli install --no-audit --no-fund }

        Write-Build Green 'Downloading Chromium ...'
        $cli = Join-Path $harness 'node_modules/playwright/cli.js'

        # Linux needs the shared libraries Chromium links against and they are
        # not in a bare container image. On Windows and macOS the browser is
        # self-contained and --with-deps has nothing to do.
        $onWindows = $env:OS -eq 'Windows_NT' -or $PSVersionTable.PSEdition -eq 'Desktop'
        if (-not $onWindows -and $IsLinux) {
            exec { & $node.Path $cli install --with-deps chromium }
        }
        else {
            exec { & $node.Path $cli install chromium }
        }
    }
    finally { Pop-Location }

    Write-Build Green 'Browser harness ready. ./build.ps1 -Task TestBrowser'
}

task TestBrowser Build, {
    # THE GATE THIS REPOSITORY DID NOT HAVE. Everything else asserts on text
    # PowerShell produced; this is the only thing that establishes a browser
    # can run the page.
    #
    # Every backend, every fixture, network blocked. Not "network available and
    # unused" - a harness that can reach a CDN has not tested what it thinks,
    # which is the ambiguity that decided the vendoring question.
    $node = Resolve-BuildTool -Name Node -Command node -Purpose 'the page cannot be run without it'

    $harness = Join-Path $TestsRoot 'browser'
    $playwright = Join-Path $harness 'node_modules/playwright'
    if (-not (Test-Path -LiteralPath $playwright)) {
        # By name, not by skipping. Same rule as node: a gate that quietly does
        # nothing reports success for the environment where it checked nothing.
        throw ('The browser harness is not installed. Run ./build.ps1 -Task BootstrapBrowser first. ' +
            'This task fails rather than skipping, deliberately.')
    }

    $requirements = Import-PowerShellDataFile -LiteralPath (Join-Path $BuildRoot 'Requirements.psd1') -ErrorAction Stop
    $pinned = $requirements.Tools.Playwright.RequiredVersion
    $installed = (Get-Content -LiteralPath (Join-Path $playwright 'package.json') -Raw | ConvertFrom-Json).version
    if ($installed -ne $pinned) {
        throw "Playwright $installed is installed and Requirements.psd1 pins $pinned. Re-run ./build.ps1 -Task BootstrapBrowser."
    }

    Import-Module (Join-Path $OutRoot "$ModuleName.psd1") -Force -ErrorAction Stop

    $backends = @(
        Get-ChildItem -LiteralPath (Join-Path $OutRoot 'TemplateSets') -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') }
    )
    $fixtures = @(Get-ChildItem -LiteralPath (Join-Path $TestsRoot 'fixtures/viewmodels') -Filter *.json -File)
    if ($backends.Count -eq 0 -or $fixtures.Count -eq 0) {
        throw 'No backend or no fixture to run. The harness found nothing to check, which is not the same as passing.'
    }

    $scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-browser-$PID"
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    try {
        $cases = @(
            foreach ($backend in $backends) {
                $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $backend.FullName 'templateset.psd1')
                if (-not $manifest.Contains('Smoke')) {
                    throw ("$($backend.Name) declares no Smoke block in templateset.psd1, so nothing states what " +
                        'a live page looks like for it. A backend the harness cannot check is a backend the harness skips.')
                }

                # The same backend rendering nothing. This is the floor the
                # harness compares a drawn view against, and it is rendered
                # here rather than pinned as a number so the comparison is
                # made on whatever machine is running - see CanvasGrowth in
                # templateset.psd1.
                $baseline = Join-Path $scratch "$($backend.Name)-EMPTY.html"
                [System.IO.File]::WriteAllText($baseline, (New-RenderDocument `
                            -ViewModel ([pscustomobject]@{ nodes = @(); links = @() }) `
                            -Title 'empty' -TemplateSet $backend.Name))

                foreach ($fixture in $fixtures) {
                    $payload = Get-Content -LiteralPath $fixture.FullName -Raw | ConvertFrom-Json
                    $document = New-RenderDocument -ViewModel $payload.data -Meta $payload.meta `
                        -Title 'smoke' -TemplateSet $backend.Name

                    $file = Join-Path $scratch "$($backend.Name)-$($fixture.BaseName).html"
                    [System.IO.File]::WriteAllText($file, $document)

                    @{
                        backend  = $backend.Name
                        fixture  = $fixture.BaseName
                        path     = $file
                        baseline = $baseline
                        counts   = @{
                            nodes = @($payload.data.nodes).Count
                            links = @($payload.data.links).Count
                        }
                        smoke    = $manifest.Smoke
                    }
                }
            }
        )

        $jobFile = Join-Path $scratch 'job.json'
        [System.IO.File]::WriteAllText($jobFile, (@{ cases = $cases } | ConvertTo-Json -Depth 12))

        $output = & $node.Path (Join-Path $harness 'smoke.cjs') $jobFile 2>&1
        $exit = $LASTEXITCODE
        $text = ($output | Out-String)

        if ($exit -ne 0) {
            Write-Host $text
            throw "The browser harness reported failures across $($cases.Count) case(s)."
        }

        $report = $text | ConvertFrom-Json
        foreach ($m in $report.canvas) {
            Write-Build Green ("  canvas $($m.case) $($m.selector): $($m.drawn) bytes drawn against $($m.empty) empty" +
                " - ratio $($m.ratio), required $($m.required)")
        }
        Write-Build Green ("Browser: $($report.cases) page(s) came alive, network blocked, across " +
            "$($backends.Count) backend(s) and $($fixtures.Count) fixture(s) at " +
            "$($report.viewport.width)x$($report.viewport.height)@$($report.deviceScaleFactor)x")
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

task Build Clean, {
    New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null

    # Copy manifest
    Copy-Item -LiteralPath $ManifestPath -Destination (Join-Path $OutRoot "$ModuleName.psd1") -Force

    # Compose psm1 from private + public functions
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Auto-generated by PSGraphRender.build.ps1 — do not edit.')
    [void]$sb.AppendLine('Set-StrictMode -Version Latest')
    # Every source file is concatenated here at the module root, so $PSScriptRoot
    # differs from what the same code sees under the dev loader. Assets resolve
    # from $script:ModuleRoot in both. See Get-RenderAssetPath.
    [void]$sb.AppendLine('$script:ModuleRoot = $PSScriptRoot')
    [void]$sb.AppendLine()

    $privateDir = Join-Path $SrcRoot 'Private'
    if (Test-Path -LiteralPath $privateDir) {
        # Recurse so Private/Html/*.ps1 is included. Sort by FullName, not Name,
        # so ordering is stable across subfolders.
        Get-ChildItem -Path $privateDir -Filter *.ps1 -File -Recurse | Sort-Object FullName | ForEach-Object {
            $relative = $_.FullName.Substring($privateDir.Length).TrimStart('\', '/')
            [void]$sb.AppendLine("# region $relative")
            [void]$sb.AppendLine((Get-Content -LiteralPath $_.FullName -Raw))
            [void]$sb.AppendLine("# endregion")
            [void]$sb.AppendLine()
        }
    }

    # Deliberately NOT recursive: the export list is derived from these
    # filenames, so Public/ must stay flat.
    $publicDir = Join-Path $SrcRoot 'Public'
    $publicNames = @()
    if (Test-Path -LiteralPath $publicDir) {
        Get-ChildItem -Path $publicDir -Filter *.ps1 -File | Sort-Object Name | ForEach-Object {
            $publicNames += [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            [void]$sb.AppendLine("# region $($_.Name)")
            [void]$sb.AppendLine((Get-Content -LiteralPath $_.FullName -Raw))
            [void]$sb.AppendLine("# endregion")
            [void]$sb.AppendLine()
        }
    }

    if ($publicNames.Count -gt 0) {
        $exportList = ($publicNames | ForEach-Object { "'$_'" }) -join ', '
        [void]$sb.AppendLine("Export-ModuleMember -Function @($exportList)")
    }

    $outPsm1 = Join-Path $OutRoot "$ModuleName.psm1"
    [System.IO.File]::WriteAllText($outPsm1, $sb.ToString())

    # Copy any other root files (formats, types, etc.)
    Get-ChildItem -Path $SrcRoot -File | Where-Object {
        $_.Extension -notin @('.psd1', '.psm1') -and $_.Name -ne '.gitkeep'
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $OutRoot $_.Name) -Force
    }

    # Copy the template sets. Each subdirectory is one rendering backend,
    # shipped as-is; there is no bundler. tests/Module.Quality.Tests.ps1 asserts
    # every file a templateset.psd1 names lands in the output.
    $templateSetsDir = Join-Path $SrcRoot 'TemplateSets'
    if (Test-Path -LiteralPath $templateSetsDir) {
        Copy-Item -LiteralPath $templateSetsDir -Destination $OutRoot -Recurse -Force
        $setCount = @(Get-ChildItem -Path (Join-Path $OutRoot 'TemplateSets') -Directory).Count
        $fileCount = @(Get-ChildItem -Path (Join-Path $OutRoot 'TemplateSets') -File -Recurse).Count
        Write-Build Green "  template sets: $setCount backend(s), $fileCount file(s)"
    }

    # The contract ships WITH the module, not only in the repository. A
    # renderer that cannot read the schema it validates against is a renderer
    # that silently stops validating - and contract/ lives at the repository
    # root rather than under src/ because it is versioned independently and is
    # the product, not part of one implementation of it.
    $contractDir = Join-Path $BuildRoot 'contract'
    if (Test-Path -LiteralPath $contractDir) {
        Copy-Item -LiteralPath $contractDir -Destination $OutRoot -Recurse -Force
        Write-Build Green "  contract: $(@(Get-ChildItem -Path (Join-Path $OutRoot 'contract') -File -Recurse).Count) file(s)"
    }

    # Copy culture directories (en-US, fr-FR, ...) so Get-Help finds about_ topics.
    Get-ChildItem -Path $SrcRoot -Directory |
        Where-Object { $_.Name -match '^[a-z]{2}(-[A-Za-z]{2,4})?$' } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $OutRoot -Recurse -Force
            Write-Build Green "  help: $($_.Name)"
        }

    Write-Build Green "Built $ModuleName -> $OutRoot"
}

task Test Build, {
    $pesterModule = Get-Module -Name Pester -ListAvailable |
        Where-Object { $_.Version -ge [version]'6.0.0' -and $_.Version -lt [version]'7.0.0' } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $pesterModule) {
        throw 'Pester 6.x is required. Run ./build.ps1 -Bootstrap'
    }

    Import-Module -Name $pesterModule.Path -Force

    $outputParent = Join-Path $BuildRoot 'output'

    $config = New-PesterConfiguration
    $config.Run.Path = $TestsRoot
    # Throw, not Exit: Run.Exit makes Pester call exit, which can terminate the
    # host process running the build. Throw raises inside InvokeBuild, which
    # fails the task properly and lets the rest of the build react.
    $config.Run.Throw = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'

    # Classic 'Should -Be' throws, so the suite cannot drift back to v5 style.
    $config.Should.DisableV5 = $true

    # PreTag tests are seals on a FINISHED iteration, not checks on work in
    # progress. The build should stay green while an iteration is half done;
    # the tag should not. ./build.ps1 -Task PreTag runs them.
    $config.Filter.ExcludeTag = 'PreTag'

    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $outputParent 'testResults.xml'
    $config.TestResult.OutputFormat = 'NUnitXml'

    # Cover the built module, which is what the tests actually import.
    # CoverageGutters was removed in Pester 6 - do not add it back.
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = Join-Path $OutRoot "$ModuleName.psm1"
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = Join-Path $outputParent 'coverage.xml'
    # 80, against 83.33% measured at v0.2.0. It was 70 against 71.56% when the
    # renderer arrived; the config resolvers' own tests came across and a second
    # backend and a hand-written fixture arrived with theirs. The number follows
    # what the suite reaches - a target nobody has seen fail is a target nobody
    # knows works.
    $config.CodeCoverage.CoveragePercentTarget = 80

    # Ensure built module is preferred on PSModulePath for tests that Import-Module by name
    $env:PSModulePath = $outputParent + [System.IO.Path]::PathSeparator + $env:PSModulePath

    $result = Invoke-Pester -Configuration $config

    # CoveragePercentTarget only REPORTS. It has never once failed a run, and a
    # threshold nobody has seen fail is a threshold nobody knows works - this
    # sat at 74.88% against a target of 75 through three green builds. The
    # throw is the gate; the setting above is just the number it reads.
    $coverage = $result.CodeCoverage
    if ($coverage) {
        $percent = [math]::Round($coverage.CoveragePercent, 2)
        $target = $coverage.CoveragePercentTarget
        if ($percent -lt $target) {
            throw "Line coverage $percent% is below the target of $target%. Raise coverage, or lower the target deliberately and say so in the ledger."
        }
        Write-Build Green "Line coverage: $percent% (target $target%)"
    }
}

task PreTag Build, {
    # The gates that seal an iteration, run before `git tag -a` and not before
    # anything else. Deliberately a separate task rather than part of Test: a
    # half-finished iteration should still be able to run a green build, which
    # is most of what a build is for.
    $pesterModule = Get-Module -Name Pester -ListAvailable |
        Where-Object { $_.Version -ge [version]'6.0.0' -and $_.Version -lt [version]'7.0.0' } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $pesterModule) {
        throw 'Pester 6.x is required. Run ./build.ps1 -Bootstrap'
    }

    Import-Module -Name $pesterModule.Path -Force

    $config = New-PesterConfiguration
    $config.Run.Path = $TestsRoot
    $config.Run.Throw = $true
    $config.Output.Verbosity = 'Detailed'
    $config.Should.DisableV5 = $true
    $config.Filter.Tag = 'PreTag'
    $config.Run.PassThru = $true

    $env:PSModulePath = (Join-Path $BuildRoot 'output') + [System.IO.Path]::PathSeparator + $env:PSModulePath

    $result = Invoke-Pester -Configuration $config

    # A filtered run that executes nothing succeeds. This task printed 'Pre-tag
    # gates passed' against zero tests for four tags, which is the same failure
    # as a lint gate that skips when its tool is missing: a green line for an
    # environment where nothing was checked.
    #
    # PassedCount + FailedCount, NOT TotalCount. TotalCount counts tests
    # DISCOVERED, and discovery walks the whole tests/ path before the tag
    # filter applies - so it is never zero and the guard written against it in
    # v0.4.0 could not fire. Measured: one untagged test, filtered by a tag
    # nothing carries, reports Total 1, Passed 0, NotRun 1, Result 'Passed'.
    $executed = $result.PassedCount + $result.FailedCount
    if ($executed -eq 0) {
        throw ("No test carries the PreTag tag, so the pre-tag gates checked nothing " +
            "($($result.TotalCount) discovered, $($result.NotRunCount) not run). That is not the same as passing.")
    }

    Write-Build Green "Pre-tag gates passed ($($result.PassedCount) test(s)). Safe to tag." 
}

task Import Build, {
    $manifest = Join-Path $OutRoot "$ModuleName.psd1"
    Import-Module -Name $manifest -Force -Verbose
}

task . Clean, Lint, LintJavaScript, Build, LintDocument, Test, TestBrowser
