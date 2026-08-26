#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-PSGraphRenderUnderTest

    # THE CHARTER'S TARGET, CHECKED.
    #
    # infrastructure.json is hand-written and describes Terraform resources: a
    # VPC, subnets, security groups, an RDS instance, ECS services, IAM roles,
    # variables and outputs. No producer made it, no producer could have made
    # it, and nothing in this repository knows what any of those words mean.
    #
    # sample-module.json could not make this claim. It was lifted out of a real
    # render, so every shape in it was a shape one producer already emitted.
    # This one exists to be the case that producer would never have produced.
    #
    # It also carries four things sample-module.json does not, each of which is
    # a way rendering can go wrong and none of which the golden has ever seen:
    #
    #   1. a label with an apostrophe AND an angle bracket
    #   2. a path with a space in it
    #   3. a two-node cycle
    #   4. a metric at the top of its range
    $script:Fixture = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'infrastructure.json') -Raw |
        ConvertFrom-Json
}

Describe 'A view model of something that is not code' {
    It 'has no producer module loaded while it runs' {
        @(Get-Module -Name PSModuleGraph).Count | Should-Be 0
    }

    It 'carries the four shapes the sample payload does not' {
        # Asserted on the fixture itself, not on the output. If someone tidies
        # the awkwardness out of the data, every test below keeps passing while
        # testing nothing, and this is the one that notices.
        $nodes = $script:Fixture.data.nodes

        $hostileLabel = @($nodes | Where-Object { $_.name -match "'" -and $_.name -match '[<>]' })
        $hostileLabel.Count | Should-BeGreaterThan 0

        $spacedPath = @($nodes | Where-Object { $_.path -match ' ' })
        $spacedPath.Count | Should-BeGreaterThan 0

        $links = $script:Fixture.data.links
        $cycle = @($links | Where-Object { $edge = $_
                $links | Where-Object { $_.source -eq $edge.target -and $_.target -eq $edge.source } })
        $cycle.Count | Should-BeGreaterThan 0

        $top = ($nodes.metrics.blastRadius | Measure-Object -Maximum).Maximum
        @($nodes | Where-Object { $_.metrics.blastRadius -eq $top }).Count | Should-BeGreaterThan 0
        $top | Should-BeGreaterThan 0
    }

    It 'renders through every backend' -ForEach @(
        @{ Backend = 'cytoscape' }
        @{ Backend = 'plain' }
    ) {
        $document = New-RenderDocument -ViewModel $script:Fixture.data -Meta $script:Fixture.meta `
            -Title 'prod-eu-west-1' -TemplateSet $Backend

        $document | Should-MatchString '<!DOCTYPE html>'
        $document | Should-NotMatchString '__SLOT_[A-Z0-9_]+__'
        $document | Should-NotMatchString '/\*__[A-Z]+__\*/ null'
        $document | Should-NotMatchString '__PAGE_TITLE__'
    }

    It 'keeps a label with an apostrophe and an angle bracket out of the markup' -ForEach @(
        @{ Backend = 'cytoscape' }
        @{ Backend = 'plain' }
    ) {
        # "customers' uploads <staging>". The angle brackets must not survive
        # into the document as markup, or a label closes a tag it did not open.
        $document = New-RenderDocument -ViewModel $script:Fixture.data -Meta $script:Fixture.meta `
            -Title 'Escaping' -TemplateSet $Backend

        $document | Should-NotMatchString ([regex]::Escape('<staging>'))
        $document | Should-MatchString 'staging'
    }

    It 'survives a closing script sequence in a label' -ForEach @(
        @{ Backend = 'cytoscape' }
        @{ Backend = 'plain' }
    ) {
        # The payload lives inside a <script> block. A label carrying </script>
        # would terminate it and everything after would render as text.
        $hostile = $script:Fixture.data | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $hostile.nodes[0].name = 'break</script><script>alert(1)</script>out'

        $document = New-RenderDocument -ViewModel $hostile -Title 'Hostile' -TemplateSet $Backend

        # Every </script> in the document must be closing a <script> the layout
        # opened, so the two counts agree. An escaped one is </script>.
        ([regex]::Matches($document, '</script>')).Count |
            Should-Be ([regex]::Matches($document, '<script[ >]')).Count
    }

    It 'carries the path with a space in it through unaltered' {
        $document = New-RenderDocument -ViewModel $script:Fixture.data -Meta $script:Fixture.meta `
            -Title 'Spaces' -TemplateSet plain

        # A path is data. Nothing may helpfully normalise, escape or quote it on
        # the way through - the page rebuilds absolute paths from meta and a
        # mangled relative path would point at nothing.
        $document | Should-MatchString ([regex]::Escape('modules/data store/rds.tf'))
    }

    It 'renders a two-node cycle without looping' {
        # Two security groups that each allow the other. A layout that walks
        # edges without a visited set hangs here rather than failing, so the
        # assertion that matters is that this test finishes at all.
        $document = New-RenderDocument -ViewModel $script:Fixture.data -Title 'Cycle' -TemplateSet plain

        $document | Should-MatchString 'aws_security_group.database'
        $document | Should-MatchString 'aws_security_group.application'
    }

    It 'branches on no node kind this fixture uses' {
        # resource, module, variable, output. Nothing in src/ may special-case
        # any of them - the moment it does, a third producer's vocabulary is a
        # code change.
        #
        # COMPARISONS, not occurrences. Two of these kinds are ordinary words
        # that shipped code has every right to use for something else: the
        # reports directory is literally called 'output'. What would actually
        # break a producer is code that ASKS whether something is of a kind, so
        # that is what this looks for.
        #
        # It caught one real thing when it was written, and not by this clause:
        # New-RenderDocumentPath took -ModuleName and fell back to the stem
        # 'module'. A path builder does not know what it is naming.
        $srcRoot = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'src/PSGraphRender'
        $kinds = @($script:Fixture.data.nodes.kind | Select-Object -Unique)
        $operators = '-eq|-ne|-like|-notlike|-match|-notmatch|-contains|-notcontains|-in|-notin'

        $offenders = foreach ($file in Get-ChildItem -LiteralPath $srcRoot -Filter *.ps1 -File -Recurse) {
            $code = [regex]::Replace((Get-Content -LiteralPath $file.FullName -Raw), '(?s)<#.*?#>', '')
            foreach ($kind in $kinds) {
                # [char]39 and [char]34 rather than an escaped literal: this
                # string is a regex character class of both quote characters,
                # and writing it inline is how you get it wrong.
                $anyQuote = '[' + [char]39 + [char]34 + ']'
                $quoted = $anyQuote + [regex]::Escape($kind) + $anyQuote
                if ($code -match "($operators)\s*$quoted" -or $code -match "$quoted\s*($operators)") {
                    "$($file.Name): $kind"
                }
            }
        }

        @($offenders).Count | Should-Be 0 -Because "shipped code branches on a node kind: $(@($offenders) -join '; ')"
    }
}
