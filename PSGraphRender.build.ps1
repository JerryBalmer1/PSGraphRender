#Requires -Module @{ ModuleName = 'InvokeBuild'; ModuleVersion = '5.11.0' }

[CmdletBinding()]
param(
    # Extra view model files for -Task Samples, beyond the fixtures. A real
    # payload is megabytes and belongs in neither repository's history; this is
    # how one gets rendered without being committed. See the Samples task.
    [Parameter()]
    [string[]] $ExtraPayload = @()
)

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

    # Which parts are fragments, read from each backend's own manifest. A
    # fragment is valid only where its slot puts it - the link-mode action parts
    # are runs of array elements - so checking one on its own reports a
    # SyntaxError about the check. Wrapped into the shape the manifest names,
    # the check still parses the file's real syntax and still says which file.
    #
    # Discovered from FragmentSlots rather than from a list of paths here, so a
    # new mode's parts arrive covered. See the note in cytoscape/templateset.psd1.
    $fragmentShape = @{}
    foreach ($manifestFile in (Get-ChildItem -LiteralPath $templateSets -Filter 'templateset.psd1' -File -Recurse)) {
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestFile.FullName
        $setRoot = Split-Path $manifestFile.FullName -Parent
        if (-not $manifest.Contains('FragmentSlots')) { continue }
        $fragmentSlots = $manifest['FragmentSlots']

        foreach ($slot in @($fragmentSlots.Keys)) {
            $lists = @($manifest.Slots[$slot])
            if ($manifest.Contains('SlotsBySetting')) {
                foreach ($modeMap in @($manifest.SlotsBySetting.Values)) {
                    foreach ($mode in @($modeMap.Values)) {
                        if ($mode.Contains($slot)) { $lists += @($mode[$slot]) }
                    }
                }
            }
            foreach ($part in ($lists | Where-Object { $_ })) {
                $fragmentShape[(Join-Path $setRoot $part)] = $fragmentSlots[$slot]
            }
        }
    }

    $failed = @()
    $wrapped = 0
    foreach ($file in $scripts) {
        # --check parses and discards. It reports a SyntaxError with a line and
        # a caret, which is the whole value; nothing here needs to run the file.
        $target = $file.FullName

        $shape = $fragmentShape[$file.FullName]
        if ($shape) {
            if ($shape -ne 'ArrayElements') {
                throw "templateset.psd1 names fragment shape '$shape', which this check does not know how to wrap."
            }
            # Written beside nothing the build ships: a temp file, removed below.
            $target = Join-Path ([System.IO.Path]::GetTempPath()) "psgr-fragment-$PID-$($file.BaseName).js"
            [System.IO.File]::WriteAllText($target,
                "var __fragment = [`n" + [System.IO.File]::ReadAllText($file.FullName) + "`n];")
            $wrapped++
        }

        $output = & $node.Path --check $target 2>&1
        if ($LASTEXITCODE -ne 0) {
            $relative = $file.FullName.Substring($templateSets.Length).TrimStart('\', '/')
            $failed += "$relative`n$($output -join [Environment]::NewLine)"
        }
        if ($shape) { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue }
    }

    if ($failed) {
        $failed | ForEach-Object { Write-Host $_ }
        throw "node --check rejected $($failed.Count) backend script(s)."
    }

    Write-Build Green ("JavaScript: $($scripts.Count) script(s) parse, $wrapped of them as declared " +
        "fragments (node $($node.Version))")
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
    # Two layouts, because npm does not sit in the same place relative to node
    # on every platform. Windows puts it beside the executable; Unix puts it a
    # level up under lib/. Assuming the first cost the Ubuntu leg its first two
    # runs - "npm was not found beside node at /opt/.../bin/node", which was
    # true and was the wrong place to look.
    $nodeDir = Split-Path -Parent $node.Path
    $candidates = @(
        Join-Path $nodeDir 'node_modules/npm/bin/npm-cli.js'
        Join-Path (Split-Path -Parent $nodeDir) 'lib/node_modules/npm/bin/npm-cli.js'
    )
    $npmCli = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $npmCli) {
        throw ("npm was not found near node at $($node.Path). Looked in: " + ($candidates -join '; ') +
            '. Install a Node distribution that includes npm and re-run.')
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

        # BOTH floors on every line, whichever one gated. The harness computes
        # them from the same two pictures, and printing only the one that gated
        # is how a floor gets re-pinned from argument instead of from
        # measurement - which is the defect finding 67 recorded.
        foreach ($m in $report.canvas) {
            Write-Build Green ("  canvas $($m.case) $($m.selector): changed $($m.changedPixels)/$($m.totalPixels) px" +
                " = $($m.fraction) | bytes $($m.drawnBytes) drawn / $($m.emptyBytes) empty = ratio $($m.ratio)" +
                " | gated on $($m.gatedOn) >= $($m.required)")
        }
        Write-Build Green ("Browser: $($report.cases) page(s) came alive, network blocked, across " +
            "$($backends.Count) backend(s) and $($fixtures.Count) fixture(s) at " +
            "$($report.viewport.width)x$($report.viewport.height)@$($report.deviceScaleFactor)x, " +
            "changed-pixel threshold $($report.channelThreshold)/255")
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# What a node link DOES, as opposed to what the document says. Separate from
# TestBrowser because it asks a different question: TestBrowser establishes that
# a page came alive, this establishes that the link a live page offers is the one
# configuration asked for. Both need a browser; neither is a substitute.
task TestLinkMode Build, {
    $node = Resolve-BuildTool -Name Node -Command node -Purpose 'a link is not a link until a browser resolves it'

    $harness = Join-Path $TestsRoot 'browser'
    $playwright = Join-Path $harness 'node_modules/playwright'
    if (-not (Test-Path -LiteralPath $playwright)) {
        # By name, not by skipping - the same rule as TestBrowser. A gate that
        # quietly does nothing reports success for the environment where it
        # checked nothing.
        throw ('The browser harness is not installed. Run ./build.ps1 -Task BootstrapBrowser first. ' +
            'This task fails rather than skipping, deliberately.')
    }

    Import-Module (Join-Path $OutRoot "$ModuleName.psd1") -Force -ErrorAction Stop

    $scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-linkmode-$PID"
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null

    try {
        # ONE node, so a fitted view puts it at the centre of the canvas and the
        # probe's first right-click lands on it. A nine-node fixture would make
        # the probe hunt, and a probe that hunts reports "no node here" for a
        # layout change as readily as for a broken link.
        $meta = [pscustomobject]@{
            contractVersion = '1.0.0'
            title           = 'Link mode'
            rootPath        = 'C:/fixtures/LinkMode'
        }
        $plain = [pscustomobject]@{
            nodes = @([pscustomobject]@{
                    id = 'function:Get-Thing'; name = 'Get-Thing'; kind = 'Function'
                    path = 'src\Public\Get-Thing.ps1'; startLine = 12; isExported = $true
                })
            links = @()
        }
        # SC3's payload. A label that is markup and a path carrying a quote and a
        # bracket: if either reaches an attribute value unencoded, the report is
        # one forwarded file away from executing a producer's string.
        $hostile = [pscustomobject]@{
            nodes = @([pscustomobject]@{
                    id = 'function:Bad'; name = '"><script>alert(1)</script>'; kind = 'Function'
                    path = 'src\a"b<c>.ps1'; startLine = 1; isExported = $true
                })
            links = @()
        }

        function New-ModeSet {
            param([string] $Name, [hashtable] $Setting, [string] $Backend)

            $dest = Join-Path $scratch "set-$Name"
            Copy-Item -LiteralPath (Join-Path $OutRoot "TemplateSets/$Backend") -Destination $dest -Recurse -Force

            $file = Join-Path $dest 'Config/settings.psd1'
            $text = [System.IO.File]::ReadAllText($file)
            foreach ($key in ($Setting.Keys | Sort-Object)) {
                $assignment = "    $key = '$($Setting[$key].Replace("'", "''"))'"

                # REPLACE a shipped key, append only a new one. A duplicate key
                # is a parse error, not an override: the file then fails to load,
                # the resolver warns and falls back to schema defaults, and every
                # case quietly renders the DEFAULT mode.
                if ($text -match "(?m)^\s*$key\s*=") {
                    $text = $text -replace "(?m)^\s*$key\s*=.*$", $assignment.Replace('$', '$$')
                }
                else {
                    $text = $text.Insert($text.LastIndexOf('}'), $assignment + "`n")
                }
            }
            [System.IO.File]::WriteAllText($file, $text)
            $dest
        }

        # The five behaviours, stated once and run against EVERY backend that
        # declares link modes. Written per-backend, the second backend's cases
        # would be the first's retyped, and the day a sixth behaviour is added
        # it lands in one of them - which is how a backend ends up with its own
        # quietly weaker idea of what a link mode is.
        $specs = @(
            @{ id = 'editor'; payload = $plain; expect = 'prefix'; prefix = 'vscode://file/'
                setting = @{ LinkMode = 'editor' }
            }
            @{ id = 'hrefTemplate'; payload = $plain; expect = 'prefix'; prefix = 'https://example.invalid/'
                setting = @{ LinkMode = 'hrefTemplate'; LinkHrefTemplate = 'https://example.invalid/{relativePath}' }
            }
            @{ id = 'none'; payload = $plain; expect = 'none'
                setting = @{ LinkMode = 'none' }
            }
            @{ id = 'injection'; payload = $hostile; expect = 'prefix'; prefix = 'https://example.invalid/'
                forbid = @('<', '>', '"')
                setting = @{ LinkMode = 'hrefTemplate'; LinkHrefTemplate = 'https://example.invalid/{relativePath}?l={label}' }
            }
            # SC3's other half. The case above proves producer data is escaped;
            # this one proves the TEMPLATE cannot execute either. It is not
            # escaped - it is configuration and has to stay a URL - so the claim
            # here is different and weaker on purpose: whatever it contains, the
            # result is assigned to an href property rather than interpolated
            # into markup, so nothing runs and the page reports no error.
            @{ id = 'injection-template'; payload = $hostile; expect = 'prefix'; prefix = 'https://example.invalid/'
                setting = @{ LinkMode = 'hrefTemplate'
                    LinkHrefTemplate = 'https://example.invalid/{relativePath}?q="><script>alert(2)</script>&l={label}'
                }
            }
        )

        # Which backends have link modes at all, and how each one's node actions
        # are reached - both discovered from the manifests. A backend states its
        # own shape in its own LinkProbe block, beside Smoke and for the same
        # reason; nothing here and nothing in tests/browser/link-mode.cjs names a
        # selector. See TemplateSets/cytoscape/templateset.psd1.
        #
        # `plain` renders a table and has no node action, so it declares no
        # SlotsBySetting and is skipped - which is not a failure and is not a
        # silent inclusion either.
        $probes = @(
            foreach ($backend in (Get-ChildItem -LiteralPath (Join-Path $OutRoot 'TemplateSets') -Directory)) {
                $manifestPath = Join-Path $backend.FullName 'templateset.psd1'
                if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
                $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
                if (-not $manifest.Contains('SlotsBySetting')) { continue }
                if (-not $manifest.SlotsBySetting.Contains('LinkMode')) { continue }
                if (-not $manifest.Contains('LinkProbe')) {
                    # By name, not by skipping. A backend that grew link modes
                    # and no way to drive them is a gate quietly checking one
                    # fewer thing than the build reports.
                    throw ("$($backend.Name) declares link modes and no LinkProbe block in $manifestPath, so " +
                        'nothing states how a browser reaches its node actions. Declare LinkProbe beside Smoke; ' +
                        'a backend the probe skips is a mode nobody checked.')
                }
                [pscustomobject]@{ Name = $backend.Name; Probe = $manifest.LinkProbe }
            }
        )
        if ($probes.Count -eq 0) {
            throw 'No backend declares a link mode. The probe found nothing to drive, which is not the same as passing.'
        }

        $cases = @(
            foreach ($probe in $probes) {
                foreach ($spec in $specs) {
                    $id = "$($probe.Name)/$($spec.id)"
                    $set = New-ModeSet -Name "$($probe.Name)-$($spec.id)" -Setting $spec.setting -Backend $probe.Name
                    $file = Join-Path $scratch "$($probe.Name)-$($spec.id).html"
                    [System.IO.File]::WriteAllText($file, (New-RenderDocument -ViewModel $spec.payload `
                                -Meta $meta -Title "link mode $id" -TemplateSetPath $set))

                    # The block whole and verbatim under one key, the same way
                    # TestBrowser hands smoke.cjs a Smoke block. Flattening its
                    # fields onto the case is what let the harness default the
                    # missing ones, and defaulting them is what made the harness
                    # a third place cytoscape's shape was written down.
                    $case = @{ id = $id; file = $file; expect = $spec.expect; probe = $probe.Probe }
                    if ($spec.Contains('prefix')) { $case['prefix'] = $spec.prefix }
                    if ($spec.Contains('forbid')) { $case['forbidInHref'] = $spec.forbid }
                    $case
                }
            }
        )

        $jobFile = Join-Path $scratch 'job.json'
        [System.IO.File]::WriteAllText($jobFile, (ConvertTo-Json -InputObject @($cases) -Depth 8))

        $output = & $node.Path (Join-Path $harness 'link-mode.cjs') $jobFile 2>&1
        $exit = $LASTEXITCODE
        $text = ($output | Out-String)

        if ($exit -ne 0) {
            Write-Host $text
            throw "The link-mode probe reported failures across $($cases.Count) case(s)."
        }

        $report = $text | ConvertFrom-Json
        foreach ($r in $report.results) {
            $shown = if ($r.hrefs) { $r.hrefs -join ', ' } else { '(no link action)' }
            Write-Build Green "  link mode $($r.case): $shown"
        }
        Write-Build Green "Link mode: $($report.results.Count) case(s) resolved as configured."
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# What the page DRAWS, as opposed to what its configuration says. Separate from
# TestBrowser and TestLinkMode because it asks a third question: TestBrowser
# establishes that a page came alive, TestLinkMode that the link a live page
# offers is the one configuration asked for, and this that the DRAWING a live
# page makes is the one configuration asked for.
#
# Neither of the other two can see it. Both are satisfied by a page that draws
# every item as the same blue ball, which is exactly what this backend did
# until v0.16.0.
#
# A backend joins by declaring a LookProbe block beside Smoke and LinkProbe.
# Nothing here and nothing in tests/browser/look.cjs names a selector.
task TestLook Build, {
    $node = Resolve-BuildTool -Name Node -Command node -Purpose 'a drawing is not a drawing until a browser makes one'

    $harness = Join-Path $TestsRoot 'browser'
    $playwright = Join-Path $harness 'node_modules/playwright'
    if (-not (Test-Path -LiteralPath $playwright)) {
        throw ('The browser harness is not installed. Run ./build.ps1 -Task BootstrapBrowser first. ' +
            'This task fails rather than skipping, deliberately.')
    }

    Import-Module (Join-Path $OutRoot "$ModuleName.psd1") -Force -ErrorAction Stop

    $scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-look-$PID"
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null

    try {
        $meta = [pscustomobject]@{ contractVersion = '1.0.0'; title = 'Look'; rootPath = 'C:/fixtures/Look' }

        # A HUB and three spokes, plus two more classifications off to the side.
        # The hub is what makes "highlight the neighbours" a different number
        # from "highlight the item": hovering it must light five things, and
        # hovering a leaf must light two, so a mode that quietly highlights
        # everything and a mode that quietly highlights one cannot both pass.
        #
        # Five classifications, four of them named by the shipped mapping and
        # `Widget` deliberately not, because a producer may send anything and
        # the fallback is the only branch that is always reachable.
        $payload = [pscustomobject]@{
            nodes = @(
                [pscustomobject]@{ id = 'hub'; name = 'Invoke-Hub'; kind = 'Function'; path = 'src/Hub.ps1'
                    startLine = 1; isExported = $true; metrics = [pscustomobject]@{ blastRadius = 40; reach = 12 }
                }
                [pscustomobject]@{ id = 'k2'; name = 'ThingClass'; kind = 'Class'; path = 'src/Thing.ps1'
                    startLine = 2; isExported = $false; metrics = [pscustomobject]@{ blastRadius = 1; reach = 1 }
                }
                [pscustomobject]@{ id = 'k3'; name = 'ThingEnum'; kind = 'Enum'; path = 'src/Enum.ps1'
                    startLine = 3; isExported = $false; metrics = [pscustomobject]@{ blastRadius = 2; reach = 1 }
                }
                [pscustomobject]@{ id = 'k4'; name = 'Setup'; kind = 'Script'; path = 'src/Setup.ps1'
                    startLine = 4; isExported = $true; metrics = [pscustomobject]@{ blastRadius = 6; reach = 3 }
                }
                [pscustomobject]@{ id = 'k5'; name = 'Gadget'; kind = 'Widget'; path = 'src/Gadget.ps1'
                    startLine = 5; isExported = $false; metrics = [pscustomobject]@{ blastRadius = 3; reach = 2 }
                }
                [pscustomobject]@{ id = 'k6'; name = 'Doohickey'; kind = 'Widget'; path = 'src/Doo.ps1'
                    startLine = 6; isExported = $false; metrics = [pscustomobject]@{ blastRadius = 20; reach = 8 }
                }
            )
            links = @(
                [pscustomobject]@{ source = 'hub'; target = 'k2'; kind = 'Calls'; resolution = 'Certain' }
                [pscustomobject]@{ source = 'hub'; target = 'k3'; kind = 'Calls'; resolution = 'Ambiguous' }
                [pscustomobject]@{ source = 'hub'; target = 'k4'; kind = 'Calls'; resolution = 'Certain' }
                [pscustomobject]@{ source = 'k5'; target = 'k6'; kind = 'Calls'; resolution = 'Certain' }
            )
        }

        function New-LookSet {
            param([string] $Name, [hashtable] $Setting, [string] $Backend)

            $dest = Join-Path $scratch "set-$Name"
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            Copy-Item -LiteralPath (Join-Path $OutRoot "TemplateSets/$Backend") -Destination $dest -Recurse -Force

            # Every key is written into the file the SCHEMA says it belongs in.
            # Writing a theme value into settings.psd1 applies it and warns on
            # every render, which is a green gate over a noisy build.
            $schema = (Import-PowerShellDataFile -LiteralPath (Join-Path $dest 'Config/settings.schema.psd1')).Entries
            foreach ($group in @('Settings', 'Theme')) {
                $file = Join-Path $dest ('Config/' + $(if ($group -eq 'Settings') { 'settings.psd1' } else { 'theme.psd1' }))
                $text = [System.IO.File]::ReadAllText($file)
                $touched = $false

                foreach ($key in ($Setting.Keys | Sort-Object)) {
                    if (-not $schema.Contains($key)) { throw "No schema entry for '$key'; a probe may only move declared settings." }
                    if ($schema[$key].In -ne $group) { continue }

                    $value = $Setting[$key]
                    $assignment = if ($value -is [string]) { "    $key = '$($value.Replace("'", "''"))'" }
                    else { "    $key = $value" }

                    # REPLACE a shipped key, append only a new one. A duplicate
                    # key is a parse error rather than an override: the file then
                    # fails to load, the resolver warns and falls back to schema
                    # defaults, and every case renders the DEFAULT look while the
                    # report says the feature is missing.
                    if ($text -match "(?m)^\s*$key\s*=") {
                        $text = $text -replace "(?m)^\s*$key\s*=.*$", $assignment.Replace('$', '$$')
                    }
                    else {
                        $text = $text.Insert($text.LastIndexOf('}'), $assignment + "`n")
                    }
                    $touched = $true
                }
                if ($touched) { [System.IO.File]::WriteAllText($file, $text) }
            }
            $dest
        }

        function New-LookDocument {
            param([string] $Name, [hashtable] $Setting, [string] $Backend)

            $set = New-LookSet -Name "$Backend-$Name" -Setting $Setting -Backend $Backend
            $file = Join-Path $scratch "$Backend-$Name.html"
            [System.IO.File]::WriteAllText($file, (New-RenderDocument -ViewModel $payload -Meta $meta `
                        -Title "look $Name" -TemplateSetPath $set))
            $file
        }

        # Which backends have a look to check, discovered from the manifests.
        # A backend that draws into a canvas and declares no LookProbe is
        # skipped rather than failed: `plain` renders a table and has no
        # geometry, no hover and no camera, and demanding a probe of it would be
        # this file inventing a requirement the backend never took on.
        $probes = @(
            foreach ($backend in (Get-ChildItem -LiteralPath (Join-Path $OutRoot 'TemplateSets') -Directory)) {
                $manifestPath = Join-Path $backend.FullName 'templateset.psd1'
                if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
                $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
                if (-not $manifest.Contains('LookProbe')) { continue }
                [pscustomobject]@{ Name = $backend.Name; Probe = $manifest.LookProbe }
            }
        )
        if ($probes.Count -eq 0) {
            throw ('No backend declares a LookProbe. The look gate found nothing to drive, which is not the ' +
                'same as passing.')
        }

        $cases = @(
            foreach ($p in $probes) {
                $shipped = Import-PowerShellDataFile -LiteralPath (Join-Path $OutRoot "TemplateSets/$($p.Name)/Config/theme.psd1")
                $fallback = $shipped.NodeShapeFallback

                # -- B: the mapping was resolved, per item, and an unmapped
                #       classification took the declared fallback.
                @{
                    kind = 'shapes'; backend = $p.Name; name = 'shapes-resolved'; probe = $p.Probe
                    path = (New-LookDocument -Name 'shapes-resolved' -Setting @{} -Backend $p.Name)
                    expect = @{ distinctShapes = 4; fallbackFor = 'Widget'; fallbackShape = $fallback }
                }

                # -- B: and the geometry reached the DRAWING. One theme value
                #       apart; a byte-identical picture means the mapping was
                #       resolved into the DOM and never into a triangle.
                @{
                    kind = 'pixels'; backend = $p.Name; name = 'shapes-drawn'; probe = $p.Probe
                    what = 'a kind-to-shape mapping against one shape for every kind'
                    path = (New-LookDocument -Name 'shape-mapped' -Setting @{} -Backend $p.Name)
                    other = (New-LookDocument -Name 'shape-uniform' -Setting @{ KindShape = '' } -Backend $p.Name)
                }
                @{
                    kind = 'pixels'; backend = $p.Name; name = 'metric-size-drawn'; probe = $p.Probe
                    what = 'a declared metrics size key against uniform sizing'
                    path = (New-LookDocument -Name 'size-metric' -Setting @{ NodeSizeMetric = 'blastRadius'; NodeSizeMetricMax = 3.5 } -Backend $p.Name)
                    other = (New-LookDocument -Name 'size-uniform' -Setting @{ NodeSizeMetric = '' } -Backend $p.Name)
                }
                @{
                    kind = 'pixels'; backend = $p.Name; name = 'glow-drawn'; probe = $p.Probe
                    what = 'a glow at full strength against none'
                    path = (New-LookDocument -Name 'glow-on' -Setting @{ GlowStrength = 2.4; GlowSize = 3.0; GlowOpacity = 0.6 } -Backend $p.Name)
                    other = (New-LookDocument -Name 'glow-off' -Setting @{ GlowStrength = 0; GlowSize = 1.0; GlowOpacity = 0 } -Backend $p.Name)
                }

                # -- C: a setting reached the LIVE object that consumes it,
                #       read back off that object rather than off CONFIG.
                foreach ($live in @(
                        @{ n = 'zoom-speed'; s = @{ ZoomSpeed = 0.35 }; f = 'zoomSpeed'; v = 0.35 }
                        @{ n = 'rotate-speed'; s = @{ RotateSpeed = 2.0 }; f = 'rotateSpeed'; v = 2 }
                        @{ n = 'particles'; s = @{ ParticleCount = 5 }; f = 'particleCount'; v = 5 }
                        @{ n = 'button'; s = @{ NodeActionButton = 'right' }; f = 'nodeActionButton'; v = 'right' }
                    )) {
                    @{
                        kind = 'live'; backend = $p.Name; name = "live-$($live.n)"; probe = $p.Probe
                        field = $live.f; expect = @{ value = $live.v }
                        path = (New-LookDocument -Name "live-$($live.n)" -Setting $live.s -Backend $p.Name)
                    }
                }

                # -- C: and one that SCALES rather than arrives. Fog density is
                #       normalised by camera distance so one value means one
                #       appearance on any payload, which means no single
                #       reading can be compared to the setting - the first
                #       version of this case asserted equality and failed
                #       against a correct page, reporting 0.00399 where 0.004
                #       was configured. Two documents, one twice the other.
                @{
                    kind = 'liveRatio'; backend = $p.Name; name = 'live-fog-scales'; probe = $p.Probe
                    field = 'fogDensity'; expect = @{ ratio = 2 }
                    path = (New-LookDocument -Name 'fog-high' -Setting @{ FogDensity = 0.008 } -Backend $p.Name)
                    other = (New-LookDocument -Name 'fog-low' -Setting @{ FogDensity = 0.004 } -Backend $p.Name)
                }

                # -- C: hover does what the setting says, driven through a real
                #       pointer. Three modes, three different numbers.
                foreach ($hover in @(
                        @{ n = 'off'; s = @{ HoverMode = 'none'; HoverTooltip = 'none' }; h = 0; t = ''; tt = 'none' }
                        @{ n = 'node'; s = @{ HoverMode = 'node'; HoverTooltip = 'label' }; h = 'node'; t = $null; tt = 'label' }
                        @{ n = 'neighbors'; s = @{ HoverMode = 'neighbors'; HoverTooltip = 'labelAndKind' }; h = 'neighbors'; t = $null; tt = 'labelAndKind' }
                    )) {
                    $expect = @{ highlights = $hover.h; tooltip = $hover.tt }
                    if ($null -ne $hover.t) { $expect['tooltipContains'] = $hover.t }
                    @{
                        kind = 'hover'; backend = $p.Name; name = "hover-$($hover.n)"; probe = $p.Probe
                        expect = $expect
                        path = (New-LookDocument -Name "hover-$($hover.n)" -Setting $hover.s -Backend $p.Name)
                    }
                }
            }
        )

        $jobFile = Join-Path $scratch 'job.json'
        [System.IO.File]::WriteAllText($jobFile, (@{ cases = $cases } | ConvertTo-Json -Depth 12))

        $output = & $node.Path (Join-Path $harness 'look.cjs') $jobFile 2>&1
        $exit = $LASTEXITCODE
        $text = ($output | Out-String)

        if ($exit -ne 0) {
            Write-Host $text
            throw "The look probe reported failures across $($cases.Count) case(s)."
        }

        $report = $text | ConvertFrom-Json
        foreach ($o in $report.observed) {
            $detail = @($o.PSObject.Properties | Where-Object { $_.Name -ne 'case' } |
                    ForEach-Object { "$($_.Name)=$(if ($_.Value -is [array]) { $_.Value -join '/' } else { $_.Value })" }) -join ' '
            Write-Build Green "  look $($o.case): $detail"
        }
        Write-Build Green ("Look: $($report.cases) case(s) drew what configuration asked for, network blocked, " +
            "across $($probes.Count) backend(s) at $($report.viewport.width)x$($report.viewport.height).")
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
            throw "Line coverage $percent% is below the target of $target%. Raise coverage, or lower the target deliberately and say so in the commit message."
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

task Samples Build, {
    # Every fixture through every backend, so there is something to LOOK at.
    #
    # This exists because four open threads all said the same thing: nobody has
    # opened the page. The growth check measures a screenshot's compressed size
    # and never shows it to anyone; a style calibrated against 702 dashed edges
    # out of 1,271 was never seen at that density or at any other.
    #
    # The index is a build ARTEFACT, not a template set. Dumb static markup with
    # a table in it, generated here, no config, no strings, no slots. If it ever
    # grows a theme it has become a third backend and it should be deleted
    # instead.
    #
    # The rendered pages are NOT committed - 600 KB each since vendoring, six of
    # them, regenerated whenever the renderer moves. output/ is gitignored. The
    # screenshots are committed, under docs/samples/.
    Import-Module (Join-Path $OutRoot "$ModuleName.psd1") -Force -ErrorAction Stop

    $sampleRoot = Join-Path (Join-Path $BuildRoot 'output') 'samples'
    New-Item -ItemType Directory -Path $sampleRoot -Force | Out-Null

    $backends = @(
        Get-ChildItem -LiteralPath (Join-Path $OutRoot 'TemplateSets') -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') }
    )

    # The shipped fixtures, plus anything the caller points at. -ExtraPayload is
    # how a payload too big to commit gets rendered: PSModuleGraph can write one
    # for a real gallery module, and this renders it without either repository
    # gaining a 1.4 MB file or a dependency on the other.
    $payloads = @(Get-ChildItem -LiteralPath (Join-Path $TestsRoot 'fixtures/viewmodels') -Filter *.json -File)
    foreach ($extra in @($ExtraPayload)) {
        if (-not $extra) { continue }
        if (-not (Test-Path -LiteralPath $extra)) { throw "No payload at '$extra'." }
        $payloads += Get-Item -LiteralPath $extra
    }

    if ($backends.Count -eq 0 -or $payloads.Count -eq 0) {
        throw 'No backend or no payload. Samples rendered nothing, which is not the same as succeeding.'
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($payload in $payloads) {
        $vm = Get-Content -LiteralPath $payload.FullName -Raw | ConvertFrom-Json
        foreach ($backend in $backends) {
            $name = "$($backend.Name)-$($payload.BaseName)"
            $file = Join-Path $sampleRoot "$name.html"
            $title = if ($vm.meta -and $vm.meta.title) { $vm.meta.title } else { $payload.BaseName }

            $document = New-RenderDocument -ViewModel $vm.data -Meta $vm.meta -Title $title -TemplateSet $backend.Name
            [System.IO.File]::WriteAllText($file, $document)

            $rows.Add([pscustomobject]@{
                    Id      = $name
                    Backend = $backend.Name
                    Payload = $payload.BaseName
                    Title   = $title
                    Nodes   = @($vm.data.nodes).Count
                    Links   = @($vm.data.links).Count
                    File    = "$name.html"
                    Bytes   = $document.Length
                })
            Write-Build Gray ("  {0,-34} {1,5} nodes {2,5} links {3,9:N0} bytes" -f $name, @($vm.data.nodes).Count, @($vm.data.links).Count, $document.Length)
        }
    }

    # Static markup, assembled here and nowhere else. Escaped by hand because
    # this is a page about the renderer rather than a page the renderer made.
    $esc = { param($t) [System.Net.WebUtility]::HtmlEncode([string]$t) }
    $body = [System.Text.StringBuilder]::new()
    [void]$body.AppendLine('<!DOCTYPE html>')
    [void]$body.AppendLine('<html lang="en"><head><meta charset="utf-8">')
    [void]$body.AppendLine('<title>PSGraphRender samples</title>')
    [void]$body.AppendLine('<style>')
    [void]$body.AppendLine('body{font:14px/1.5 system-ui,sans-serif;margin:2rem;max-width:60rem;color:#111}')
    [void]$body.AppendLine('table{border-collapse:collapse;width:100%}')
    [void]$body.AppendLine('th,td{text-align:left;padding:.4rem .6rem;border-bottom:1px solid #ddd}')
    [void]$body.AppendLine('td.n{text-align:right;font-variant-numeric:tabular-nums}')
    [void]$body.AppendLine('p.note{color:#555}')
    [void]$body.AppendLine('</style></head><body>')
    [void]$body.AppendLine('<h1>PSGraphRender samples</h1>')
    [void]$body.AppendLine("<p class=`"note`">Every payload under <code>tests/fixtures/viewmodels/</code> rendered through every backend in <code>TemplateSets/</code>. Generated by <code>./build.ps1 -Task Samples</code>; not committed.</p>")
    [void]$body.AppendLine("<p class=`"note`">None of these payloads was produced by PSModuleGraph. They are hand-written JSON describing tasks, hosts and services, which is the point: the renderer has no producer.</p>")
    [void]$body.AppendLine('<table><thead><tr><th>Sample</th><th>Backend</th><th>Payload</th><th class="n">Nodes</th><th class="n">Links</th><th class="n">KB</th></tr></thead><tbody>')
    foreach ($row in $rows) {
        [void]$body.AppendLine(('<tr><td><a href="{0}">{1}</a></td><td>{2}</td><td>{3}</td><td class="n">{4}</td><td class="n">{5}</td><td class="n">{6:N0}</td></tr>' -f
            (& $esc $row.File), (& $esc $row.Title), (& $esc $row.Backend), (& $esc $row.Payload), $row.Nodes, $row.Links, ($row.Bytes / 1KB)))
    }
    [void]$body.AppendLine('</tbody></table></body></html>')
    [System.IO.File]::WriteAllText((Join-Path $sampleRoot 'index.html'), $body.ToString())

    Write-Build Green "  $($rows.Count) sample(s) -> $(Join-Path $sampleRoot 'index.html')"
}

task Import Build, {
    $manifest = Join-Path $OutRoot "$ModuleName.psd1"
    Import-Module -Name $manifest -Force -Verbose
}

# The chain, stated once. `.` runs it with the browser harness; WithoutBrowser
# runs it and says out loud that it did not - see task ReportBrowserNotRun.
$script:CoreTasks = @('Clean', 'Lint', 'LintJavaScript', 'Build', 'LintDocument', 'Test')

task . (@($script:CoreTasks) + 'TestBrowser')

task WithoutBrowser (@($script:CoreTasks) + 'ReportBrowserNotRun')

task ReportBrowserNotRun {
    # A DECISION, ANNOUNCED. The browser harness runs on one CI leg because the
    # page a browser loads does not vary by which PowerShell produced it, so
    # installing half a gigabyte of Chromium three times buys nothing. Every
    # other gate does vary and runs everywhere.
    #
    # It says so by name rather than being absent from a task list. A leg
    # quietly missing a gate is the failure this repository has now found three
    # times: a lint gate that skipped, a pre-tag run that selected nothing, and
    # a guard that could not fire.
    Write-Build Yellow ('TestBrowser did not run on this leg, deliberately. The browser harness runs on ' +
        'ubuntu-latest only; see .github/workflows/ci.yml. Every other gate ran here.')
}
