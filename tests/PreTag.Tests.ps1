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
}
