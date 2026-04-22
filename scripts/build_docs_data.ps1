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

function Get-ChemicalGroupRules() {
    return @(
        [PSCustomObject]@{
            id = 'oxalate'; label = 'Oxalate'; canonical = 'Oxalic-2'
            detect_patterns = @('(?i)\bOxalic-2\b','(?i)\bOxalic acid\b','(?i)\bEthanedioic acid\b','(?i)\boxalate\b')
            normalize_patterns = @('(?i)\bEthanedioic acid(?:\s*\(Oxalic acid\))?(?:\s*\(C2H2O4\))?\b','(?i)\bOxalic acid(?:\s*\(C2H2O4\))?\b','(?i)\boxalate\b')
        },
        [PSCustomObject]@{
            id = 'citrate'; label = 'Citrate'; canonical = 'Citric-3'
            detect_patterns = @('(?i)\bCitric-3\b','(?i)\bCitric acid\b','(?i)\b2-Hydroxypropane-1,2,3-tricarboxylic acid\b','(?i)\bcitrate\b')
            normalize_patterns = @('(?i)\b2-Hydroxypropane-1,2,3-tricarboxylic acid(?:\s*\(Citric acid\))?(?:\s*\(C6H8O7\))?\b','(?i)\bCitric acid(?:\s*\(C6H8O7\))?\b','(?i)\bcitrate\b')
        },
        [PSCustomObject]@{
            id = 'malonate'; label = 'Malonate'; canonical = 'Malonic-2'
            detect_patterns = @('(?i)\bMalonic-2\b','(?i)\bMalonic acid\b','(?i)\bPropanedioic acid\b','(?i)\bmalonate\b')
            normalize_patterns = @('(?i)\bPropanedioic acid(?:\s*\(Malonic acid\))?(?:\s*\(C3H4O4\))?\b','(?i)\bMalonic acid(?:\s*\(C3H4O4\))?\b','(?i)\bmalonate\b')
        },
        [PSCustomObject]@{
            id = 'tartrate'; label = 'Tartrate'; canonical = 'Tartaric-2'
            detect_patterns = @('(?i)\bTartaric-2\b','(?i)\bTartaric acid\b','(?i)\btartrate\b')
            normalize_patterns = @('(?i)\bTartaric acid(?:\s*\(C4H6O6\))?\b','(?i)\btartrate\b')
        },
        [PSCustomObject]@{
            id = 'succinate'; label = 'Succinate'; canonical = 'Succinic-2'
            detect_patterns = @('(?i)\bSuccinic-2\b','(?i)\bSuccinic acid\b','(?i)\bButanedioic acid\b','(?i)\bsuccinate\b')
            normalize_patterns = @('(?i)\bButanedioic acid(?:\s*\(Succinic acid\))?(?:\s*\(C4H6O4\))?\b','(?i)\bSuccinic acid(?:\s*\(C4H6O4\))?\b','(?i)\bsuccinate\b')
        },
        [PSCustomObject]@{
            id = 'fumarate'; label = 'Fumarate'; canonical = 'Fumaric-2'
            detect_patterns = @('(?i)\bFumaric-2\b','(?i)\bFumaric acid\b','(?i)\bfumarate\b')
            normalize_patterns = @('(?i)\bFumaric acid(?:\s*\(C4H4O4\))?\b','(?i)\bfumarate\b')
        },
        [PSCustomObject]@{
            id = 'maleate'; label = 'Maleate'; canonical = 'Maleic-2'
            detect_patterns = @('(?i)\bMaleic-2\b','(?i)\bMaleic acid\b','(?i)\bmaleate\b')
            normalize_patterns = @('(?i)\bMaleic acid(?:\s*\(C4H4O4\))?\b','(?i)\bmaleate\b')
        },
        [PSCustomObject]@{
            id = 'glutarate'; label = 'Glutarate'; canonical = 'Glutaric-2'
            detect_patterns = @('(?i)\bGlutaric-2\b','(?i)\bGlutaric acid\b','(?i)\bglutarate\b')
            normalize_patterns = @('(?i)\bGlutaric acid(?:\s*\(C5H8O4\))?\b','(?i)\bglutarate\b')
        },
        [PSCustomObject]@{
            id = 'adipate'; label = 'Adipate'; canonical = 'Adipic-2'
            detect_patterns = @('(?i)\bAdipic-2\b','(?i)\bAdipic acid\b','(?i)\badipate\b')
            normalize_patterns = @('(?i)\bAdipic acid(?:\s*\(C6H10O4\))?\b','(?i)\badipate\b')
        },
        [PSCustomObject]@{
            id = 'phthalate'; label = 'Phthalate'; canonical = 'Phthalic-2'
            detect_patterns = @('(?i)\bPhthalic-2\b','(?i)\bPhthalic acid\b','(?i)\bphthalate\b')
            normalize_patterns = @('(?i)\bPhthalic acid(?:\s*\(C8H6O4\))?\b','(?i)\bphthalate\b')
        },
        [PSCustomObject]@{
            id = 'salicylate'; label = 'Salicylate'; canonical = 'Salicylic-2'
            detect_patterns = @('(?i)\bSalicylic-2\b','(?i)\bSalicylic acid\b','(?i)\bsalicylate\b')
            normalize_patterns = @('(?i)\bSalicylic acid(?:\s*\(C7H6O3\))?\b','(?i)\bsalicylate\b')
        },
        [PSCustomObject]@{
            id = 'benzoate'; label = 'Benzoate'; canonical = 'Benzoic-1'
            detect_patterns = @('(?i)\bBenzoic-1\b','(?i)\bBenzoic acid\b','(?i)\bbenzoate\b')
            normalize_patterns = @('(?i)\bBenzoic acid(?:\s*\(C7H6O2\))?\b','(?i)\bbenzoate\b')
        },
        [PSCustomObject]@{
            id = 'acetate'; label = 'Acetate'; canonical = 'Acetic-1'
            detect_patterns = @('(?i)\bAcetic-1\b','(?i)\bAcetic acid\b','(?i)\bEthanoic acid\b','(?i)\bacetate\b')
            normalize_patterns = @('(?i)\bEthanoic acid(?:\s*\(Acetic acid\))?(?:\s*\(C2H4O2\))?\b','(?i)\bAcetic acid(?:\s*\(C2H4O2\))?\b','(?i)\bacetate\b')
        },
        [PSCustomObject]@{
            id = 'formate'; label = 'Formate'; canonical = 'Formic-1'
            detect_patterns = @('(?i)\bFormic-1\b','(?i)\bFormic acid\b','(?i)\bMethanoic acid\b','(?i)\bformate\b')
            normalize_patterns = @('(?i)\bMethanoic acid(?:\s*\(Formic acid\))?(?:\s*\(CH2O2\))?\b','(?i)\bFormic acid(?:\s*\(CH2O2\))?\b','(?i)\bformate\b')
        },
        [PSCustomObject]@{
            id = 'propionate'; label = 'Propionate'; canonical = 'Propanoic-1'
            detect_patterns = @('(?i)\bPropanoic-1\b','(?i)\bPropanoic acid\b','(?i)\bpropionate\b')
            normalize_patterns = @('(?i)\bPropanoic acid(?:\s*\(C3H6O2\))?\b','(?i)\bpropionate\b')
        },
        [PSCustomObject]@{
            id = 'lactate'; label = 'Lactate'; canonical = 'Lactic-1'
            detect_patterns = @('(?i)\bLactic-1\b','(?i)\bLactic acid\b','(?i)\b2-Hydroxypropanoic acid\b','(?i)\blactate\b')
            normalize_patterns = @('(?i)\b2-Hydroxypropanoic acid(?:\s*\(Lactic acid\))?(?:\s*\(C3H6O3\))?\b','(?i)\bLactic acid(?:\s*\(C3H6O3\))?\b','(?i)\blactate\b')
        },
        [PSCustomObject]@{
            id = 'glycolate'; label = 'Glycolate'; canonical = 'Glycolic-1'
            detect_patterns = @('(?i)\bGlycolic-1\b','(?i)\bGlycolic acid\b','(?i)\bHydroxyacetic acid\b','(?i)\bglycolate\b')
            normalize_patterns = @('(?i)\bHydroxyacetic acid(?:\s*\(Glycolic acid\))?(?:\s*\(C2H4O3\))?\b','(?i)\bGlycolic acid(?:\s*\(C2H4O3\))?\b','(?i)\bglycolate\b')
        },
        [PSCustomObject]@{
            id = 'pyruvate'; label = 'Pyruvate'; canonical = 'Pyruvic-1'
            detect_patterns = @('(?i)\bPyruvic-1\b','(?i)\bPyruvic acid\b','(?i)\b2-Oxopropanoic acid\b','(?i)\bpyruvate\b')
            normalize_patterns = @('(?i)\b2-Oxopropanoic acid(?:\s*\(Pyruvic acid\))?(?:\s*\(C3H4O3\))?\b','(?i)\bPyruvic acid(?:\s*\(C3H4O3\))?\b','(?i)\bpyruvate\b')
        },
        [PSCustomObject]@{
            id = 'gluconate'; label = 'Gluconate'; canonical = 'Gluconic-1'
            detect_patterns = @('(?i)\bGluconic-1\b','(?i)\bGluconic acid\b','(?i)\bgluconate\b')
            normalize_patterns = @('(?i)\bGluconic acid(?:\s*\(C6H12O7\))?\b','(?i)\bgluconate\b')
        },
        [PSCustomObject]@{
            id = 'diglycolate'; label = 'Diglycolate'; canonical = 'Diglycol-2'
            detect_patterns = @('(?i)\bDiglycol-2\b','(?i)\bDiglycolic acid\b','(?i)\bOxydiacetic acid\b','(?i)\bdiglycolate\b')
            normalize_patterns = @('(?i)\bOxydiacetic acid(?:\s*\(Diglycolic acid\))?(?:\s*\(C4H6O5\))?\b','(?i)\bDiglycolic acid(?:\s*\(C4H6O5\))?\b','(?i)\bdiglycolate\b')
        },
        [PSCustomObject]@{
            id = 'thiodiacetate'; label = 'Thiodiacetate'; canonical = 'Thiodiacetate'
            detect_patterns = @('(?i)\bThiodiacetic acid\b','(?i)\bDithiodiacetic acid\b','(?i)\bDiethylenetrithiodiacetic acid\b','(?i)\bThioDiAcet(?:-[0-9]+)?\b','(?i)\bthiodiacetate\b')
            normalize_patterns = @('(?i)\bThiodiacetic acid(?:\s*\(C4H6O4S1\))?\b','(?i)\bDithiodiacetic acid(?:\s*\(C4H6O4S2\))?\b','(?i)\bDiethylenetrithiodiacetic acid(?:\s*\(C8H14O4S3\))?\b','(?i)\bThioDiAcet(?:-[0-9]+)?\b','(?i)\bthiodiacetate\b')
        },
        [PSCustomObject]@{
            id = 'malate'; label = 'Malate'; canonical = 'Malic-2'
            detect_patterns = @('(?i)\bMalic-2\b','(?i)\bMalic acid\b','(?i)\bHydroxysuccinic acid\b','(?i)\bL-Hydroxybutanedioic acid\b','(?i)\bmalate\b')
            normalize_patterns = @('(?i)\bL-Hydroxybutanedioic acid(?:\s*\(Hydroxysuccinic acid\))?(?:\s*\(Malic acid\))?(?:\s*\(C4H6O5\))?\b','(?i)\bHydroxysuccinic acid\b','(?i)\bMalic acid(?:\s*\(C4H6O5\))?\b','(?i)\bmalate\b')
        },
        [PSCustomObject]@{
            id = 'aspartate'; label = 'Aspartate'; canonical = 'Asp-2'
            detect_patterns = @('(?i)\bAsp-2\b','(?i)\bAspartic acid\b','(?i)\baspartate\b')
            normalize_patterns = @('(?i)\bAspartic acid\b','(?i)\baspartate\b')
        },
        [PSCustomObject]@{
            id = 'glutamate'; label = 'Glutamate'; canonical = 'Glu-2'
            detect_patterns = @('(?i)\bGlu-2\b','(?i)\bGlutamic acid\b','(?i)\bglutamate\b')
            normalize_patterns = @('(?i)\bGlutamic acid\b','(?i)\bglutamate\b')
        },
        [PSCustomObject]@{
            id = 'glycine'; label = 'Glycine'; canonical = 'Gly-1'
            detect_patterns = @('(?i)\bGly-1\b','(?i)\bGly-2\b','(?i)\bGlycine\b')
            normalize_patterns = @('(?i)\bGlycine\b')
        },
        [PSCustomObject]@{
            id = 'histidine'; label = 'Histidine'; canonical = 'His-1'
            detect_patterns = @('(?i)\bHis-1\b','(?i)\bHistidine\b')
            normalize_patterns = @('(?i)\bHistidine\b')
        },
        [PSCustomObject]@{
            id = 'cysteine'; label = 'Cysteine'; canonical = 'Cys-2'
            detect_patterns = @('(?i)\bCys-2\b','(?i)\bCysteine\b')
            normalize_patterns = @('(?i)\bCysteine\b')
        },
        [PSCustomObject]@{
            id = 'tyrosine'; label = 'Tyrosine'; canonical = 'Tyr-2'
            detect_patterns = @('(?i)\bTyr-2\b','(?i)\bTyrosine\b')
            normalize_patterns = @('(?i)\bTyrosine\b')
        },
        [PSCustomObject]@{
            id = 'edta'; label = 'EDTA'; canonical = 'EDTA-4'
            detect_patterns = @('(?i)\bEDTA-4\b','(?i)\bEdta-4\b','(?i)\bEDTA\b','(?i)\bethylenediaminetetraacetic\b','(?i)\bEthylenedinitrilotetraacetic acid\b')
            normalize_patterns = @('(?i)\bethylenediaminetetraacetic acid(?:\s*\(EDTA\))?(?:\s*\(C10H16N2O8\))?\b','(?i)\bEthylenedinitrilotetraacetic acid(?:\s*\(EDTA\))?(?:\s*\(C10H16N2O8\))?\b','(?i)\bEdta-4\b','(?i)\bEDTA\b')
        },
        [PSCustomObject]@{
            id = 'hedta'; label = 'HEDTA'; canonical = 'HEDTA'
            detect_patterns = @('(?i)\bHEDTA\b','(?i)\bHedta\b','(?i)\bN-\(2-Hydroxyethyl\)ethylenedinitrilotriacetic acid\b')
            normalize_patterns = @('(?i)\bN-\(2-Hydroxyethyl\)ethylenedinitrilotriacetic acid(?:\s*\(HEDTA\))?\b','(?i)\bHedta\b')
        },
        [PSCustomObject]@{
            id = 'dtpa'; label = 'DTPA'; canonical = 'DTPA-5'
            detect_patterns = @('(?i)\bDTPA-5\b','(?i)\bDtpa-5\b','(?i)\bDTPA\b','(?i)\bdiethylenetriaminepentaacetic\b','(?i)\bDiethylenetrinitrilopentaacetic acid\b')
            normalize_patterns = @('(?i)\bdiethylenetriaminepentaacetic acid(?:\s*\(DTPA\))?(?:\s*\(C14H23N3O10\))?\b','(?i)\bDiethylenetrinitrilopentaacetic acid(?:\s*\(DTPA\))?(?:\s*\(C14H23N3O10\))?\b','(?i)\bDtpa-5\b','(?i)\bDTPA\b')
        },
        [PSCustomObject]@{
            id = 'nta'; label = 'NTA'; canonical = 'NTA-3'
            detect_patterns = @('(?i)\bNTA-3\b','(?i)\bNTA\b','(?i)\bNitrilotriacetic acid\b')
            normalize_patterns = @('(?i)\bNitrilotriacetic acid(?:\s*\(NTA\))?(?:\s*\(C6H9N1O6\))?\b','(?i)\bNTA\b')
        },
        [PSCustomObject]@{
            id = 'ida'; label = 'IDA'; canonical = 'IDA-2'
            detect_patterns = @('(?i)\bIDA-2\b','(?i)\bIDA\b','(?i)\bIminodiacetic acid\b')
            normalize_patterns = @('(?i)\bIminodiacetic acid(?:\s*\(IDA\))?(?:\s*\(C4H7N1O4\))?\b','(?i)\bIDA\b')
        },
        [PSCustomObject]@{
            id = 'egta'; label = 'EGTA'; canonical = 'EGTA-4'
            detect_patterns = @('(?i)\bEGTA-4\b','(?i)\bEGTA\b','(?i)\bethylene glycol-bis\(2-aminoethyl ether\)-N,N,N'',N''-tetraacetic\b','(?i)\bEthylenebis\(oxyethylenenitrilo\)tetraacetic acid\b')
            normalize_patterns = @('(?i)\bethylene glycol-bis\(2-aminoethyl ether\)-N,N,N'',N''-tetraacetic acid(?:\s*\(EGTA\))?\b','(?i)\bEthylenebis\(oxyethylenenitrilo\)tetraacetic acid(?:\s*\(EGTA\))?(?:\s*\(C14H24N2O10\))?\b','(?i)\bEGTA\b')
        },
        [PSCustomObject]@{
            id = 'cdta'; label = 'CDTA'; canonical = 'CDTA-4'
            detect_patterns = @('(?i)\bCDTA-4\b','(?i)\bCDTA\b','(?i)\btrans-1,2-Cyclohexylenedinitrilotetraacetic acid\b')
            normalize_patterns = @('(?i)\btrans-1,2-Cyclohexylenedinitrilotetraacetic acid(?:\s*\(CDTA\))?(?:\s*\(C14H22N2O8\))?\b','(?i)\bCDTA\b')
        },
        [PSCustomObject]@{
            id = 'picolinate'; label = 'Picolinate'; canonical = 'Picolinate'
            detect_patterns = @('(?i)\bPicolinic acid\b','(?i)\bPyridine-2-carboxylic acid\b','(?i)\bpicolinate\b')
            normalize_patterns = @('(?i)\bPyridine-2-carboxylic acid(?:\s*\(Picolinic acid\))?(?:\s*\(C6H5N1O2\))?\b','(?i)\bPicolinic acid(?:\s*\(C6H5N1O2\))?\b','(?i)\bpicolinate\b')
        },
        [PSCustomObject]@{
            id = 'dipicolinate'; label = 'Dipicolinate'; canonical = 'Dipicolinic-2'
            detect_patterns = @('(?i)\bDipicolinic acid\b','(?i)\bPyridine-2,6-dicarboxylic acid\b','(?i)\bdipicolinate\b')
            normalize_patterns = @('(?i)\bPyridine-2,6-dicarboxylic acid(?:\s*\(Dipicolinic acid\))?(?:\s*\(C7H5N1O4\))?\b','(?i)\bDipicolinic acid(?:\s*\(C7H5N1O4\))?\b','(?i)\bdipicolinate\b')
        },
        [PSCustomObject]@{
            id = 'bispycolylamine'; label = 'Bispycolylamine (DPA)'; canonical = 'Di-2-picolylamine'
            detect_patterns = @('(?i)\bDi-2-picolylamine\b','(?i)\bDi-\(2-picolyl\)amine\b','(?i)\bDipicolylamine\b','(?i)\bIminobis\(methylene-2-pyridine\)\b','(?i)\bbis\(2-pyridylmethyl\)amine\b','(?i)\bbis\(pyridin-2-ylmethyl\)amine\b','(?i)\bbis\[\(pyridin-2-yl\)methyl\]amine\b','(?i)\bDPA\b','(?i)\bbispycolylamine\b','(?i)\bbispicolylamine\b')
            normalize_patterns = @('(?i)\bDi-\(2-picolyl\)amine\b','(?i)\bDipicolylamine\b','(?i)\bIminobis\(methylene-2-pyridine\)\b','(?i)\bbis\(2-pyridylmethyl\)amine\b','(?i)\bbis\(pyridin-2-ylmethyl\)amine\b','(?i)\bbis\[\(pyridin-2-yl\)methyl\]amine\b','(?i)\bbispycolylamine\b','(?i)\bbispicolylamine\b','(?i)\(DPA\)','(?i)\bDPA\b')
        },
        [PSCustomObject]@{
            id = 'aminomethylphosphonic'; label = 'Aminomethylphosphonic acid (AMPA)'; canonical = 'Aminomethylphosphonic acid'
            detect_patterns = @('(?i)\bAminomethylphosphonic acid\b','(?i)\bAminomethyl phosphonic acid\b','(?i)\bAminomethanephosphonic acid\b','(?i)\bAcide \(aminom[ée]thyl\)phosphonique\b','(?i)\b\(Aminomethyl\)phosphonic acid\b','(?i)\b\(Aminomethyl\)phosphonate\b','(?i)\bPhosphonic acid, \(aminomethyl\)-\b','(?i)\bAMPA\b','(?i)\bGly-P\b','(?i)\baminomethylphosphonate\b')
            normalize_patterns = @('(?i)\bAminomethyl phosphonic acid \(AMPA\)\b','(?i)\bAminomethanephosphonic acid\b','(?i)\bAcide \(aminom[ée]thyl\)phosphonique\b','(?i)\b\(Aminomethyl\)phosphonic acid\b','(?i)\b\(Aminomethyl\)phosphonate\b','(?i)\bPhosphonic acid, \(aminomethyl\)-\b','(?i)\baminomethylphosphonate\b','(?i)\bAMPA\b','(?i)\bGly-P\b')
        },
        [PSCustomObject]@{
            id = 'clodronate'; label = 'Clodronate'; canonical = 'Clodronic-4'
            detect_patterns = @('(?i)\bClodronic-4\b','(?i)\bClodronic acid\b','(?i)\bclodronate\b')
            normalize_patterns = @('(?i)\bClodronic acid\b','(?i)\bclodronate\b')
        },
        [PSCustomObject]@{
            id = 'mandelate'; label = 'Mandelate'; canonical = 'Mandelic-1'
            detect_patterns = @('(?i)\bMandelic(?:-1|-)?\b','(?i)\bMandelic acid\b','(?i)\bL-Phenyl\(hydroxy\)acetic acid\b','(?i)\bmandelate\b')
            normalize_patterns = @('(?i)\bL-Phenyl\(hydroxy\)acetic acid(?:\s*\(Mandelic acid\))?(?:\s*\(C8H8O3\))?\b','(?i)\bMandelic acid(?:\s*\(C8H8O3\))?\b','(?i)\bmandelate\b')
        },
        [PSCustomObject]@{
            id = 'ascorbate'; label = 'Ascorbate'; canonical = 'Ascorbic-1'
            detect_patterns = @('(?i)\bAscorbic(?:-1|-)?\b','(?i)\bL-Ascorbic acid\b','(?i)\bascorbate\b')
            normalize_patterns = @('(?i)\bL-Ascorbic acid\b','(?i)\bAscorbic acid\b','(?i)\bascorbate\b')
        },
        [PSCustomObject]@{
            id = 'itaconate'; label = 'Itaconate'; canonical = 'Itaconic-2'
            detect_patterns = @('(?i)\bItaconic(?:-2|-)?\b','(?i)\bItaconic acid\b','(?i)\bPropene-2,3-dicarboxylic acid\b','(?i)\bitaconate\b')
            normalize_patterns = @('(?i)\bPropene-2,3-dicarboxylic acid(?:\s*\(Itaconic acid\))?(?:\s*\(C5H6O4\))?\b','(?i)\bItaconic acid(?:\s*\(C5H6O4\))?\b','(?i)\bitaconate\b')
        },
        [PSCustomObject]@{
            id = 'tricarballylate'; label = 'Tricarballylate'; canonical = 'Tricarballylic-3'
            detect_patterns = @('(?i)\bTricarballylic(?:-3|-)?\b','(?i)\bTricarballylic acid\b','(?i)\bPropane-1,2,3-tricarboxylic acid\b','(?i)\btricarballylate\b')
            normalize_patterns = @('(?i)\bPropane-1,2,3-tricarboxylic acid(?:\s*\(Tricarballylic acid\))?(?:\s*\(C6H8O6\))?\b','(?i)\bTricarballylic acid(?:\s*\(C6H8O6\))?\b','(?i)\btricarballylate\b')
        },
        [PSCustomObject]@{
            id = 'sulfosalicylate'; label = 'Sulfosalicylate'; canonical = 'SulfSal-3'
            detect_patterns = @('(?i)\bSulfSal(?:-[0-9]+)?\b','(?i)\b3Br5SulfSal(?:-[0-9]+)?\b','(?i)\b35DiSulfSal(?:-[0-9]+)?\b','(?i)\b5-Sulfosalicylic acid\b','(?i)\b3,5-Disulfosalicylic acid\b')
            normalize_patterns = @('(?i)\b3Br5SulfSal(?:-[0-9]+)?\b','(?i)\b35DiSulfSal(?:-[0-9]+)?\b','(?i)\b5-Sulfosalicylic acid\b','(?i)\b3,5-Disulfosalicylic acid\b')
        },
        [PSCustomObject]@{
            id = 'edtmp'; label = 'EDTMP'; canonical = 'EDTMP-8'
            detect_patterns = @('(?i)\bEDTMP(?:-8|-)?\b','(?i)\bethylenediaminetetramethylenephosphonic acid\b')
            normalize_patterns = @('(?i)\bethylenediaminetetramethylenephosphonic acid\b','(?i)\bEDTMP(?:-8|-)?\b')
        },
        [PSCustomObject]@{
            id = 'dtpmp'; label = 'DTPMP'; canonical = 'DTPMP-9'
            detect_patterns = @('(?i)\bDTPMP(?:-9|-)?\b','(?i)\bdiethylenetriaminepentamethylenephosphonic acid\b')
            normalize_patterns = @('(?i)\bdiethylenetriaminepentamethylenephosphonic acid\b','(?i)\bDTPMP(?:-9|-)?\b')
        },
        [PSCustomObject]@{
            id = 'pyrophosphate'; label = 'Pyrophosphate'; canonical = 'P2O7-4'
            detect_patterns = @('(?i)\bP2O7(?:-4|-)?\b','(?i)\bpyrophosphate\b')
            normalize_patterns = @('(?i)\bpyrophosphate\b')
        },
        [PSCustomObject]@{
            id = 'tripolyphosphate'; label = 'Tripolyphosphate'; canonical = 'P3O10-5'
            detect_patterns = @('(?i)\bP3O10(?:-5|-)?\b','(?i)\btripolyphosphate\b')
            normalize_patterns = @('(?i)\btripolyphosphate\b')
        },
        [PSCustomObject]@{
            id = 'thiocyanate'; label = 'Thiocyanate'; canonical = 'SCN-1'
            detect_patterns = @('(?i)\bSCN(?:-1|-)?\b','(?i)\bthiocyanate\b')
            normalize_patterns = @('(?i)\bthiocyanate\b','(?i)\bSCN-\b')
        },
        [PSCustomObject]@{
            id = 'thiosulfate'; label = 'Thiosulfate'; canonical = 'S2O3-2'
            detect_patterns = @('(?i)\bS2O3(?:-2|-)?\b','(?i)\bthiosulfate\b')
            normalize_patterns = @('(?i)\bthiosulfate\b')
        },
        [PSCustomObject]@{
            id = 'molybdate'; label = 'Molybdate'; canonical = 'MoO4-2'
            detect_patterns = @('(?i)\bMoO4(?:-2|-)?\b','(?i)\bmolybdate\b')
            normalize_patterns = @('(?i)\bmolybdate\b')
        },
        [PSCustomObject]@{
            id = 'chromate'; label = 'Chromate'; canonical = 'CrO4-2'
            detect_patterns = @('(?i)\bCrO4(?:-2|-)?\b','(?i)\bchromate\b')
            normalize_patterns = @('(?i)\bchromate\b')
        },
        [PSCustomObject]@{
            id = 'arsenate'; label = 'Arsenate'; canonical = 'AsO4-3'
            detect_patterns = @('(?i)\bAsO4(?:-3|-)?\b','(?i)\barsenate\b')
            normalize_patterns = @('(?i)\barsenate\b')
        },
        [PSCustomObject]@{
            id = 'selenite'; label = 'Selenite'; canonical = 'SeO3-2'
            detect_patterns = @('(?i)\bSeO3(?:-2|-)?\b','(?i)\bselenite\b')
            normalize_patterns = @('(?i)\bselenite\b')
        },
        [PSCustomObject]@{
            id = 'silicate'; label = 'Silicate'; canonical = 'SiH2O4-2'
            detect_patterns = @('(?i)\bSiH2O4(?:-2|-)?\b','(?i)\bsilicate\b')
            normalize_patterns = @('(?i)\bsilicate\b')
        }
    )
}

