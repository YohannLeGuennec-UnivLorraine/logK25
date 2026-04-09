Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Get-Location
$inPath = Join-Path $root 'outputs\thermo_equilibrium_merged.tsv'
if (-not (Test-Path $inPath)) {
    throw "Missing input TSV: $inPath"
}

$docsDir = Join-Path $root 'docs'
$dataDir = Join-Path $docsDir 'data'
$chunksDir = Join-Path $dataDir 'chunks'
New-Item -ItemType Directory -Force -Path $docsDir, $dataDir, $chunksDir | Out-Null
Get-ChildItem -Path $chunksDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$script:PeriodicElements = @(
    'H','He','Li','Be','B','C','N','O','F','Ne','Na','Mg','Al','Si','P','S','Cl','Ar','K','Ca','Sc','Ti','V','Cr','Mn','Fe','Co','Ni','Cu','Zn',
    'Ga','Ge','As','Se','Br','Kr','Rb','Sr','Y','Zr','Nb','Mo','Tc','Ru','Rh','Pd','Ag','Cd','In','Sn','Sb','Te','I','Xe','Cs','Ba','La','Ce','Pr','Nd',
    'Pm','Sm','Eu','Gd','Tb','Dy','Ho','Er','Tm','Yb','Lu','Hf','Ta','W','Re','Os','Ir','Pt','Au','Hg','Tl','Pb','Bi','Po','At','Rn','Fr','Ra','Ac',
    'Th','Pa','U','Np','Pu','Am','Cm','Bk','Cf','Es','Fm','Md','No','Lr','Rf','Db','Sg','Bh','Hs','Mt','Ds','Rg','Cn','Nh','Fl','Mc','Lv','Ts','Og'
)
$script:ElementSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($e in $script:PeriodicElements) { [void]$script:ElementSet.Add($e) }

function Get-AtomsFromText([string]$txt) {
    if ([string]::IsNullOrWhiteSpace($txt)) { return @() }
    # Match tokens in chemical-like context (next char is uppercase, digit, sign, bracket, delimiter, or end).
    $m = [regex]::Matches($txt, '[A-Z][a-z]?(?=[A-Z0-9\(\)\[\]\+\-\s,;:=]|$)') | ForEach-Object { $_.Value }
    return @($m | Where-Object { $script:ElementSet.Contains($_) } | Select-Object -Unique | Sort-Object)
}

function Get-ChunkKey([string]$product) {
    if ($null -eq $product) { $product = '' }
    $h = [Math]::Abs($product.GetHashCode())
    $bucket = $h % 128
    return ('c{0:d3}' -f $bucket)
}

function Get-SourcesFromContrib([string]$txt) {
    if ([string]::IsNullOrWhiteSpace($txt)) { return @() }
    $set = New-Object System.Collections.Generic.HashSet[string]
    $m = [regex]::Matches($txt, '\(([^()]+)\)') | ForEach-Object { $_.Groups[1].Value.Trim() }
    foreach ($v in $m) {
        if (-not [string]::IsNullOrWhiteSpace($v)) { [void]$set.Add($v) }
    }
    return @($set | Sort-Object)
}

function Convert-IntOrOne([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return 1 }
    $v = 0
    if ([int]::TryParse($s, [ref]$v)) { return $v }
    return 1
}

function Add-Count($map, [string]$el, [int]$n) {
    if ($n -le 0) { return }
    if ($map.ContainsKey($el)) { $map[$el] += $n } else { $map[$el] = $n }
}

function Merge-CountMap($dst, $src, [int]$mult) {
    foreach ($k in $src.Keys) {
        Add-Count $dst $k ($src[$k] * $mult)
    }
}

function Parse-FormulaPart([string]$f) {
    $i = 0
    $n = $f.Length
    $stack = New-Object System.Collections.Stack
    $stack.Push(@{})
    while ($i -lt $n) {
        $ch = $f[$i]
        if ($ch -eq '(') {
            $stack.Push(@{})
            $i++
            continue
        }
        if ($ch -eq ')') {
            if ($stack.Count -lt 2) { return $null }
            $grp = $stack.Pop()
            $i++
            $j = $i
            while ($j -lt $n -and [char]::IsDigit($f[$j])) { $j++ }
            $mult = Convert-IntOrOne ($f.Substring($i, $j - $i))
            $top = $stack.Peek()
            Merge-CountMap $top $grp $mult
            $i = $j
            continue
        }
        if ([char]::IsUpper($ch)) {
            $j = $i + 1
            while ($j -lt $n -and [char]::IsLower($f[$j])) { $j++ }
            $el = $f.Substring($i, $j - $i)
            if (-not $script:ElementSet.Contains($el)) { return $null }
            $k = $j
            while ($k -lt $n -and [char]::IsDigit($f[$k])) { $k++ }
            $cnt = Convert-IntOrOne ($f.Substring($j, $k - $j))
            $top = $stack.Peek()
            Add-Count $top $el $cnt
            $i = $k
            continue
        }
        return $null
    }
    if ($stack.Count -ne 1) { return $null }
    return $stack.Pop()
}

