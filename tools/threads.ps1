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
    the reader's problem and the reader has the ledger. So is the path-flip
    hint added at v0.12.0: a thread names a path, the path exists or does not,
    and that is not what it was when the thread was raised. Two commits, one
    `git cat-file`, no model to be wrong. That is the line - a staleness SCORE
    would be a heuristic wearing a signal's clothes, and this tool would then
    be ranking after all.

    Nothing here schedules a triage. A hint that costs nothing to ignore is the
    cheap version; a pass somebody has to sit through is the expensive one.

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
        Accepts        = Read-List -Source $front -Key 'accepts_threads'
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

# The WHOLE numbered item, not its first sentence. The summary above is
# deliberately one sentence; a path is usually named in the second or third,
# and scanning only the sentence would have found `docs/html-architecture.md`
# and missed most of the rest.
function Get-ThreadItemText {
    param([string] $Body, [string] $Id)

    # The final alternative is end-of-input, and it is not decoration: ledger
    # 0001 has no blank line after its last thread, so without it this returned
    # nothing for `0001-t7` - which reads downstream exactly like a thread that
    # names no path. Found by running the hint, not by reading it.
    $m = [regex]::Match(
        $Body,
        "\[$([regex]::Escape($Id))\](?<v>.*?)(?=\r?\n\s*\d+\.\s+\*\*\[|\r?\n\r?\n|$)",
        'Singleline')
    if (-not $m.Success) { return (Get-ThreadSummary -Body $Body -Id $Id) }
    ($m.Groups['v'].Value -replace '\s+', ' ').Trim()
}

# ---- the path-flip hint -----------------------------------------------------
# IT STILL DOES NOT DECIDE. This reports one fact and no judgement: a thread
# names a path in backticks, and whether that path exists is not what it was
# when the thread was raised. A reader rules on what that means.
#
# The distinction against the ranking this tool refuses is the whole reason it
# is allowed to exist. A carry count is a number that rises on its own and has
# never once predicted a closure, so ranking on it would put a measured-false
# belief into code. A path either exists or it does not, at two commits, and
# `git cat-file -e` answers it. There is no model in here to be wrong.
#
# WHAT IT WOULD HAVE CAUGHT, run rather than estimated: ONE of the four stale
# Closes found by hand at v0.11.0 - `[0009-t4]`, which named a `CHANGELOG.md`
# that did not exist and then did. `PSGraphRender`'s `0012` argued for this and
# said three. That count was written without running anything, and all three
# parts of it were wrong: `[0003-t2]` and `[0004-t3]` name no path, and
# `[0001-t7]` names `docs/html-architecture.md`, which the same entry said had
# left PSModuleGraph at v0.9.0. It has not. It is still there, still tracked.
#
# So the case for this is weaker than the case made for it, and the first run
# is what said so. That is also the case FOR it: the argument was written from
# memory and believed, and one execution disagreed with three of its four
# claims. See `0013`.
function Get-NamedPath {
    param([string] $Text)

    # Backticked, because that is how every ledger entry writes a path, and a
    # bare-word scan over prose would collect English. A token counts as a path
    # if it has a separator or an extension this repository actually uses -
    # which keeps `0002-t4`, `Get-RenderTemplateSet` and `RequiredModules` out.
    $found = [regex]::Matches($Text, '`(?<v>[^`]+)`') |
        ForEach-Object { $_.Groups['v'].Value.Trim() } |
        Where-Object { $_ -match '/' -or $_ -match '\.(md|ps1|psd1|psm1|js|cjs|css|html|json|ya?ml)$' } |
        # A URI scheme has a slash and is not a path. `vscode:`, `file:` and
        # `http://127.0.0.1:PORT` all came through the first version.
        Where-Object { $_ -notmatch '^[A-Za-z][A-Za-z0-9+.-]*:' } |
        # A bare extension is a class of file, not a file. `.ps1` did too.
        Where-Object { $_ -notmatch '^\.' } |
        Where-Object { $_ -and $_ -notmatch '^\s*$' }

    # The trailing slash is KEPT. It is how a ledger says "directory", and the
    # two tests below branch on whether the token has a separator at all.
    @($found | Select-Object -Unique)
}

# A ledger writes a path two ways: repository-relative when it means a
# location, and bare when it means a file - `SubsystemCharter.Tests.ps1` rather
# than `tests/Private/SubsystemCharter.Tests.ps1`. Resolving a bare name
# against the root would report it absent at both ends, which looks exactly
# like a file that never moved and is the wrong answer twice.
$script:TreeCache = @{}

