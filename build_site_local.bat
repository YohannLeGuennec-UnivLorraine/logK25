@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "BUILD_MODE=full"
set "SERVE_SITE=0"
set "SOURCE_FILTER="

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--site-only" (
  set "BUILD_MODE=site-only"
  shift
  goto parse_args
)
if /I "%~1"=="--serve" (
  set "SERVE_SITE=1"
  shift
  goto parse_args
)
if /I "%~1"=="--sources" (
  if "%~2"=="" goto usage_error
  set "SOURCE_FILTER=%~2"
  set "BUILD_MODE=site-only"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage

echo [ERROR] Unknown option: %~1
goto usage_error

:args_done
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Windows PowerShell was not found in PATH.
  exit /b 1
)

if not exist "scripts\run_all.ps1" (
  echo [ERROR] Missing scripts\run_all.ps1
  exit /b 1
)

echo ============================================================
echo  logK25 - local site build
echo  Project: %CD%
echo  Mode: %BUILD_MODE%
echo ============================================================

if /I "%BUILD_MODE%"=="site-only" (
  if not exist "outputs\thermo_equilibrium_merged.tsv" (
    echo [ERROR] Missing outputs\thermo_equilibrium_merged.tsv
    echo         Run this script without --site-only first.
    exit /b 1
  )
  echo [1/1] Rebuilding the web site from the existing merged table...
  if defined SOURCE_FILTER (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\build_docs_data.ps1" -Sources "%SOURCE_FILTER%"
  ) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\build_docs_data.ps1"
  )
) else (
  echo [1/1] Rebuilding the thermodynamic data and the complete web site...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run_all.ps1"
)

if errorlevel 1 (
  echo.
  echo [ERROR] Build failed. Review the error messages above.
  exit /b 1
)

if not exist "docs\index.html" (
  echo [ERROR] Build completed without docs\index.html
  exit /b 1
)
if not exist "docs\data\manifest.json" (
  echo [ERROR] Build completed without docs\data\manifest.json
  exit /b 1
)
if not exist "docs\data\sources.json" (
  echo [ERROR] Build completed without docs\data\sources.json
  exit /b 1
)

echo.
echo [OK] Site generated in: %CD%\docs

if "%SERVE_SITE%"=="1" goto serve

echo To preview it locally, run:
echo   build_site_local.bat --site-only --serve
exit /b 0

:serve
echo.
echo Starting the local site at http://localhost:8000/
echo Press Ctrl+C to stop the server.
start "" "http://localhost:8000/"

where py.exe >nul 2>&1
if not errorlevel 1 (
  py.exe -3 -m http.server 8000 --directory "%CD%\docs"
  exit /b %ERRORLEVEL%
)

where python.exe >nul 2>&1
if not errorlevel 1 (
  python.exe -m http.server 8000 --directory "%CD%\docs"
  exit /b %ERRORLEVEL%
)

echo [ERROR] Python was not found. The site was built successfully,
echo         but --serve requires py.exe or python.exe.
exit /b 1

:usage
echo Usage: build_site_local.bat [--site-only] [--sources AqSolDB,NIST-SRD46] [--serve]
echo.
echo   no option     Rebuild all source data and the complete site.
echo   --site-only   Rebuild only docs/ from the existing merged TSV.
echo   --sources     Update only listed sources from the existing merged TSV.
echo   --serve       Build, open, and serve the site on localhost:8000.
exit /b 0

:usage_error
echo Usage: build_site_local.bat [--site-only] [--sources AqSolDB,NIST-SRD46] [--serve]
exit /b 2
