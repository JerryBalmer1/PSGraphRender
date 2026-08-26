#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # No producer is imported anywhere in this file, and none may be. A suite
    # that reaches for a real dependency graph to get something to render has
    # re-coupled the two repositories at the only place the coupling was
    # removed. The payload is JSON on disk.
    Import-PSGraphRenderUnderTest

    $script:ViewModel = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'sample-module.json') -Raw |
        ConvertFrom-Json
}

Describe 'Rendering a view model with no producer installed' {
    It 'has no producer module loaded while it runs' {
        # The assertion the whole file rests on. Without it the rest could pass
        # because something else in the session happened to import a producer.
        @(Get-Module -Name PSModuleGraph).Count | Should-Be 0
    }

    It 'assembles the reference template set and leaves no slot unresolved' {
        $template = Get-RenderTemplateSet

        $template.Length | Should-BeGreaterThan 0
        $template | Should-NotMatchString '__SLOT_[A-Z0-9_]+__'
    }

    It 'resolves a configuration without being told anything about the payload' {
        $config = Resolve-RenderConfiguration

        $config | Should-NotBeNull
        $config.Keys.Count | Should-BeGreaterThan 0
    }

    It 'renders the fixture into a document with every token substituted' {
        # This is the first evidence the extraction actually worked, and the
        # test that stops it silently un-working later. Everything here is what
        # a producer in any language would do: hand over a payload, a meta
        # block, a configuration and a set of strings.
        $template = Get-RenderTemplateSet
        $config = Resolve-RenderConfiguration
        $strings = Resolve-RenderString -Value @{}

        $document = $template.Replace('/*__DATA__*/ null', (ConvertTo-EscapedHtmlJson -InputObject $script:ViewModel.data))
        $document = $document.Replace('/*__META__*/ null', (ConvertTo-EscapedHtmlJson -InputObject $script:ViewModel.meta))
        $document = $document.Replace('/*__CONFIG__*/ null', (ConvertTo-EscapedHtmlJson -InputObject $config))
        $document = $document.Replace('/*__STRINGS__*/ null', (ConvertTo-EscapedHtmlJson -InputObject $strings))
        $document = $document.Replace('__PAGE_TITLE__', (ConvertTo-EscapedHtmlText -Text 'A fixture'))

        $document | Should-NotMatchString '__PAGE_TITLE__'
        $document | Should-NotMatchString '/\*__[A-Z]+__\*/ null'
        $document | Should-MatchString '<!DOCTYPE html>'
        $document | Should-MatchString 'A fixture'
    }

    It 'escapes a closing script sequence out of the payload' {
        # A label or a path containing </script> would otherwise terminate the
        # block the payload lives in. See CLAUDE.md, "Traps that survived the
        # move".
        $hostile = [pscustomobject]@{ label = '</script><script>alert(1)</script>' }

        ConvertTo-EscapedHtmlJson -InputObject $hostile | Should-NotMatchString '</script>'
    }

    It 'leaves a token nobody filled as written rather than collapsing it' {
        # A gap that shows up beats a gap that reads as a finished sentence.
        # The renderer ships no default for editorLinkHelpCommand, because a
        # default would be the renderer knowing a producer's vocabulary.
        $strings = Resolve-RenderString -Value @{}

        $withToken = @($strings.Values | Where-Object { $_ -is [string] -and $_ -match '\{[a-zA-Z]+\}' })
        $withToken.Count | Should-BeGreaterThan 0
    }
}
