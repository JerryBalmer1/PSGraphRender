#Requires -Version 7.0
<#
.SYNOPSIS
    Total the open and closed threads across one or more ledger directories and
    write the result as a committed JSON record.

.DESCRIPTION
    IT REPORTS. IT DOES NOT DECIDE.

    No scoring, no priority, no staleness heuristic, no "stale" flag, no sort by
    anything but id. That is not an omission and it is not a first version.
    Ledger `0010` measured what carry count actually predicts and the answer was
    nothing: twenty-one of twenty-three closures happened in the very next
    entry, and nothing has ever been closed after being carried four times. A
    number that rises every iteration and has never once decided anything is not
    a priority signal, and a tool that ranked on it would put the same mistake
    in code, where it would look authoritative.

    `carries` is here because it is a fact about the record. What it means is
    the reader's problem and the reader has the ledger.

    Written after the survey it replaces, not instead of it - see `0010-t4`. The
    hand pass took a full reading of twenty-six files and was stale the moment
    the next entry landed; it also produced the before-and-after that made this
    worth writing. That ordering was the point.

.PARAMETER Ledger
    One or more `<label>=<path>` pairs naming a ledger directory. The label is
    the repository name as it appears in the output. Paths are resolved
    relative to the current directory.

.PARAMETER OutputPath
    Where to write the record. Defaults to `docs/threads.json` beside this
    repository.

.EXAMPLE
    ./tools/threads.ps1 -Ledger 'PSGraphRender=knowledge/ledger', 'PSModuleGraph=../PSModuleGraph/knowledge/ledger'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]] $Ledger,
    [Parameter()] [string] $OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The front matter is read with a regex rather than a YAML parser. There is no
