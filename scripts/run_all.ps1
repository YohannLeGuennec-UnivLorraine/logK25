Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..')

Write-Host "[1/2] Running thermodynamic extraction..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'extract_thermo.ps1')

Write-Host "[2/2] Building GitHub Pages data..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'build_docs_data.ps1')

Write-Host "Done. Outputs in:"
Write-Host " - $root\\outputs"
Write-Host " - $root\\docs"
