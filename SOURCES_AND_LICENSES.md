# Sources, licences and reuse conditions

logK25 is a transformed compilation built from independent scientific resources. Public accessibility does not necessarily imply unrestricted reuse or redistribution. Each contribution remains subject to the rights and conditions of its original source.

This register records the information identified as of 21 August 2026. Entries marked **institutional review required** must be confirmed with the Université de Lorraine's SDVI before a stable release or any commercial reuse. This document is descriptive and is not legal advice.

## AqSolDB

- **Version used:** repository snapshot containing 9,982 curated compounds.
- **Official source:** <https://github.com/mcsorkun/AqSolDB>
- **Files used:** curated aqueous-solubility data and associated processing resources.
- **Use in logK25:** aqueous-solubility `logS` values represented as proxy entries. These values are not direct thermodynamic equilibrium constants.
- **Data rights:** CC0 1.0 Universal.
- **Code rights:** MIT License. The copyright and permission notice must be retained in copies or substantial portions of the code.
- **Redistribution status:** permitted for the CC0 data; code redistribution is permitted under the MIT conditions.
- **Recommended citation:** M. C. Sorkun, A. Khetan and S. Er, *AqSolDB, a curated reference set of aqueous solubility and 2D descriptors for a diverse set of compounds*, Scientific Data 6, 143 (2019), <https://doi.org/10.1038/s41597-019-0151-1>.
- **Transformations:** selection, conversion to the logK25 common schema and source labelling.
- **Legal status:** documented.

## GWB thermodynamic datasets

- **Official source:** <https://www.gwb.com/thermo.php>
- **Files used:** multiple `.tdat` datasets listed in the repository's `External databases/GWB` directory.
- **Use in logK25:** extraction of reactions and values tabulated at 25 degrees C.
- **Rights:** dataset-specific. Several headers state that, to the authors' knowledge, a dataset is not subject to copyright; other files contain no equivalent grant. This is not a single licence covering the whole GWB family.
- **Redistribution status:** institutional review required for each dataset. The GWB reference manual must not be treated as data or as openly licensed merely because it is downloadable.
- **Attribution:** retain each dataset's exact name, version, authors, header and bibliographic references. Attribute the original dataset rather than GWB when GWB is only the file format or distribution channel.
- **Transformations:** extraction at 25 degrees C, reaction parsing, normalization and aggregation.
- **Legal status:** institutional review required.

## IUPAC Digitized pKa Dataset

- **Version used:** v2.3d, as recorded by the source snapshot integrated into logK25.
- **Official source:** <https://github.com/IUPAC/Dissociation-Constants>
- **Persistent identifier:** <https://doi.org/10.5281/zenodo.7236453>
- **Use in logK25:** conversion of aqueous dissociation constants to the logK25 common representation.
- **Licence:** CC BY-NC 4.0.
- **Redistribution status:** permitted for non-commercial use, subject to attribution and the licence conditions. Commercial use requires separate permission.
- **Required attribution:** `Reproduced by permission of International Union of Pure and Applied Chemistry.`
- **Recommended citation:** Jonathan W. Zheng and Olivier Lafontant-Joseph (2025), *IUPAC Digitized pKa Dataset, v2.3d*, International Union of Pure and Applied Chemistry.
- **Transformations:** filtering, normalization and conversion from pKa to logK form. Modified material must be identified as such and linked to the CC BY-NC 4.0 licence.
- **Legal status:** documented for non-commercial use.

## JESS Thermodynamic Reaction Database

- **Version used:** v8.9.
- **Official source:** <https://zenodo.org/records/7700024>
- **Persistent identifier:** <https://doi.org/10.5281/zenodo.7700024>
- **Use in logK25:** extraction of reaction data from the publicly disseminated PDF files and transformation to a tabular, PHREEQC-like representation.
- **Rights:** the JESS notice grants permission to use the contents of the PDF documents freely when appropriate attribution is given. All JESS intellectual-property rights are retained.
- **Redistribution status:** extracted content may be used with attribution. Any dissemination of the JESS PDF documents to third parties must include the JESS licence, copyright and disclaimer notice.
- **Attribution:** Josep Bonet, Montserrat Filella, Peter M. May, Ruth F. May and Kevin Murray, *JESS Thermodynamic Database of Chemical Reactions, v8.9*.
- **Disclaimer:** JESS material is provided as is, without warranty, and is used at the user's own risk.
- **Transformations:** PDF extraction, reaction reconstruction, filtering at 25 degrees C and normalization.
- **Legal status:** documented custom permission; institutional confirmation recommended for large-scale redistribution of the transformed compilation.

