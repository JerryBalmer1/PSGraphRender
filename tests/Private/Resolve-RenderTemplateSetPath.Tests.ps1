#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSGraphRenderUnderTest

    function New-TemplateSetsRoot {
        <#
            A TemplateSets-shaped directory. A backend is a directory containing
            templateset.psd1 and nothing registers it anywhere.
        #>
        param([string[]] $Backend, [string] $Default, [switch] $NoIndex, [string[]] $Decoy)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        foreach ($name in @($Backend)) {
            $dir = Join-Path $root $name
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'templateset.psd1') -Value "@{ Layout = 'layout.html' }"
        }

        # A directory with no manifest is not a backend. Half a copy, an
        # editor's backup folder, or Config/ itself would all otherwise count.
        foreach ($name in @($Decoy)) {
            New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
        }

        if (-not $NoIndex) {
            Set-Content -LiteralPath (Join-Path $root 'index.psd1') -Value "@{ Default = '$Default' }"
        }

        $root
    }
}

Describe 'Get-RenderTemplateSetName' {
    It 'discovers a backend by its manifest, not by a registry' {
        # The rule that pays: adding a backend is adding a directory. If this
        # ever needs a list to be edited too, the design has regressed.
        $root = New-TemplateSetsRoot -Backend 'alpha', 'beta' -Default 'alpha'

        $names = InModuleScope PSGraphRender -Parameters @{ Root = $root } {
            param($Root)
            Get-RenderTemplateSetName -Root $Root
        }

        $names | Should-BeCollection @('alpha', 'beta')
    }

    It 'ignores a directory with no manifest in it' {
        $root = New-TemplateSetsRoot -Backend 'alpha' -Default 'alpha' -Decoy 'notes', 'alpha.bak'

        $names = InModuleScope PSGraphRender -Parameters @{ Root = $root } {
            param($Root)
            Get-RenderTemplateSetName -Root $Root
        }

        @($names).Count | Should-Be 1
    }

    It 'finds the backends that actually ship' {
        $names = InModuleScope PSGraphRender { Get-RenderTemplateSetName }

        @($names).Count | Should-BeGreaterThan 0
        $names | Should-ContainCollection 'cytoscape'
    }
}

Describe 'Resolve-RenderTemplateSetPath' {
    It 'takes the default from data rather than from any .ps1' {
        # Changing which backend is default must be one data edit. The name of
        # a backend appearing in a .ps1 is what this test exists to prevent.
        $resolved = InModuleScope PSGraphRender { Resolve-RenderTemplateSetPath }

        Test-Path -LiteralPath (Join-Path $resolved 'templateset.psd1') | Should-BeTrue
        (Import-PowerShellDataFile -LiteralPath (Join-Path (Split-Path $resolved -Parent) 'index.psd1')).Default |
            Should-Be (Split-Path $resolved -Leaf)
    }

    It 'resolves a named backend' {
        # A test may name a backend. Code may not - that is the whole point.
        $resolved = InModuleScope PSGraphRender { Resolve-RenderTemplateSetPath -Name 'cytoscape' }

        Split-Path $resolved -Leaf | Should-Be 'cytoscape'
    }

    It 'names what is available when asked for a backend that is not' {
        # A missing backend is nearly always a typo or a build that did not copy
        # the directory, and the list answers both.
        $err = $null
        try {
            InModuleScope PSGraphRender { Resolve-RenderTemplateSetPath -Name 'no-such-backend' }
        }
        catch { $err = $_ }

        $err | Should-NotBeNull
        $err.Exception.Message | Should-MatchString 'no-such-backend'
        $err.Exception.Message | Should-MatchString 'Available:'
        $err.Exception.Message | Should-MatchString 'cytoscape'
    }

    It 'derives one Config directory rather than resolving a second path' {
        # The bug this whole change answers: three functions each hardcoded
        # where a backend lives and nothing made them agree.
        $set = InModuleScope PSGraphRender { Resolve-RenderTemplateSetPath }

        Test-Path -LiteralPath (Join-Path $set 'Config/settings.psd1') | Should-BeTrue
    }
}
