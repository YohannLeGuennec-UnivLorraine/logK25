Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')
$jessDir = Join-Path $root 'External databases\JESS'
$outDir = Join-Path $root 'outputs'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$outFile = Join-Path $outDir 'jess_phreeqc_like.dat'
$tmpTxtDir = Join-Path $outDir 'jess_txt_tmp'
New-Item -ItemType Directory -Force -Path $tmpTxtDir | Out-Null

function Parse-Double([string]$s) {
    $v = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) {
        return $v
    }
    return $null
}

function Normalize-JessSpecies([string]$s) {
    $x = $s.Trim()
    $x = $x -replace '\s+', ' '
    # Convert trailing charge notation like Fe+1 -> Fe+, SO4-1 -> SO4-
    $x = [regex]::Replace($x, '(?<sp>[A-Za-z0-9\(\)]+)\+1\b', '${sp}+')
    $x = [regex]::Replace($x, '(?<sp>[A-Za-z0-9\(\)]+)-1\b', '${sp}-')
    return $x
}

function Normalize-Equation([string]$eq) {
    $x = $eq.Trim()
    $x = $x -replace '\s+', ' '
    # Convert JESS angle-bracket notation to plain PHREEQC-like species tokens.
    # Example: 21<Sn+2> -> 21 Sn+2 ; <H+1> -> H+1
    $x = [regex]::Replace($x, '([+-]?\d+(?:\.\d+)?)<\s*([^>]+?)\s*>', '$1 $2')
    $x = [regex]::Replace($x, '<\s*([^>]+?)\s*>', '$1')
    # Re-attach separated charge notation from PDF text, e.g. "Ag + 1" -> "Ag+1", "SO4 - 2" -> "SO4-2"
    $x = [regex]::Replace($x, '([A-Za-z0-9\)\]\}_])\s*([+-])\s*(\d+)\b', '$1$2$3')
    if ($x -notmatch '=') { return '' }
    $parts = $x -split '='
    if ($parts.Count -ne 2) { return $x }
    $lhs = ($parts[0] -split '\s\+\s') | ForEach-Object { Normalize-JessSpecies $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $rhs = ($parts[1] -split '\s\+\s') | ForEach-Object { Normalize-JessSpecies $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    return (('{0} = {1}' -f (($lhs -join ' + ').Trim()), (($rhs -join ' + ').Trim())).Trim())
}

function Parse-IonicStrength([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $m = [regex]::Match($s, '([+-]?\d+(?:\.\d+)?)')
    if (-not $m.Success) { return $null }
    return Parse-Double $m.Groups[1].Value
}

function Score-Entry($entry) {
    $score = 0
    # Prefer exact 25 C
    if ([Math]::Abs($entry.t - 25.0) -lt 1.0E-6) { $score += 100000 } else { $score -= [Math]::Abs($entry.t - 25.0) * 1000 }
    # Prefer I = 0 (infinite dilution-ish)
    if ($null -ne $entry.iNum) {
        $score -= [Math]::Abs($entry.iNum) * 100
        if ([Math]::Abs($entry.iNum) -lt 1.0E-9) { $score += 5000 }
    }
    # Prefer higher weight
    $score += ($entry.w * 10)
    # Mild preference when medium hints at infinite dilution
    if ($entry.medium -match '(?i)inf\.\s*dilution') { $score += 200 }
    return $score
}

if (-not (Test-Path $jessDir)) {
    throw "JESS directory not found: $jessDir"
}

$pdfs = Get-ChildItem -Path $jessDir -File | Where-Object {
    $_.Name -match '^[A-Za-z0-9]+R\.PDF$' -or $_.Name -eq 'E.PDF'
} | Sort-Object Name

if ($pdfs.Count -eq 0) {
    throw "No JESS reaction PDF files found in $jessDir"
}

$bestByEq = @{}
$allRows = 0

foreach ($pdf in $pdfs) {
    $txtPath = Join-Path $tmpTxtDir ($pdf.BaseName + '.txt')
    & pdftotext -layout $pdf.FullName $txtPath

    if (-not (Test-Path $txtPath)) { continue }
    $lines = Get-Content -Path $txtPath
    $currentRxnNo = ''
    $currentEq = ''

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match '^\s*Reaction No\.\s*(\d+)') {
            $currentRxnNo = $matches[1]
            $currentEq = ''
            # Next non-empty line with "=" is expected to be reaction equation
            for ($j = $i + 1; $j -lt [Math]::Min($i + 8, $lines.Count); $j++) {
                $cand = $lines[$j].Trim()
                if ([string]::IsNullOrWhiteSpace($cand)) { continue }
                if ($cand -match '=') {
                    $currentEq = Normalize-Equation $cand
                    break
                }
            }
            continue
        }

        if ([string]::IsNullOrWhiteSpace($currentEq)) { continue }
        # Data row pattern with lgK value
        if ($ln -match '^\s*(\d+)\s+([+-]?\d+(?:\.\d+)?)\s+([^\s]+)\s+(.+?)lgK:([+-]?\d+(?:\.\d+)?)\(([^)]*)\)\s+(\d+)\s+([A-Za-z]+)\s+(\d+)\s*$') {
            $rowNo = [int]$matches[1]
            $t = Parse-Double $matches[2]
            $iStr = $matches[3].Trim()
            $medium = $matches[4].Trim()
            $logk = Parse-Double $matches[5]
            $dev = $matches[6].Trim()
            $w = [int]$matches[7]
            $tech = $matches[8].Trim()
            $ref = $matches[9].Trim()
            if ($null -eq $t -or $null -eq $logk) { continue }
            if ([Math]::Abs($t - 25.0) -gt 1.0E-6) { continue }

            $entry = [PSCustomObject]@{
                equation = $currentEq
                logk = $logk
                t = $t
                iStr = $iStr
                iNum = Parse-IonicStrength $iStr
                medium = $medium
                dev = $dev
                w = $w
                tech = $tech
                ref = $ref
                pdf = $pdf.Name
                rxnNo = $currentRxnNo
                rowNo = $rowNo
                score = 0
            }
            $entry.score = Score-Entry $entry
            $allRows++

            if (-not $bestByEq.ContainsKey($currentEq)) {
                $bestByEq[$currentEq] = $entry
            } else {
                if ($entry.score -gt $bestByEq[$currentEq].score) {
                    $bestByEq[$currentEq] = $entry
                }
            }
        }
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('TITLE JESS thermodynamic extraction (PHREEQC-like)')
[void]$sb.AppendLine('# Source: External databases\JESS (PDF reaction sheets)')
[void]$sb.AppendLine('# Selection rule: keep 25 C entries; choose best per equation (prefer I=0, higher W, inf dilution medium).')
[void]$sb.AppendLine('SOLUTION_SPECIES')
[void]$sb.AppendLine('')

$selected = $bestByEq.Keys | Sort-Object
foreach ($eq in $selected) {
    $e = $bestByEq[$eq]
    [void]$sb.AppendLine($eq)
    [void]$sb.AppendLine(('    -log_k {0}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.########}', $e.logk))))
    [void]$sb.AppendLine(('    # JESS file={0}; reaction_no={1}; row={2}; T={3}; I={4}; medium={5}; W={6}; tech={7}; ref={8}; dev={9}' -f $e.pdf, $e.rxnNo, $e.rowNo, $e.t, $e.iStr, $e.medium, $e.w, $e.tech, $e.ref, $e.dev))
    [void]$sb.AppendLine('')
}

[System.IO.File]::WriteAllText($outFile, $sb.ToString(), [System.Text.Encoding]::UTF8)

Write-Output ("JESS PDFs scanned: {0}" -f $pdfs.Count)
Write-Output ("25C table rows parsed: {0}" -f $allRows)
Write-Output ("Unique equations exported: {0}" -f $selected.Count)
Write-Output ("Created: {0}" -f $outFile)
