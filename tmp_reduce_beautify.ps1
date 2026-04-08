Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Get-Location
$outDir = Join-Path $root 'outputs'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$inputPath = Join-Path $outDir 'thermo_equilibrium_merged.tsv'
if (-not (Test-Path $inputPath)) { throw "Input file not found: $inputPath" }

$TopN = 12000
$SubsetPattern = '^K'

function Parse-Double([string]$s) {
    $v = 0.0
    if ([double]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) {
        if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { return $null }
        return $v
    }
    return $null
}

function Format-Coeff([double]$v) { [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.######}', $v) }

function Normalize-Aq([string]$s) {
    if ($null -eq $s) { return '' }
    $x = $s.Trim()
    $x = $x -replace '\s+\(aq\)$',''
    $x = $x -replace '\(aq\)$',''
    $x = $x -replace '\s+',' '
    return $x.Trim()
}

function Canonical-Species([string]$s) { (Normalize-Aq $s) -replace '\s+','' }

function Parse-Equation([string]$eq) {
    if ([string]::IsNullOrWhiteSpace($eq)) { return $null }
    $parts = $eq -split '='
    if ($parts.Count -ne 2) { return $null }
    $lhsRaw = $parts[0].Trim()
    $rhsRaw = $parts[1].Trim()
    if ([string]::IsNullOrWhiteSpace($lhsRaw) -or [string]::IsNullOrWhiteSpace($rhsRaw)) { return $null }
    $terms = @()
    foreach ($t in ($lhsRaw -split '\s+\+\s+')) {
        $tt = $t.Trim()
        if ([string]::IsNullOrWhiteSpace($tt)) { continue }
        if ($tt -match '^([+-]?\d+(?:\.\d+)?)\s+(.+)$') {
            $c = Parse-Double $matches[1]
            if ($null -eq $c) { continue }
            $terms += [PSCustomObject]@{ coeff = [double]$c; species = (Normalize-Aq $matches[2]) }
        } else {
            $terms += [PSCustomObject]@{ coeff = 1.0; species = (Normalize-Aq $tt) }
        }
    }
    if ($terms.Count -eq 0) { return $null }
    [PSCustomObject]@{ lhs = $terms; rhs = (Normalize-Aq $rhsRaw) }
}

function Make-Signature($lhsTerms) {
    $sig = @()
    foreach ($t in $lhsTerms) { $sig += ('{0}|{1}' -f (Format-Coeff ([double]$t.coeff)), (Canonical-Species $t.species)) }
    (($sig | Sort-Object) -join ';')
}

function Is-SimilarLogK([double]$a, [double]$b) {
    $scale = [Math]::Max([Math]::Abs($a), [Math]::Abs($b))
    if ($scale -lt 1.0E-6) { return ([Math]::Abs($a - $b) -le 5.0E-8) }
    ([Math]::Abs($a - $b) -le 0.05 * $scale)
}

function Pretty-SpeciesHtml([string]$s) {
    $x = Normalize-Aq $s
    $x = $x -replace '&','&amp;'
    $x = $x -replace '<','&lt;'
    $x = $x -replace '>','&gt;'
    $x = [regex]::Replace($x, '([A-Za-z\)\]])(\d+)', { param($m) $m.Groups[1].Value + '<sub>' + $m.Groups[2].Value + '</sub>' })
    if ($x -match '^(.*?)(\d+)([+-])$') { return ($matches[1] + '<sup>' + $matches[2] + $matches[3] + '</sup>') }
    if ($x -match '^(.*?)([+-])(\d+)$') { return ($matches[1] + '<sup>' + $matches[3] + $matches[2] + '</sup>') }
    if ($x -match '^(.*?)([+-]{1,3})$') {
        $signs = $matches[2]
        if ($signs.Length -eq 1) { return ($matches[1] + '<sup>' + $signs + '</sup>') }
        $sign = if ($signs[0] -eq '+') { '+' } else { '-' }
        return ($matches[1] + '<sup>' + $signs.Length + $sign + '</sup>')
    }
    $x
}

function Build-EquationPlain($lhsTerms, [string]$rhs) {
    $left = ($lhsTerms | ForEach-Object {
        $c = [double]$_.coeff
        $sp = Normalize-Aq $_.species
        if ([Math]::Abs($c - 1.0) -lt 1.0E-12) { $sp } else { ('{0} {1}' -f (Format-Coeff $c), $sp) }
    }) -join ' + '
    ('{0} = {1}' -f $left, (Normalize-Aq $rhs))
}

function Build-EquationHtml($lhsTerms, [string]$rhs) {
    $left = ($lhsTerms | ForEach-Object {
        $c = [double]$_.coeff
        $sp = Pretty-SpeciesHtml $_.species
        if ([Math]::Abs($c - 1.0) -lt 1.0E-12) { $sp } else { ('{0} {1}' -f (Format-Coeff $c), $sp) }
    }) -join ' + '
    ('{0} = {1}' -f $left, (Pretty-SpeciesHtml $rhs))
}

$allRows = Import-Csv -Path $inputPath -Delimiter "`t"
if (-not [string]::IsNullOrWhiteSpace($SubsetPattern)) {
    $rows = $allRows | Where-Object { ([string]$_.product) -match $SubsetPattern } | Select-Object -First $TopN
} else {
    $rows = $allRows | Select-Object -First $TopN
}
$prepared = New-Object System.Collections.Generic.List[object]
foreach ($r in $rows) {
    $lk = Parse-Double ([string]$r.logK_25C)
    if ($null -eq $lk) { continue }
    $parsed = Parse-Equation ([string]$r.equation_full)
    if ($null -eq $parsed) { continue }
    $prepared.Add([PSCustomObject]@{
        product_canon = (Canonical-Species $parsed.rhs)
        lhs_terms = $parsed.lhs
        rhs = $parsed.rhs
        sig = (Make-Signature $parsed.lhs)
        logK = [double]$lk
        reference_consolidated = [string]$r.reference_consolidated
        source_databases = [string]$r.source_databases
        source_files = [string]$r.source_files
    }) | Out-Null
}

$grouped = $prepared | Group-Object { '{0}|{1}' -f $_.product_canon, $_.sig }
$finalRows = New-Object System.Collections.Generic.List[object]
foreach ($g in $grouped) {
    $clusters = @()
    foreach ($e in ($g.Group | Sort-Object logK)) {
        $placed = $false
        foreach ($c in $clusters) {
            if (Is-SimilarLogK ([double]$e.logK) ([double]$c.mean)) {
                $c.items.Add($e) | Out-Null
                $c.mean = (($c.items | ForEach-Object { [double]$_.logK } | Measure-Object -Average).Average)
                $placed = $true
                break
            }
        }
        if (-not $placed) {
            $clusters += [PSCustomObject]@{ mean = [double]$e.logK; items = (New-Object System.Collections.Generic.List[object]) }
            $clusters[-1].items.Add($e) | Out-Null
        }
    }

    foreach ($c in $clusters) {
        $items = $c.items
        $rep = $items[0]
        $srcDb = New-Object System.Collections.Generic.HashSet[string]
        $srcFiles = New-Object System.Collections.Generic.HashSet[string]
        $refs = New-Object System.Collections.Generic.HashSet[string]
        $vals = @()
        foreach ($it in $items) {
            foreach ($db in ($it.source_databases -split ',\s*')) { if (-not [string]::IsNullOrWhiteSpace($db)) { [void]$srcDb.Add($db) } }
            foreach ($sf in ($it.source_files -split '\s+\|\s+')) { if (-not [string]::IsNullOrWhiteSpace($sf)) { [void]$srcFiles.Add($sf) } }
            if (-not [string]::IsNullOrWhiteSpace($it.reference_consolidated)) { [void]$refs.Add($it.reference_consolidated) }
            $vals += [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.#########} ({1})', [double]$it.logK, $it.source_databases)
        }
        $finalRows.Add([PSCustomObject]@{
            product = (Normalize-Aq $rep.rhs)
            equation_pretty = (Build-EquationPlain $rep.lhs_terms $rep.rhs)
            equation_html = (Build-EquationHtml $rep.lhs_terms $rep.rhs)
            logK_definition = 'log10(K) at 25C for equation as written'
            logK_25C = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.#########}', [double]$c.mean)
            n_merged = $items.Count
            contributing_logK = ($vals -join ' | ')
            reference_consolidated = (($refs | Sort-Object) -join ' || ')
            source_databases = (($srcDb | Sort-Object) -join ', ')
            source_files = (($srcFiles | Sort-Object) -join ' | ')
            merge_key = ('{0}|{1}' -f $rep.product_canon, $rep.sig)
        }) | Out-Null
    }
}

$final = $finalRows | Sort-Object product, {[double]$_.logK_25C}

$tsvOut = Join-Path $outDir 'thermo_equilibrium_reduced_beautified.tsv'
$final | Select-Object product,equation_pretty,logK_definition,logK_25C,n_merged,contributing_logK,reference_consolidated,source_databases,source_files,merge_key |
    Export-Csv -Path $tsvOut -Delimiter "`t" -NoTypeInformation -Encoding UTF8

$htmlOut = Join-Path $outDir 'thermo_equilibrium_reduced_beautified.html'
$json = ($final | Select-Object product,equation_pretty,equation_html,logK_definition,logK_25C,n_merged,contributing_logK,reference_consolidated,source_databases,source_files,merge_key | ConvertTo-Json -Depth 6 -Compress)
$json = $json -replace '</script>', '<\/script>'
$html = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Reduced Beautified Thermo Extraction</title>
  <style>
    :root { --bg:#f6f7fb; --fg:#1f2937; --muted:#6b7280; --line:#d1d5db; --card:#ffffff; }
    body { margin:0; font-family: "Segoe UI", Tahoma, sans-serif; background:var(--bg); color:var(--fg); }
    .wrap { max-width: 1800px; margin: 0 auto; padding: 16px; }
    h1 { margin: 0 0 10px; font-size: 22px; }
    .meta { color: var(--muted); margin-bottom: 12px; }
    .bar { display:flex; gap:10px; flex-wrap:wrap; margin-bottom:12px; }
    input { padding: 8px 10px; border:1px solid var(--line); border-radius: 8px; background:var(--card); min-width: 380px; }
    .table-wrap { border:1px solid var(--line); border-radius: 10px; background:var(--card); overflow:auto; max-height: 78vh; }
    table { border-collapse: collapse; width: 100%; min-width: 1500px; }
    th, td { border-bottom:1px solid #e5e7eb; padding: 8px 10px; text-align:left; vertical-align: top; font-size: 12px; }
    th { position: sticky; top: 0; background: #ecfeff; cursor: pointer; user-select: none; }
    tr:hover td { background:#f9fafb; }
    .mono { font-family: Consolas, "Courier New", monospace; font-size: 11.5px; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>Reduced Beautified Thermo Extraction</h1>
    <div class="meta">Rows: <span id="count">0</span> | (aq) treated as implicit for merge and product normalization.</div>
    <div class="bar"><input id="q" type="text" placeholder="Search product, equation, references, sources..." /></div>
    <div class="table-wrap">
      <table id="tbl">
        <thead>
          <tr>
            <th data-k="product">Product</th>
            <th data-k="equation_pretty">Equation (pretty)</th>
            <th data-k="logK_25C">logK_25C</th>
            <th data-k="n_merged">n_merged</th>
            <th data-k="contributing_logK">Contributing logK</th>
            <th data-k="reference_consolidated">Reference</th>
            <th data-k="source_databases">Source databases</th>
          </tr>
        </thead>
        <tbody></tbody>
      </table>
    </div>
  </div>
  <script>
    const data = __JSON_DATA__;
    const q = document.getElementById('q');
    const tbody = document.querySelector('#tbl tbody');
    const count = document.getElementById('count');
    const headers = [...document.querySelectorAll('th[data-k]')];
    let sortKey = 'product';
    let sortAsc = true;
    function toNum(v){ const n = Number(v); return Number.isFinite(n) ? n : null; }
    function cmp(a,b,key){
      if(key==='logK_25C' || key==='n_merged'){ const na=toNum(a[key]), nb=toNum(b[key]); if(na!==null && nb!==null) return na-nb; }
      return String(a[key]||'').localeCompare(String(b[key]||''), undefined, {numeric:true, sensitivity:'base'});
    }
    function render(){
      const needle = q.value.trim().toLowerCase();
      let rows = data.filter(r => {
        if (!needle) return true;
        const blob = [r.product, r.equation_pretty, r.logK_25C, r.reference_consolidated, r.source_databases, r.source_files].join(' ').toLowerCase();
        return blob.includes(needle);
      });
      rows.sort((a,b) => sortAsc ? cmp(a,b,sortKey) : -cmp(a,b,sortKey));
      count.textContent = rows.length;
      tbody.innerHTML = rows.map(r => `
        <tr>
          <td class="mono">${r.product||''}</td>
          <td class="mono">${r.equation_html||''}</td>
          <td class="mono">${r.logK_25C||''}</td>
          <td class="mono">${r.n_merged||''}</td>
          <td class="mono">${r.contributing_logK||''}</td>
          <td>${r.reference_consolidated||''}</td>
          <td>${r.source_databases||''}</td>
        </tr>`).join('');
    }
    q.addEventListener('input', render);
    headers.forEach(h => h.addEventListener('click', () => {
      const k = h.getAttribute('data-k');
      if (sortKey === k) sortAsc = !sortAsc; else { sortKey = k; sortAsc = true; }
      render();
    }));
    render();
  </script>
</body>
</html>
'@
$html = $html.Replace('__JSON_DATA__', $json)
[System.IO.File]::WriteAllText($htmlOut, $html, [System.Text.Encoding]::UTF8)

Write-Output ('Created: {0}' -f $tsvOut)
Write-Output ('Created: {0}' -f $htmlOut)
Write-Output ('Input rows (reduced): {0}; output rows: {1}' -f $rows.Count, $final.Count)
