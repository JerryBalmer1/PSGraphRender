#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-PSGraphRenderUnderTest

    $script:Backends = @(Get-BackendDirectory)

    # Every backend that vendors anything, with what its manifest says it
    # vendored. A backend with no vendor/ is not a failure - `plain` needs no
    # library and that is the point of it.
    $script:Vendoring = @(
        foreach ($backend in $script:Backends) {
            $dir = Join-Path $backend.FullName 'vendor'
            if (-not (Test-Path -LiteralPath $dir)) { continue }

            [pscustomobject]@{
                Name      = $backend.Name
                Root      = $backend.FullName
                Directory = $dir
                Manifest  = Import-PowerShellDataFile -LiteralPath (Join-Path $dir 'vendor.psd1') -ErrorAction Stop
                Set       = Import-PowerShellDataFile -LiteralPath (Join-Path $backend.FullName 'templateset.psd1') -ErrorAction Stop
            }
        }
    )
}

Describe 'A vendored library carries its provenance' {
    It 'has a backend that vendors something to check' {
        # Every assertion below iterates a collection. An empty one passes them
        # all, which is the failure mode of the whole file.
        @($script:Vendoring).Count | Should-BeGreaterThan 0
    }

    It 'records where every vendored file came from' {
        foreach ($v in $script:Vendoring) {
            $recorded = @($v.Manifest.Files | ForEach-Object { $_.Name }) | Sort-Object
            $present = @(
                Get-ChildItem -LiteralPath $v.Directory -File |
                    Where-Object { $_.Name -ne 'vendor.psd1' } |
                    ForEach-Object { $_.Name }
            ) | Sort-Object

            # Both directions. A file with no entry is a blob with no
            # provenance, which is the thing being prevented; an entry with no
            # file is a manifest describing something that is not there.
            ($recorded -join ', ') | Should-Be ($present -join ', ') -Because "$($v.Name)/vendor"
        }
    }

    It 'states a source URL, a version and a licence for each' {
        foreach ($v in $script:Vendoring) {
            foreach ($entry in $v.Manifest.Files) {
                $where = "$($v.Name)/vendor/$($entry.Name)"
                $entry.Url | Should-MatchString '^https://' -Because $where
                $entry.Version | Should-MatchString '^[0-9]+\.[0-9]+' -Because $where
                $entry.License | Should-MatchString '\S' -Because $where

                # The version in the URL and the version in the entry are two
                # statements of one fact, so they have to agree - otherwise the
                # manifest documents a file nobody fetched.
                $entry.Url | Should-BeLikeString "*@$($entry.Version)/*" -Because $where
            }
        }
    }

    It 'matches every file against the hash it was verified with' {
        # The only thing that makes a re-download checkable. Someone replacing
        # cytoscape in a year has to change the file, the version and this hash
        # together, and this test is what makes changing one of the three a
        # build failure rather than a silent swap.
        foreach ($v in $script:Vendoring) {
            foreach ($entry in $v.Manifest.Files) {
                $path = Join-Path $v.Directory $entry.Name
                $bytes = [System.IO.File]::ReadAllBytes($path)
                $computed = 'sha384-' + [Convert]::ToBase64String(
                    [System.Security.Cryptography.SHA384]::Create().ComputeHash($bytes))

                $computed | Should-Be $entry.Integrity -Because "$($v.Name)/vendor/$($entry.Name) does not match its recorded Subresource Integrity hash"
            }
        }
    }

    It 'names every vendored file in the template set manifest' {
        # A vendored file is an asset of the backend like any other. If it is
        # not in templateset.psd1 it does not reach the document, and the page
        # goes blank with the library missing.
        foreach ($v in $script:Vendoring) {
            $declared = @($v.Set.Slots.Values | ForEach-Object { $_ })
            foreach ($entry in $v.Manifest.Files) {
                ($declared -contains "vendor/$($entry.Name)") | Should-BeTrue -Because "$($v.Name) vendored $($entry.Name) and no slot uses it"
            }
        }
    }
}

Describe 'The vendor exclusion is scoped to vendor' {
    # An exclusion that quietly grows is how the producer-vocabulary check
    # missed four things for three tags. These bound it in both directions.

    It 'excludes a path with a vendor directory in it' {
        Test-VendorPath -Path 'C:\x\TemplateSets\cytoscape\vendor\cytoscape.min.js' | Should-BeTrue
        Test-VendorPath -Path 'TemplateSets/cytoscape/vendor/cytoscape.min.js' | Should-BeTrue
    }

    It 'excludes nothing else' {
        # The near misses, one per way a looser rule would go wrong.
        Test-VendorPath -Path 'TemplateSets/cytoscape/scripts/bootstrap.js' | Should-BeFalse
        Test-VendorPath -Path 'TemplateSets/cytoscape/scripts/vendor-notes.js' | Should-BeFalse
        Test-VendorPath -Path 'TemplateSets/cytoscape/vendored/thing.js' | Should-BeFalse
        Test-VendorPath -Path 'TemplateSets/myvendor/thing.js' | Should-BeFalse
        Test-VendorPath -Path 'TemplateSets/cytoscape/Config/settings.psd1' | Should-BeFalse
    }

    It 'skips exactly the files the manifests declare vendored, and no others' {
        # The formulation that matters: what a scan does NOT read must equal
        # what a backend says is not its code. Stated as two sets rather than as
        # a path rule, so a wider exclusion fails here even when it looks right.
        foreach ($backend in $script:Backends) {
            $all = @(Get-ChildItem -LiteralPath $backend.FullName -File -Recurse | ForEach-Object { $_.FullName })
            $scanned = @(Get-BackendSourceFile -Backend $backend.FullName | ForEach-Object { $_.FullName })
            $skipped = @($all | Where-Object { $_ -notin $scanned } |
                    ForEach-Object { [System.IO.Path]::GetFileName($_) }) | Sort-Object

            $vendorDir = Join-Path $backend.FullName 'vendor'
            $expected = @()
            if (Test-Path -LiteralPath $vendorDir) {
                $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $vendorDir 'vendor.psd1')
                $expected = @(@($manifest.Files | ForEach-Object { $_.Name }) + 'vendor.psd1') | Sort-Object
            }

            ($skipped -join ', ') | Should-Be ($expected -join ', ') -Because "$($backend.Name): the scan skips exactly its vendored files"
        }
    }

    It 'still reads the backend scripts it is supposed to read' {
        # The other failure: an exclusion so wide the scan reads nothing at all
        # would satisfy every "none of these appear" assertion in the suite.
        foreach ($backend in $script:Backends) {
            $scanned = @(Get-BackendSourceFile -Backend $backend.FullName -Include *.js)
            @($scanned).Count | Should-BeGreaterThan 0 -Because "$($backend.Name) has scripts of its own"
            @($scanned | Where-Object { $_.Name -eq 'bootstrap.js' }).Count | Should-Be 1
        }
    }
}
