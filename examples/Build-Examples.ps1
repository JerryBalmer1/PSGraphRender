#requires -Version 7.0
<#
.SYNOPSIS
    Regenerates the committed examples under examples/.
.DESCRIPTION
    Run from the repository root. Every example in examples/README.md names the
    exact invocation that rebuilds it, and this script is what those commands
    call.

    Settings reach PSGraphRender only through a template-set DIRECTORY - there
    is no -Setting parameter on New-RenderDocument, by design. So each variant
    here materialises a caller-owned OVERLAY of the shipped cytoscape set in a
    temporary directory, edits the one data file it needs, and hands the
    directory over with -TemplateSetPath. That is the seam the module documents
    for a backend that does not ship with it, and it means generating an
    example never edits the renderer.

    The overlay is temporary and is removed afterwards, so nothing committed
    carries a path from the machine that generated it.
    The VARIANT CATALOGUE works the same way and is driven by data rather than
    by a list here: threed/variants.psd1 holds one row per labelled look, and
    -Variant builds them, screenshots them, and regenerates threed/catalog.html
    from the same rows. The catalogue page is never hand-written, so a variant
    appears in it because it appears in that table and for no other reason.
.PARAMETER Only
    Build one example instead of all of them.
.PARAMETER Variant
    Build the labelled 3D variants instead of the examples: `all` for every row
    in threed/variants.psd1, or one label such as E1. The catalogue page is
    regenerated whenever any variant is built.
.PARAMETER SkipShots
    Build the variant documents without taking their screenshots. The pictures
    need node and a Playwright install; this is for a run that only wants the
    HTML, and it leaves whatever PNGs are already committed alone.
.PARAMETER OutputRoot
    Where the examples tree lives. Defaults to examples/ beside this script.
.EXAMPLE
    pwsh -NoProfile -File examples/Build-Examples.ps1

    Rebuilds every example.
.EXAMPLE
    pwsh -NoProfile -File examples/Build-Examples.ps1 -Only callflow

    Rebuilds examples/layouts/callflow.html and nothing else.
.EXAMPLE
    pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant all

    Rebuilds every labelled 3D variant, its screenshot, and the catalogue page.
.EXAMPLE
    pwsh -NoProfile -File examples/Build-Examples.ps1 -Variant E1

    Rebuilds one variant and the catalogue page that indexes it.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('all', 'foundation', 'testorder', 'callflow', 'default', 'contrast', 'links', 'forge', 'threed')]
    [string] $Only = 'all',

    # Not a ValidateSet, unlike -Only, and the difference is deliberate: the
    # labels live in threed/variants.psd1 and a set here would be a second place
    # they are written down. An unknown label is refused by name at the point
    # the table is read, which is a better message than a parameter error.
    [Parameter()]
    [string] $Variant,

    [Parameter()]
    [switch] $SkipShots,

    [Parameter()]
    [string] $OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$examplesRoot = if ($OutputRoot) { $OutputRoot } else { $PSScriptRoot }
$repoRoot = Split-Path -Parent $examplesRoot
$inputRoot = Join-Path $examplesRoot 'input'

# -- import the module, built output first, source second --------------------
$built = Join-Path $repoRoot 'output/PSGraphRender/PSGraphRender.psd1'
$source = Join-Path $repoRoot 'src/PSGraphRender/PSGraphRender.psd1'
$manifest = if (Test-Path -LiteralPath $built) { $built } else { $source }
if (-not (Test-Path -LiteralPath $manifest)) {
    throw "No PSGraphRender manifest found. Looked for '$built' and '$source'. Run ./build.ps1 first."
}
Import-Module -Name $manifest -Force -ErrorAction Stop
$module = Get-Module -Name PSGraphRender
Write-Host "PSGraphRender $($module.Version) from $($module.Path)"

$setsRoot = Join-Path (Split-Path -Parent $module.Path) 'TemplateSets'
function Get-ShippedSet {
    param([string] $Name)

    $path = Join-Path $setsRoot $Name
    if (-not (Test-Path -LiteralPath (Join-Path $path 'templateset.psd1'))) {
        throw "PSGraphRender $($module.Version) ships no '$Name' template set. Looked in '$path'."
    }
    $path
}

