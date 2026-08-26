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
        $config = InModuleScope PSGraphRender { Resolve-RenderConfiguration }

        $config | Should-NotBeNull
        $config.Keys.Count | Should-BeGreaterThan 0
    }

    It 'renders the fixture with one call and no knowledge of the contract' {
        # This is the first evidence the extraction actually worked, and the
        # test that stops it silently un-working later. It is also the shape of
        # the whole claim: a producer hands over a payload, a meta block, some
        # strings and a title. It does not escape anything, does not know a
        # marker name, and does not know where a backend keeps its settings.
        $document = New-RenderDocument -ViewModel $script:ViewModel.data -Meta $script:ViewModel.meta -Title 'A fixture'

        $document | Should-NotMatchString '__PAGE_TITLE__'
        $document | Should-NotMatchString '/\*__[A-Z]+__\*/ null'
        $document | Should-MatchString '<!DOCTYPE html>'
        $document | Should-MatchString 'A fixture'
    }

    It 'escapes the title as markup rather than as JSON' {
        # & < > and " only. An apostrophe is left alone deliberately: the title
        # lands in element text and in no attribute, where ' is not special, and
        # escaping it would put &#39; in front of every reader with a possessive
        # in their module name.
        $document = New-RenderDocument -ViewModel $script:ViewModel.data -Title 'Bob''s <report> & "quotes"'

        $document | Should-MatchString ([regex]::Escape("Bob's &lt;report&gt; &amp; &quot;quotes&quot;"))
        $document | Should-NotMatchString ([regex]::Escape('<report>'))
    }

    It 'interpolates a caller string without learning what it means' {
        # The seam, paid for. A producer hands down the name of its own command
        # and the renderer treats it as text.
        $document = New-RenderDocument -ViewModel $script:ViewModel.data -Strings @{
            editorLinkHelpCommand = 'Invoke-SomethingFromAnotherLanguage'
        }

        $document | Should-MatchString 'Invoke-SomethingFromAnotherLanguage'
    }

    It 'escapes a closing script sequence out of the payload' {
        # A label or a path containing </script> would otherwise terminate the
        # block the payload lives in. See docs/development.md, "Traps that
        # survived the move". Asserted through the seam, because that is now
        # the only way a
        # producer can reach the escaper - which is the point of moving it.
        $hostile = [pscustomobject]@{ label = '</script><script>alert(1)</script>' }

        $document = New-RenderDocument -ViewModel $hostile -Title 'Hostile'

        ($document -split '</script>').Count | Should-Be (
            ($document -split '<script').Count)
    }

    It 'leaves a token nobody filled as written rather than collapsing it' {
        # A gap that shows up beats a gap that reads as a finished sentence.
        # The renderer ships no default for editorLinkHelpCommand, because a
        # default would be the renderer knowing a producer's vocabulary.
        $document = New-RenderDocument -ViewModel $script:ViewModel.data

        # {origin} is a display-time token: only the browser knows what origin
        # the report ended up on, so it survives into the document for the page
        # to fill. A renderer that collapsed it would hide the gap.
        $document | Should-MatchString '\{origin\}'
    }
}
