# Constraints

**Things this repository has decided to live with.** Each was a real doubt, each
was raised as a ledger thread, each was ruled on, and each is here because the
answer is *"yes, and that is the trade"* rather than *"not yet"*.

This file exists because an accepted limitation that stays in the thread list is
not accepted, it is deferred — and the ledger's own measurement is that deferral
is the state nothing in this project has ever recovered from. Twenty-one of
twenty-three closures happened in the very next entry and **none has ever
happened after four carries**. A thread that will not be worked on and will not
be struck is a line item that costs a reading every iteration and buys nothing.

**Reading this is how you find out something is deliberate before proposing to
fix it.** If you think one of these is wrong, that is a proposal — raise it,
do not quietly reverse it.

Retired at **v0.11.0** unless a later entry says otherwise. The thread id is
kept so the ledger entry that argued it is still findable.

## The drawing

**The fill channel is nearly dead on the payload that needs it most.**
`0008-t3`. 469 of SqlServerDsc's 532 nodes are one kind, so colouring by kind
paints 88% of the page one colour. **That is the module, not the renderer.**
Choosing a different channel at density would be the renderer deciding what the
data means, which is the one thing it must not do — the producer says what the
kinds are and how many there are of each.

**The heat ramp has no middle.** `0010-t5`. Colour is **rank over distinct
values**, not magnitude, so on a skewed metric the outliers separate cleanly and
the bulk does not: blast radius on SqlServerDsc runs 0 to 281 with a median of
1, 36 distinct values, and 87% of nodes in the coldest quarter of the ramp.
Measured from a screenshot rather than argued. The algorithm is right for the
question the metric answers — *which of these is worst* — and wrong for
*is this one worse than that one*, which the raw number in the panel answers
exactly. **Five colours is the right number for a person and a skewed
distribution does not fit in five bands.** What was *not* accepted is the page
implying otherwise: the legend saying colour is rank and not magnitude is open
as `0012-t1`.

**The candidate count says how many, never how many of what.** `0007-t3`. The
Details panel can say *three of these links are uncertain* and cannot say which
targets they might have meant, because the number of candidates is a producer
fact and contract 1.1.0 does not carry it. **The contract is not edited to make
a panel richer.** Adding `links[].candidates` is a proposal, and it is one.

## The seam

**`Get-HashtableValue` exists in this repository and in `PSModuleGraph`.**
`0001-t5`. Fifteen lines, duplicated. Sharing them means one repository taking a
dependency on the other, which is the coupling the extraction removed — and the
whole claim of this repository is that its producer could be written in Go.
**Duplicating a helper is cheaper than re-coupling two repositories.**

**Validation happens in one place and that cuts both ways.** `0003-t4`.
`New-RenderDocument` is the only thing that checks a payload against the
contract, so a caller reaching a backend another way is unchecked. One place is
the design: the alternative is every backend validating separately, which is how
a backend ends up with its own idea of the contract.

**`plain` is trivial enough to prove less than it looks.** `0002-t1`. It renders
a table and asks configuration for nothing structural, so "two backends work"
is weaker evidence for the seam than the count suggests. **Its triviality is
what makes it a control** — a second elaborate backend would prove the seam and
would also hide a seam defect behind its own machinery.

## What the tests can and cannot say

**Semantic equivalence checks the dimensions somebody listed.** `0003-t1`. Six
were chosen; a difference outside all six passes. Every comparison of two
documents is a chosen list, and the alternative — byte identity — was tried and
could not survive a deliberate rename.

**The payload scan reaches one level and cannot see a computed access.**
`0004-t2`. `BackendContract.Tests.ps1` follows a direct alias of `DATA` or
`META`; a backend that builds a property name at runtime is invisible to it. A
static scan of dynamic access has a ceiling and this is where it is.

**Playwright was measured and nothing else was.** `0004-t4`. One browser engine,
headless, pinned. Two engines is twice the install for a page whose only
engine-specific surface is a canvas.

## The report's own claims

**A vendored file names a resource that is not vendored.** `0005-t4`.
`cytoscape-dagre.min.js` ends with a `sourceMappingURL` pointing at a `.map`
that is not shipped. It is relative, it is fetched only with developer tools
open, and **stripping it would invalidate the SRI hash that proves the file is
what upstream published.** The page's claim to need nothing is one
developer-tools session away from being tested, and that is the trade.

## The tooling around it

**The skills are a fork and nothing watches the drift.** `0010-t1`. Five files
exist in both repositories and are deliberately different as of v0.9.0, because
four of the five were never the same document — one opened by naming another
repository's directories. A sync check over documents that describe different
repositories is a gate whose correct state is red, and those get deleted. What
holds instead is a rule: **a skill copied between these repositories is reread
against the destination before it lands.**

**Two of five CI defects were PowerShell 5.1-only, on a leg that had run four
times.** `0006-t3`. A young CI leg has found what it has found. Nothing here
fixes that except more runs.

## Closed rather than accepted

For completeness, because they read the same way in a diff and are not the same
fact. These were **struck**, not accepted — the question had already been
answered and nobody had removed the thread:

- `0003-t2` — *nothing checks a backend reads only what the contract promises.*
  `tests/BackendContract.Tests.ps1` has done exactly that since **v0.4.0**.
  Seven entries.
- `0004-t3` — *the offline measurement is Chromium's failure, not a proxy's.*
  Vendoring at v0.5.0 removed every request the page makes. A backend that
  fetches something re-raises it, and that is the right time.
- `0009-t4` — *there is no `CHANGELOG.md`.* There is, as of v0.9.0.
- `0001-t2` — *the golden has never been compared on another machine.* The
  golden is not in this repository and has not been since the extraction.
