# logK25 database

This repository builds a merged thermodynamic equilibrium dataset at 25 C from multiple publicly accessible scientific resources, and publishes a searchable GitHub Pages interface at https://yohannleguennec-univlorraine.github.io/logK25/

Public accessibility does not necessarily imply unrestricted reuse or redistribution. Each contribution remains subject to the rights and conditions of its original source. See [Sources, licences and reuse conditions](SOURCES_AND_LICENSES.md) and the [rights statement](RIGHTS.md).

## Institutional affiliation

logK25 is developed by Yohann Le Guennec at the Laboratoire Réactions et Génie des Procédés (LRGP, UMR CNRS 7274), Université de Lorraine.

Contact: [yohann.le-guennec@univ-lorraine.fr](mailto:yohann.le-guennec@univ-lorraine.fr)

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

The machine-readable source register is maintained in `config/sources.json`. It records source versions, authors or responsible organisations, reference publications, URLs, known licences, required attribution and the current redistribution-review status. For GWB and Medusa/Spana, authorship follows the underlying dataset rather than the software or exchange format.

The scientific database names shown in the web interface, their displayed versions and their technical acquisition paths are maintained separately in `config/database_families.json`. Distribution formats such as GWB, CHESS, PHREEQC, ToughReact and Medusa are retained in row-level provenance rather than presented as independent scientific databases.

- `GWB` (`External databases/GWB/*.tdat`)
  - Aqueous/mineral/gas equilibrium reactions with logK (25 C extraction from tabulated data).
  - `GWB` is the file format/distribution route; rights and attribution are evaluated for the underlying LLNL, USGS, THEREDA, MINTEQ, NEA, Thermochimie and other datasets file by file.
- `Medusa` / `Spana` text exports (`External databases/Medusa/*.txt`)
  - The current pipeline ingests the SOLTHERM and Thermoddem text exports only.
  - Medusa/Spana is the software container: SOLTHERM is treated under its CC BY 4.0 dataset record, while the Thermoddem export retains the BRGM/Thermoddem rights status.
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
  - The Fair Use terms attached to the SQL distribution permit derivative works and redistribution with NIST acknowledgement and a dated description of modifications; the SQL extraction carries a NIST reliability warning.
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

On Windows, the simplest command is:

```bat
build_site_local.bat
```

Useful options:

```bat
build_site_local.bat --site-only
build_site_local.bat --site-only --serve
build_site_local.bat --sources AqSolDB
build_site_local.bat --sources AqSolDB,NIST-SRD46 --serve
```

- `--site-only` rebuilds `docs/` from the existing merged TSV without rerunning source extraction.
- `--sources` updates only the selected source families (or exact source IDs) from the existing merged TSV. Other rows are retained; only changed data chunks are written, and the search indexes are refreshed. A complete existing site is required. This updates the site's derived data, not the original database extraction.
- `--serve` opens and serves the generated site at <http://localhost:8000/>; Python must be available as `py` or `python`.

The complete PowerShell pipeline remains available with:

Run the full pipeline with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_all.ps1
```

The targeted site update can also be called directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_docs_data.ps1 -Sources AqSolDB
```

AqSolDB element indexing uses the molecular formula in the compound's InChI, including salts and their protonation layer. Older merged exports resolve that structure from the source CSV using the AqSolDB ID.

This executes:

1. `scripts/extract_thermo.ps1`
2. `scripts/build_docs_data.ps1`

## Rights, attribution and disclaimer

logK25 is a transformed compilation of data originating from several independent scientific resources. Each contribution remains subject to the rights and conditions of its original source.

Source attribution, version information and known reuse conditions are documented in [SOURCES_AND_LICENSES.md](SOURCES_AND_LICENSES.md). Some redistribution conditions are currently under institutional review. No single licence currently applies to the entire repository or consolidated dataset; see [RIGHTS.md](RIGHTS.md).

The inclusion of a value does not imply validation or endorsement by the Université de Lorraine, LRGP or the original data provider. No warranty is provided regarding correctness, completeness or fitness for use. Users must verify critical values against the cited original source.
