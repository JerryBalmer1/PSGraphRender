#Requires -Version 7.0

<#
.SYNOPSIS
    Verify, or re-fetch and replace, the third-party files recorded in every
    TemplateSets/*/vendor/vendor.psd1.

.DESCRIPTION
    The manifests are the record of provenance; this is the only tool that acts
    on them, and it does exactly two things.

    -Verify re-hashes every listed file and compares it with the Integrity the
    manifest recorded. It names EVERY file that disagrees, not the first, and a
    listed file that is not on disk counts as a disagreement - "absent" and
    "matches" are different facts and a checker that conflated them would pass
    an empty directory.

    -Update fetches each entry's Url to a temporary file, hashes THAT, and only
    then replaces the vendored file and rewrites the entry's Version, Url and
    Integrity. Nothing is written before the bytes are in hand and hashed, so a
    failed download leaves the repository exactly as it was.

    Three rules this tool does not bend:

    1. It never touches a file that is not named in a manifest. The only paths
       it writes are <manifest directory>/<entry Name> and the manifest itself,
       and Name is refused if it contains a path separator.
    2. It replaces whole files. It has no notion of editing a vendored .js,
       because the hash covers the whole file and a partial edit would make the
       manifest a lie.
    3. It rewrites the manifest TEXTUALLY - three property lines inside the
       matched entry block. It never regenerates the .psd1 from the parsed
       hashtable: the long comment header is most of the value of that file and
       a round trip through Import-PowerShellDataFile would delete it.

    The integrity expression is copied verbatim from tests/Vendor.Tests.ps1 so
    that the tool and the gate cannot drift apart:

        'sha384-' + [Convert]::ToBase64String(
            [System.Security.Cryptography.SHA384]::Create().ComputeHash($bytes))

    Manifests are read with Import-PowerShellDataFile. DATA, never executed,
    never Invoke-Expression.

.PARAMETER Verify
    Re-hash every listed file and compare it with its recorded Integrity. Exits
    nonzero if any file mismatches or is missing.

.PARAMETER Update
    Re-fetch every targeted entry and replace the file and its manifest record.

.PARAMETER Name
    With -Update, restrict the work to the one entry with this manifest Name,
    for example 'cytoscape.min.js'.

.PARAMETER PinVersion
    With -Update, fetch a different version: the recorded Url has its version
    substituted, and the entry's Version, Url and Integrity are rewritten
    together. Requires -Name whenever more than one entry is in scope, because
    one version number across two different packages means nothing.

.PARAMETER Root
    The repository root to work in. Defaults to the parent of this script, so
    the tool aims at its own checkout. It exists so the tool can be aimed at a
    scratch copy and made to fail there - a checker nobody has watched go red
    is not yet a checker.

.EXAMPLE
    pwsh -NoProfile -File tools/Update-Vendor.ps1 -Verify

    Hash every vendored file and report it against the manifest. Exit 0 when
    they all match, nonzero with every offending file named when they do not.

.EXAMPLE
    ./tools/Update-Vendor.ps1 -Update -WhatIf

    Fetch what the manifests already pin and report what would change, without
    writing anything. The fetch still happens: that is what makes the report a
    prediction rather than a guess.

.EXAMPLE
    ./tools/Update-Vendor.ps1 -Update -Name cytoscape.min.js -PinVersion 3.35.0

    Move one entry to a new version, replacing the file and its Version, Url
    and Integrity in one operation.
#>

# Nothing goes between #Requires and the block above, and there is a blank line
# between them. Measured on PowerShell 7.6.5: with the help butted against
# #Requires, or with a single `#` comment line in the gap, Get-Help finds no
# comment-based help at all and reports the syntax line as the synopsis.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()] [switch] $Verify,
    [Parameter()] [switch] $Update,
    [Parameter()] [string] $Name,
    [Parameter()] [string] $PinVersion,
    [Parameter()] [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# 2 is "you asked for something that is not a request"; 1 is "the request was
# understood and the answer is no". Both are nonzero and CI needs only that,
# but a person reading a log wants to know which of the two happened.
$script:ExitUsage = 2
$script:ExitFailed = 1

function Write-Report {
    <#
    .SYNOPSIS
        One line of the human report.
    .DESCRIPTION
        Everything this tool says goes through here and onto one stream. The
        verdict is the exit code; the text is for whoever reads the log.
    #>
    param([Parameter()] [AllowEmptyString()] [string] $Message = '')
    Write-Information $Message
}

function Get-TemplateSetRoot {
    <#
    .SYNOPSIS
        Where the backends live under a checkout. Stated once.
    #>
    param([Parameter(Mandatory)] [string] $RepositoryRoot)
    Join-Path $RepositoryRoot 'src/PSGraphRender/TemplateSets'
}

function Get-VendorManifest {
    <#
    .SYNOPSIS
        Every backend that vendors something, with its manifest read as data.
    .DESCRIPTION
        Discovered by the presence of vendor/vendor.psd1 under a template set
        directory, never from a list - a list here would be a second place a
        backend's vendoring is stated. A backend with no vendor/ is not a
        failure: `plain` needs no library and that is the point of it.
    #>
    param([Parameter(Mandatory)] [string] $RepositoryRoot)

    $setsRoot = Get-TemplateSetRoot -RepositoryRoot $RepositoryRoot

    Get-ChildItem -LiteralPath $setsRoot -Directory | ForEach-Object {
        $directory = Join-Path $_.FullName 'vendor'
        $path = Join-Path $directory 'vendor.psd1'
        if (Test-Path -LiteralPath $path) {
            [pscustomobject]@{
                Backend   = $_.Name
                Directory = $directory
                Path      = $path
                Data      = Import-PowerShellDataFile -LiteralPath $path -ErrorAction Stop
            }
        }
    }
}

function Get-VendorEntry {
    <#
    .SYNOPSIS
        Flatten the discovered manifests into one record per vendored file.
    .DESCRIPTION
        Every field the rest of the tool reads is checked here, by name, so a
        malformed manifest fails with the entry named rather than with a
        strict-mode property error fifty lines later.
    #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Manifest)

    foreach ($m in $Manifest) {
        if (-not $m.Data.ContainsKey('Files')) {
            throw "$($m.Path) has no Files key."
        }
        foreach ($entry in @($m.Data.Files)) {
            foreach ($key in 'Name', 'Version', 'Url', 'Integrity') {
                if (-not $entry.ContainsKey($key)) {
                    throw "$($m.Path): an entry has no $key."
                }
            }

            # THE constraint, enforced where the path is built rather than
            # trusted where it is used. A Name with a separator in it would aim
            # this tool at a file outside vendor/, and this tool writes whole
            # files.
            if ($entry.Name -match '[\\/]' -or $entry.Name -in '.', '..') {
                throw "$($m.Path): entry name '$($entry.Name)' is not a plain file name."
            }

            [pscustomobject]@{
                Backend      = $m.Backend
                ManifestPath = $m.Path
                Label        = "$($m.Backend)/vendor/$($entry.Name)"
                Name         = $entry.Name
                Version      = $entry.Version
                Url          = $entry.Url
                Integrity    = $entry.Integrity
                FilePath     = Join-Path $m.Directory $entry.Name
            }
        }
    }
}

function Invoke-VendorWork {
    <#
    .SYNOPSIS
        Run one script block per file, concurrently, and collect the results.
    .DESCRIPTION
        Hashing 435 KB is quick; fetching it over the network is not, and the
        two modes share this so that -Verify exercises the same scheduling
        -Update depends on. ThreadJob is the mechanism and its absence is
        reported rather than hidden: a tool that quietly went sequential would
        be reporting on a machine rather than on the work.
    #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Item,
        [Parameter(Mandatory)] [scriptblock] $Work,
        [Parameter(Mandatory)] [scriptblock] $ArgumentBuilder
    )

    if (@($Item).Count -eq 0) { return @() }

    $threaded = [bool](Get-Command -Name Start-ThreadJob -ErrorAction SilentlyContinue)
    if (-not $threaded) {
        Write-Report ('  Start-ThreadJob is not available here; {0} file(s) processed one at a time.' -f @($Item).Count)
        return @(foreach ($one in $Item) {
                # SPLATTED from a variable. `& $Work @(& $ArgumentBuilder $one)`
                # looks like splatting and is array syntax: it handed the whole
                # array to the first parameter, and every result came back
                # labelled with the joined array. Found by running this branch,
                # which is why it is run.
                $arguments = @(& $ArgumentBuilder $one)
                & $Work @arguments
            })
    }

    $jobs = foreach ($one in $Item) {
        Start-ThreadJob -ScriptBlock $Work -ArgumentList (& $ArgumentBuilder $one)
    }
    $results = @(Receive-Job -Job $jobs -Wait -AutoRemoveJob)
    Write-Report ("  {0} file(s) processed concurrently on ThreadJob." -f @($Item).Count)
    $results
}

# Runs in its own runspace: no function of this script is in scope, so
# everything it needs arrives as an argument and it uses only .NET and
# built-ins.
$script:HashWork = {
    param([string] $Label, [string] $FilePath, [string] $Integrity)

    $result = [pscustomobject]@{
        Label    = $Label
        FilePath = $FilePath
        Expected = $Integrity
        Actual   = $null
        Status   = 'ok'
        Detail   = ''
    }
    try {
        if (-not [System.IO.File]::Exists($FilePath)) {
            $result.Status = 'missing'
            $result.Detail = 'the manifest lists it and it is not on disk'
            return $result
        }
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $result.Actual = 'sha384-' + [Convert]::ToBase64String(
            [System.Security.Cryptography.SHA384]::Create().ComputeHash($bytes))
        if ($result.Actual -ne $result.Expected) {
            $result.Status = 'mismatch'
            $result.Detail = 'the bytes on disk are not the bytes the manifest recorded'
        }
    } catch {
        $result.Status = 'error'
        $result.Detail = $_.Exception.Message
    }
    $result
}

# Self-contained for the same reason. It writes only to a temporary file it
# names itself and never to the repository - every decision about the working
# tree is taken in the main runspace, behind ShouldProcess.
$script:FetchWork = {
    param([string] $Label, [string] $Url, [string] $FilePath, [string] $Integrity)

    $ProgressPreference = 'SilentlyContinue'
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('psgraphrender-vendor-' + [Guid]::NewGuid().ToString('N'))

    $result = [pscustomobject]@{
        Label    = $Label
        Url      = $Url
        FilePath = $FilePath
        Recorded = $Integrity
        Fetched  = $null
        OnDisk   = $null
        TempPath = $null
        Status   = 'ok'
        Detail   = ''
    }
    try {
        Invoke-WebRequest -Uri $Url -OutFile $temp -MaximumRedirection 5 -ErrorAction Stop
        if (-not [System.IO.File]::Exists($temp)) { throw 'the download produced no file' }

        $bytes = [System.IO.File]::ReadAllBytes($temp)
        if ($bytes.Length -eq 0) { throw 'the download produced an empty file' }

        $result.TempPath = $temp
        $result.Fetched = 'sha384-' + [Convert]::ToBase64String(
            [System.Security.Cryptography.SHA384]::Create().ComputeHash($bytes))

        if ([System.IO.File]::Exists($FilePath)) {
            $onDisk = [System.IO.File]::ReadAllBytes($FilePath)
            $result.OnDisk = 'sha384-' + [Convert]::ToBase64String(
                [System.Security.Cryptography.SHA384]::Create().ComputeHash($onDisk))
        }
    } catch {
        $result.Status = 'error'
        $result.Detail = $_.Exception.Message
        # -WhatIf:$false because this file is the tool's own scratch, not
        # repository state. A dry run that left 435 KB in %TEMP% every time it
        # was asked what it would do is a dry run with a side effect.
        if ([System.IO.File]::Exists($temp)) {
            Remove-Item -LiteralPath $temp -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }
    $result
}

function Set-VendorManifestText {
    <#
    .SYNOPSIS
        The new text of a manifest with one entry's Version, Url and Integrity
        replaced, and every other byte of the file left alone.
    .DESCRIPTION
        Returns the text; it writes nothing. Composing the replacement before
        anything is copied is deliberate - if the entry cannot be rewritten,
        this throws while the working tree is still untouched.

        Only the quoted value is substituted, so the alignment of the `=` and
        any comment inside the entry survives. The entry block is bounded by
        walking back from the Name line to its `@{` and forward to its `}`, so
        a second entry's Version can never be hit.
    #>
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $EntryName,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $Integrity
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]]($Text -split "`n"))

    $pattern = "^\s*Name\s*=\s*'" + [regex]::Escape($EntryName) + "'\s*$"
    $nameIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            if ($nameIndex -ge 0) { throw "'$EntryName' is named by two entries in the manifest." }
            $nameIndex = $i
        }
    }
    if ($nameIndex -lt 0) { throw "No entry named '$EntryName' in the manifest text." }

    $start = -1
    for ($i = $nameIndex; $i -ge 0; $i--) {
        if ($lines[$i] -match '@\{\s*$') { $start = $i; break }
    }
    $end = -1
    for ($i = $nameIndex; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '}') { $end = $i; break }
    }
    if ($start -lt 0 -or $end -lt 0) { throw "Could not find the entry block for '$EntryName'." }

    $wanted = [ordered]@{ Version = $Version; Url = $Url; Integrity = $Integrity }
    foreach ($key in $wanted.Keys) {
        $hits = 0
        for ($i = $start; $i -le $end; $i++) {
            if ($lines[$i] -match ('^(\s*' + $key + "\s*=\s*')([^']*)('.*)$")) {
                $lines[$i] = $Matches[1] + $wanted[$key] + $Matches[3]
                $hits++
            }
        }
        # Not a warning. An entry with no Integrity line is one this tool must
        # not half-rewrite.
        if ($hits -ne 1) { throw "Entry '$EntryName' has $hits $key line(s); expected exactly one." }
    }

    $lines -join "`n"
}

# ---- mode selection ---------------------------------------------------------

$usage = @(
    'Usage:'
    '  Update-Vendor.ps1 -Verify [-Root <path>]'
    '  Update-Vendor.ps1 -Update [-Name <file>] [-PinVersion <version>] [-Root <path>] [-WhatIf]'
    ''
    'Exactly one of -Verify and -Update. -Verify re-hashes every file a vendor'
    'manifest lists; -Update re-fetches it and rewrites its record.'
)

if ($Verify -and $Update) {
    Write-Report '-Verify and -Update do different things to the same files. Give one.'
    foreach ($line in $usage) { Write-Report $line }
    exit $script:ExitUsage
}
if (-not $Verify -and -not $Update) {
    Write-Report 'No mode given.'
    foreach ($line in $usage) { Write-Report $line }
    exit $script:ExitUsage
}
if ($Verify -and ($Name -or $PinVersion)) {
    Write-Report '-Name and -PinVersion select what to fetch, and -Verify fetches nothing. They belong to -Update.'
    exit $script:ExitUsage
}

if (-not $Root) { $Root = Split-Path -Path $PSScriptRoot -Parent }
if (-not (Test-Path -LiteralPath $Root)) {
    Write-Report "No such directory: '$Root'."
    exit $script:ExitUsage
}
$Root = (Resolve-Path -LiteralPath $Root).Path

$setsRoot = Get-TemplateSetRoot -RepositoryRoot $Root
if (-not (Test-Path -LiteralPath $setsRoot)) {
    Write-Report "No template sets under '$setsRoot'. -Root must name a PSGraphRender checkout."
    exit $script:ExitUsage
}

# Caught so that a malformed manifest is reported as a sentence rather than as
# a stack trace. It is still a failure and still exits nonzero.
try {
    $manifests = @(Get-VendorManifest -RepositoryRoot $Root)
    $entries = @(Get-VendorEntry -Manifest $manifests)
} catch {
    Write-Report ('Cannot read the vendor manifests: {0}' -f $_.Exception.Message)
    exit $script:ExitFailed
}

# A backend with nothing vendored is normal - `plain` deliberately vendors
# nothing. A checkout where NOTHING is vendored means the discovery found
# nothing to check, and a checker that reports success over an empty collection
# is the failure mode of the whole idea. tests/Vendor.Tests.ps1 asserts the
# same thing for the same reason.
if ($entries.Count -eq 0) {
    Write-Report "No vendor manifests under '$Root'. Nothing was checked, which is not the same as everything passing."
    exit $script:ExitFailed
}

Write-Report ('{0} vendored file(s) in {1} manifest(s) under {2}' -f $entries.Count, $manifests.Count, $Root)

# ---- -Verify ----------------------------------------------------------------

if ($Verify) {
    $results = @(Invoke-VendorWork -Item $entries -Work $script:HashWork -ArgumentBuilder {
            param($e) @($e.Label, $e.FilePath, $e.Integrity)
        })

    $hashed = @{}
    foreach ($r in $results) { $hashed[$r.Label] = $r }

    $failed = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $entries) {
        if (-not $hashed.ContainsKey($entry.Label)) {
            Write-Report ('  LOST     {0} - the check produced no result' -f $entry.Label)
            $failed.Add($entry.Label)
            continue
        }
        $r = $hashed[$entry.Label]
        if ($r.Status -eq 'ok') {
            Write-Report ('  OK       {0}  {1}' -f $r.Label, $r.Expected)
            continue
        }
        Write-Report ('  {0} {1}' -f $r.Status.ToUpperInvariant().PadRight(8), $r.Label)
        Write-Report ('             {0}' -f $r.Detail)
        Write-Report ('             recorded {0}' -f $r.Expected)
        if ($r.Actual) { Write-Report ('             on disk  {0}' -f $r.Actual) }
        $failed.Add($r.Label)
    }

    Write-Report ('{0} file(s) checked, {1} failed.' -f $entries.Count, $failed.Count)
    if ($failed.Count -gt 0) {
        # Every one, by name. The first failing file is rarely the whole story,
        # and a report that stopped at it would send someone back for a second
        # run to learn the rest.
        Write-Report 'Files that do not match what the manifest recorded:'
        foreach ($label in $failed) { Write-Report ('  {0}' -f $label) }
        exit $script:ExitFailed
    }
    exit 0
}

# ---- -Update ----------------------------------------------------------------

$targets = $entries
if ($Name) {
    $targets = @($entries | Where-Object { $_.Name -eq $Name })
    if ($targets.Count -eq 0) {
        Write-Report ("No manifest entry is named '{0}'. Known: {1}" -f $Name, (($entries | ForEach-Object { $_.Name }) -join ', '))
        exit $script:ExitUsage
    }
}

if ($PinVersion -and $targets.Count -gt 1) {
    Write-Report ('-PinVersion sets one version and {0} entries are in scope. One version number across different packages means nothing; name the entry with -Name.' -f $targets.Count)
    exit $script:ExitUsage
}

$plans = foreach ($entry in $targets) {
    $url = $entry.Url
    if ($PinVersion) {
        # Substituted into the URL that is already on the record, not rebuilt
        # from a template. The recorded URL is the one known to have worked; a
        # hand-built one is a guess about a CDN's layout.
        $old = '@' + $entry.Version + '/'
        if (-not $entry.Url.Contains($old)) {
            Write-Report ("{0}: its Url does not contain '{1}', so there is no version in it to substitute." -f $entry.Label, $old)
            exit $script:ExitUsage
        }
        $url = $entry.Url.Replace($old, '@' + $PinVersion + '/')
    }
    [pscustomobject]@{
        Entry   = $entry
        Url     = $url
        Version = if ($PinVersion) { $PinVersion } else { $entry.Version }
    }
}
$plans = @($plans)

$fetched = @(Invoke-VendorWork -Item $plans -Work $script:FetchWork -ArgumentBuilder {
        param($p) @($p.Entry.Label, $p.Url, $p.Entry.FilePath, $p.Entry.Integrity)
    })

$downloads = @{}
foreach ($f in $fetched) { $downloads[$f.Label] = $f }

$problems = [System.Collections.Generic.List[string]]::new()
$temporaries = [System.Collections.Generic.List[string]]::new()
$changed = 0

try {
    foreach ($plan in $plans) {
        $entry = $plan.Entry

        if (-not $downloads.ContainsKey($entry.Label)) {
            Write-Report ('  FAILED   {0} - the fetch produced no result' -f $entry.Label)
            $problems.Add($entry.Label)
            continue
        }
        $result = $downloads[$entry.Label]
        if ($result.TempPath) { $temporaries.Add($result.TempPath) }

        if ($result.Status -ne 'ok') {
            Write-Report ('  FAILED   {0}' -f $entry.Label)
            Write-Report ('             {0}' -f $plan.Url)
            Write-Report ('             {0}' -f $result.Detail)
            $problems.Add($entry.Label)
            continue
        }

        # The pin that changed nothing. Recording a new Version beside the old
        # bytes would make the manifest state something false about the file
        # next to it, which is the one thing these manifests exist to prevent.
        if ($PinVersion -and $result.Fetched -eq $entry.Integrity) {
            Write-Report ('  REFUSED  {0}' -f $entry.Label)
            Write-Report ('             {0} serves the bytes already recorded for {1}.' -f $plan.Url, $entry.Version)
            Write-Report ('             Recording Version {0} against them would make the manifest lie.' -f $PinVersion)
            $problems.Add($entry.Label)
            continue
        }

        $fileDiffers = ($null -eq $result.OnDisk) -or ($result.OnDisk -ne $result.Fetched)
        $recordDiffers = ($plan.Version -ne $entry.Version) -or
            ($plan.Url -ne $entry.Url) -or
            ($result.Fetched -ne $entry.Integrity)

        if (-not $fileDiffers -and -not $recordDiffers) {
            Write-Report ('  CURRENT  {0}  {1}' -f $entry.Label, $result.Fetched)
            continue
        }

        # Composed before anything is written, so a manifest that cannot be
        # rewritten stops the entry with the vendored file still intact.
        $manifestText = [System.IO.File]::ReadAllText($entry.ManifestPath)
        $newManifestText = Set-VendorManifestText -Text $manifestText -EntryName $entry.Name `
            -Version $plan.Version -Url $plan.Url -Integrity $result.Fetched

        Write-Report ('  UPDATE   {0}' -f $entry.Label)
        if ($plan.Version -ne $entry.Version) { Write-Report ('             Version   {0} -> {1}' -f $entry.Version, $plan.Version) }
        if ($plan.Url -ne $entry.Url) { Write-Report ('             Url       {0}' -f $plan.Url) }
        if ($result.Fetched -ne $entry.Integrity) { Write-Report ('             Integrity {0} -> {1}' -f $entry.Integrity, $result.Fetched) }
        if ($fileDiffers) { Write-Report ('             file      restored to {0}' -f $result.Fetched) }

        # ONE ShouldProcess for both writes, deliberately. They are two files
        # and one fact: a run that replaced the bytes and was then denied the
        # manifest - or the reverse - would leave the record disagreeing with
        # what is on disk, which is precisely the state -Verify exists to
        # catch. The prompt names whatever is actually about to happen, so
        # nothing is hidden by the coupling.
        $action = switch ($true) {
            { $fileDiffers -and $recordDiffers } { "replace the file and rewrite its Version, Url and Integrity in $($entry.ManifestPath)"; break }
            { $fileDiffers } { "restore the file to the bytes $($entry.ManifestPath) records"; break }
            default { "rewrite its Version, Url and Integrity in $($entry.ManifestPath)" }
        }
        if (-not $PSCmdlet.ShouldProcess($entry.FilePath, $action)) { continue }

        # Whole file, never a patch: the recorded hash covers all of it.
        if ($fileDiffers) { Copy-Item -LiteralPath $result.TempPath -Destination $entry.FilePath -Force }

        # Read back what is actually on disk rather than trusting the copy. The
        # manifest is only allowed to claim a hash that has been observed on
        # the file it sits beside, and this is the observation.
        $written = [System.IO.File]::ReadAllBytes($entry.FilePath)
        $writtenHash = 'sha384-' + [Convert]::ToBase64String(
            [System.Security.Cryptography.SHA384]::Create().ComputeHash($written))
        if ($writtenHash -ne $result.Fetched) {
            Write-Report ('  FAILED   {0} - the file on disk hashes to {1}, not {2}. The manifest was left alone.' -f $entry.Label, $writtenHash, $result.Fetched)
            $problems.Add($entry.Label)
            continue
        }

        # Compared as text, so a run that changes nothing in the manifest does
        # not rewrite it. UTF-8 without a BOM and the file's own newlines, both
        # preserved by Set-VendorManifestText splitting and rejoining on "`n".
        if ($newManifestText -ne $manifestText) {
            [System.IO.File]::WriteAllText($entry.ManifestPath, $newManifestText, (New-Object System.Text.UTF8Encoding $false))
        }
        $changed++
    }
} finally {
    # -WhatIf:$false for the same reason as in the fetch block: the temporary
    # file is this tool's, not the repository's, and a dry run must not leave
    # one behind.
    foreach ($temp in $temporaries) {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }
}

Write-Report ('{0} entry(ies) considered, {1} updated, {2} refused or failed.' -f $plans.Count, $changed, $problems.Count)
if ($problems.Count -gt 0) {
    Write-Report 'Entries that were not updated:'
    foreach ($label in $problems) { Write-Report ('  {0}' -f $label) }
    exit $script:ExitFailed
}
exit 0
