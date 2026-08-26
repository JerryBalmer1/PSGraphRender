#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:BuiltManifest = Get-BuiltModulePath
    $script:BuiltRoot = Get-BuiltModuleRoot
    $script:TemplateSetsRoot = Join-Path $script:BuiltRoot 'TemplateSets'

    # Every backend that shipped, discovered the same way the module discovers
    # them. Naming them here would be a second registry to forget, and the
    # whole point of this design is that there is no registry.
    $script:Backends = @(
        Get-ChildItem -LiteralPath $script:TemplateSetsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') } |
            Select-Object -ExpandProperty FullName |
            Sort-Object
    )
}

Describe 'Built module layout' {
    BeforeAll {
        if (-not (Test-Path -LiteralPath $script:BuiltManifest)) {
            throw "Built module not found at '$script:BuiltManifest'. Run ./build.ps1 first."
        }
    }

    It 'ships more than one backend' {
        # A seam with one implementation is an assertion, not a seam. The second
        # backend is deliberately trivial; its job is to be different enough
        # that a Cytoscape assumption could not have leaked into it.
        @($script:Backends).Count | Should-BeGreaterThan 1
    }

    It 'names a default backend in data' {
        # Changing which backend renders by default must be one data edit. If a
        # name appears in a .ps1, the reference implementation is privileged in
        # code and "a template set is a rendering backend" has stopped being
        # true.
        $index = Join-Path $script:TemplateSetsRoot 'index.psd1'
        Test-Path -LiteralPath $index | Should-BeTrue

        $default = (Import-PowerShellDataFile -LiteralPath $index).Default
        Test-Path -LiteralPath (Join-Path (Join-Path $script:TemplateSetsRoot $default) 'templateset.psd1') |
            Should-BeTrue
    }

    It 'ships every file each backend manifest names' {
        # The manifest is the contract. A part added to it but not copied by the
        # build would fail only when someone rendered a report. Asserted for
        # every backend, so a third one is covered without editing this test.
        foreach ($set in $script:Backends) {
            $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $set 'templateset.psd1')

            $declared = @($manifest.Layout) + @($manifest.Slots.Values | ForEach-Object { $_ })
            foreach ($part in $declared) {
                $full = Join-Path $set $part
                $message = "$(Split-Path $set -Leaf) declares '$part' and it did not ship"
                Test-Path -LiteralPath $full | Should-BeTrue -Because $message
                (Get-Item -LiteralPath $full).Length | Should-BeGreaterThan 0 -Because $message
            }
        }
    }

    It 'ships four config data files per backend and they still parse' {
        # If the build stops copying these, every render warns and falls back to
        # the schema defaults - a change the user made would just stop taking
        # effect.
        foreach ($set in $script:Backends) {
            $config = Join-Path $set 'Config'

            foreach ($file in 'settings.schema.psd1', 'settings.psd1', 'theme.psd1', 'strings.psd1') {
                $full = Join-Path $config $file
                $message = "$(Split-Path $set -Leaf) is missing $file"
                Test-Path -LiteralPath $full | Should-BeTrue -Because $message
                Import-PowerShellDataFile -LiteralPath $full | Should-NotBeNull -Because $message
            }
        }
    }

    It 'declares every shipped value in its own backend schema' {
        # The rule that pays for this design: a setting is added by editing data
        # only. A value with no schema entry warns at every user.
        foreach ($set in $script:Backends) {
            $config = Join-Path $set 'Config'
            $schema = Import-PowerShellDataFile -LiteralPath (Join-Path $config 'settings.schema.psd1')

            foreach ($file in 'settings.psd1', 'theme.psd1') {
                $values = Import-PowerShellDataFile -LiteralPath (Join-Path $config $file)
                foreach ($key in $values.Keys) {
                    $message = "$(Split-Path $set -Leaf) ships '$key' with no schema entry"
                    $schema.Entries.ContainsKey($key) | Should-BeTrue -Because $message
                }
            }
        }
    }

    It 'keeps a producer command name out of every backend' {
        # Extraction checklist: no producer vocabulary anywhere below the seam.
        # The rendered document may carry a name a producer handed down; the
        # shipped backend must not know it.
        foreach ($set in $script:Backends) {
            $offenders = @(Get-ChildItem -LiteralPath $set -File -Recurse |
                    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'PSModuleGraphEditorLink' })

            $offenders.Count | Should-Be 0 -Because "$(Split-Path $set -Leaf) names a producer command"
        }
    }

    It 'produces a manifest that still parses' {
        Import-PowerShellDataFile -LiteralPath $script:BuiltManifest | Should-NotBeNull
    }

    It 'exports exactly the four functions the manifest declares' {
        # Public/ is not enumerated recursively and this list is explicit, so a
        # new file that nobody added to the manifest is unavailable at runtime.
        # This is the test that makes that loud rather than mysterious.
        #
        # Four, not seven. The escapers and the two resolvers were public only
        # because a producer had to call them to render anything; that work is
        # behind New-RenderDocument now, so the surface is the four things a
        # caller actually has business with.
        Remove-Module -Name PSGraphRender -Force -ErrorAction SilentlyContinue
        Import-Module -Name $script:BuiltManifest -Force -ErrorAction Stop

        $expected = @(
            'Get-RenderTemplateSet'
            'New-RenderDocument'
            'New-RenderDocumentPath'
            'Show-RenderDocument'
        )

        $actual = @(Get-Command -Module PSGraphRender | Select-Object -ExpandProperty Name | Sort-Object)

        $actual.Count | Should-Be 4
        $actual | Should-BeCollection $expected
    }

    It 'includes functions from Private subfolders in the generated psm1' {
        # Private/ is enumerated recursively; Private/Config, Private/Document
        # and Private/Transport would silently vanish if that regressed.
        $psm1 = Join-Path $script:BuiltRoot 'PSGraphRender.psm1'
        $content = Get-Content -LiteralPath $psm1 -Raw

        $content | Should-MatchString 'function Test-RenderSettingValue'
        $content | Should-MatchString 'function Get-RenderAssetPath'
        $content | Should-MatchString 'function Resolve-LoopbackDocumentUrl'
    }

    It 'sets $script:ModuleRoot in the generated psm1' {
        # Asset resolution depends on this; $PSScriptRoot alone would be wrong in
        # one of the two loaders.
        $psm1 = Join-Path $script:BuiltRoot 'PSGraphRender.psm1'
        Get-Content -LiteralPath $psm1 -Raw | Should-MatchString '\$script:ModuleRoot = \$PSScriptRoot'
    }
}
