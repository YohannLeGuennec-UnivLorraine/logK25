Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Get-Location
$inPath = Join-Path $root 'outputs\thermo_equilibrium_merged.tsv'
$outPath = Join-Path $root 'outputs\thermo_equilibrium_merged_prettified.tsv'

if (-not (Test-Path $inPath)) {
    throw "Missing input TSV: $inPath"
}

function Normalize-Species([string]$s) {
    if ($null -eq $s) { return '' }
    $x = $s.Trim()
    $x = $x -replace '\[',''
    $x = $x -replace '\]',''
    $x = $x -replace '\s+type=.*$',''
    $x = [regex]::Replace($x, '\s*([+-])\s*(\d+)\s*$', '$1$2')
    $x = [regex]::Replace($x, '\s*(\d+)\s*([+-])\s*$', '$2$1')
    if ($x -match '^(.*?)(\+{2,})$') { $x = ($matches[1] + '+' + $matches[2].Length) }
    elseif ($x -match '^(.*?)(-{2,})$') { $x = ($matches[1] + '-' + $matches[2].Length) }
    elseif ($x -match '^(.*?)(\d+)([+-])$') { $x = ($matches[1] + $matches[3] + $matches[2]) }
    if ($x -match '^(.*?)([+-])1$') { $x = ($matches[1] + $matches[2]) }
    $x = $x -replace '\s+',' '
    return $x
}

function Format-Coefficient([double]$v) {
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $v)
}

function Normalize-ChargeNotation([string]$species) {
    if ([string]::IsNullOrWhiteSpace($species)) { return '' }
    $x = $species.Trim()
    $x = [regex]::Replace($x, '(.*?)(\d+)\/([+-])$', {
        param($m)
        if ($m.Groups[2].Value -eq '1') { return ($m.Groups[1].Value + $m.Groups[3].Value) }
        return ($m.Groups[1].Value + $m.Groups[3].Value + $m.Groups[2].Value)
    })
    $x = [regex]::Replace($x, '\s*([+-])\s*(\d+)\s*$', '$1$2')
    $x = [regex]::Replace($x, '\s*(\d+)\s*([+-])\s*$', '$2$1')
    if ($x -match '^(.*?)(\+{2,})$') { $x = ($matches[1] + '+' + $matches[2].Length) }
    elseif ($x -match '^(.*?)(-{2,})$') { $x = ($matches[1] + '-' + $matches[2].Length) }
    if ($x -match '^(.*?)([+-])1$') { $x = ($matches[1] + $matches[2]) }
    return $x
}

function Infer-SourceFamilyFromContrib([string]$contrib) {
    if ([string]::IsNullOrWhiteSpace($contrib)) { return '' }
    $m = [regex]::Match($contrib, '\(([^()]+)\)')
    if (-not $m.Success) { return '' }
    $tag = $m.Groups[1].Value
    if ($tag -like 'GWB-*') { return 'GWB' }
    if ($tag -like 'Medusa-*') { return 'MedusaText' }
    if ($tag -like 'Thermoddem-GWB-*') { return 'Thermoddem-GWB' }
    if ($tag -like 'Thermoddem-PHREEQC-*') { return 'Thermoddem-PHREEQC' }
    if ($tag -like 'Thermoddem-ToughReact-*') { return 'Thermoddem-ToughReact' }
    if ($tag -like 'Thermoddem-CHESS-*') { return 'Thermoddem-CHESS' }
    if ($tag -like 'Thermoddem-Crunch-*') { return 'Thermoddem-Crunch' }
    if ($tag -like 'PSINagra-PHREEQC-*') { return 'PSINagra-PHREEQC' }
    if ($tag -like 'JESS-PHREEQC-like-*') { return 'JESS-PHREEQC-like' }
    if ($tag -like 'NIST-SRD46-*') { return 'NIST-SRD46' }
    if ($tag -like 'IUPAC-pKa-*') { return 'IUPAC-pKa' }
    if ($tag -like 'AqSolDB-logS-*') { return 'AqSolDB-logS' }
    return ''
}

function Prettify-SpeciesBySource([string]$sourceFamily, [string]$species) {
    if ([string]::IsNullOrWhiteSpace($species)) { return '' }
    $s = Normalize-Species $species
    $s = Normalize-ChargeNotation $s
    if ($sourceFamily -eq 'NIST-SRD46') {
        $s = $s -replace '^\(([^()]+)\)$', '$1'
    }
    return $s
}

function Prettify-EquationBySource([string]$sourceFamily, [string]$eq) {
    if ([string]::IsNullOrWhiteSpace($eq)) { return '' }
    $raw = ($eq -replace '\s+', ' ').Trim()
    if ($raw -notmatch '=') { return $raw }
    $parts = $raw -split '='
    if ($parts.Count -ne 2) { return $raw }

    $prettifySide = {
        param([string]$side)
        $out = @()
        $terms = $side.Trim() -split '\s+\+\s+'
        foreach ($t in $terms) {
            $tt = $t.Trim()
            if ([string]::IsNullOrWhiteSpace($tt)) { continue }
            $coeff = 1.0
            $sp = $tt
            if ($tt -match '^([+-]?\d+(?:\.\d+)?)\s+(.+)$') {
                $coeff = [double]$matches[1]
                $sp = $matches[2].Trim()
            } elseif (
                ($sourceFamily -in @('Thermoddem-PHREEQC','PSINagra-PHREEQC','JESS-PHREEQC-like')) -and
                ($tt -match '^([+-]?\d+\.\d+)([A-Za-z\(\[].+)$')
            ) {
                $coeff = [double]$matches[1]
                $sp = $matches[2].Trim()
            }
            $sp = Prettify-SpeciesBySource $sourceFamily $sp
            if ([Math]::Abs($coeff - 1.0) -lt 1.0E-12) {
                $out += $sp
            } else {
                $out += ('{0} {1}' -f (Format-Coefficient $coeff), $sp)
            }
        }
        return ($out -join ' + ')
    }

    $lhs = & $prettifySide $parts[0]
    $rhs = & $prettifySide $parts[1]
    return ('{0} = {1}' -f $lhs, $rhs)
}

$rows = Import-Csv -Delimiter "`t" -Path $inPath
$changed = 0

foreach ($r in $rows) {
    $src = Infer-SourceFamilyFromContrib ([string]$r.contributing_logK)
    $oldEq = [string]$r.equation_full
    $newEq = Prettify-EquationBySource $src $oldEq
    if ($newEq -ne $oldEq) {
        $r.equation_full = $newEq
        $changed++
    }
}

$rows | Export-Csv -Path $outPath -Delimiter "`t" -NoTypeInformation -Encoding UTF8

Write-Output ("Created: {0}" -f $outPath)
Write-Output ("Rows processed: {0}" -f $rows.Count)
Write-Output ("Equation rows changed: {0}" -f $changed)
