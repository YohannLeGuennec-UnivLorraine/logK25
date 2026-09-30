Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..')

Write-Host "[1/2] Running thermodynamic extraction..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'extract_thermo.ps1')
if ($LASTEXITCODE -ne 0) {
    throw "Thermodynamic extraction failed with exit code $LASTEXITCODE."
}

Write-Host "[2/2] Building GitHub Pages data..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'build_docs_data.ps1')
if ($LASTEXITCODE -ne 0) {
    throw "GitHub Pages data build failed with exit code $LASTEXITCODE."
}

Write-Host "Done. Outputs in:"
Write-Host " - $root\\outputs"
Write-Host " - $root\\docs"
