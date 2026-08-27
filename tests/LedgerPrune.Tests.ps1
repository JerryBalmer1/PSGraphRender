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
            Closes         = Read-List -Source $front -Key 'closes'
            PruneProposals = Read-List -Source $front -Key 'prune_proposals'
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
