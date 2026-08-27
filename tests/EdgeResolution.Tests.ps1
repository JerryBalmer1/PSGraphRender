#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-PSGraphRenderUnderTest

    $script:Ambiguous = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'ambiguous.json') -Raw |
        ConvertFrom-Json
    $script:Plainest = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'sample-module.json') -Raw |
        ConvertFrom-Json
}

Describe 'StyleMap, the setting type behind an edge classification' {
    It 'accepts any key, because the keys are the producer''s words' {
        InModuleScope PSGraphRender {
            $entry = @{ Type = 'StyleMap'; Default = @{} }
            # Three words from three imaginary producers. None of them means
            # anything here, and that is the requirement.
            $value = @{
                Ambiguous = @{ LineStyle = 'dashed'; Opacity = 0.45 }
                Vermutet  = @{ Opacity = 0.6 }
                '推定'    = @{ LineStyle = 'dotted' }
            }
            $result = Test-RenderSettingValue -Value $value -Entry $entry
            $result.IsValid | Should-BeTrue
            $result.Value.Keys.Count | Should-Be 3
        }
    }

    It 'refuses a style property this renderer does not draw' {
        InModuleScope PSGraphRender {
            # The other half of the rule. A key is the producer's and is never
            # checked; a PROPERTY NAME is the renderer's own vocabulary, so a
            # typo has to fail rather than silently draw nothing.
            $entry = @{ Type = 'StyleMap'; Default = @{} }
            $result = Test-RenderSettingValue -Value @{ Ambiguous = @{ LineStyle = 'dashed'; Opactiy = 0.4 } } -Entry $entry

            $result.IsValid | Should-BeFalse
            $result.Reason | Should-MatchString 'Opactiy'
            $result.Reason | Should-MatchString 'LineStyle and Opacity'
        }
    }

    It 'refuses a line style and an opacity it cannot draw' {
        InModuleScope PSGraphRender {
            $entry = @{ Type = 'StyleMap'; Default = @{} }

            $badLine = Test-RenderSettingValue -Value @{ X = @{ LineStyle = 'squiggly' } } -Entry $entry
            $badLine.IsValid | Should-BeFalse
            $badLine.Reason | Should-MatchString 'squiggly'

            $badOpacity = Test-RenderSettingValue -Value @{ X = @{ Opacity = 4 } } -Entry $entry
            $badOpacity.IsValid | Should-BeFalse
            $badOpacity.Reason | Should-MatchString '0 to 1'
        }
    }
}

Describe 'An edge that could not be tied to one target' {
    It 'carries the resolution the payload stated into the document' {
        $document = New-RenderDocument -ViewModel $script:Ambiguous.data -Meta $script:Ambiguous.meta

        # The value reaches the page as data on the edge, not as a class name
        # the renderer invented.
        $document | Should-MatchString '"resolution": "Ambiguous"'
        $document | Should-MatchString '"resolution": "SameFile"'
        $document | Should-MatchString '"resolution": "Unique"'
    }

    It 'draws a resolution the theme names, and only from the theme' {
        $document = New-RenderDocument -ViewModel $script:Ambiguous.data -Meta $script:Ambiguous.meta

        # The style map reaches the config block, and the selector is generated
        # from whatever it holds rather than written out.
        $document | Should-MatchString 'EdgeResolutionStyle'
        $document | Should-MatchString ([regex]::Escape('edge[resolution = '))
    }

    It 'has no resolution value written into any script' {
        # The KIND_HEX rule, a fifth time. A list of one producer's resolution
        # words inside a renderer is the thing this whole mechanism exists to
        # prevent, and a generated selector is the proof it is not there.
        foreach ($backend in Get-BackendDirectory) {
            foreach ($file in Get-BackendSourceFile -Backend $backend.FullName -Include '*.js') {
                $source = Remove-JavaScriptComment -Source (Get-Content -LiteralPath $file.FullName -Raw)
                foreach ($word in 'Ambiguous', 'SameFile') {
                    $source | Should-NotMatchString $word -Because "$($file.Name) must not know what a resolution value is"
                }
            }
        }
    }

    It 'treats a link that states nothing as not stated, never as certain' {
        # The whole reason the field is optional. sample-module.json predates
        # it and carries no resolution at all; nothing may invent one.
        $document = New-RenderDocument -ViewModel $script:Plainest.data -Meta $script:Plainest.meta

        # Not a value, and not an empty one either: the key is simply absent
        # from every link in the payload, and elements.js turns that into ''
        # in the browser - which matches no selector the theme generates.
        $document | Should-NotMatchString '"resolution"'
    }
}
