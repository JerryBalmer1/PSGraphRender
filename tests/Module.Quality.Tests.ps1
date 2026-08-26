#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:BuiltManifest = Get-BuiltModulePath
    $script:BuiltRoot = Get-BuiltModuleRoot
    $script:CytoscapeSet = Join-Path $script:BuiltRoot 'TemplateSets/cytoscape'
}

Describe 'Built module layout' {
    BeforeAll {
        if (-not (Test-Path -LiteralPath $script:BuiltManifest)) {
            throw "Built module not found at '$script:BuiltManifest'. Run ./build.ps1 first."
        }
    }

    It 'ships the reference template set' {
        # Guards against a future build change silently dropping the copy.
        # Without the template set every render fails at runtime, not at build
        # time. Asserting the manifest and one file of each kind rather than a
        # fixed list: partials get split as they grow, and a test that names
        # every one of them fails for the wrong reason.
        foreach ($part in 'templateset.psd1', 'layout.html', 'partials/sidebar.html',
            'styles/base.css', 'scripts/bootstrap.js') {
            $full = Join-Path $script:CytoscapeSet $part
            Test-Path -LiteralPath $full | Should-BeTrue
            (Get-Item -LiteralPath $full).Length | Should-BeGreaterThan 0
        }
    }

    It 'ships every file the template set manifest names' {
        # The manifest is the contract. A part added to it but not copied by the
        # build would fail only when someone rendered a report.
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:CytoscapeSet 'templateset.psd1')

        $declared = @($manifest.Layout) + @($manifest.Slots.Values | ForEach-Object { $_ })
        foreach ($part in $declared) {
            Test-Path -LiteralPath (Join-Path $script:CytoscapeSet $part) | Should-BeTrue
        }
    }

    It 'ships the four config data files for the backend and they still parse' {
        # If the build stops copying these, every render warns and falls back to
        # the schema defaults - a change the user made would just stop taking
        # effect.
        $config = Join-Path $script:CytoscapeSet 'Config'

        foreach ($file in 'settings.schema.psd1', 'settings.psd1', 'theme.psd1', 'strings.psd1') {
            $full = Join-Path $config $file
            Test-Path -LiteralPath $full | Should-BeTrue
            Import-PowerShellDataFile -LiteralPath $full | Should-NotBeNull
        }

        (Import-PowerShellDataFile -LiteralPath (Join-Path $config 'settings.psd1')).ZoomSpeed |
            Should-Be 1.25
    }

    It 'declares every shipped value in the schema' {
        # The rule that pays for this design: a setting is added by editing data
        # only. A value with no schema entry would warn at every user.
        $config = Join-Path $script:CytoscapeSet 'Config'
        $schema = Import-PowerShellDataFile -LiteralPath (Join-Path $config 'settings.schema.psd1')

        foreach ($file in 'settings.psd1', 'theme.psd1') {
            $values = Import-PowerShellDataFile -LiteralPath (Join-Path $config $file)
            foreach ($key in $values.Keys) {
                $schema.Entries.ContainsKey($key) | Should-BeTrue
            }
        }
    }

    It 'keeps a producer command name out of the template set' {
        # Extraction checklist: no producer vocabulary anywhere below the seam.
        # The substituted document may carry the name a producer handed down;
        # the shipped backend must not know it. This assertion came across from
        # PSModuleGraph with the files it guards - it was never about the
        # producer, only about what shipped beside it.
        $offenders = @(Get-ChildItem -Path $script:CytoscapeSet -File -Recurse |
                Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'PSModuleGraphEditorLink' })

        $offenders.Count | Should-Be 0
    }

    It 'produces a manifest that still parses' {
        Import-PowerShellDataFile -LiteralPath $script:BuiltManifest | Should-NotBeNull
    }

    It 'exports exactly the seven functions the manifest declares' {
        # Public/ is not enumerated recursively and this list is explicit, so a
        # new file that nobody added to the manifest is unavailable at runtime.
        # This is the test that makes that loud rather than mysterious.
        Remove-Module -Name PSGraphRender -Force -ErrorAction SilentlyContinue
        Import-Module -Name $script:BuiltManifest -Force -ErrorAction Stop

        $expected = @(
            'ConvertTo-EscapedHtmlJson'
            'ConvertTo-EscapedHtmlText'
            'Get-HtmlTemplateSet'
            'New-GraphReportPath'
            'Resolve-HtmlConfiguration'
            'Resolve-HtmlString'
            'Show-GraphDocument'
        )

        $actual = @(Get-Command -Module PSGraphRender | Select-Object -ExpandProperty Name | Sort-Object)

        $actual.Count | Should-Be 7
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
