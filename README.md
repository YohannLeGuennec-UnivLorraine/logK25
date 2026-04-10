# logK25 database

This repository builds a merged thermodynamic equilibrium dataset at 25 C from multiple freely accessible sources, and publishes a searchable GitHub Pages interface at https://yohannleguennec-univlorraine.github.io/logK25/

## What is produced

- Main merged table: `outputs/thermo_equilibrium_merged.tsv`
- Human-readable reports:
  - `outputs/thermo_equilibrium_report.md`
  - `outputs/thermo_equilibrium_report.html`
- GitHub Pages app:
  - `docs/index.html`
  - `docs/data/manifest.json`
  - `docs/data/chunks/*.json`

## Source databases and extracted data type

- `GWB` (`External databases/GWB/*.tdat`)
  - Aqueous/mineral/gas equilibrium reactions with logK (25 C extraction from tabulated data).
- `Medusa` text exports (`External databases/Medusa/*.txt`)
  - Equilibrium reactions and logK from semicolon-separated text exports.
- `Thermoddem` exports:
  - `Thermoddem-GWB`
  - `Thermoddem-PHREEQC`
  - `Thermoddem-ToughReact`
  - `Thermoddem-CHESS`
  - `Thermoddem-Crunch`
  - Extracted reaction equations and logK, with source-specific comments when available.
- `PSINagra-PHREEQC` (`psinagra2020_v2-1ext.dat`)
  - PHREEQC-style reactions and logK with associated metadata/comments when present.
- `JESS-PHREEQC-like`
  - Generated from JESS PDF sheets in `External databases/JESS`.
  - Reactions and logK (25 C only), preserving JESS metadata (file, reaction number, ionic strength/medium when available).
- `NIST-SRD46` (raw SQL export)
  - Complexation and equilibrium constants mapped to reaction-like rows, including ligand names and context metadata.
- `IUPAC-pKa`
  - Acid/base dissociation constants converted to logK form (from pKa) with conditions when available.
- `AqSolDB-logS`
  - Aqueous solubility values (logS) stored as a solubility proxy entry.
  - Important: this is not a direct thermodynamic equilibrium constant.

## Complementary online source

- SC-Database (EquilibriumData): https://equilibriumdata.github.io/sc-database.html
  - Useful complementary online source for additional equilibrium-related information.

## Merging and conventions

- Merging key uses:
  - product (canonicalized),
  - stoichiometric signature,
  - experimental condition key.
- Near-identical logK values (<=5% relative deviation) are merged only within the same condition group.
- Contributions are retained in `contributing_logK`, including explicit source labels.
- Reaction strings and species names are normalized to reduce notation inconsistencies across databases.

## GitHub Pages app behavior

- No data is loaded at startup.
- Users can:
  - select atoms from the periodic table,
  - choose which databases are included (default: all selected),
  - optionally load all data,
  - search in currently loaded rows,
  - export current view to CSV.

## Rebuild pipeline

Run the full pipeline with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_all.ps1
```

This executes:

1. `scripts/extract_thermo.ps1`
2. `scripts/build_docs_data.ps1`

## Disclaimer

All data are extracted from freely accessible databases. No warranty is provided regarding correctness or completeness. Always verify critical values against the original source databases included in this repository.
