# Sources, licences and reuse conditions

logK25 is a transformed compilation built from independent scientific resources. Public accessibility does not necessarily imply unrestricted reuse or redistribution. Each contribution remains subject to the rights and conditions of its original source.

This register records the information identified as of 27 August 2026. Entries marked **institutional review required** must be confirmed with the Université de Lorraine's SDVI before a stable release or any commercial reuse. This document is descriptive and is not legal advice.

## Authors and reference-publication policy

The machine-readable register in `config/sources.json` now records `authors` and `reference_publications` for every source family. A reference publication establishes scientific provenance; it does not replace a licence or create a right to redistribute the data. Where a software package carries several databases, authorship is assigned to each underlying dataset.

The principal references used by logK25 are:

- **AqSolDB:** Murat Cihan Sorkun, Abhishek Khetan and Süleyman Er; Scientific Data 6, 143 (2019), <https://doi.org/10.1038/s41597-019-0151-1>.
- **IUPAC Digitized pKa:** Jonathan W. Zheng and Olivier Lafontant-Joseph; dataset v2.3d, <https://doi.org/10.5281/zenodo.7236453>. The digitisation method is also described by Zheng, Lafontant-Joseph and Green (2026), <https://doi.org/10.1039/D6RA02418A>.
- **JESS v8.9:** Josep Bonet, Montserrat Filella, Peter M. May, Ruth F. May and Kevin Murray; <https://doi.org/10.5281/zenodo.7700024>. The thermodynamic-database design is described by May and Murray, *Talanta* 38 (1991), 1419–1426.
- **SOLTHERM:** Mark H. Reed, Jim Palandri and the University of Oregon maintainers; Reed and Palandri (2006), *SOLTHERM.H06, A Database of Equilibrium Constants for Minerals and Aqueous Species*, <https://doi.org/10.15121/1805737>. Individual reactions retain their record-level references from `Soltherm_References.txt`.
- **HYDRA/MEDUSA/Spana software:** Ignasi Puigdomènech; KTH documentation and Puigdomènech et al. (2014), <https://doi.org/10.1557/opl.2014.635>. This software citation is not an attribution for the databases it reads.
- **NIST SRD 46:** data selected by R. M. Smith and A. E. Martell; program by R. J. Motekaitis; NIST record by Donald R. Burgess (2004), <https://doi.org/10.18434/M32154>. The six-volume *Critical Stability Constants* compilation by Martell and Smith is the principal printed antecedent.
- **PSI/Nagra TDB 2020:** Wolfgang Hummel and Tres Thoenen; *The PSI Chemical Thermodynamic Database 2020*, Nagra NTB 21-03 (2023). Cite George-Dan Miron, PSI TM 44-25-04 (2025), when the relevant temperature/pressure extensions are used. See the [official citation instructions](https://www.psi.ch/en/les/database).
- **Thermoddem:** Philippe Blanc, Arnault Lassin, Patrice Piantone, Mohamed Azaroual, Nicolas Jacquemet, Antonin Fabbri and Éric C. Gaucher; *Applied Geochemistry* 27 (2012), 2107–2116, <https://doi.org/10.1016/j.apgeochem.2012.06.002>.
- **THEREDA:** THEREDA consortium; Moog, Bok, Marquardt and Brendler, *Applied Geochemistry* 55 (2015), 72–84, <https://doi.org/10.1016/j.apgeochem.2014.12.016>, together with the release-specific references maintained by THEREDA.

For the GWB-formatted files, the underlying references are recorded file by file:

- `thermo_cemdata.tdat`: Lothenbach et al., Cemdata18, <https://doi.org/10.1016/j.cemconres.2018.04.018>.
- `thermo_coldchem.tdat`: Toner and Catling (2017), <https://doi.org/10.1021/acs.jced.6b00812>.
- `thermo_frezchem.tdat`: Toner and Sletten (2013), <https://doi.org/10.1016/j.gca.2013.02.013>, with the earlier FREZCHEM work cited in the file header.
- `thermo_minteq.tdat`: Visual MINTEQ database maintained by Jon Petter Gustafsson; local v2.40 compilation dated 2005.
- `thermo_nea.tdat`: OECD NEA Thermochemical Database Project and its Chemical Thermodynamics Series; local SIT snapshot v1.0 (November 2018).
- `thermo_phreeqc.tdat`: PHREEQC by David L. Parkhurst and C. A. J. Appelo, <https://doi.org/10.3133/tm6A43>; local GWB conversion by Daniel Saalfeld and Craig Bethke (2003).
- `thermo_sit.tdat`: ThermoChimie by Giffaut et al. (2014), <https://doi.org/10.1016/j.apgeochem.2014.05.007>.
- `thermo.tdat` and `thermo.com.V8.R6+.tdat`: LLNL/EQ3/6 compilation associated with Thomas J. Wolery; Delany and Lundeen (1990), *The LLNL Thermochemical Database*, UCRL-21658.
- `thermo_hmw.tdat`: Harvie, Møller and Weare (1984), <https://doi.org/10.1016/0016-7037(84)90098-X>.
- `thermo_phrqpitz.tdat`: Plummer, Parkhurst, Fleming and Dunkle (1988), USGS WRI 88-4153.
- `thermo_wateq4f.tdat`: Ball and Nordstrom (1991), USGS OFR 91-183; local GWB conversion by Daniel Saalfeld and Craig Bethke (2003).
- `thermo_ymp.R2.tdat`: Jové-Colón, Wolery, Rard, Wijesinghe, Jareck and Helean (2007), Appendix I of ANL-EBS-MD-000045 REV 03; GWB reformatting by Frank Bok.

## Provenance rule: software is not the data source

GWB and Medusa/Hydra/Spana can load, convert or distribute thermodynamic databases created by other organisations. Their software licences and terms do not automatically determine the rights in those databases. Rights analysis must therefore follow the underlying dataset and the exact file header. In logK25, a label such as `GWB-*` or `Medusa-*` describes the technical route by which a record was obtained, not necessarily the owner or licensor of the scientific data.

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
- **Role of GWB:** GWB provides the `.tdat` format, conversion tools and a distribution page. Its official page identifies the upstream origin of each dataset, including LLNL, USGS/PHREEQC, Visual MINTEQ, THEREDA, Thermochimie, NEA, FREZCHEM, COLDCHEM and Cemdata. GWB is not a single licensor for all of those scientific compilations.
- **Rights:** dataset-specific. Permission to edit a `.tdat` file for use in GWB and public download availability do not, by themselves, license bulk republication of the underlying data.
- **Attribution:** retain each dataset's exact name, version, authors, header and bibliographic references. Attribute the original dataset rather than GWB when GWB is only the file format or distribution channel.
- **Transformations:** extraction at 25 degrees C, reaction parsing, normalization and aggregation.
- **Official distribution page:** <https://www.gwb.com/thermo.php>.

### GWB files with an explicit header notice

The integrated files `thermo_cemdata.tdat`, `thermo_coldchem.tdat`, `thermo_frezchem.tdat`, `thermo_minteq.tdat`, `thermo_nea.tdat`, `thermo_phreeqc.tdat` and `thermo_sit.tdat` state that, to the distributor's best knowledge, the dataset is not subject to copyright.

- **Interpretation:** this is favourable evidence for reuse, but it is not a conventional open-data licence granted by every original contributor.
- **Redistribution status:** source notice documented; retain the complete header and attribution. Source-level review remains prudent for substantial commercial republication.
- **Legal status:** documented source notice, not a universal GWB licence.

### THEREDA distributed in GWB format

`THEREDA_2023a_GWB.tdat` embeds a **CC BY-NC-ND 4.0** notice.

- **Permitted:** non-commercial sharing of the unmodified material with attribution.
- **Restriction:** the NoDerivatives clause does not clearly permit redistribution of logK25's normalized, selected and converted records.
- **Redistribution status:** do not publish the transformed THEREDA contribution without permission or confirmation that the transformation is allowed.
- **Legal status:** documented restriction.

### Other GWB-formatted files

The remaining integrated GWB files include LLNL-derived `thermo.tdat` and `thermo.com.V8.R6+.tdat`, Harvie-Møller-Weare `thermo_hmw.tdat`, PHRQPITZ, WATEQ4F and the Yucca Mountain Pitzer dataset. Their local headers document provenance and scientific references but do not contain a uniform redistribution grant.

- **Redistribution status:** review the upstream LLNL, USGS, Sandia/DOE or other source terms file by file.
- **Legal status:** institutional review required until the upstream status is recorded.

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

## Medusa/Hydra / Spana distribution layer

- **Official source:** <https://www.kth.se/che/medusa/downloads-1.386254>
- **Software source:** <https://www.kth.se/che/medusa/downloads-1.386254> and <https://sourceforge.net/projects/eq-diagr/>.
- **Software rights:** the eq-diagr software is distributed under GPLv3. This licence covers the software code, not automatically the thermodynamic databases that it reads or bundles.
- **Files actually ingested by logK25:** `Soltherm.txt` and `PHREEQC_ThermoddemV1.10_15Dec2020.txt` only. The binary/default Medusa databases present in the folder are not parsed by the current pipeline.
- **Attribution rule:** cite Medusa/Spana for the software or export layer, and cite the underlying database for the scientific content.

### SOLTHERM export

- **Underlying source:** SOLTHERM, maintained by the University of Oregon; the local references identify `soltherm.REE_working.xpt` v.65 dated 25 September 2018.
- **Official dataset record:** <https://catalog.data.gov/dataset/soltherm-thermodynamic-database-for-geochemical-modeling>.
- **Persistent identifier:** <https://doi.org/10.15121/1805737>.
- **Licence:** CC BY 4.0, as recorded in the official DOE/Data.gov metadata.
- **Redistribution status:** modification and redistribution permitted with attribution, a link to CC BY 4.0 and identification of the conversion and logK25 transformations.
- **Legal status:** documented.

### Thermoddem export carried by Medusa/Spana

- **Underlying source:** BRGM Thermoddem v1.10, not Medusa/KTH.
- **Rights treatment:** the site maps `Medusa-PHREEQC_ThermoddemV1.10_15Dec2020` to the Thermoddem rights record. The Medusa label describes only the export location.
- **Redistribution status:** identical to the Thermoddem entry below; institutional review remains required until the applicable BRGM licence is confirmed.

## NIST SRD 46

- **Version used:** Version 8.0.
- **Official source:** <https://data.nist.gov/pdr/lps/ark:/88434/mds2-2154>
- **Persistent identifier:** <https://doi.org/10.18434/M32154>
- **Use in logK25:** transformation of the SQL export into reaction-like rows with ligand and experimental metadata.
- **Rights:** the `SRD 46 README.txt` distributed with the SQL archive expressly permits users to improve, modify, create derivative works, copy and distribute those modifications worldwide on a royalty-free basis.
- **Official terms:** <https://data.nist.gov/od/ds/mds2-2154/SRD%2046%20README.txt>.
- **Redistribution status:** permitted with acknowledgement of NIST and a notice stating the date and nature of the changes.
- **Required citation:** Donald R. Burgess (2004), *NIST SRD 46. Critically Selected Stability Constants of Metal Complexes: Version 8.0 for Windows*, National Institute of Standards and Technology, <https://doi.org/10.18434/M32154>.
- **Modification notice:** logK25 must state that it transformed the data and identify the date and nature of the changes. It must not imply that the transformed compilation is an official NIST product.
- **Reliability warning:** the README states that the SQL archive was extracted from the Windows database by an outside group, that NIST cannot vouch for its reliability and that known structural errors exist.
- **Legal status:** documented permission for reuse and redistribution of the SQL-derived data, subject to acknowledgement and change notice.

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
2. Source-specific attribution, version and rights information must remain attached to every contribution and export. A software or file-format label must not replace the underlying dataset attribution.
3. A value's inclusion does not imply validation or endorsement by the Université de Lorraine, LRGP or the original provider.
4. Data marked `institutional review required` must not be presented as openly reusable without restriction.
5. Critical values must be checked against the cited original source.
6. The original logK25 code, the consolidated dataset and any redistributed third-party source files require separate licensing statements; documented source permissions must be preserved and unresolved sources must remain under review.
