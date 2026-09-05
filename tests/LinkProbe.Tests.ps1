#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# How the link probe reaches a backend's node actions, declared BY that backend.
#
# `./build.ps1 -Task TestLinkMode` used to carry a `$LINK_PROBE` map naming each
# backend's canvas, menu and mouse button, and `tests/browser/link-mode.cjs`
# used to carry cytoscape's as fallback defaults. Both were second and third
# places a backend's shape was written down - the exact defect the `Smoke` block
# was invented to remove from `tests/browser/smoke.cjs`, whose own comment states
# the rule: *a harness naming '#c-nodes' would be a second place this backend's
# shape is written down, somewhere other than this backend.*
#
# So the declaration lives in `templateset.psd1` beside `Smoke`, and this suite
# is the gate that keeps it there:
#
#   A. every backend with link modes declares a LinkProbe the harness can use;
#   B. neither the build task nor the harness names a selector any more;
#   C. declaring one changes no rendered byte.
#
# What a probe VALUE is worth is not asserted here and cannot be: a selector is
# right only if a browser finds an element with it. `./build.ps1 -Task
# TestLinkMode` is what establishes that, and it is a separate gate for the same
# reason TestBrowser is.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    Import-PSGraphRenderUnderTest

    $script:RepoRootDir = Split-Path $PSScriptRoot -Parent
    $script:BuildScript = Join-Path $script:RepoRootDir 'PSGraphRender.build.ps1'
    $script:HarnessFile = Join-Path $PSScriptRoot 'browser/link-mode.cjs'

    # The fields tests/browser/link-mode.cjs cannot work without. Stated here
    # because this is the gate: the harness fails BY NAME on a job missing one,
    # and this turns that failure red at build time instead of forty seconds
    # into a browser run.
    $script:RequiredProbeField = @('Canvas', 'Menu', 'Button', 'Ready')

    # Discovered, never listed - the same rule Get-BackendDirectory documents.
    $script:Backend = @(Get-BackendDirectory | ForEach-Object {
            [pscustomobject]@{
                Name     = $_.Name
                Path     = $_.FullName
                Manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $_.FullName 'templateset.psd1')
            }
        })

    function Test-DeclaresLinkMode {
        param([Parameter(Mandatory)] $Backend)

        # The same three questions the build task's discovery asks, in the same
        # order. A backend answering yes to all three is one whose link modes a
        # browser is expected to drive.
        if (-not $Backend.Manifest.Contains('SlotsBySetting')) { return $false }
        if (-not $Backend.Manifest.SlotsBySetting.Contains('LinkMode')) { return $false }
        return $true
    }

    $script:WithLinkMode = @($script:Backend | Where-Object { Test-DeclaresLinkMode -Backend $_ })
    $script:WithoutLinkMode = @($script:Backend | Where-Object { -not (Test-DeclaresLinkMode -Backend $_) })

    $script:Scratch = Join-Path ([System.IO.Path]::GetTempPath()) "psgraphrender-linkprobe-$PID"
    New-Item -ItemType Directory -Path $script:Scratch -Force | Out-Null

    $script:ViewModel = Get-Content -LiteralPath (Get-ViewModelFixturePath -Name 'sample-module.json') -Raw |
        ConvertFrom-Json

    # A COPY of a shipped backend, never an edit in place - the same rule
    # LinkMode.Tests.ps1 states. `Mutate` receives the manifest text and returns
    # what should replace it, so a case says what it changes and nothing else.
    function New-MutatedBackend {
        param(
            [Parameter(Mandatory)] [string] $Name,
            [Parameter(Mandatory)] [string] $Backend,
            [Parameter(Mandatory)] [scriptblock] $Mutate
        )

        $source = Join-Path (Get-BuiltModuleRoot) "TemplateSets/$Backend"
        if (-not (Test-Path -LiteralPath $source)) {
            $source = Join-Path $script:RepoRootDir "src/PSGraphRender/TemplateSets/$Backend"
        }

        $dest = Join-Path $script:Scratch $Name
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Copy-Item -LiteralPath $source -Destination $dest -Recurse -Force

        $file = Join-Path $dest 'templateset.psd1'
        [System.IO.File]::WriteAllText($file, (& $Mutate ([System.IO.File]::ReadAllText($file))))
        $dest
    }

    # Delete one top-level block from a manifest, by counting braces from its
    # opening line. Text surgery on a data file is worth distrusting, so every
    # caller asserts the result still PARSES and no longer carries the key -
    # a stripper that silently did nothing would make the strongest claim in
    # this file for the weakest reason.
    function Remove-ManifestBlock {
        param(
            [Parameter(Mandatory)] [string] $Text,
            [Parameter(Mandatory)] [string] $Key
        )

        $lines = $Text -split "`r?`n"
        $start = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s*$Key\s*=\s*@\{") { $start = $i; break }
        }
        if ($start -lt 0) { return $Text }

        $depth = 0
        $end = -1
        for ($i = $start; $i -lt $lines.Count; $i++) {
            $depth += ([regex]::Matches($lines[$i], '\{')).Count
            $depth -= ([regex]::Matches($lines[$i], '\}')).Count
            if ($depth -le 0) { $end = $i; break }
        }
        if ($end -lt 0) { return $Text }

        # Take the comment block immediately above it too. A header left behind
        # describing a block that is gone is the kind of debris that makes a
        # scratch fixture read like a manifest somebody meant.
        while ($start -gt 0 -and $lines[$start - 1] -match '^\s*#') { $start-- }

        (@($lines[0..($start - 1)]) + @($lines[($end + 1)..($lines.Count - 1)])) -join "`n"
    }

    function New-Document {
        param([Parameter(Mandatory)] [string] $TemplateSetPath)

        New-RenderDocument -ViewModel $script:ViewModel.data -Meta $script:ViewModel.meta `
            -Title 'Link probe fixture' -TemplateSetPath $TemplateSetPath
    }
}

AfterAll {
    if ($script:Scratch -and (Test-Path -LiteralPath $script:Scratch)) {
        Remove-Item -LiteralPath $script:Scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Acceptance A: a backend with link modes declares how to reach them' {

    It 'found backends on both sides of the rule' {
        # A rule that applies to everything or to nothing is not discriminating,
        # and would pass just as happily if Test-DeclaresLinkMode were broken.
        # `plain` renders a table and has no node action at all; it is the
        # backend that must NOT need a probe.
        @($script:WithLinkMode).Count | Should-BeGreaterThan 1
        @($script:WithoutLinkMode).Count | Should-BeGreaterThan 0
    }

    It 'declares a LinkProbe block for every backend that declares link modes' {
        foreach ($backend in $script:WithLinkMode) {
            $because = "$($backend.Name) declares SlotsBySetting.LinkMode, so something has to say how a " +
            'browser reaches its node actions; without it the probe would either guess or skip the backend'
            $backend.Manifest.Contains('LinkProbe') | Should-BeTrue -Because $because
        }
    }

    It 'carries every field the harness consumes, as a non-empty value' {
        # The counter is the point. Skipping a backend with no block keeps the
        # failure above from being reported twice in different words - but a
        # loop that skipped EVERYTHING would report the same green, which is
        # the shape of a check nobody notices has stopped looking.
        $checked = 0
        foreach ($backend in $script:WithLinkMode) {
            if (-not $backend.Manifest.Contains('LinkProbe')) { continue }
            $checked++
            $probe = $backend.Manifest.LinkProbe

            foreach ($field in $script:RequiredProbeField) {
                $message = "$($backend.Name) LinkProbe is missing $field"
                $probe.Contains($field) | Should-BeTrue -Because $message
                [string]::IsNullOrWhiteSpace([string]$probe[$field]) |
                    Should-BeFalse -Because "$message, or declares it empty"
            }
        }
        $checked | Should-Be @($script:WithLinkMode).Count `
            -Because 'every backend with link modes must have been examined here, not skipped past'
    }

    It 'names a real mouse button' {
        # The one field whose domain is fixed by Playwright rather than by a
        # backend. A typo here costs a forty-second browser run that reports
        # "no node menu opened" and blames the page.
        $checked = 0
        foreach ($backend in $script:WithLinkMode) {
            if (-not $backend.Manifest.Contains('LinkProbe')) { continue }
            $checked++
            @('left', 'right', 'middle') |
                Should-ContainCollection ([string]$backend.Manifest.LinkProbe.Button) `
                    -Because "$($backend.Name) declares a button a browser cannot press"
        }
        $checked | Should-Be @($script:WithLinkMode).Count `
            -Because 'every backend with link modes must have been examined here, not skipped past'
    }

    It 'declares no LinkProbe for a backend with no link modes' {
        # The other half of "discriminating". A block here would be data nothing
        # reads, which is how a manifest starts describing a backend it is not.
        foreach ($backend in $script:WithoutLinkMode) {
            $backend.Manifest.Contains('LinkProbe') |
                Should-BeFalse -Because "$($backend.Name) declares no link modes, so it needs no probe"
        }
    }
}

