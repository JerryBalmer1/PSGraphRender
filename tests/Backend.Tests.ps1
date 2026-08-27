#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-PSGraphRenderUnderTest

    $script:Repo = Split-Path -Path $PSScriptRoot -Parent
    $script:SrcRoot = Join-Path $script:Repo 'src/PSGraphRender'

    $script:ViewModel = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'sample-module.json') -Raw |
        ConvertFrom-Json

    $script:Backends = @(
        Get-ChildItem -LiteralPath (Join-Path $script:SrcRoot 'TemplateSets') -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') } |
            Select-Object -ExpandProperty Name |
            Sort-Object
    )
}

Describe 'A backend is a directory' {
    It 'names no backend in any .ps1 under src' {
        # THE TEST THIS WHOLE DESIGN EXISTS FOR.
        #
        # Adding a backend must require editing data files only. Before v0.2.0
        # three functions each hardcoded `TemplateSets/cytoscape`, so a second
        # backend was three code edits and the rule that pays for the config
        # split was quietly failing.
        #
        # CODE only. Comments and comment-based help are stripped first, and
        # deliberately so: `.EXAMPLE ... -TemplateSet plain` is exactly the
        # documentation a caller needs, and the comment in
        # Resolve-RenderTemplateSetPath explains the bug this test prevents.
        # Deleting either to satisfy the check would be the check eating its own
        # reason.
        #
        # A name counts as named when it appears as a string literal or inside a
        # TemplateSets path. Bare-word matching is useless here: one backend is
        # called `plain`, which occurs in ordinary English prose.
        $offenders = foreach ($file in Get-ChildItem -LiteralPath $script:SrcRoot -Filter *.ps1 -File -Recurse) {
            $text = Get-Content -LiteralPath $file.FullName -Raw

            # Comment-based help first, then line comments. Neither is code.
            $code = [regex]::Replace($text, '(?s)<#.*?#>', '')
            $code = ($code -split "`n" | ForEach-Object { ($_ -split '#', 2)[0] }) -join "`n"

            foreach ($name in $script:Backends) {
                $quoted = "['`"]" + [regex]::Escape($name) + "['`"]"
                $inPath = 'TemplateSets[/\\]' + [regex]::Escape($name)
                if ($code -match $quoted -or $code -match $inPath) {
                    "$($file.Name) names '$name'"
                }
            }
        }

        $message = "a backend name appears in shipped code: $(@($offenders) -join '; '). Adding a backend must be a data change."
        @($offenders).Count | Should-Be 0 -Because $message
    }

    It 'discovers every shipped backend without a registry' {
        $discovered = InModuleScope PSGraphRender { Get-RenderTemplateSetName }

        $discovered | Should-BeCollection $script:Backends
    }

    It 'renders the same view model through every backend' -ForEach @(
        @{ Backend = 'cytoscape' }
        @{ Backend = 'plain' }
    ) {
        # One payload, two backends, no producer involved and no branch anywhere
        # deciding what the nodes mean.
        $document = New-RenderDocument -ViewModel $script:ViewModel.data -Meta $script:ViewModel.meta `
            -Title 'Both backends' -TemplateSet $Backend

        $document | Should-MatchString '<!DOCTYPE html>'
        $document | Should-NotMatchString '__SLOT_[A-Z0-9_]+__'
        $document | Should-NotMatchString '/\*__[A-Z]+__\*/ null'
        $document | Should-NotMatchString '__PAGE_TITLE__'
        $document | Should-MatchString 'Both backends'
    }

    It 'renders the default backend when none is named' {
        $named = New-RenderDocument -ViewModel $script:ViewModel.data -Title 'x' -TemplateSet (
            (Import-PowerShellDataFile -LiteralPath (Join-Path $script:SrcRoot 'TemplateSets/index.psd1')).Default)
        $default = New-RenderDocument -ViewModel $script:ViewModel.data -Title 'x'

        $default | Should-Be $named
    }

    It 'fetches nothing from anywhere, in every backend' {
        # The vendoring decision, made in 0.5.0 and asserted here. Every
        # backend now, not just the one that never needed a library.
        #
        # Matching the string https:// would be wrong and would fail: the
        # vendored libraries carry MIT licence headers with URLs in them, and a
        # URL in a comment is not a fetch. What matters is whether the DOCUMENT
        # asks a browser to go anywhere, so this looks for the attributes that
        # make it do so. The stronger claim - zero requests actually made - is
        # asserted by the headless harness with the network blocked.
        $fetching = @(
            '<script[^>]+\bsrc\s*=\s*["'']?https?:'
            '<link[^>]+\bhref\s*=\s*["'']?https?:'
            '<img[^>]+\bsrc\s*=\s*["'']?https?:'
            '<iframe[^>]+\bsrc\s*=\s*["'']?https?:'
            '@import\s+(url\()?["'']?https?:'
        )

        foreach ($backend in $script:Backends) {
            $document = New-RenderDocument -ViewModel $script:ViewModel.data -Title 'Offline' -TemplateSet $backend

            foreach ($pattern in $fetching) {
                [regex]::Matches($document, $pattern).Count |
                    Should-Be 0 -Because "$backend asks the browser to fetch something"
            }
        }
    }

    It 'names what is available when asked for a backend that does not exist' {
        $err = $null
        try { New-RenderDocument -ViewModel $script:ViewModel.data -TemplateSet 'no-such-backend' }
        catch { $err = $_ }

        $err | Should-NotBeNull
        $err.Exception.Message | Should-MatchString 'Available:'
    }

    It 'renders from a caller-supplied directory that ships nowhere' {
        # The parameter that made a second backend possible before there was
        # one. A backend outside this module is the case a producer in another
        # language will actually hit.
        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $dir 'Config') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'templateset.psd1') -Value "@{ Layout = 'layout.html' }"
        Set-Content -LiteralPath (Join-Path $dir 'layout.html') -Value '<p>__PAGE_TITLE__</p><script>/*__DATA__*/ null</script>'
        Set-Content -LiteralPath (Join-Path $dir 'Config/settings.schema.psd1') -Value '@{ Entries = @{ Nothing = @{ Type = "String"; Default = "" } } }'
        Set-Content -LiteralPath (Join-Path $dir 'Config/settings.psd1') -Value '@{}'
        Set-Content -LiteralPath (Join-Path $dir 'Config/theme.psd1') -Value '@{}'
        Set-Content -LiteralPath (Join-Path $dir 'Config/strings.psd1') -Value '@{}'

        $document = New-RenderDocument -ViewModel $script:ViewModel.data -Title 'Elsewhere' -TemplateSetPath $dir

        $document | Should-MatchString 'Elsewhere'
        $document | Should-NotMatchString '/\*__DATA__\*/ null'
    }
}