function Get-TreeAtTag {
    param([string] $RepositoryRoot, [string] $Tag)

    $key = "$RepositoryRoot`n$Tag"
    if ($script:TreeCache.ContainsKey($key)) { return $script:TreeCache[$key] }

    & git -C $RepositoryRoot rev-parse --verify --quiet "$Tag^{commit}" *> $null
    if ($LASTEXITCODE -ne 0) { $script:TreeCache[$key] = $null; return $null }

    $script:TreeCache[$key] = @(& git -C $RepositoryRoot ls-tree -r --name-only "$Tag" 2>$null)
    $script:TreeCache[$key]
}

function Test-PathAtTag {
    <#
        Did this path exist in the repository at that tag? $null when the
        question cannot be answered - no git, no such tag, not a work tree -
        because "unknown" and "absent" are different facts and a hint that
        conflated them would be the thing this tool exists not to be.
    #>
    param([string] $RepositoryRoot, [string] $Tag, [string] $Path)

    if (-not $Tag -or -not $RepositoryRoot) { return $null }

    $tree = Get-TreeAtTag -RepositoryRoot $RepositoryRoot -Tag $Tag
    if ($null -eq $tree) { return $null }

    $clean = $Path.TrimEnd('/')
    if ($Path -match '/') {
        return [bool](@($tree | Where-Object { $_ -eq $clean -or $_ -like "$clean/*" }).Count)
    }
    [bool](@($tree | Where-Object { (Split-Path -Path $_ -Leaf) -eq $clean }).Count)
}

function Test-PathNow {
    param([string] $RepositoryRoot, [string] $Path)

    if (-not $RepositoryRoot) { return $null }
    $clean = $Path.TrimEnd('/')
    if ($Path -match '/') { return [bool](Test-Path -LiteralPath (Join-Path $RepositoryRoot $clean)) }

    # Bare name: anywhere in the work tree, output/ and .git excluded because
    # a built copy is not the thing the thread was talking about.
    $hit = Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Filter $clean -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](\.git|output|node_modules)[\\/]' } |
        Select-Object -First 1
    [bool]$hit
}

$sources = [System.Collections.Generic.List[object]]::new()
$roots = @{}
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

    # <root>/knowledge/ledger, by the convention both stores keep. Resolved
    # rather than assumed: if the shape ever changes, the hint goes quiet
    # instead of reporting against the wrong tree.
    $ledgerPath = (Resolve-Path -LiteralPath $dir).Path
    $root = Split-Path -Path (Split-Path -Path $ledgerPath -Parent) -Parent
    if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) { $root = $null }

    # Held beside the record rather than in it. `path` is already one absolute
    # machine path in a committed file; a second would double the churn between
    # two checkouts for nothing a reader wants.
    $roots[$label] = $root

    $sources.Add([ordered]@{ repository = $label; path = $ledgerPath; entries = $found.Count })
}

$threads = [System.Collections.Generic.List[object]]::new()

