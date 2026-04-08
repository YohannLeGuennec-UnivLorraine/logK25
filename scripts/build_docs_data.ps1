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

function Get-AtomsFromText([string]$txt) {
    if ([string]::IsNullOrWhiteSpace($txt)) { return @() }
    $periodic = @(
        'H','He','Li','Be','B','C','N','O','F','Ne','Na','Mg','Al','Si','P','S','Cl','Ar','K','Ca','Sc','Ti','V','Cr','Mn','Fe','Co','Ni','Cu','Zn',
        'Ga','Ge','As','Se','Br','Kr','Rb','Sr','Y','Zr','Nb','Mo','Tc','Ru','Rh','Pd','Ag','Cd','In','Sn','Sb','Te','I','Xe','Cs','Ba','La','Ce','Pr','Nd',
        'Pm','Sm','Eu','Gd','Tb','Dy','Ho','Er','Tm','Yb','Lu','Hf','Ta','W','Re','Os','Ir','Pt','Au','Hg','Tl','Pb','Bi','Po','At','Rn','Fr','Ra','Ac',
        'Th','Pa','U','Np','Pu','Am','Cm','Bk','Cf','Es','Fm','Md','No','Lr','Rf','Db','Sg','Bh','Hs','Mt','Ds','Rg','Cn','Nh','Fl','Mc','Lv','Ts','Og'
    )
    $set = New-Object System.Collections.Generic.HashSet[string]
    foreach ($e in $periodic) { [void]$set.Add($e) }
    # Match tokens in chemical-like context (next char is uppercase, digit, sign, bracket, delimiter, or end).
    $m = [regex]::Matches($txt, '[A-Z][a-z]?(?=[A-Z0-9\(\)\[\]\+\-\s,;:=]|$)') | ForEach-Object { $_.Value }
    return @($m | Where-Object { $set.Contains($_) } | Select-Object -Unique | Sort-Object)
}

function Get-ChunkKey([string]$product) {
    if ($null -eq $product) { $product = '' }
    $h = [Math]::Abs($product.GetHashCode())
    $bucket = $h % 128
    return ('c{0:d3}' -f $bucket)
}

$rows = Import-Csv -Delimiter "`t" -Path $inPath
$chunks = @{}
$atomToChunks = @{}
$total = 0

foreach ($r in $rows) {
    $k = if ($r.PSObject.Properties.Name -contains 'logK') { $r.logK } else { $r.logK_25C }
    $product = [string]$r.product
    $equation = [string]$r.equation_full
    $atoms = @(Get-AtomsFromText ($product + ' ' + $equation))
    $chunkKey = Get-ChunkKey $product
    if (-not $chunks.ContainsKey($chunkKey)) {
        $chunks[$chunkKey] = New-Object System.Collections.Generic.List[object]
    }

    $row = [PSCustomObject]@{
        p = $product
        e = $equation
        k = [string]$k
        c = [string]$r.contributing_logK
        x = [string]$r.experimental_conditions
        m = [string]$r.database_comments
        rf = [string]$r.reference_consolidated
        a = $atoms
    }
    $chunks[$chunkKey].Add($row) | Out-Null
    $total++

    foreach ($a in $atoms) {
        if (-not $atomToChunks.ContainsKey($a)) {
            $atomToChunks[$a] = New-Object System.Collections.Generic.HashSet[string]
        }
        [void]$atomToChunks[$a].Add($chunkKey)
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

$manifest = [PSCustomObject]@{
    generated_at = (Get-Date).ToString('s')
    total_rows = $total
    chunks = $chunkManifest
    atom_to_chunks = $atomChunksOut
}

[System.IO.File]::WriteAllText(
    (Join-Path $dataDir 'manifest.json'),
    ($manifest | ConvertTo-Json -Depth 8 -Compress),
    [System.Text.Encoding]::UTF8
)

# Ensure GitHub Pages serves static assets as-is.
[System.IO.File]::WriteAllText((Join-Path $docsDir '.nojekyll'), '', [System.Text.Encoding]::UTF8)

Write-Output ("Built docs data: {0} rows, {1} chunks" -f $total, $chunkManifest.Count)