function Get-GroupCanonicalRoot([string]$canonical) {
    if ([string]::IsNullOrWhiteSpace($canonical)) { return '' }
    $root = [string]$canonical
    $root = $root -replace '(?i)[\+\-]\d+$', ''
    $root = $root.TrimEnd('-', '+')
    return $root
}

function Get-GroupCanonicalAliasPattern([string]$canonical) {
    $root = Get-GroupCanonicalRoot $canonical
    if ([string]::IsNullOrWhiteSpace($root)) { return $null }
    if ($root -eq $canonical) { return $null }
    return ("(?i)\b{0}(?:[\+\-]\d+|-)?\b" -f [regex]::Escape($root))
}

function Expand-ChemicalGroupRules($rules) {
    $expanded = New-Object System.Collections.Generic.List[object]
    foreach ($rule in $rules) {
        $canonical = [string]$rule.canonical
        $detect = New-Object System.Collections.Generic.List[string]
        $normalize = New-Object System.Collections.Generic.List[string]

        foreach ($pat in @($rule.detect_patterns)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$pat)) { [void]$detect.Add([string]$pat) }
        }
        foreach ($pat in @($rule.normalize_patterns)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$pat)) { [void]$normalize.Add([string]$pat) }
        }

        if (-not [string]::IsNullOrWhiteSpace($canonical)) {
            $canonicalPattern = ("(?i)\b{0}\b" -f [regex]::Escape($canonical))
            [void]$detect.Add($canonicalPattern)
            [void]$normalize.Add($canonicalPattern)

            $aliasPattern = Get-GroupCanonicalAliasPattern $canonical
            if (-not [string]::IsNullOrWhiteSpace($aliasPattern)) {
                [void]$detect.Add($aliasPattern)
                [void]$normalize.Add($aliasPattern)
            }
        }

        $lbl = [string]$rule.label
        if (-not [string]::IsNullOrWhiteSpace($lbl)) {
            [void]$detect.Add(("(?i)\b{0}\b" -f [regex]::Escape($lbl)))
        }

        $expanded.Add([PSCustomObject]@{
            id = [string]$rule.id
            label = [string]$rule.label
            canonical = $canonical
            detect_patterns = @($detect | Select-Object -Unique)
            normalize_patterns = @($normalize | Select-Object -Unique)
        }) | Out-Null
    }
    return $expanded.ToArray()
}