# YAML parser in either repository, adding one to read five array fields would
# be the larger mistake, and a malformed entry throws here rather than being
# silently counted as empty.
function Read-LedgerEntry {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Repository)

    $text = [System.IO.File]::ReadAllText($Path)
    $split = [regex]::Match($text, "(?s)^---\r?\n(?<front>.*?)\r?\n---\r?\n(?<body>.*)$")
    if (-not $split.Success) { throw "no front matter in $Path" }

    $front = $split.Groups['front'].Value
    $body = $split.Groups['body'].Value

    function Read-List {
        param([string] $Source, [string] $Key)
        $m = [regex]::Match($Source, "(?m)^$Key\s*:\s*\[(?<v>[^\]]*)\]\s*$")
        if (-not $m.Success) { return @() }
        @($m.Groups['v'].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $id = [regex]::Match($front, '(?m)^id\s*:\s*"(?<v>[0-9]{4})"\s*$').Groups['v'].Value
    if (-not $id) { throw "no id in $Path" }

    [pscustomobject]@{
        Repository     = $Repository
        Id             = $id
        Tag            = [regex]::Match($front, '(?m)^tag\s*:\s*(?<v>\S+)\s*$').Groups['v'].Value
        Date           = [regex]::Match($front, '(?m)^date\s*:\s*(?<v>\S+)\s*$').Groups['v'].Value
        OpenThreads    = Read-List -Source $front -Key 'open_threads'
        Closes         = Read-List -Source $front -Key 'closes'
        CarriesForward = Read-List -Source $front -Key 'carries_forward'
        Supersedes     = Read-List -Source $front -Key 'supersedes_threads'
        Recovers       = Read-List -Source $front -Key 'recovers_threads'
        Body           = $body
    }
}

# The one line comes from the entry that RAISED the thread, in the numbered
# "Open threads" list, where it is written as **[0004-t2] One sentence.** Later
# glosses in later entries are shorter and drift; the original is what the
# thread meant when somebody decided it was worth an id.
function Get-ThreadSummary {
    param([string] $Body, [string] $Id)

    $m = [regex]::Match($Body, "\[$([regex]::Escape($Id))\]\s*(?<v>.+?\.)(\s|\*\*)", 'Singleline')
    if (-not $m.Success) { return '' }
    ($m.Groups['v'].Value -replace '\s+', ' ' -replace '\*\*', '').Trim()
}

$sources = [System.Collections.Generic.List[object]]::new()
$entries = [System.Collections.Generic.List[object]]::new()

foreach ($spec in $Ledger) {
    $parts = $spec -split '=', 2
    if ($parts.Count -ne 2) { throw "-Ledger takes '<label>=<path>' pairs; got '$spec'." }
    $label = $parts[0].Trim()
    $dir = $parts[1].Trim()
    if (-not (Test-Path -LiteralPath $dir)) { throw "No ledger directory at '$dir' (for '$label')." }

    $found = @(Get-ChildItem -LiteralPath $dir -Filter '*.md' -File | Sort-Object Name)
    if ($found.Count -eq 0) { throw "No ledger entries under '$dir'. An empty source is not the same as a source with nothing open." }

    foreach ($file in $found) { $entries.Add((Read-LedgerEntry -Path $file.FullName -Repository $label)) }
    $sources.Add([ordered]@{ repository = $label; path = (Resolve-Path -LiteralPath $dir).Path; entries = $found.Count })
}

$threads = [System.Collections.Generic.List[object]]::new()

foreach ($repository in ($sources | ForEach-Object { $_.repository })) {
    $chain = @($entries | Where-Object { $_.Repository -eq $repository } | Sort-Object Id)
    $state = [ordered]@{}

    foreach ($entry in $chain) {
        foreach ($id in $entry.OpenThreads) {
            if (-not $state.Contains($id)) {
                $state[$id] = [ordered]@{
                    id         = $id
                    repository = $repository
                    openedAt   = $entry.Id
                    openedTag  = $entry.Tag
                    carries    = 0
                    status     = 'open'
                    resolvedAt = $null
                    summary    = (Get-ThreadSummary -Body $entry.Body -Id $id)
                }
            }
        }
        foreach ($id in $entry.CarriesForward) {
            if ($state.Contains($id)) { $state[$id].carries++ }
        }
        foreach ($id in $entry.Closes) {
            if ($state.Contains($id)) { $state[$id].status = 'closed'; $state[$id].resolvedAt = $entry.Id }
        }
        foreach ($id in $entry.Supersedes) {
            if ($state.Contains($id)) { $state[$id].status = 'superseded'; $state[$id].resolvedAt = $entry.Id }
        }
        foreach ($id in $entry.Recovers) {
            if ($state.Contains($id)) { $state[$id].recoveredAt = $entry.Id }
        }
    }

    foreach ($id in $state.Keys) { $threads.Add($state[$id]) }
}

$byStatus = @{}
foreach ($status in 'open', 'closed', 'superseded') {
    $byStatus[$status] = @($threads | Where-Object { $_.status -eq $status }).Count
}

$perRepository = [ordered]@{}
foreach ($repository in ($sources | ForEach-Object { $_.repository })) {
    $mine = @($threads | Where-Object { $_.repository -eq $repository })
    $perRepository[$repository] = [ordered]@{
        raised     = $mine.Count
        open       = @($mine | Where-Object { $_.status -eq 'open' }).Count
        closed     = @($mine | Where-Object { $_.status -eq 'closed' }).Count
        superseded = @($mine | Where-Object { $_.status -eq 'superseded' }).Count
        recovered  = @($mine | Where-Object { $_.PSObject.Properties.Name -contains 'recoveredAt' }).Count
    }
}

$record = [ordered]@{
    schemaVersion = '1.0.0'
    toolchain     = [ordered]@{
        tool              = 'tools/threads.ps1'
        powerShellVersion = [string]$PSVersionTable.PSVersion
        powerShellEdition = [string]$PSVersionTable.PSEdition
    }
    run           = [ordered]@{
        # UTC and second-resolution, so two runs on one day differ only where
        # the ledgers differ. A record that churns on its own timestamp is a
        # record nobody diffs.
        generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        sources      = $sources
    }
    counts        = [ordered]@{
        raised     = $threads.Count
        open       = $byStatus['open']
        closed     = $byStatus['closed']
        superseded = $byStatus['superseded']
        perRepository = $perRepository
    }
    # Sorted by repository then id, and by nothing else. Ordering is the
    # cheapest place a reporting tool starts deciding.
    threads       = @($threads | ForEach-Object { [pscustomobject]$_ } | Sort-Object -Property repository, id)
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'docs/threads.json'
}
$json = $record | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutputPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))

Write-Host ("{0} thread(s): {1} open, {2} closed, {3} superseded -> {4}" -f
    $record.counts.raised, $record.counts.open, $record.counts.closed, $record.counts.superseded, $OutputPath)