function Convert-ToHillFormula($countMap) {
    if ($null -eq $countMap -or $countMap.Keys.Count -eq 0) { return '' }
    $order = @()
    if ($countMap.ContainsKey('C')) {
        $order += 'C'
        if ($countMap.ContainsKey('H')) { $order += 'H' }
        $others = @($countMap.Keys | Where-Object { $_ -ne 'C' -and $_ -ne 'H' } | Sort-Object)
        $order += $others
    } else {
        $order = @($countMap.Keys | Sort-Object)
    }
    $parts = @()
    foreach ($el in $order) {
        $v = [int]$countMap[$el]
        if ($v -eq 1) { $parts += $el } else { $parts += ('{0}{1}' -f $el, $v) }
    }
    return ($parts -join '')
}

function Parse-FormulaCandidate([string]$cand) {
    if ([string]::IsNullOrWhiteSpace($cand)) { return '' }
    $x = $cand.Trim()
    $x = $x -replace '\s+', ''
    $x = $x -replace '\[',''
    $x = $x -replace '\]',''
    $x = $x -replace '(?i)\((aq|s|g|l)\)$',''
    $x = $x -replace '([A-Za-z0-9\)\]])(?:[\+\-]{1,2}|\+?\-?\d+[+\-])$','$1'
    $x = $x -replace '([A-Za-z0-9\)\]])(?:[\+\-]\d+)$','$1'
    if ($x -notmatch '^[A-Za-z0-9\(\)\.]+$') { return '' }
    if ($x -notmatch '[A-Z]') { return '' }

    $sum = @{}
    $parts = $x -split '\.'
    foreach ($p in $parts) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $q = $p
        $mult = 1
        if ($q -match '^(\d+)([A-Za-z\(].*)$') {
            $mult = Convert-IntOrOne $matches[1]
            $q = $matches[2]
        }
        $map = Parse-FormulaPart $q
        if ($null -eq $map) { return '' }
        Merge-CountMap $sum $map $mult
    }
    return Convert-ToHillFormula $sum
}

function Extract-HillFromSpecies([string]$species) {
    $out = New-Object System.Collections.Generic.HashSet[string]
    if ([string]::IsNullOrWhiteSpace($species)) { return @() }

    # Highest-priority explicit hints (common in GWB/NIST text exports).
    $hintMatches = [regex]::Matches($species, '(?i)formula\s*=\s*([^;,\|]+)')
    foreach ($m in $hintMatches) {
        $h = Parse-FormulaCandidate $m.Groups[1].Value
        if (-not [string]::IsNullOrWhiteSpace($h)) { [void]$out.Add($h) }
    }
    $parenForm = [regex]::Matches($species, '\(([^()]{1,120})\)')
    foreach ($m in $parenForm) {
        $h = Parse-FormulaCandidate $m.Groups[1].Value
        if (-not [string]::IsNullOrWhiteSpace($h)) { [void]$out.Add($h) }
    }
    if ($out.Count -gt 0) { return @($out | Sort-Object) }

    $s = $species.Trim()
    $s = $s -replace '\s*formula\s*=.*$',''
    $s = $s -replace '\s+type=.*$',''
    $s = $s -replace '(?i)\s*\((aq|s|g|l)\)\s*$',''
    $s = $s -replace '\s+', ''
    $h2 = Parse-FormulaCandidate $s
    if (-not [string]::IsNullOrWhiteSpace($h2)) { [void]$out.Add($h2) }
    return @($out | Sort-Object)
}

function Get-EquationSpecies([string]$eq) {
    if ([string]::IsNullOrWhiteSpace($eq)) { return @() }
    $raw = ($eq -replace '\s+',' ').Trim()
    if ($raw -notmatch '=') { return @() }
    $parts = $raw -split '='
    if ($parts.Count -ne 2) { return @() }
    $terms = @()
    foreach ($side in $parts) {
        foreach ($t in ($side.Trim() -split '\s+\+\s+')) {
            $x = $t.Trim()
            if ([string]::IsNullOrWhiteSpace($x)) { continue }
            if ($x -match '^[+-]?\d+(?:\.\d+)?\s+(.+)$') {
                $x = $matches[1].Trim()
            }
            $x = $x -replace '^\<\s*',''
            $x = $x -replace '\s*\>$',''
            if (-not [string]::IsNullOrWhiteSpace($x)) { $terms += $x }
        }
    }
    return $terms
}