Describe 'Acceptance B: the selectors are written down once' {

    It 'keeps a probe map out of the build task' {
        # By absence. The map was here, and the entry that logged it said so:
        # docs/improvements.md, "The link probe names each backend's selectors
        # in the build task".
        $text = [System.IO.File]::ReadAllText($script:BuildScript)
        $text.Contains('$LINK_PROBE') |
            Should-BeFalse -Because 'the build task must read the declaration, not carry a second copy of it'
    }

    It 'keeps every declared selector out of the browser harness' {
        # Derived from the manifests rather than from a list of known selectors,
        # so a fourth backend's shape is covered the day it is declared and not
        # the day somebody remembers to add it here.
        #
        # Matched as a quoted JS literal, which is what "written down in the
        # harness" would actually look like, and searched with comments removed:
        # the file is allowed to DISCUSS '#cy' in the sentence explaining why it
        # must not contain one.
        $code = Remove-JavaScriptComment -Source ([System.IO.File]::ReadAllText($script:HarnessFile))

        $declared = @(
            foreach ($backend in $script:WithLinkMode) {
                if (-not $backend.Manifest.Contains('LinkProbe')) { continue }
                foreach ($key in @($backend.Manifest.LinkProbe.Keys)) {
                    $value = $backend.Manifest.LinkProbe[$key]
                    if ($value -is [string] -and $value) { $value }
                }
            }
        ) | Sort-Object -Unique

        @($declared).Count |
            Should-BeGreaterThan 3 -Because 'a check derived from an empty list checks nothing'

        foreach ($value in $declared) {
            foreach ($literal in "'$value'", "`"$value`"") {
                $code.Contains($literal) |
                    Should-BeFalse -Because "link-mode.cjs names $literal, which is a backend's shape stated somewhere other than that backend"
            }
        }
    }
}

Describe 'Acceptance C: declaring a probe changes no rendered byte' {

    It 'renders identically with the LinkProbe block removed entirely' {
        # The whole claim of putting it in templateset.psd1: it is data for a
        # gate, not for the document. Get-RenderTemplateSet reads Layout, Slots
        # and SlotsBySetting and nothing else, and this is what asserts that
        # stays true rather than assuming it.
        foreach ($backend in $script:WithLinkMode) {
            $stripped = New-MutatedBackend -Name "$($backend.Name)-noprobe" -Backend $backend.Name -Mutate {
                param($text) Remove-ManifestBlock -Text $text -Key 'LinkProbe'
            }

            # The surgery, distrusted. Both of these are red if the stripper
            # matched nothing, which would make the comparison below vacuous.
            $after = Import-PowerShellDataFile -LiteralPath (Join-Path $stripped 'templateset.psd1')
            $after.Contains('LinkProbe') |
                Should-BeFalse -Because "the fixture for $($backend.Name) must actually have lost the block"
            $after.Contains('Slots') |
                Should-BeTrue -Because 'and must have lost nothing else'

            $shipped = New-MutatedBackend -Name "$($backend.Name)-shipped" -Backend $backend.Name -Mutate {
                param($text) $text
            }

            (New-Document -TemplateSetPath $stripped) |
                Should-Be (New-Document -TemplateSetPath $shipped) `
                    -Because "$($backend.Name)'s LinkProbe block must be invisible to assembly"
        }
    }

    It 'goes red for a manifest edit that DOES reach the document' {
        # Red-capability for the comparison above. A control that cannot fail
        # reports the same green whether or not it is looking at anything.
        $backend = $script:WithLinkMode[0]

        $mutated = New-MutatedBackend -Name "$($backend.Name)-slots" -Backend $backend.Name -Mutate {
            param($text) $text -replace "(?m)^(\s*STYLES\s*=\s*@\()", '$1''styles/base.css'', '
        }

        $shipped = New-MutatedBackend -Name "$($backend.Name)-control" -Backend $backend.Name -Mutate {
            param($text) $text
        }

        (New-Document -TemplateSetPath $mutated) |
            Should-NotBe (New-Document -TemplateSetPath $shipped) `
                -Because 'a Slots edit reaches the document, so the comparison above can fail'
    }
}
