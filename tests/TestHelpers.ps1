$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
$script:BuiltModulePath = Join-Path $RepoRoot 'output\PSGraphRender\PSGraphRender.psd1'
$script:SrcModulePath = Join-Path $RepoRoot 'src\PSGraphRender\PSGraphRender.psd1'
$script:ViewModelPath = Join-Path $PSScriptRoot 'fixtures\viewmodels'

function Import-PSGraphRenderUnderTest {
    [CmdletBinding()]
    param()

    Remove-Module -Name PSGraphRender -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $script:BuiltModulePath) {
        Import-Module -Name $script:BuiltModulePath -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name $script:SrcModulePath -Force -ErrorAction Stop
    }
}

function Get-ViewModelFixturePath {
    <#
    .SYNOPSIS
        Directory of hand-checkable view model payloads.
    .DESCRIPTION
        JSON on disk, never produced by running a producer. A suite that imports
        PSModuleGraph to get something to render has re-coupled the two
        repositories at the only place the coupling was removed.
    #>
    param([string] $Name)

    if ($Name) { return Join-Path $script:ViewModelPath $Name }
    $script:ViewModelPath
}

function Get-BuiltModulePath {
    $script:BuiltModulePath
}

function Get-BuiltModuleRoot {
    Split-Path -Path $script:BuiltModulePath -Parent
}

function Remove-JavaScriptComment {
    <#
    .SYNOPSIS
        Source with JavaScript comments removed, for checks that must not fire
        on prose.
    .DESCRIPTION
        Every check that scans backend scripts needs this, because a comment
        legitimately names the thing the check forbids - the comment above
        cfgMap in bootstrap.js says the word KIND_HEX was removed from, and a
        check that reads it reports the note explaining the fix as the bug.

        Line comments are stripped only when they START a line. A trailing //
        cannot be told from the // in a URL without parsing, and eating the
        second is worse than keeping the first.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Source
    )

    $text = [regex]::Replace($Source, '(?s)/\*.*?\*/', '')
    ($text -split "`n" | ForEach-Object { if ($_ -match '^\s*//') { '' } else { $_ } }) -join "`n"
}

function Get-BackendDirectory {
    <#
    .SYNOPSIS
        Every rendering backend, discovered the way the module discovers them.
    .DESCRIPTION
        By the presence of templateset.psd1, never from a list. A list here
        would be a second place a backend's existence is stated, which is the
        design bug iteration 2 removed from src/.
    #>
    [CmdletBinding()]
    param()

    Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src/PSGraphRender/TemplateSets') -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'templateset.psd1') }
}