function Build-HillForReaction([string]$product, [string]$equation) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    # Primary source: all species from the full reaction equation (both sides).
    foreach ($sp in (Get-EquationSpecies $equation)) {
        foreach ($h in (Extract-HillFromSpecies $sp)) {
            if (-not [string]::IsNullOrWhiteSpace($h)) { [void]$set.Add($h) }
        }
    }
    # Fallback when equation parsing yields nothing.
    if ($set.Count -eq 0) {
        foreach ($h in (Extract-HillFromSpecies $product)) {
            if (-not [string]::IsNullOrWhiteSpace($h)) { [void]$set.Add($h) }
        }
    }
    return (@($set | Sort-Object) -join ' | ')
}

$rows = Import-Csv -Delimiter "`t" -Path $inPath
$chunks = @{}
$atomToChunks = @{}
$sourceToChunks = @{}
$allSources = New-Object System.Collections.Generic.HashSet[string]
$total = 0

foreach ($r in $rows) {
    $k = if ($r.PSObject.Properties.Name -contains 'logK') { $r.logK } else { $r.logK_25C }
    $product = [string]$r.product
    $equation = [string]$r.equation_full
    $contrib = [string]$r.contributing_logK
    $hill = Build-HillForReaction $product $equation
    $atoms = @(Get-AtomsFromText ($product + ' ' + $equation))
    $sources = @(Get-SourcesFromContrib $contrib)
    $chunkKey = Get-ChunkKey $product
    if (-not $chunks.ContainsKey($chunkKey)) {
        $chunks[$chunkKey] = New-Object System.Collections.Generic.List[object]
    }

    $row = [PSCustomObject]@{
        p = $product
        e = $equation
        h = $hill
        k = [string]$k
        c = $contrib
        x = [string]$r.experimental_conditions
        m = [string]$r.database_comments
        rf = [string]$r.reference_consolidated
        a = $atoms
        s = $sources
    }
    $chunks[$chunkKey].Add($row) | Out-Null
    $total++

    foreach ($a in $atoms) {
        if (-not $atomToChunks.ContainsKey($a)) {
            $atomToChunks[$a] = New-Object System.Collections.Generic.HashSet[string]
        }
        [void]$atomToChunks[$a].Add($chunkKey)
    }
    foreach ($s in $sources) {
        [void]$allSources.Add($s)
        if (-not $sourceToChunks.ContainsKey($s)) {
            $sourceToChunks[$s] = New-Object System.Collections.Generic.HashSet[string]
        }
        [void]$sourceToChunks[$s].Add($chunkKey)
    }
}

$chunkManifest = @()
foreach ($key in ($chunks.Keys | Sort-Object)) {
    $file = "chunk_$key.json"
    $path = Join-Path $chunksDir $file
    $json = $chunks[$key] | ConvertTo-Json -Depth 6 -Compress
    [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
    $chunkManifest += [PSCustomObject]@{ key = $key; file = $file; n = $chunks[$key].Count }
}

$atomChunksOut = @{}
foreach ($a in ($atomToChunks.Keys | Sort-Object)) {
    $atomChunksOut[$a] = @($atomToChunks[$a] | Sort-Object)
}

$sourceChunksOut = @{}
foreach ($s in ($sourceToChunks.Keys | Sort-Object)) {
    $sourceChunksOut[$s] = @($sourceToChunks[$s] | Sort-Object)
}

$manifest = [PSCustomObject]@{
    generated_at = (Get-Date).ToString('s')
    total_rows = $total
    chunks = $chunkManifest
    atom_to_chunks = $atomChunksOut
    sources = @($allSources | Sort-Object)
    source_to_chunks = $sourceChunksOut
}

[System.IO.File]::WriteAllText(
    (Join-Path $dataDir 'manifest.json'),
    ($manifest | ConvertTo-Json -Depth 8 -Compress),
    [System.Text.Encoding]::UTF8
)

# Ensure GitHub Pages serves static assets as-is.
[System.IO.File]::WriteAllText((Join-Path $docsDir '.nojekyll'), '', [System.Text.Encoding]::UTF8)

Write-Output ("Built docs data: {0} rows, {1} chunks" -f $total, $chunkManifest.Count)
