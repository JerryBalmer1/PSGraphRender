#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:BuiltManifest = Get-BuiltModulePath
    $script:BuiltRoot = Get-BuiltModuleRoot
}

Describe 'Built module layout' {
    BeforeAll {
        if (-not (Test-Path -LiteralPath $script:BuiltManifest)) {
            throw "Built module not found at '$script:BuiltManifest'. Run ./build.ps1 first."
        }
    }

    It 'produces a manifest that still parses' {
        Import-PowerShellDataFile -LiteralPath $script:BuiltManifest | Should-NotBeNull
    }

    It 'sets $script:ModuleRoot in the generated psm1' {
        # Asset resolution depends on this; $PSScriptRoot alone would be wrong in
        # one of the two loaders. See CLAUDE.md, "Traps that survived the move".
        $psm1 = Join-Path $script:BuiltRoot 'PSGraphRender.psm1'
        Get-Content -LiteralPath $psm1 -Raw | Should-MatchString '\$script:ModuleRoot = \$PSScriptRoot'
    }
}
