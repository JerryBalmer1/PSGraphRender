#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# A seal on a FINISHED iteration. Tagged PreTag and excluded from the default
# build, like everything else that judges an iteration rather than the work.
#
# This exists because `instruction-prune` told every session that a deferred
# deletion proposal is blocked by a gate in tests/PreTag.Tests.ps1, and in THIS
# repository there was no such gate. The document claimed an enforcement that
# was not there, `0009-t1` sat unenforced from the turn it was written, and
# nothing would ever have said so - which is
# PSModuleGraph's knowledge/patterns/0017-nothing-could-have-said-otherwise.md
# wearing a skill's clothes.
#
# The front matter is read with a regex rather than a YAML parser. There is no
# YAML parser here and adding one to read two array fields would be the larger
# mistake; the shape is fixed by the entries themselves and a malformed entry
# fails the first test below rather than passing silently.

BeforeAll {
    $script:LedgerDir = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'knowledge/ledger'

    function Get-LedgerFront {
        param([Parameter(Mandatory)][string] $Path)

        $text = [System.IO.File]::ReadAllText($Path)
        $match = [regex]::Match($text, "(?s)^---\r?\n(?<front>.*?)\r?\n---\r?\n(?<body>.*)$")
        if (-not $match.Success) { throw "no front matter in $Path" }

        $front = $match.Groups['front'].Value

        function Read-List {
            param([string] $Source, [string] $Key)
            $m = [regex]::Match($Source, "(?m)^$Key\s*:\s*\[(?<v>[^\]]*)\]\s*$")
            if (-not $m.Success) { return @() }
            @($m.Groups['v'].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        [pscustomobject]@{
            Path           = $Path
            Id             = [regex]::Match($front, '(?m)^id\s*:\s*"(?<v>[0-9]{4})"\s*$').Groups['v'].Value
            OpenThreads    = Read-List -Source $front -Key 'open_threads'
            PruneProposals = Read-List -Source $front -Key 'prune_proposals'
            CarriesForward = Read-List -Source $front -Key 'carries_forward'
            Closes         = Read-List -Source $front -Key 'closes'
            Supersedes     = Read-List -Source $front -Key 'supersedes_threads'
            Accepts        = Read-List -Source $front -Key 'accepts_threads'
            Recovers       = Read-List -Source $front -Key 'recovers_threads'
            Body           = $match.Groups['body'].Value
        }
    }

    $script:Entries = @(
        Get-ChildItem -LiteralPath $script:LedgerDir -Filter '*.md' -File |
            Sort-Object Name |
            ForEach-Object { Get-LedgerFront -Path $_.FullName }
    )
}

Describe 'Sealing an iteration' -Tag 'PreTag' {

    It 'finds ledger entries to judge at all' {
        # A zero-length list makes every assertion below vacuously true, which
        # is the failure mode of any gate expressed as a loop.
        $script:Entries.Count | Should-BeGreaterThan 1
        @($script:Entries | Where-Object { -not $_.Id }).Count | Should-Be 0
    }

    It 'closes every prune proposal the previous entry left open' {
        # THE BACKSTOP. instruction-prune applies a MOVE in-turn, because a move
        # loses nothing and there is nothing to review. A genuine DELETION still
        # proposes and waits - and waiting is free unless something costs.
        #
        # This is the cost. A proposal that survives a second entry unclosed
        # blocks the tag by name. Carrying it forward is not enough: carrying is
        # exactly the idling the mechanism exists to stop. Explicit rejection
        # closes it - "we considered this and it stays, because X" is a
        # decision, and silence is not.
        for ($i = 1; $i -lt $script:Entries.Count; $i++) {
            $previous = $script:Entries[$i - 1]
            $current = $script:Entries[$i]

            $ignored = @($previous.PruneProposals | Where-Object { $current.Closes -notcontains $_ })

            $message = "entry $($current.Id) neither applied nor rejected prune proposal(s) opened by $($previous.Id): $($ignored -join ', '). Apply it, or close it with a reason. Carrying it forward is the idling this gate exists to stop."
            @($ignored).Count | Should-Be 0 -Because $message
        }
    }

    It 'names a prune proposal only where a thread was opened for it' {
        # The mirror. A prune proposal has to be a real thread, so the body has
        # to describe it under the same id and a reader can find out what was
        # proposed rather than only that something was.
        foreach ($entry in $script:Entries) {
            foreach ($id in $entry.PruneProposals) {
                $id | Should-BeLikeString "$($entry.Id)-t*" -Because "entry $($entry.Id) lists prune proposal $id, which is not one of its own threads"
                $entry.Body | Should-MatchString ([regex]::Escape("[$id]")) -Because "entry $($entry.Id) names prune proposal $id in its front matter and nowhere in its body"
            }
        }
    }
}

Describe 'The ledger accounts for its own threads' -Tag 'PreTag' {

    It 'accounts for every thread that was still open, not merely for the last ones raised' {
        # THIS REPOSITORY HAD NO SUCH CHECK AT ALL, and it lost a thread.
        #
        # `0002-t4` was carried by 0003 and gone from 0004. Entry 0003's PROSE
        # says `0003-t2` is "the open half of 0002-t4"; its front matter dropped
        # the id without a word. The prose knew and the machine half did not,
        # and the machine half is the one anything reads.
        #
        # PSModuleGraph had a check and it was broken the same way in a subtler
        # place - it compared an entry against the threads the PREVIOUS ENTRY
        # ITSELF RAISED, so a thread was guarded for exactly one iteration. Both
        # repositories are now on the same rule:
        #
        #   open(N) = open(N-1) + recovers(N) - closes(N) - supersedes(N)
        #
        # and carries_forward(N) must equal it EXACTLY. A drop is judged over
        # the whole chain, because a gap a later entry owns up to is a recorded
        # gap and a gap nobody mentions is a lost thread - and that costs
        # nothing where it matters, since a drop made today has no later entry
        # to recover it.
        $open = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]@($script:Entries[0].OpenThreads), [System.StringComparer]::Ordinal)
        $lostAt = [ordered]@{}
        $recoveredBy = @{}
        $phantoms = [System.Collections.Generic.List[string]]::new()

        for ($i = 1; $i -lt $script:Entries.Count; $i++) {
            $current = $script:Entries[$i]

            foreach ($id in $current.Recovers) {
                if (-not $recoveredBy.ContainsKey($id)) { $recoveredBy[$id] = $current.Id }
                [void]$open.Add($id)
            }
            foreach ($id in @($current.Closes) + @($current.Supersedes) + @($current.Accepts)) { [void]$open.Remove($id) }

            $carried = @($current.CarriesForward)
            foreach ($id in @($open)) {
                if ($carried -notcontains $id) {
                    if (-not $lostAt.Contains($id)) { $lostAt[$id] = $current.Id }
                    [void]$open.Remove($id)
                }
            }
            foreach ($id in $carried) {
                if (-not $open.Contains($id)) { $phantoms.Add("$id (carried by $($current.Id))") }
            }
            foreach ($id in $current.OpenThreads) { [void]$open.Add($id) }
        }

        # Named, not counted. A failure that does not say which thread vanished
        # and where tells the reader nothing they can act on.
        $unrecovered = @($lostAt.Keys | Where-Object { -not $recoveredBy.ContainsKey($_) } |
                ForEach-Object { "$_ (dropped by $($lostAt[$_]))" } | Sort-Object)
        $message = "thread(s) left the ledger without being closed, superseded or recovered: $($unrecovered -join '; '). Close them, supersede them by id, or - if the record genuinely has a gap - name them in recovers_threads and say so in the body."
        @($unrecovered).Count | Should-Be 0 -Because $message

        $message = "thread(s) carried by an entry that were not open before it: $(@($phantoms) -join '; '). A thread that was dropped needs recovers_threads, which says the record has a gap in it."
        @($phantoms).Count | Should-Be 0 -Because $message
    }

    It 'references only threads that some entry actually opened' {
        # EXISTENCE, not shape. A pattern match on the id is not this:
        # `Should-BeLikeString "0009-t*"` passed on `0009-t9`, a thread that has
        # never existed, because a fake id of the right shape has the right
        # shape. That cost a break to find, in this file, two commits ago.
        $opened = @{}
        foreach ($entry in $script:Entries) {
            foreach ($id in $entry.OpenThreads) { $opened[$id] = $entry.Id }
        }
        foreach ($entry in $script:Entries) {
            foreach ($id in (@($entry.Closes) + @($entry.CarriesForward) + @($entry.Supersedes) + @($entry.Recovers) + @($entry.Accepts))) {
                $opened.ContainsKey($id) | Should-BeTrue -Because "entry $($entry.Id) references thread $id, which no entry ever opened"
            }
        }
    }

    It 'names in the body every thread it supersedes or recovers' {
        # The half that would have caught 0002-t4 from the other side. An id
        # leaving the open set has to leave a sentence behind saying what
        # replaced it, or what the gap in its record was.
        foreach ($entry in $script:Entries) {
            foreach ($id in @($entry.Supersedes) + @($entry.Recovers) + @($entry.Accepts)) {
                $entry.Body | Should-MatchString ([regex]::Escape("[$id]")) -Because "entry $($entry.Id) retires $id in its front matter and says nothing about it in its body"
            }
        }
    }
}