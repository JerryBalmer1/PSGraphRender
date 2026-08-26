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
