#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:Repo = Split-Path -Path $PSScriptRoot -Parent
    $script:SchemaPath = Join-Path $script:Repo 'contract/viewmodel.schema.json'
    $script:Schema = Get-Content -LiteralPath $script:SchemaPath -Raw | ConvertFrom-Json
    $script:Backends = @(Get-BackendDirectory)

    function Get-DeclaredField {
        <#
        .SYNOPSIS
            The property names one section of the contract declares.
        #>
        param(
            [Parameter(Mandatory)] [string] $Section,
            [switch] $DeprecatedOnly
        )

        $properties = $script:Schema.properties.$Section.properties
        foreach ($property in $properties.PSObject.Properties) {
            $isDeprecated = $property.Value.PSObject.Properties['deprecated'] -and $property.Value.deprecated
            if ($DeprecatedOnly -and -not $isDeprecated) { continue }
            $property.Name
        }
    }

    function Get-PayloadAccess {
        <#
        .SYNOPSIS
            Every payload field a backend script reads, with where it reads it.
        .DESCRIPTION
            DATA and META are the two names New-RenderDocument substitutes a
            payload into, so anything reaching the payload either uses them or
            was assigned one of them. Direct aliases are followed - the
            reference backend opens with `var meta = META || {}` and reads
            `meta.rootPath` four files later - because a scan that only saw
            `META.` would find two accesses in a backend that makes eight.

            A field read is looked for with nothing before the name, which is
            what separates the payload's `data.metrics` from Cytoscape's
            `el.data.name`. Both appear in elements.js and only one of them is
            about the contract.
        #>
        param(
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $Source,
            [Parameter(Mandatory)] [string] $Name
        )

        $source = Remove-JavaScriptComment -Source $Source

        # name -> which contract section it is a view of.
        $aliases = [ordered]@{ DATA = 'data'; META = 'meta' }
        $declaration = '(?m)^\s*(?:var|let|const)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(DATA|META)\b(?!\s*\.)'
        foreach ($match in [regex]::Matches($source, $declaration)) {
            $aliases[$match.Groups[1].Value] = if ($match.Groups[2].Value -eq 'DATA') { 'data' } else { 'meta' }
        }

        $lines = $source -split "`n"
        foreach ($alias in $aliases.Keys) {
            $pattern = '(?<![.\w$])' + [regex]::Escape($alias) + '\.([A-Za-z_$][A-Za-z0-9_$]*)'
            for ($i = 0; $i -lt $lines.Count; $i++) {
                foreach ($match in [regex]::Matches($lines[$i], $pattern)) {
                    [pscustomobject]@{
                        Section = $aliases[$alias]
                        Field   = $match.Groups[1].Value
                        Where   = "${Name}:$($i + 1)"
                        Via     = $alias
                    }
                }
            }
        }
    }

    $script:Accesses = @(
        foreach ($backend in $script:Backends) {
            $scripts = Join-Path $backend.FullName 'scripts'
            if (-not (Test-Path -LiteralPath $scripts)) { continue }
            foreach ($file in Get-ChildItem -LiteralPath $scripts -Filter *.js -File) {
                Get-PayloadAccess -Source (Get-Content -LiteralPath $file.FullName -Raw) -Name $file.Name |
                    Add-Member -NotePropertyName Backend -NotePropertyValue $backend.Name -PassThru
            }
        }
    )
}

Describe 'A backend reads only what the contract promises' {
    It 'found payload accesses to check, in every backend' {
        # Every assertion below is of the form "none of these is wrong", which
        # passes perfectly when the scan found nothing at all. This is the test
        # that says the scan works.
        foreach ($backend in $script:Backends) {
            $found = @($script:Accesses | Where-Object Backend -EQ $backend.Name)
            $found.Count | Should-BeGreaterThan 0 -Because "$($backend.Name) reads the payload somewhere"
        }
    }

    It 'reads no <_> field the schema does not declare' -ForEach @('data', 'meta') {
        $section = $_
        $declared = @(Get-DeclaredField -Section $section)
        @($declared).Count | Should-BeGreaterThan 0

        $undeclared = @(
            $script:Accesses |
                Where-Object { $_.Section -eq $section -and $_.Field -notin $declared } |
                ForEach-Object { "$($_.Backend)/$($_.Where) reads $section.$($_.Field)" }
        )

        # By name and by file, because "a backend reads something undeclared"
        # is a sentence nobody can act on.
        $undeclared -join '; ' | Should-Be ''
    }

    It 'reads no meta name the seam removes before the payload leaves' {
        # Resolve-RenderMeta accepts a deprecated name on the way IN and strips
        # it on the way out, so the contract declaring it is not the same as it
        # arriving. A backend reading meta.moduleRoot reads undefined for every
        # payload ever written, including the ones that still send it.
        $removed = @(Get-DeclaredField -Section 'meta' -DeprecatedOnly)
        @($removed).Count | Should-BeGreaterThan 0

        $reading = @(
            $script:Accesses |
                Where-Object { $_.Section -eq 'meta' -and $_.Field -in $removed } |
                ForEach-Object { "$($_.Backend)/$($_.Where) reads meta.$($_.Field), which never arrives" }
        )

        $reading -join '; ' | Should-Be ''
    }
}

Describe 'The scan itself' {
    # A check expressed as "none of these is wrong" is only worth what its
    # detector is worth, and nothing above would fail if the detector found
    # nothing. These feed it source with a known answer.

    It 'follows a direct alias of the payload' {
        $source = @'
var meta = META || {};
var data = DATA;
document.title = meta.title + data.roots.length;
'@
        $found = @(Get-PayloadAccess -Source $source -Name 'x.js')
        @($found | Where-Object { $_.Section -eq 'meta' -and $_.Field -eq 'title' }).Count | Should-Be 1
        @($found | Where-Object { $_.Section -eq 'data' -and $_.Field -eq 'roots' }).Count | Should-Be 1
    }

    It 'does not mistake another object property named data for the payload' {
        # elements.js reads el.data.name, which is Cytoscape's element store and
        # has nothing to do with the contract. Both appear in the same file.
        $source = @'
var data = DATA;
if (el.data && el.data.name) { return el.data.nonsense; }
'@
        $found = @(Get-PayloadAccess -Source $source -Name 'x.js')
        @($found | Where-Object { $_.Field -in 'name', 'nonsense' }).Count | Should-Be 0
    }

    It 'reports a field the contract does not declare' {
        $source = 'var rows = DATA.rows;'
        $found = @(Get-PayloadAccess -Source $source -Name 'x.js')
        $declared = @(Get-DeclaredField -Section 'data')

        @($found | Where-Object { $_.Field -notin $declared }).Field | Should-Be 'rows'
    }

    It 'cannot see a computed access, and this records that' {
        # The limitation, written as a test rather than as a comment, because a
        # comment saying "this is weak" is not a thing anyone runs. A backend
        # reading DATA[fieldName] passes every assertion in this file.
        $source = 'var rows = DATA["rows"]; var x = DATA[whatever];'
        @(Get-PayloadAccess -Source $source -Name 'x.js').Count | Should-Be 0
    }
}