# -- overlay helpers ---------------------------------------------------------
function New-Overlay {
    <#
        A caller-owned copy of one shipped backend. Returns its path.
    #>
    param([string] $Set = 'cytoscape')

    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('psgraphrender-example-' + [guid]::NewGuid().ToString('n'))
    Copy-Item -LiteralPath (Get-ShippedSet -Name $Set) -Destination $dir -Recurse -Force
    return $dir
}

function Set-OverlayFlow {
    param([string] $OverlayPath, [string] $Flow)

    # Replace the value in place rather than writing a minimal file: a minimal
    # settings.psd1 would silently reset every other setting to its schema
    # default, which is the same thing today and would stop being the same
    # thing the moment a shipped value diverges from its default.
    $file = Join-Path $OverlayPath 'Config/settings.psd1'
    $text = [System.IO.File]::ReadAllText($file)
    $pattern = "(?m)^(\s*DefaultFlow\s*=\s*)'[^']*'"

    # Assert the LINE EXISTS rather than that the text changed. Setting
    # foundation over foundation is a legitimate no-op, and a guard that treats
    # "unchanged" as "not found" fails the one variant whose value already
    # matches - which is exactly what it did the first time this ran.
    if ($text -notmatch $pattern) {
        throw "Could not set DefaultFlow in '$file' - the settings file has no DefaultFlow line to replace."
    }
    [System.IO.File]::WriteAllText($file, ($text -replace $pattern, ('${1}''' + $Flow + '''')))
}

function Set-OverlayLinkMode {
    param([string] $OverlayPath, [string] $Mode, [string] $Template)

    # Same in-place replacement as Set-OverlayFlow, and for the same reason: a
    # minimal settings.psd1 would reset every other setting to its schema
    # default. Both keys are shipped values, so both lines exist to replace -
    # asserted rather than assumed, because a silent no-op here would render the
    # DEFAULT mode and look like the feature is missing.
    $file = Join-Path $OverlayPath 'Config/settings.psd1'
    $text = [System.IO.File]::ReadAllText($file)

    foreach ($pair in @(@{ Key = 'LinkMode'; Value = $Mode }, @{ Key = 'LinkHrefTemplate'; Value = $Template })) {
        if ($null -eq $pair.Value) { continue }
        $pattern = "(?m)^(\s*$($pair.Key)\s*=\s*)'[^']*'"
        if ($text -notmatch $pattern) {
            throw "Could not set $($pair.Key) in '$file' - the settings file has no $($pair.Key) line to replace."
        }
        $text = $text -replace $pattern, ('${1}''' + $pair.Value + '''')
    }
    [System.IO.File]::WriteAllText($file, $text)
}

function Set-OverlayTheme {
    param([string] $OverlayPath, [string] $ThemeFile)

    Copy-Item -LiteralPath $ThemeFile -Destination (Join-Path $OverlayPath 'Config/theme.psd1') -Force
}

function Invoke-Render {
    param(
        [string] $InputFile,
        [string] $OutputFile,
        [string] $Set = 'cytoscape',
        [string] $Flow,
        [string] $ThemeFile,
        [string] $LinkMode,
        [string] $LinkHrefTemplate,
        [string] $Title
    )

    $payload = Get-Content -LiteralPath $InputFile -Raw | ConvertFrom-Json
    $overlay = New-Overlay -Set $Set
    try {
        if ($Flow) { Set-OverlayFlow -OverlayPath $overlay -Flow $Flow }
        if ($ThemeFile) { Set-OverlayTheme -OverlayPath $overlay -ThemeFile $ThemeFile }
        if ($LinkMode) { Set-OverlayLinkMode -OverlayPath $overlay -Mode $LinkMode -Template $LinkHrefTemplate }

        $document = New-RenderDocument `
            -ViewModel $payload.data `
            -Meta $payload.meta `
            -Title $(if ($Title) { $Title } else { $payload.meta.title }) `
            -TemplateSetPath $overlay

        $dir = Split-Path -Parent $OutputFile
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }

        # UTF8 without BOM, LF-normalised by .gitattributes on the way in.
        [System.IO.File]::WriteAllText($OutputFile, $document, [System.Text.UTF8Encoding]::new($false))
        Write-Host ("  wrote {0} ({1:N0} bytes)" -f (Resolve-Path -Relative $OutputFile), (Get-Item $OutputFile).Length)
    }
    finally {
        Remove-Item -LiteralPath $overlay -Recurse -Force -ErrorAction SilentlyContinue
    }
}


# -- the variant catalogue ---------------------------------------------------
#
# Everything below is driven by threed/variants.psd1. Nothing here names a
# label, a colour or a caption: this code knows how to build a row and not
# which rows exist.

function Set-OverlayValue {
    <#
        Writes one variant's overlay into a caller-owned copy of the backend.

        Every key goes into the file the SCHEMA says it belongs in. A theme
        value written into settings.psd1 still applies and warns on every
        render, which is a catalogue built out of noisy runs.
    #>
    param([string] $OverlayPath, [hashtable] $Overlay)

    if (-not $Overlay.Count) { return }

    $schema = (Import-PowerShellDataFile -LiteralPath (Join-Path $OverlayPath 'Config/settings.schema.psd1')).Entries

    foreach ($key in $Overlay.Keys) {
        if (-not $schema.Contains($key)) {
            # By name, not silently. An undeclared key applies, warns on every
            # render, and puts a look in the catalogue that no caller could
            # reproduce from the shipped schema.
            throw ("Variant overlay names '$key', which is not a declared setting of this backend. " +
                'A variant may only move configuration that ships.')
        }
    }

    foreach ($group in @(
            @{ In = 'Settings'; File = 'Config/settings.psd1' }
            @{ In = 'Theme'; File = 'Config/theme.psd1' }
        )) {
        $file = Join-Path $OverlayPath $group.File
        $text = [System.IO.File]::ReadAllText($file)
        $touched = $false

        foreach ($key in ($Overlay.Keys | Sort-Object)) {
            if ($schema[$key].In -ne $group.In) { continue }
            $value = $Overlay[$key]

            if ($value -is [hashtable]) {
                # A map value - KindColor, LinkResolutionColor. Rendered as a
                # literal rather than assigned from a variable, because this
                # file is DATA and nothing in it is ever executed.
                $pairs = @($value.Keys | Sort-Object | ForEach-Object {
                        "        $_ = '$($value[$_].ToString().Replace("'", "''"))'"
                    })
                $assignment = "    $key = @{`n$($pairs -join "`n")`n    }"
            }
            elseif ($value -is [string]) { $assignment = "    $key = '$($value.Replace("'", "''"))'" }
            else { $assignment = "    $key = $value" }

            # REPLACE a shipped key, append only a new one. Appending
            # unconditionally produces a duplicate hash key, which PowerShell
            # refuses rather than resolving last-wins - and the refusal is quiet
            # in the worst way: the file then fails to load, the resolver warns
            # and falls back to schema defaults, and every variant renders the
            # DEFAULT look while the catalogue claims otherwise.
            #
            # A map spans lines, so the existing value is matched to the end of
            # its block rather than to the end of its line.
            #
            # THE TEST AND THE REPLACE MUST USE THE SAME OPTIONS, and the first
            # version of this did not: `-match` takes no RegexOptions, so the
            # guard ran without Singleline, `.` never crossed a newline, and a
            # map key failed the test and fell through to the single-line
            # branch below. That replaced only the `KindColor = @{` line and
            # left the rest of the block orphaned, so the file no longer
            # parsed - and Resolve-RenderConfiguration does the right thing
            # with a file it cannot parse, which is to warn and fall back to
            # the defaults. Five variants rendered the DEFAULT look while the
            # catalogue said otherwise. Caught because the byte counts of the
            # five were identical to each other and to nothing else.
            $mapOptions = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
                [System.Text.RegularExpressions.RegexOptions]::Multiline
            $linePattern = "^\s*$key\s*=\s*@\{.*?^\s*\}"
            if ([regex]::IsMatch($text, $linePattern, $mapOptions)) {
                $text = [regex]::Replace($text, $linePattern, $assignment.Replace('$', '$$'), $mapOptions)
            }
            elseif ($text -match "(?m)^\s*$key\s*=") {
                $text = $text -replace "(?m)^\s*$key\s*=.*$", $assignment.Replace('$', '$$')
            }
            else {
                $text = $text.Insert($text.LastIndexOf('}'), $assignment + "`n")
            }
            $touched = $true
        }
        if ($touched) { [System.IO.File]::WriteAllText($file, $text) }
    }
}

function Build-Variant {
    param([hashtable] $Row, [string] $InputFile, [string] $TitlePattern, [string] $CatalogDir)

    $out = Join-Path $CatalogDir "$($Row.Label).html"
    $payload = Get-Content -LiteralPath $InputFile -Raw | ConvertFrom-Json

    # A0 renders with NO overlay directory at all, rather than with a copy
    # carrying an empty one. It has to be the thing that actually ships, byte
    # for byte, or the catalogue's fixed origin is a near-miss of the default
    # instead of the default.
    if (-not $Row.Overlay.Count) {
        $document = New-RenderDocument -ViewModel $payload.data -Meta $payload.meta `
            -Title ($TitlePattern -replace '\{label\}', $Row.Label) -TemplateSet 'forcegraph3d'
    }
    else {
        $overlay = New-Overlay -Set 'forcegraph3d'
        try {
            Set-OverlayValue -OverlayPath $overlay -Overlay $Row.Overlay
            $document = New-RenderDocument -ViewModel $payload.data -Meta $payload.meta `
                -Title ($TitlePattern -replace '\{label\}', $Row.Label) -TemplateSetPath $overlay
        }
        finally { Remove-Item -LiteralPath $overlay -Recurse -Force -ErrorAction SilentlyContinue }
    }

    [System.IO.File]::WriteAllText($out, $document, [System.Text.UTF8Encoding]::new($false))
    Write-Host ("  {0,-3} {1,-38} {2,9:N0} bytes" -f $Row.Label, $Row.Name, $document.Length)
    $out
}

function Write-CatalogPage {
    <#
        The catalogue page, GENERATED from the same rows the documents were
        built from. Never hand-written, so a variant is in it because it is in
        the table - drift is not prevented by discipline, it is impossible.

        Static markup, escaped by hand, assembled here and nowhere else. This is
        a page ABOUT the renderer rather than a page the renderer made: no
        config, no strings, no slots, and no vendored library. If it ever grows
        a theme it has become a fourth backend and should be deleted instead.
    #>
    param([array] $Rows, [string] $Path, [string] $InputRelative)

    $esc = { param($t) [System.Net.WebUtility]::HtmlEncode([string]$t) }
    $b = [System.Text.StringBuilder]::new()

    [void]$b.AppendLine('<!DOCTYPE html>')
    [void]$b.AppendLine('<html lang="en"><head><meta charset="utf-8">')
    [void]$b.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$b.AppendLine('<title>forcegraph3d variant catalogue</title>')
    [void]$b.AppendLine('<style>')
    [void]$b.AppendLine(':root{color-scheme:dark}')
    [void]$b.AppendLine('body{font:14px/1.55 system-ui,-apple-system,Segoe UI,sans-serif;margin:0;padding:2rem;background:#080b12;color:#e6edf3}')
    [void]$b.AppendLine('h1{font-size:1.5rem;margin:0 0 .35rem}')
    [void]$b.AppendLine('h2{font-size:1rem;margin:2.5rem 0 .25rem;color:#7fd4ff;font-weight:600}')
    [void]$b.AppendLine('p.note{color:#8b949e;max-width:60rem;margin:.35rem 0}')
    [void]$b.AppendLine('.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(20rem,1fr));gap:1.1rem;margin-top:.9rem}')
    [void]$b.AppendLine('.card{border:1px solid #1f2937;border-radius:8px;overflow:hidden;background:#0e1420;display:flex;flex-direction:column}')
    [void]$b.AppendLine('.card img{display:block;width:100%;height:auto;background:#080b12}')
    [void]$b.AppendLine('.card .body{padding:.7rem .85rem .85rem}')
    [void]$b.AppendLine('.label{font-weight:700;color:#7fd4ff;font-family:ui-monospace,SFMono-Regular,Consolas,monospace}')
    [void]$b.AppendLine('.name{font-weight:600}')
    [void]$b.AppendLine('.caption{color:#8b949e;margin:.3rem 0 .5rem}')
    [void]$b.AppendLine('.keys{color:#6b7785;font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:12px;overflow-wrap:anywhere}')
    [void]$b.AppendLine('a{color:#58a6ff}')
    [void]$b.AppendLine('code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;color:#c9d1d9}')
    [void]$b.AppendLine('</style></head><body>')

    [void]$b.AppendLine('<h1>forcegraph3d variant catalogue</h1>')
    [void]$b.AppendLine(('<p class="note">{0} labelled looks for the 3D backend, in {1} families. Every one is ONE overlay of declared settings away from <span class="label">A0</span>, which is what the backend ships with no configuration at all &mdash; so any two pictures here differ by exactly the keys named under them.</p>' -f
            $Rows.Count, @($Rows.Family | Sort-Object -Unique).Count))
    [void]$b.AppendLine(('<p class="note">All of them draw the same payload, <code>{0}</code>, so the only variable is the overlay. Generated from <code>examples/threed/variants.psd1</code> by <code>examples/Build-Examples.ps1 -Variant all</code>; this page is never edited by hand.</p>' -f (& $esc $InputRelative)))
    [void]$b.AppendLine('<p class="note">A screenshot cannot show a zoom speed or a hover. The D family is here for its labels and its captions; open the page to use it.</p>')

    foreach ($family in ($Rows.Family | Sort-Object -Unique)) {
        $inFamily = @($Rows | Where-Object { $_.Family -eq $family })
        [void]$b.AppendLine(('<h2>{0} &mdash; {1}</h2>' -f (& $esc $family), (& $esc (Get-FamilyTitle -Family $family))))
        [void]$b.AppendLine('<div class="grid">')
        foreach ($row in $inFamily) {
            $keys = @($row.Overlay.Keys | Sort-Object)
            $keyText = if ($keys.Count) { $keys -join ', ' } else { 'no overlay - this is the default' }
            [void]$b.AppendLine('<div class="card">')
            [void]$b.AppendLine(('<a href="catalog/{0}.html"><img src="catalog/{0}.png" alt="{1}" loading="lazy"></a>' -f
                (& $esc $row.Label), (& $esc "$($row.Label) - $($row.Name)")))
            [void]$b.AppendLine('<div class="body">')
            [void]$b.AppendLine(('<div><span class="label">{0}</span> <span class="name">{1}</span></div>' -f
                (& $esc $row.Label), (& $esc $row.Name)))
            [void]$b.AppendLine(('<div class="caption">{0}</div>' -f (& $esc $row.Caption)))
            [void]$b.AppendLine(('<div class="keys">{0}</div>' -f (& $esc $keyText)))
            [void]$b.AppendLine(('<div style="margin-top:.5rem"><a href="catalog/{0}.html">open</a></div>' -f (& $esc $row.Label)))
            [void]$b.AppendLine('</div></div>')
        }
        [void]$b.AppendLine('</div>')
    }

    [void]$b.AppendLine('</body></html>')
    [System.IO.File]::WriteAllText($Path, $b.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host ("  wrote {0}" -f (Resolve-Path -Relative $Path))
}

function Get-FamilyTitle {
    param([string] $Family)

    # The one place a family letter means something in prose. Kept here rather
    # than in the table because it describes the SCHEME, not a variant, and a
    # per-row copy of it would be nineteen places to change one word.
    switch ($Family) {
        'A' { 'shape and size' }
        'B' { 'colour and mood' }
        'C' { 'connectors' }
        'D' { 'interaction' }
        'E' { 'composed looks' }
        default { 'other' }
    }
}

function Invoke-VariantShots {
    <#
        The pictures, through tools/shoot.cjs - the same tool every other
        screenshot in this repository was taken with, at the same viewport, with
        the network blocked.

        Reported and never silent when it cannot run. A catalogue whose pictures
        quietly did not regenerate is a catalogue that says one thing and shows
        another, which is the exact failure the generated page exists to
        prevent.
    #>
    param([array] $Rows, [string] $CatalogDir, [string] $RepoRoot)

    $shoot = Join-Path $RepoRoot 'tools/shoot.cjs'
    $playwright = Join-Path $RepoRoot 'tests/browser/node_modules/playwright'
    if (-not (Test-Path -LiteralPath $playwright)) {
        throw ('The browser harness is not installed, so no screenshot can be taken. ' +
            'Run ./build.ps1 -Task BootstrapBrowser, or pass -SkipShots to build the documents only.')
    }

    $job = @{
        outDir = $CatalogDir
        viewport = @{ width = 1280; height = 900 }
        deviceScaleFactor = 1
        shots = @(
            foreach ($row in $Rows) {
                @{
                    id = $row.Label
                    file = (Join-Path $CatalogDir "$($row.Label).html")
                    selector = '#fg'
                    # Longer than the tool's default. A force layout is still
                    # moving when the canvas first exists and the view fits
                    # itself when it stops, so a shorter wait photographs a
                    # graph on its way to where it ends up - and two variants
                    # caught mid-flight are not comparable, which is the one
                    # thing a catalogue has to be.
                    settleMs = 3600
                }
            }
        )
    }

    $jobFile = Join-Path ([System.IO.Path]::GetTempPath()) ("psgraphrender-catalog-$PID.json")
    [System.IO.File]::WriteAllText($jobFile, ($job | ConvertTo-Json -Depth 8))
    try {
        $output = & node $shoot $jobFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host ($output | Out-String)
            throw 'tools/shoot.cjs failed, so the catalogue pictures are not the catalogue documents.'
        }
        $results = ($output | Out-String) | ConvertFrom-Json
        foreach ($r in $results) {
            if ($r.errors -and @($r.errors).Count) {
                throw "Variant $($r.id) reported $(@($r.errors).Count) page error(s): $($r.errors -join ' | ')"
            }
            Write-Host ("  shot {0,-3} {1,8:N0} bytes" -f $r.id, $r.bytes)
        }
    }
    finally { Remove-Item -LiteralPath $jobFile -Force -ErrorAction SilentlyContinue }
}

if ($Variant) {
    $tablePath = Join-Path $examplesRoot 'threed/variants.psd1'
    if (-not (Test-Path -LiteralPath $tablePath)) { throw "No variant table at '$tablePath'." }
    $table = Import-PowerShellDataFile -LiteralPath $tablePath

    $all = @($table.Variants)
    if ($Variant -eq 'all') { $wanted = $all }
    else {
        $wanted = @($all | Where-Object { $_.Label -eq $Variant })
        if (-not $wanted.Count) {
            throw ("No variant labelled '$Variant' in '$tablePath'. It has: " +
                (($all.Label | Sort-Object) -join ', '))
        }
    }

    $catalogDir = Join-Path $examplesRoot 'threed/catalog'
    if (-not (Test-Path -LiteralPath $catalogDir)) { $null = New-Item -ItemType Directory -Path $catalogDir -Force }

    Write-Host "building $($wanted.Count) variant(s) of $($all.Count)"
    foreach ($row in $wanted) {
        $null = Build-Variant -Row $row -InputFile (Join-Path $examplesRoot $table.Input) `
            -TitlePattern $table.Title -CatalogDir $catalogDir
    }

    if (-not $SkipShots) { Invoke-VariantShots -Rows $wanted -CatalogDir $catalogDir -RepoRoot $repoRoot }

    # ALWAYS regenerated from the WHOLE table, even when one variant was built.
    # A page rebuilt from only what this run touched would drop every row it did
    # not, which is the drift the generation exists to prevent.
    Write-CatalogPage -Rows $all -Path (Join-Path $examplesRoot 'threed/catalog.html') `
        -InputRelative $table.Input

    Write-Host 'done.'
    return
}

# -- the matrix --------------------------------------------------------------
$ecosystem = Join-Path $inputRoot 'ecosystem-viewmodel.json'
$linksInput = Join-Path $inputRoot 'links-viewmodel.json'
$contrastTheme = Join-Path $inputRoot 'theme-contrast.psd1'

$builds = @(
    @{ Name = 'foundation'; Input = $ecosystem; Out = 'layouts/foundation.html'; Flow = 'foundation' }
    @{ Name = 'testorder'; Input = $ecosystem; Out = 'layouts/testorder.html'; Flow = 'testorder' }
    @{ Name = 'callflow'; Input = $ecosystem; Out = 'layouts/callflow.html'; Flow = 'callflow' }
    @{ Name = 'default'; Input = $ecosystem; Out = 'theme/default.html'; Flow = 'foundation' }
    @{ Name = 'contrast'; Input = $ecosystem; Out = 'theme/contrast.html'; Flow = 'foundation'; Theme = $contrastTheme }
    @{ Name = 'links'; Input = $linksInput; Out = 'links/editor-links.html'; Flow = 'callflow'
        LinkMode = 'editor'
        Title = 'Node links - editor mode, opening a node in your own editor'
    }
    # The same payload, the same layout, one setting different - and links that
    # actually go somewhere from a committed file. hrefTemplate never reads
    # meta.rootPath, so the placeholder in the input stays put and no machine
    # path is baked in: the URL is built from each node's own relative path.
    @{ Name = 'forge'; Input = $linksInput; Out = 'links/forge-links.html'; Flow = 'callflow'
        LinkMode = 'hrefTemplate'
        LinkHrefTemplate = 'https://github.com/JerryBalmer1/PSGraphRender/blob/main/{relativePath}#L{line}'
        Title = 'Node links - hrefTemplate mode, opening a node on GitHub'
    }
    # A different BACKEND, not a different setting - the first example here that
    # varies the one thing every other row holds fixed. Same payload as the
    # three layout rows, so the two drawings are of the same data and can be put
    # side by side.
    #
    # No Flow: DefaultFlow is a cytoscape setting and this backend has no view
    # to choose between. Overlaying it would write a key with no schema entry
    # and warn at every render, which is what the config split is for.
    @{ Name = 'threed'; Set = 'forcegraph3d'; Input = $ecosystem; Out = 'threed/forcegraph3d.html'
        LinkMode = 'hrefTemplate'
        LinkHrefTemplate = 'https://github.com/JerryBalmer1/PSGraphRender/blob/main/{relativePath}#L{line}'
        Title = 'Three dimensions - the same view model, a different backend'
    }
)

foreach ($b in $builds) {
    if ($Only -ne 'all' -and $Only -ne $b.Name) { continue }
    Write-Host "building $($b.Name)"
    Invoke-Render `
        -InputFile $b.Input `
        -OutputFile (Join-Path $examplesRoot $b.Out) `
        -Set $(if ($b.ContainsKey('Set')) { $b.Set } else { 'cytoscape' }) `
        -Flow $(if ($b.ContainsKey('Flow')) { $b.Flow } else { $null }) `
        -ThemeFile $(if ($b.ContainsKey('Theme')) { $b.Theme } else { $null }) `
        -LinkMode $(if ($b.ContainsKey('LinkMode')) { $b.LinkMode } else { $null }) `
        -LinkHrefTemplate $(if ($b.ContainsKey('LinkHrefTemplate')) { $b.LinkHrefTemplate } else { $null }) `
        -Title $(if ($b.ContainsKey('Title')) { $b.Title } else { $null })
}

Write-Host 'done.'