## Medusa/Hydra databases

- **Official source:** <https://www.kth.se/che/medusa/downloads-1.386254>
- **Files used:** Medusa/Hydra reaction databases, text exports and associated reference files.
- **Use in logK25:** extraction of reactions, logK values and source references.
- **Rights:** no explicit redistribution licence was identified in the files examined.
- **Redistribution status:** institutional review required. Public download availability must not be interpreted as permission to republish the complete database files.
- **Attribution:** identify Medusa/Hydra and KTH Royal Institute of Technology, the exact database file or version, and the record-level bibliographic reference where available.
- **Transformations:** text or binary-data extraction, normalization and aggregation.
- **Legal status:** institutional review required.

## NIST SRD 46

- **Version used:** Version 8.0.
- **Official source:** <https://data.nist.gov/pdr/lps/ark:/88434/mds2-2154>
- **Persistent identifier:** <https://doi.org/10.18434/M32154>
- **Use in logK25:** transformation of the SQL export into reaction-like rows with ligand and experimental metadata.
- **Rights:** NIST Standard Reference Data may be protected as a compilation. The official record links to NIST's copyright, fair-use and licensing statements.
- **Redistribution status:** institutional review required for republication of the SQL files or a substantial transformed portion of the database.
- **Required citation:** Donald R. Burgess (2004), *NIST SRD 46. Critically Selected Stability Constants of Metal Complexes: Version 8.0 for Windows*, National Institute of Standards and Technology, <https://doi.org/10.18434/M32154>.
- **Modification notice:** logK25 must state that it transformed the data and identify the date and nature of the changes. It must not imply that the transformed compilation is an official NIST product.
- **Legal status:** institutional review required.

## PSI/Nagra Chemical Thermodynamic Database 2020

- **Version used:** psinagra2020 v2-1, PHREEQC distribution.
- **Official source:** <https://www.psi.ch/en/les/thermodynamic-databases>
- **Use in logK25:** extraction of PHREEQC reactions and values at 25 degrees C with available comments and references.
- **Rights:** the database is openly downloadable in several modelling formats, but no source-specific open-data licence was identified in the integrated file. PSI's general website conditions reserve commercial use unless otherwise indicated.
- **Redistribution status:** non-commercial scientific use is consistent with the published conditions; republication of the complete file and broader licensing remain subject to institutional confirmation.
- **Attribution:** `psinagra2020 v2-1 (Hummel and Thoenen, 2023)`. Cite G. D. Miron (2025) where the relevant temperature and pressure extensions are used. Retain the original file header and documentation references.
- **Transformations:** extraction at 25 degrees C, reaction parsing, normalization and aggregation.
- **Legal status:** institutional review required before stable redistribution.

## Thermoddem

- **Version used:** v1.10, database update dated 15 December 2020.
- **Official source:** <https://thermoddem.brgm.fr/databases>
- **Use in logK25:** extraction from CHESS, GWB, PHREEQC, ToughReact and Crunch distributions.
- **Rights:** the BRGM's InfoTerre data are generally distributed under the Licence Ouverte / Open Licence Etalab 2.0, but the application of that licence to the Thermoddem domain and files has not been explicitly confirmed.
- **Redistribution status:** institutional review required until the BRGM or SDVI confirms the applicable licence.
- **Provisional attribution:** `Source: BRGM, Thermoddem v1.10, updated 15 December 2020`, with the official URL, an indication of logK25's transformations and no distortion of the source's meaning.
- **Transformations:** extraction across modelling formats, selection at 25 degrees C, normalization and aggregation.
- **Legal status:** institutional review required.

## Complementary resource: SC-Database extracts

The SC-Database material at <https://equilibriumdata.github.io/sc-database.html> is referenced as a complementary online resource and is not currently listed as an ingested source family. Its former commercial database is no longer distributed, and the public PDF extracts include stated completeness limitations. Linking and citation do not imply permission for wholesale extraction or republication.

## Project-wide rules

1. There is no single licence covering the entire consolidated dataset at this stage.
2. Source-specific attribution, version and rights information must remain attached to every contribution and export.
3. A value's inclusion does not imply validation or endorsement by the Université de Lorraine, LRGP or the original provider.
4. Data marked `institutional review required` must not be presented as openly reusable without restriction.
5. Critical values must be checked against the cited original source.
6. The original source code, consolidated dataset and third-party files must be licensed separately after the institutional review.