function Apply-GroupNormalizationPatterns([string]$txt, $rules) {
    $x = [string]$txt
    foreach ($rule in $rules) {
        foreach ($pat in @($rule.normalize_patterns)) {
            if ([string]::IsNullOrWhiteSpace([string]$pat)) { continue }
            $x = [regex]::Replace($x, [string]$pat, [string]$rule.canonical)
        }
    }
    return $x
}

function Normalize-GroupAliasesInText([string]$txt, $rules) {
    if ([string]::IsNullOrWhiteSpace($txt)) { return '' }
    $x = Apply-GroupNormalizationPatterns ([string]$txt) $rules
    if ($x.Contains('_')) {
        $parts = $x -split '_', -1
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $parts[$i] = Apply-GroupNormalizationPatterns ([string]$parts[$i]) $rules
        }
        $x = ($parts -join '_')
    }
    $x = $x -replace '\s+', ' '
    return $x.Trim()
}

$script:GroupNormalizeCache = @{}
function Normalize-GroupAliasesCached([string]$txt, $rules) {
    $key = if ($null -eq $txt) { '' } else { [string]$txt }
    if ($script:GroupNormalizeCache.ContainsKey($key)) {
        return [string]$script:GroupNormalizeCache[$key]
    }
    $norm = Normalize-GroupAliasesInText $key $rules
    $script:GroupNormalizeCache[$key] = $norm
    return $norm
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

function Get-EquationTerms([string]$eq) {
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
            $coef = 1.0
            if ($x -match '^([+-]?\d+(?:\.\d+)?)\s+(.+)$') {
                $coef = [double]$matches[1]
                $x = $matches[2].Trim()
            }
            $x = $x -replace '^\<\s*',''
            $x = $x -replace '\s*\>$',''
            if (-not [string]::IsNullOrWhiteSpace($x)) {
                $terms += [PSCustomObject]@{
                    coeff = $coef
                    species = $x
                }
            }
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

function Build-ChemicalGroupsForReaction([string]$product, [string]$equation, $rules) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $counts = @{}
    $terms = @([PSCustomObject]@{ coeff = 1.0; species = $product })
    if ([string]::IsNullOrWhiteSpace($product)) {
        $terms = @(Get-EquationTerms $equation)
    }
    foreach ($term in $terms) {
        $species = [string]$term.species
        if ([string]::IsNullOrWhiteSpace($species)) { continue }
        $coefAbs = [Math]::Abs([double]$term.coeff)
        $termMult = [int][Math]::Round($coefAbs)
        if ($termMult -lt 1) { $termMult = 1 }
        $speciesParts = @($species)
        if ($species.Contains('_')) {
            $speciesParts = @($species -split '_', -1)
        }
        foreach ($part in $speciesParts) {
            $piece = [string]$part
            if ([string]::IsNullOrWhiteSpace($piece)) { continue }
            $pieceMult = 1
            if ($piece -match '\((\d+)\)\s*$') {
                $pieceMult = [int]$matches[1]
            }
            $mult = $termMult * $pieceMult
            foreach ($rule in $rules) {
                $matched = $false
                foreach ($pat in @($rule.detect_patterns)) {
                    if ($piece -match $pat) { $matched = $true; break }
                }
                if ($matched) {
                    [void]$set.Add($rule.id)
                    Add-Count $counts $rule.id $mult
                }
            }
        }
    }
    $countsOut = @{}
    foreach ($k in ($counts.Keys | Sort-Object)) { $countsOut[$k] = [int]$counts[$k] }
    return [PSCustomObject]@{
        groups = @($set | Sort-Object)
        counts = $countsOut
    }
}

$script:ReactionDerivedCache = @{}
function Get-ReactionDerivedCached([string]$product, [string]$equation, $rules) {
    $key = [string]$product + "`n" + [string]$equation
    if ($script:ReactionDerivedCache.ContainsKey($key)) {
        return $script:ReactionDerivedCache[$key]
    }
    $hill = Build-HillForReaction $product $equation
    $atoms = @(Get-AtomsFromText ($product + ' ' + $equation))
    $groupInfo = Build-ChemicalGroupsForReaction $product $equation $rules
    $value = [PSCustomObject]@{
        hill = $hill
        atoms = $atoms
        groups = @($groupInfo.groups)
        group_counts = $groupInfo.counts
    }
    $script:ReactionDerivedCache[$key] = $value
    return $value
}

$script:ContribSourcesCache = @{}
function Get-SourcesFromContribCached([string]$txt) {
    $key = if ($null -eq $txt) { '' } else { [string]$txt }
    if ($script:ContribSourcesCache.ContainsKey($key)) {
        return @($script:ContribSourcesCache[$key])
    }
    $sources = @(Get-SourcesFromContrib $key)
    $script:ContribSourcesCache[$key] = @($sources)
    return @($sources)
}

$rows = Import-Csv -Delimiter "`t" -Path $inPath
$groupRules = @(Expand-ChemicalGroupRules (Get-ChemicalGroupRules))
$chunks = @{}
$atomToChunks = @{}
$sourceToChunks = @{}
$groupToChunks = @{}
$sourceCounts = @{}
$groupCounts = @{}
$groupLabels = @{}
$allSources = New-Object System.Collections.Generic.HashSet[string]
$allGroups = New-Object System.Collections.Generic.HashSet[string]
foreach ($gr in $groupRules) { $groupLabels[$gr.id] = [string]$gr.label }
$total = 0

foreach ($r in $rows) {
    $k = if ($r.PSObject.Properties.Name -contains 'logK') { $r.logK } else { $r.logK_25C }
    $productRaw = [string]$r.product
    $equationRaw = [string]$r.equation_full
    $product = Normalize-GroupAliasesCached $productRaw $groupRules
    $equation = Normalize-GroupAliasesCached $equationRaw $groupRules
    $contrib = [string]$r.contributing_logK
    $reactionData = Get-ReactionDerivedCached $product $equation $groupRules
    $hill = [string]$reactionData.hill
    $atoms = @($reactionData.atoms)
    $sources = @(Get-SourcesFromContribCached $contrib)
    $groups = @($reactionData.groups)
    $groupCountMap = $reactionData.group_counts
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
        g = $groups
        gc = $groupCountMap
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
        if ($sourceCounts.ContainsKey($s)) { $sourceCounts[$s] += 1 } else { $sourceCounts[$s] = 1 }
        if (-not $sourceToChunks.ContainsKey($s)) {
            $sourceToChunks[$s] = New-Object System.Collections.Generic.HashSet[string]
        }
        [void]$sourceToChunks[$s].Add($chunkKey)
    }
    foreach ($g in $groups) {
        [void]$allGroups.Add($g)
        if ($groupCounts.ContainsKey($g)) { $groupCounts[$g] += 1 } else { $groupCounts[$g] = 1 }
        if (-not $groupToChunks.ContainsKey($g)) {
            $groupToChunks[$g] = New-Object System.Collections.Generic.HashSet[string]
        }
        [void]$groupToChunks[$g].Add($chunkKey)
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
$groupChunksOut = @{}
foreach ($g in ($groupToChunks.Keys | Sort-Object)) {
    $groupChunksOut[$g] = @($groupToChunks[$g] | Sort-Object)
}
$sourceCountsOut = @{}
foreach ($s in ($sourceCounts.Keys | Sort-Object)) {
    $sourceCountsOut[$s] = [int]$sourceCounts[$s]
}
$groupCountsOut = @{}
foreach ($g in ($groupCounts.Keys | Sort-Object)) {
    $groupCountsOut[$g] = [int]$groupCounts[$g]
}
$groupLabelsOut = @{}
foreach ($g in ($allGroups | Sort-Object)) {
    if ($groupLabels.ContainsKey($g)) { $groupLabelsOut[$g] = [string]$groupLabels[$g] }
    else { $groupLabelsOut[$g] = $g }
}

$manifest = [PSCustomObject]@{
    generated_at = (Get-Date).ToString('s')
    total_rows = $total
    chunks = $chunkManifest
    atom_to_chunks = $atomChunksOut
    sources = @($allSources | Sort-Object)
    source_to_chunks = $sourceChunksOut
    source_count = $sourceCountsOut
    groups = @($allGroups | Sort-Object)
    group_to_chunks = $groupChunksOut
    group_count = $groupCountsOut
    group_labels = $groupLabelsOut
}

[System.IO.File]::WriteAllText(
    (Join-Path $dataDir 'manifest.json'),
    ($manifest | ConvertTo-Json -Depth 8 -Compress),
    [System.Text.Encoding]::UTF8
)

# Ensure GitHub Pages serves static assets as-is.
[System.IO.File]::WriteAllText((Join-Path $docsDir '.nojekyll'), '', [System.Text.Encoding]::UTF8)

Write-Output ("Built docs data: {0} rows, {1} chunks" -f $total, $chunkManifest.Count)
