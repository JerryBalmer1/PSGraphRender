#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Seals on a FINISHED iteration, not checks on work in progress. Run by
# ./build.ps1 -Task PreTag and excluded from the default Test task.
#
# Until this file existed, PreTag selected zero tests and reported that the
# gates had passed - the same failure this iteration's other work is about,
# sitting in the task whose whole job is to be a gate. The build now throws when
# a filtered run selects nothing, so an empty PreTag can never look green again.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:Repo = Split-Path -Path $PSScriptRoot -Parent
    $script:Requirements = Import-PowerShellDataFile -LiteralPath (Join-Path $script:Repo 'Requirements.psd1') -ErrorAction Stop
    $script:Workflow = Get-Content -LiteralPath (Join-Path $script:Repo '.github/workflows/ci.yml') -Raw
}

Describe 'The tools this repository is pinned to' -Tag 'PreTag' {
    It 'agrees between the Requirements floor and what CI installs' {
        # Two places state a version, so something has to say they are the same
        # number. The alternative is a green local build against Node 22 and a
        # CI leg on whatever the runner image happened to ship.
        $floor = [version]$script:Requirements.Tools.Node.MinimumVersion

        # Matched here rather than through Should-MatchString, which asserts but
        # does not hand back what it captured.
        $declared = [regex]::Match($script:Workflow, "node-version:\s*'(?<v>[0-9]+)(\.[0-9x]+)*'")
        $declared.Success | Should-BeTrue -Because 'ci.yml must state a Node version'
        $ci = [version]"$($declared.Groups['v'].Value).0.0"

        $ci | Should-BeGreaterThanOrEqual $floor -Because 'CI must not run a Node older than the build demands'
    }

    It 'agrees between the Requirements pin and what npm installs' {
        # Two files state the Playwright version: Requirements.psd1, where every
        # other pin lives, and tests/browser/package.json, which is the one npm
        # actually reads. A pin nothing compares is a pin in one place and a
        # guess in the other.
        $pinned = $script:Requirements.Tools.Playwright.RequiredVersion
        $package = Get-Content -LiteralPath (Join-Path $script:Repo 'tests/browser/package.json') -Raw |
            ConvertFrom-Json

        $package.dependencies.playwright | Should-Be $pinned
    }

    It 'installs the browser harness in CI before the build that needs it' {
        # The default task includes TestBrowser and TestBrowser throws when the
        # harness is absent, so a browser leg without this step fails every run.
        $script:Workflow | Should-MatchString 'build\.ps1 -Task BootstrapBrowser'
    }

    It 'runs the browser harness on exactly one CI leg' {
        # One is a decision: what a browser does with the page does not vary by
        # which PowerShell produced it. Two would be waste; none would be the
        # gate quietly not running anywhere.
        [regex]::Matches($script:Workflow, '(?m)^\s*browser:\s*true\s*$').Count | Should-Be 1
        [regex]::Matches($script:Workflow, '(?m)^\s*browser:\s*false\s*$').Count | Should-BeGreaterThan 0
    }

    It 'makes the legs that do not run it say so' {
        # WithoutBrowser is the whole point: it runs every other gate and then
        # announces the one it did not. A leg configured with a hand-written
        # task list would drift from the default chain silently instead.
        $script:Workflow | Should-MatchString "'WithoutBrowser'"

        $build = Get-Content -LiteralPath (Join-Path $script:Repo 'PSGraphRender.build.ps1') -Raw
        $build | Should-MatchString '(?m)^task WithoutBrowser .*ReportBrowserNotRun'
        $build | Should-MatchString 'did not run on this leg, deliberately'

        # And both chains come from one list, so a gate added to the default
        # cannot go missing from the other.
        $build | Should-MatchString '(?m)^task \. \(@\(\$script:CoreTasks\) \+'
        $build | Should-MatchString '(?m)^task WithoutBrowser \(@\(\$script:CoreTasks\) \+'
    }

    It 'installs Node in CI at all' {
        # The floor above is satisfiable by a runner image that happens to carry
        # a new enough Node. That is luck, not a pin.
        $script:Workflow | Should-MatchString 'actions/setup-node'
    }
}

Describe 'The gates that are not allowed to skip' -Tag 'PreTag' {
    It 'runs node --check from a task that fails when node is absent' {
        # The whole point of both JavaScript tasks. A future edit that turns the
        # throw into a warning passes every other test in this suite.
        $build = Get-Content -LiteralPath (Join-Path $script:Repo 'PSGraphRender.build.ps1') -Raw

        $build | Should-MatchString 'was not found on PATH'
        $build | Should-NotMatchString '(?m)^\s*if \(-not \$node\) \{\s*return'
    }

    It 'runs the browser harness from a task that fails when it is absent' {
        $build = Get-Content -LiteralPath (Join-Path $script:Repo 'PSGraphRender.build.ps1') -Raw

        $build | Should-MatchString 'The browser harness is not installed'
        $build | Should-MatchString '(?m)^task \. .*TestBrowser'
    }

    It 'fails a filtered run that selects no test at all' {
        # THE GUARD ON THE GUARD, and this file is what it guards.
        #
        # PreTag printed 'Pre-tag gates passed' against zero tests for four
        # tags, because a filtered Pester run that selects nothing succeeds.
        # v0.4.0 added the throw; without this, deleting the throw is invisible.
        #
        # Two halves, because either alone is weak. The first says the build
        # still refuses; the second says the thing it refuses is real.
        #
        # PassedCount + FailedCount, and the check is written against that
        # rather than TotalCount deliberately: TotalCount counts tests
        # DISCOVERED, discovery walks the whole tests/ path before the tag
        # filter applies, and the guard v0.4.0 wrote against it could never
        # fire. Writing this test is what found that.
        $build = Get-Content -LiteralPath (Join-Path $script:Repo 'PSGraphRender.build.ps1') -Raw
        $build | Should-MatchString '(?s)\$executed = \$result\.PassedCount \+ \$result\.FailedCount.*?throw'
        $build | Should-NotMatchString '\$result\.TotalCount -eq 0'
        $build | Should-MatchString 'checked nothing'

        # In a CHILD PROCESS. Invoke-Pester inside Invoke-Pester inherits the
        # outer run's filter and reported 7 where 0 was the whole point - an
        # instrument measuring its own environment, which is the mistake this
        # repository has now made three times.
        $probe = Join-Path ([System.IO.Path]::GetTempPath()) "psgr-emptyfilter-$PID.ps1"
        $harness = Join-Path ([System.IO.Path]::GetTempPath()) "psgr-emptyfilter-run-$PID.ps1"
        try {
            Set-Content -LiteralPath $probe -Value "Describe 'p' { It 'a' { 1 | Should-Be 1 } }"
            Set-Content -LiteralPath $harness -Value @"
Import-Module '$((Get-Module Pester | Select-Object -First 1).Path)' -Force
`$c = New-PesterConfiguration
`$c.Run.Path = '$probe'
`$c.Run.PassThru = `$true
`$c.Output.Verbosity = 'None'
`$c.Filter.Tag = 'NoTestCarriesThisTag'
`$r = Invoke-Pester -Configuration `$c
"Passed `$(`$r.PassedCount) Result `$(`$r.Result)"
"@
            $reported = "$(& (Get-Process -Id $PID).Path -NoProfile -File $harness | Select-Object -Last 1)".Trim()
            $reported | Should-Be 'Passed 0 Result Passed' -Because 'a filtered run that executes nothing reports success, which is what the build must refuse to call a pass'
        }
        finally {
            Remove-Item -LiteralPath $probe, $harness -Force -ErrorAction SilentlyContinue
        }
    }
}