foreach ($source in $sources) {
    $repository = $source.repository
    $root = $roots[$repository]
    $chain = @($entries | Where-Object { $_.Repository -eq $repository } | Sort-Object Id)
    $state = [ordered]@{}

    foreach ($entry in $chain) {
        foreach ($id in $entry.OpenThreads) {
            if (-not $state.Contains($id)) {
                $named = foreach ($path in (Get-NamedPath -Text (Get-ThreadItemText -Body $entry.Body -Id $id))) {
                    $then = Test-PathAtTag -RepositoryRoot $root -Tag $entry.Tag -Path $path
                    $now = Test-PathNow -RepositoryRoot $root -Path $path
                    [ordered]@{
                        path              = $path
                        existedWhenRaised = $then
                        existsNow         = $now
                        # $null wherever either end is unknown. A hint that
                        # guessed would be worse than a hint that abstains.
                        flipped           = if ($null -eq $then -or $null -eq $now) { $null } else { $then -ne $now }
                    }
                }

                $state[$id] = [ordered]@{
                    id         = $id
                    repository = $repository
                    openedAt   = $entry.Id
                    openedTag  = $entry.Tag
                    carries    = 0
                    status     = 'open'
                    resolvedAt = $null
                    summary    = (Get-ThreadSummary -Body $entry.Body -Id $id)
                    pathsNamed = @($named)
                }
            }
        }
        foreach ($id in $entry.CarriesForward) {
            if ($state.Contains($id)) { $state[$id].carries++ }
        }
        # A RECOVERY REOPENS, and it is applied BEFORE the retiring verbs so
        # that an entry which recovers and retires the same id in one pass ends
        # retired - which PSGraphRender 0011 did to `0002-t4`, recovering it so
        # the gap was on the record and superseding it in the same breath. The
        # continuity gate resolves them in exactly this order and the two must
        # not disagree.
        #
        # It had been leaving the status alone, which was right for the only
        # case it had ever seen - a thread dropped from carries_forward, still
        # 'open' - and wrong for the one that arrived at PSModuleGraph 0020,
        # where a thread was CLOSED for a reason that turned out to be false.
        # That read as closed-and-recovered, which is not a state, and it cost
        # the count one open thread.
        foreach ($id in $entry.Recovers) {
            if ($state.Contains($id)) {
                $state[$id].recoveredAt = $entry.Id
                $state[$id].status = 'open'
                $state[$id].resolvedAt = $null
            }
        }
        foreach ($id in $entry.Closes) {
            if ($state.Contains($id)) { $state[$id].status = 'closed'; $state[$id].resolvedAt = $entry.Id }
        }
        foreach ($id in $entry.Supersedes) {
            if ($state.Contains($id)) { $state[$id].status = 'superseded'; $state[$id].resolvedAt = $entry.Id }
        }
        # ACCEPTED is not CLOSED and the tool refuses to conflate them. Closed
        # means the question is answered; accepted means it is not and never
        # will be, and the constraint is written down somewhere a reader meets
        # it. Two facts, two words.
        foreach ($id in $entry.Accepts) {
            if ($state.Contains($id)) { $state[$id].status = 'accepted'; $state[$id].resolvedAt = $entry.Id }
        }
    }

    foreach ($id in $state.Keys) { $threads.Add($state[$id]) }
}

$byStatus = @{}
foreach ($status in 'open', 'closed', 'superseded', 'accepted') {
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
        accepted   = @($mine | Where-Object { $_.status -eq 'accepted' }).Count
        # `.Contains` on the dictionary, not `.PSObject.Properties`, which
        # on an ordered hashtable enumerates Count/Keys/Values and reported
        # zero recoveries for as long as there have been recoveries.
        recovered  = @($mine | Where-Object { $_.Contains('recoveredAt') }).Count
    }
}

# Listed here as well as sitting on each thread, because a hint nobody has to
# go looking for is a hint. It is a list, not a verdict: no order, no score, no
# recommendation about what to do with any of them.
$pathFlips = foreach ($thread in $threads) {
    foreach ($named in $thread.pathsNamed) {
        if ($named.flipped) {
            [ordered]@{
                id         = $thread.id
                repository = $thread.repository
                status     = $thread.status
                path       = $named.path
                # Which way it went. "Appeared" usually means the thread was
                # answered and nobody struck it; "vanished" usually means the
                # thread outlived the thing it describes. Usually is not a rule,
                # which is why this says which and stops.
                went       = if ($named.existsNow) { 'appeared since it was raised' } else { 'gone since it was raised' }
            }
        }
    }
}

$record = [ordered]@{
    # 1.1.0: pathsNamed and pathFlips are new fields. Additive is minor, the
    # same rule the view model contract keeps.
    schemaVersion = '1.1.0'
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
        accepted   = $byStatus['accepted']
        pathFlips  = @($pathFlips).Count
        perRepository = $perRepository
    }
    # Not sorted, not ranked, and deliberately kept whole rather than folded
    # into a count: a reader who wants to act on one needs the id.
    pathFlips     = @($pathFlips)
    # Sorted by repository then id, and by nothing else. Ordering is the
    # cheapest place a reporting tool starts deciding.
    threads       = @($threads | ForEach-Object { [pscustomobject]$_ } | Sort-Object -Property repository, id)
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'docs/threads.json'
}
$json = $record | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutputPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))

Write-Host ("{0} thread(s): {1} open, {2} closed, {3} accepted, {4} superseded -> {5}" -f
    $record.counts.raised, $record.counts.open, $record.counts.closed, $record.counts.accepted,
    $record.counts.superseded, $OutputPath)

# Printed, not acted on. It is here so a reader meets it without having to open
# the JSON and go looking, and it stops at the fact.
foreach ($flip in $record.pathFlips) {
    Write-Host ("  hint: [{0}] {1} in {2} names {3}, {4}" -f
        $flip.id, $flip.status, $flip.repository, $flip.path, $flip.went)
}
