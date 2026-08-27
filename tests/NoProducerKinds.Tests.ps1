#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue
    Import-PSGraphRenderUnderTest

    $script:Repo = Split-Path -Path $PSScriptRoot -Parent
    $script:SrcRoot = Join-Path $script:Repo 'src/PSGraphRender'
    $script:TemplateSets = Join-Path $script:SrcRoot 'TemplateSets'

    $script:Backends = @(
        Get-ChildItem -LiteralPath $script:TemplateSets -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') }
    )

    # Every classification any fixture carries. Fixtures are the only place in
    # this repository that legitimately knows a producer's vocabulary, so they
    # are where the list of forbidden words comes from - rather than a list
    # written here, which would go stale the moment a fixture gained a kind.
    $script:KnownKinds = @(
        Get-ChildItem -LiteralPath (Get-ViewModelFixturePath) -Filter *.json -File |
            ForEach-Object {
                $payload = (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json).data
                @($payload.nodes.kind) + @($payload.links.kind)
            } |
            Where-Object { $_ } |
            Select-Object -Unique |
            Sort-Object
    )
}

Describe 'A renderer that does not know what the nodes are' {
    It 'found kinds in the fixtures to check against' {
        # A zero-length list makes every assertion below vacuous, which is the
        # failure mode of any check expressed as "none of these appear".
        @($script:KnownKinds).Count | Should-BeGreaterThan 4
    }

    It 'holds no producer classification as a literal in any backend script' {
        # THE WEAK CHECK, and it is the one that would have caught KIND_HEX.
        #
        # bootstrap.js declared
        #   KIND_HEX = { Function: ..., Class: ..., Enum: ..., Script: ... }
        # from the extraction until v0.3.0. Every producer-vocabulary check
        # written before this one looked for words in PowerShell source or in
        # function names; this was a JavaScript object literal whose KEYS were
        # the vocabulary, and nothing was looking there.
        #
        # It is weak because it can only find vocabulary someone happened to put
        # in a fixture. See the test below for the half that does not depend on
        # knowing the words.
        $offenders = foreach ($backend in $script:Backends) {
            foreach ($file in Get-BackendSourceFile -Backend $backend.FullName -Include *.js, *.css, *.html) {
                # Comments stripped first, and deliberately: the comment above
                # KIND_HEX in bootstrap.js quotes the literal it replaced, and
                # deleting the explanation to satisfy the check would be the
                # check eating its own reason. Same lesson as the backend-name
                # test, arriving in a different language.
                $text = Remove-JavaScriptComment -Source (Get-Content -LiteralPath $file.FullName -Raw)
                $text = [regex]::Replace($text, '(?s)<!--.*?-->', '')
                foreach ($kind in $script:KnownKinds) {
                    # As an object key, a quoted string, or a property access.
                    # Bare-word matching would fire on English: two of the kinds
                    # in the fixtures are `module` and `output`.
                    $patterns = @(
                        "['`"]" + [regex]::Escape($kind) + "['`"]"
                        '(^|[^A-Za-z0-9_.])' + [regex]::Escape($kind) + '\s*:'
                        '\.' + [regex]::Escape($kind) + '\b'
                    )
                    foreach ($pattern in $patterns) {
                        if ($text -cmatch $pattern) {
                            "$($backend.Name)/$($file.Name) holds '$kind'"
                            break
                        }
                    }
                }
            }
        }

        $unique = @($offenders | Select-Object -Unique)
        $message = "a backend script names a producer's classification: $($unique -join '; '). Colours and labels for a classification are theme data; see KindColor in theme.psd1."
        $unique.Count | Should-Be 0 -Because $message
    }

    It 'renders a payload whose classifications it has never seen' {
        # THE STRONGER HALF. This does not need to know a producer's words,
        # because it invents words no producer has: if any behaviour depends on
        # a classification being one of a known set, a payload of nonsense
        # classifications renders differently from one of familiar ones.
        #
        # What it CANNOT catch is a difference that shows up only in the
        # browser - KIND_HEX itself was one, since the colour it resolves is
        # read at draw time. That is why the weak check above is kept as well.
        $vm = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'infrastructure.json') -Raw |
            ConvertFrom-Json

        $strange = $vm.data | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $i = 0
        foreach ($node in $strange.nodes) { $node.kind = "zzkind$([char](97 + ($i++ % 5)))" }
        foreach ($link in $strange.links) { $link.kind = 'zzlink' }

        foreach ($backend in $script:Backends) {
            $familiar = New-RenderDocument -ViewModel $vm.data -Title 'x' -TemplateSet $backend.Name
            $nonsense = New-RenderDocument -ViewModel $strange -Title 'x' -TemplateSet $backend.Name

            # Same length within the difference the payload itself accounts for.
            # A backend that branched on a known kind would emit different
            # markup, different styles, or a different element count.
            $familiar.Length | Should-BeGreaterThan 0
            $nonsense.Length | Should-BeGreaterThan 0

            # The document outside the embedded payload must be identical: the
            # only thing that changed is data.
            # Strip the embedded payload from both, whatever the const is
            # called. Naming one backend's const here would put a backend
            # name in a test that exists to find hardcoded vocabulary.
            $payloadBlock = '(?s)const [A-Z_]*DATA = .*?;\r?\n'
            $stripFamiliar = [regex]::Replace($familiar, $payloadBlock, '')
            $stripNonsense = [regex]::Replace($nonsense, $payloadBlock, '')
            $stripFamiliar | Should-Be $stripNonsense -Because "$($backend.Name) rendered differently for classifications it had never seen"
        }
    }

    It 'colours a classification from theme data rather than from script' {
        # The specific regression. KindColor is a ColorMap, which exists as a
        # schema TYPE precisely because a backend colouring by classification
        # cannot know the classifications - so neither the keys nor their number
        # can live in a schema entry.
        $theme = Import-PowerShellDataFile -LiteralPath (
            Join-Path $script:TemplateSets 'cytoscape/Config/theme.psd1')

        $theme.KindColor | Should-NotBeNull
        @($theme.KindColor.Keys).Count | Should-BeGreaterThan 0
        $theme.KindColorFallback | Should-MatchString '^#[0-9a-fA-F]{3,6}$'

        # And it reaches the document, so a backend swapping the map changes the
        # colours without a code change.
        $vm = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'sample-module.json') -Raw |
            ConvertFrom-Json
        $document = New-RenderDocument -ViewModel $vm.data -Title 'x' -TemplateSet cytoscape

        foreach ($colour in $theme.KindColor.Values) {
            $document | Should-MatchString ([regex]::Escape($colour))
        }
    }
}
