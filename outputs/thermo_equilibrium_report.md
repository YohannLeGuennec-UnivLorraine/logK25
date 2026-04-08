# Thermodynamic Equilibrium Extraction Report

## Output Files
- Full merged table: `C:\Users\leguenne1\Documents\5. Codes\thermo-database\outputs\thermo_equilibrium_merged.tsv`

## Extraction Statistics
- Raw extracted records: **74634**
- Merged unique records: **66509**

### Records By Source Family
- `GWB`: 13409
- `IUPAC-pKa`: 8326
- `MedusaText`: 1082
- `NIST-SRD46`: 44581
- `PSINagra-PHREEQC`: 1104
- `Thermoddem-CHESS`: 1705
- `Thermoddem-GWB`: 1690
- `Thermoddem-PHREEQC`: 1033
- `Thermoddem-ToughReact`: 1704

## Databases That Could Not Be Fully Parsed
- External databases\\Medusa\\*.db and *.elb (binary format, no built-in parser in this extraction)
- External databases\\NIST SRD 46\\NIST_SRD_46_ported.db (file content is HTML, not a thermodynamic DB; using SRD 46 SQL raw dump instead)

## Notes On Merging
- Rows are grouped by product + stoichiometric signature + experimental conditions, then logK values within 5% relative deviation are merged.
- Product labels with or without explicit `(aq)` are treated as the same product key for merging.
- For each merged row, logK is the arithmetic average of contributing values.
- Contributing source labels are preserved in `contributing_logK` as `Family-DatabaseName`.
