const periodicAtoms = ["Ac","Ag","Al","Am","Ar","As","At","Au","B","Ba","Be","Bh","Bi","Bk","Br","C","Ca","Cd","Ce","Cf","Cl","Cm","Cn","Co","Cr","Cs","Cu","Db","Ds","Dy","Er","Es","Eu","F","Fe","Fl","Fm","Fr","Ga","Gd","Ge","H","He","Hf","Hg","Ho","Hs","I","In","Ir","K","Kr","La","Li","Lr","Lu","Lv","Mc","Md","Mg","Mn","Mo","Mt","N","Na","Nb","Nd","Ne","Nh","Ni","No","Np","O","Og","Os","P","Pa","Pb","Pd","Pm","Po","Pr","Pt","Pu","Ra","Rb","Re","Rf","Rg","Rh","Rn","Ru","S","Sb","Sc","Se","Sg","Si","Sm","Sn","Sr","Ta","Tb","Tc","Te","Th","Ti","Tl","Tm","Ts","U","V","W","Xe","Y","Yb","Zn","Zr"];

const periodicGrid = [
  ["H","","","","","","","","","","","","","","","","","He"],
  ["Li","Be","","","","","","","","","","","B","C","N","O","F","Ne"],
  ["Na","Mg","","","","","","","","","","","Al","Si","P","S","Cl","Ar"],
  ["K","Ca","Sc","Ti","V","Cr","Mn","Fe","Co","Ni","Cu","Zn","Ga","Ge","As","Se","Br","Kr"],
  ["Rb","Sr","Y","Zr","Nb","Mo","Tc","Ru","Rh","Pd","Ag","Cd","In","Sn","Sb","Te","I","Xe"],
  ["Cs","Ba","La","Hf","Ta","W","Re","Os","Ir","Pt","Au","Hg","Tl","Pb","Bi","Po","At","Rn"],
  ["Fr","Ra","Ac","Rf","Db","Sg","Bh","Hs","Mt","Ds","Rg","Cn","Nh","Fl","Mc","Lv","Ts","Og"],
  ["","","La","Ce","Pr","Nd","Pm","Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb","Lu",""],
  ["","","Ac","Th","Pa","U","Np","Pu","Am","Cm","Bk","Cf","Es","Fm","Md","No","Lr",""]
];

const periodicSet = new Set(periodicAtoms);

const periodic = document.getElementById("periodic");
const tbody = document.querySelector("#tbl tbody");
const headers = [...document.querySelectorAll("th[data-k]")];
const pageSizeSelect = document.getElementById("pageSize");
const eqFmtBtn = document.getElementById("eqFmtBtn");
const prevBtn = document.getElementById("prevBtn");
const nextBtn = document.getElementById("nextBtn");
const pageInfo = document.getElementById("pageInfo");
const prevBtnBottom = document.getElementById("prevBtnBottom");
const nextBtnBottom = document.getElementById("nextBtnBottom");
const pageInfoBottom = document.getElementById("pageInfoBottom");
const statusEl = document.getElementById("status");
const loadAllBtn = document.getElementById("loadAllBtn");
const exportCsvBtn = document.getElementById("exportCsvBtn");
const searchInput = document.getElementById("searchInput");
const dbPanel = document.querySelector(".db-panel");
const dbToggleBtn = document.getElementById("dbToggleBtn");
const dbFilters = document.getElementById("dbFilters");
const dbAllBtn = document.getElementById("dbAllBtn");
const dbNoneBtn = document.getElementById("dbNoneBtn");
const countVisible = document.getElementById("countVisible");
const countLoaded = document.getElementById("countLoaded");
const countTotal = document.getElementById("countTotal");

let manifest = null;
const selectedAtoms = new Set();
const loadedChunkKeys = new Set();
const loadedRows = [];
let filteredRows = [];
let sortKey = "p";
let sortAsc = true;
let page = 1;
let pageSize = Number(pageSizeSelect.value);
let loadAllMode = false;
let manifestLoaded = false;
let dataVersion = "";
let searchText = "";
let equationDisplayMode = "pretty"; // pretty | raw
const selectedSources = new Set();
const defaultPageSize = Number(pageSizeSelect.value);

function readUrlState() {
  const p = new URLSearchParams(window.location.search || "");
  const q = (p.get("q") || "").trim();
  const atomsRaw = (p.get("a") || "").trim();
  const srcRaw = (p.get("src") || "").trim();
  const loadAll = p.get("all") === "1";
  const psRaw = p.get("ps");
  const ps = Number(psRaw);
  const fmtRaw = (p.get("fmt") || "").trim().toLowerCase();
  return {
    q,
    atoms: atomsRaw ? atomsRaw.split(",").map(s => s.trim()).filter(Boolean) : [],
    sources: srcRaw ? srcRaw.split(",").map(s => s.trim()).filter(Boolean) : [],
    loadAll,
    pageSize: Number.isFinite(ps) && ps > 0 ? ps : null,
    fmt: (fmtRaw === "raw" || fmtRaw === "pretty") ? fmtRaw : null
  };
}

function writeUrlState() {
  const p = new URLSearchParams();
  if (searchText) p.set("q", searchText);
  if (selectedAtoms.size > 0) p.set("a", [...selectedAtoms].sort().join(","));
  if (loadAllMode) p.set("all", "1");
  if (pageSize !== defaultPageSize) p.set("ps", String(pageSize));
  if (equationDisplayMode === "raw") p.set("fmt", "raw");
  if (manifest && manifest.sources && selectedSources.size > 0 && selectedSources.size < manifest.sources.length) {
    p.set("src", [...selectedSources].sort().join(","));
  }
  const qs = p.toString();
  const next = qs ? `${window.location.pathname}?${qs}` : window.location.pathname;
  window.history.replaceState(null, "", next);
}

function setDbPanelCollapsed(collapsed) {
  if (!dbPanel || !dbToggleBtn) return;
  dbPanel.classList.toggle("collapsed", !!collapsed);
  dbToggleBtn.textContent = collapsed ? "Expand" : "Reduce";
}

function setStatus(msg) {
  statusEl.textContent = msg || "";
}

function toNum(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function formatAvgLogK(v) {
  const n = toNum(v);
  if (n === null) return String(v ?? "");
  return n.toFixed(2);
}

function formatExpConditions(v) {
  const s = String(v ?? "");
  const opens = (s.match(/\(/g) || []).length;
  const closes = (s.match(/\)/g) || []).length;
  if (opens > closes) return s + ")".repeat(opens - closes);
  return s;
}

function prettifySourceLabel(raw) {
  const s = String(raw ?? "").trim();
  if (!s) return s;

  const exact = {
    "AqSolDB-logS-data_curated": "AqSolDB",
    "JESS-PHREEQC-like-jess_phreeqc_like": "JESS",
    "GWB-THEREDA_2023a_GWB": "Thereda (GWB)",
    "GWB-thermo": "Thermo (GWB)",
    "GWB-thermo.com.V8.R6+": "Thermo.com V8 R6+ (GWB)",
    "GWB-thermo_cemdata": "Cemdata (GWB)"
  };
  if (Object.prototype.hasOwnProperty.call(exact, s)) return exact[s];

  if (s.startsWith("AqSolDB-logS-")) return "AqSolDB";
  if (s.startsWith("JESS-PHREEQC-like-")) return "JESS";
  if (s.startsWith("IUPAC-pKa-")) return "IUPAC pKa";
  if (s.startsWith("NIST-SRD46-")) return "NIST SRD46";
  if (s.startsWith("PSINagra-PHREEQC-")) return "PSI-Nagra (PHREEQC)";

  if (s.startsWith("Medusa-")) {
    const db = s.slice("Medusa-".length).replace(/[_\.]+/g, " ").trim();
    return db ? `${db} (Medusa)` : "Medusa";
  }

  if (s.startsWith("Thermoddem-")) {
    const tail = s.slice("Thermoddem-".length);
    const firstDash = tail.indexOf("-");
    const flavor = firstDash >= 0 ? tail.slice(0, firstDash) : tail;
    if (!flavor) return "Thermoddem";
    return `Thermoddem (${flavor})`;
  }

  if (s.startsWith("GWB-")) {
    const db = s.slice("GWB-".length);
    const gwbMap = {
      "thermo_coldchem": "Coldchem",
      "thermo_frezchem": "Frezchem",
      "thermo_hmw": "HMW",
      "thermo_minteq": "Minteq",
      "thermo_nea": "NEA",
      "thermo_phreeqc": "PHREEQC",
      "thermo_phrqpitz": "PHRQPITZ",
      "thermo_sit": "SIT",
      "thermo_wateq4f": "Wateq4f",
      "thermo_ymp.R2": "YMP R2"
    };
    if (Object.prototype.hasOwnProperty.call(gwbMap, db)) return `${gwbMap[db]} (GWB)`;
    return `${db.replace(/[_\.]+/g, " ").trim()} (GWB)`;
  }

  return s;
}

function formatContributingLogK(txt) {
  const srcRegex = /\(([^()]+)\)/g;
  return String(txt ?? "").replace(srcRegex, (_, src) => `(${prettifySourceLabel(src)})`);
}

function cmp(a, b, key) {
  if (key === "k") {
    const na = toNum(a.k);
    const nb = toNum(b.k);
    if (na !== null && nb !== null) return na - nb;
  }
  return String(a[key] || "").localeCompare(String(b[key] || ""), undefined, {
    numeric: true,
    sensitivity: "base"
  });
}

function rowHasAllAtoms(row, atoms) {
  if (!atoms || atoms.size === 0) return true;
  const s = new Set(row.a || []);
  for (const a of atoms) {
    if (!s.has(a)) return false;
  }
  return true;
}

function rowHasSelectedSources(row, sources) {
  if (!sources || sources.size === 0) return false;
  const rowSources = row.s || [];
  for (const s of rowSources) {
    if (sources.has(s)) return true;
  }
  return false;
}

function updateCounts() {
  if (countVisible) countVisible.textContent = String(filteredRows.length);
  if (countLoaded) countLoaded.textContent = String(loadedRows.length);
  if (countTotal) countTotal.textContent = manifest ? String(manifest.total_rows || 0) : "0";
}

function escHtml(v) {
  return String(v ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function formatCoeff(v) {
  const n = Number(v);
  return Number.isFinite(n) ? String(n) : String(v);
}

const SUB_DIGITS = { "0":"₀","1":"₁","2":"₂","3":"₃","4":"₄","5":"₅","6":"₆","7":"₇","8":"₈","9":"₉" };
const SUP_DIGITS = { "0":"⁰","1":"¹","2":"²","3":"³","4":"⁴","5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹" };
const SUP_SIGN = { "+":"⁺", "-":"⁻" };

function toSubDigits(s) {
  return String(s).replace(/\d/g, d => SUB_DIGITS[d] || d);
}

function toSupCharge(mag, sign) {
  let md = String(mag || "");
  const sg = String(sign || "");
  if (!sg) return "";
  if (md === "1") md = "";
  if (!md) return SUP_SIGN[sg] || sg;
  return md.replace(/\d/g, d => SUP_DIGITS[d] || d) + (SUP_SIGN[sg] || sg);
}

function extractTrailingChargeToken(s) {
  const txt = String(s ?? "").trim();
  let m = txt.match(/^(.*?)([+-])(\d+)$/);
  if (m) return { sign: m[2], mag: m[3] };
  m = txt.match(/^(.*?)(\d+)([+-])$/);
  if (m) return { sign: m[3], mag: m[2] };
  m = txt.match(/^(.*?)([+-])$/);
  if (m) return { sign: m[2], mag: "" };
  return null;
}

function hasTrailingChargeToken(s) {
  return !!extractTrailingChargeToken(s);
}

function applyGroupMultiplicityNotation(s) {
  let out = String(s ?? "");
  // Legacy pattern: X^(charge)(n)Y  -> [X^(charge)]_n Y
  // Example: Sn(CH3)2²⁺(2)OH⁻ -> [Sn(CH3)2²⁺]₂OH⁻
  out = out.replace(/(.+?[⁺⁻])\((\d+)\)(.*)/g, (_, grp, n, rest) => `[${grp}]${toSubDigits(n)}${rest}`);
  return out;
}

function formatSpeciesChemHtml(speciesRaw) {
  const raw = String(speciesRaw ?? "").trim();
  if (!raw) return "";

  const fmtOne = (partRaw) => {
    let part = partRaw.trim();
    if (!part) return "";
    // Remove inline formula annotations from display, and transfer charge when useful:
    // "Sn(Ox)3---- formula= Sn((COO)2)3-4" -> "Sn(Ox)34-" (then rendered as Sn(Ox)₃⁴⁻)
    const formulaAnn = part.match(/^(.*?)\s*-{2,}\s*formula\s*=\s*(.+)$/i);
    if (formulaAnn) {
      part = formulaAnn[1].trim();
      const ann = formulaAnn[2].trim();
      const annCharge = extractTrailingChargeToken(ann);
      if (annCharge && !hasTrailingChargeToken(part)) {
        part = `${part}${annCharge.mag || ""}${annCharge.sign}`;
      }
    }
    // Protect IUPAC locants like "1-,2,3,4-" (not ionic charges).
    part = part.replace(/(\d+)-(?=,)/g, "$1§§LOC_DASH§§");
    // Normalize slash-charge notation anywhere in the token:
    // HO/- -> HO-, Cl1/- -> Cl-, SO42/- -> SO42-
    part = part.replace(/([A-Za-z0-9\)\]])\s*(\d*)\s*\/\s*([+-])/g, (_, base, n, sgn) => {
      const mag = n && n !== "1" ? n : "";
      return `${base}${mag}${sgn}`;
    });
    // Legacy charge notation from some sources: Cl1/- -> Cl-, SO4 2/- -> SO4 2-
    part = part.replace(/(\d+)\s*\/\s*([+-])$/, (_, n, sgn) => (n === "1" ? sgn : `${n}${sgn}`));
    // Variant without explicit magnitude: HO/- -> HO-
    part = part.replace(/\/\s*([+-])$/, "$1");
    // Legacy multiplicity notation: H+1(2) -> (H+)2
    part = part.replace(/([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)([+-])1\((\d+)\)/g, "($1$2)$3");

    // Extract trailing charge first to avoid mixing it with formula indices.
    // Supported tails: +3, 3+, -, +, -2, 2-
    let core = part;
    let sign = "";
    let mag = "";
    let m = core.match(/^(.*?)([+-])(\d+)$/);
    if (m) {
      const candCore = m[1];
      const candSign = m[2];
      const digits = m[3];
      const upperCount = (candCore.match(/[A-Z]/g) || []).length;
      const hasComplexCore = /[\(\)\[\]]/.test(candCore) || /\d/.test(candCore);
      const coreEndsWithDigit = /\d$/.test(candCore);
      // Polyatomic legacy style like "NO-3" should read as NO3- (index 3, unit charge).
      // But cationic forms like "Et2Sn2+" should keep 2 as charge magnitude.
      if ((upperCount > 1 || hasComplexCore) && digits.length === 1 && !coreEndsWithDigit && candSign === "-") {
        core = `${candCore}${digits}`;
        sign = candSign;
        mag = "";
      } else {
        core = candCore;
        sign = candSign;
        mag = digits;
      }
    } else {
      m = core.match(/^(.*?)(\d+)([+-])$/);
      if (m) {
        const candCore = m[1];
        const digits = m[2];
        const candSign = m[3];
        const upperCount = (candCore.match(/[A-Z]/g) || []).length;
        const hasComplexCore = /[\(\)\[\]]/.test(candCore) || /\d/.test(candCore);
        // Heuristic:
        // - "Al3+" => Al^(3+) (single-element ion charge)
        // - "NO3-" => NO3^- (formula index + unit charge)
        // - "NdNO32+" => NdNO3^(2+)
        if ((upperCount > 1 || hasComplexCore) && digits.length > 1) {
          core = `${candCore}${digits.slice(0, -1)}`;
          mag = digits.slice(-1);
          sign = candSign;
        } else if (upperCount > 1 || hasComplexCore) {
          core = `${candCore}${digits}`;
          sign = candSign;
          mag = "";
        } else {
          core = candCore;
          mag = digits;
          sign = candSign;
        }
      } else {
        m = core.match(/^(.*?)([+-])$/);
        if (m) {
          core = m[1];
          sign = m[2];
          mag = "";
        }
      }
    }

    // Protect inline ion charges before subscript pass:
    // Ni2+, Fe3+, SO4-2, Cl-, etc.
    let coreProtected = core;
    coreProtected = coreProtected.replace(
      /([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)\+(\d+)(?=(?:\s|$|[\(\)\];:_]))/g,
      "$1§§+|$2§§"
    );
    coreProtected = coreProtected.replace(
      /([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)(\d+)\+(?=(?:\s|$|[\(\)\];:_]))/g,
      "$1§§+|$2§§"
    );
    coreProtected = coreProtected.replace(
      /([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)\+(?=(?:\s|$|[\)\];:_]))/g,
      "$1§§+|§§"
    );
    coreProtected = coreProtected.replace(
      /([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)-(\d+)(?=(?:\s|$|[\(\)\];:_]))/g,
      "$1§§-|$2§§"
    );
    coreProtected = coreProtected.replace(
      /\b([A-Z][a-z]?)(\d+)-(?=(?:\s|$|[\(\)\];:_]))/g,
      "$1§§-|$2§§"
    );
    coreProtected = coreProtected.replace(
      /([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)-(?=(?:\s|$|[\)\];:_]))/g,
      "$1§§-|§§"
    );

    let htmlCore = coreProtected;
    // Formula indices: H2O, (CH3)3, UO2; omit explicit index 1.
    htmlCore = htmlCore.replace(/([A-Za-z\)\]\}])(\d+)/g, (_, a, d) => {
      if (String(d) === "1") return `${a}`;
      return `${a}${toSubDigits(d)}`;
    });
    // Restore protected charges as Unicode superscripts.
    htmlCore = htmlCore.replace(/§§([+-])\|(\d+)§§/g, (_, sgn, d) => toSupCharge(d, sgn));
    htmlCore = htmlCore.replace(/§§([+-])\|§§/g, (_, sgn) => toSupCharge("", sgn));
    // Restore protected IUPAC locant dashes.
    htmlCore = htmlCore.replace(/§§LOC_DASH§§/g, "-");

    if (!sign) return escHtml(applyGroupMultiplicityNotation(htmlCore));
    return escHtml(applyGroupMultiplicityNotation(`${htmlCore}${toSupCharge(mag, sign)}`));
  };

  // Underscores are technical separators in some source notations; hide them in display.
  return raw.split("_").map(fmtOne).join("");
}

function formatEquationChemHtml(eqRaw) {
  const raw = String(eqRaw ?? "").replace(/\s+/g, " ").trim();
  if (!raw) return "";
  if (!raw.includes("=")) return formatSpeciesChemHtml(raw);

  const parseSide = (side) => {
    const sideNorm = String(side ?? "")
      // Strong normalization for split ionic charges in equation text:
      // "Al + 3 + -4 H2O" -> "Al+3 + -4 H2O"
      .replace(/\b([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)\s+\+\s+(\d+)\b/g, "$1+$2")
      .replace(/\b([A-Za-z][A-Za-z0-9\(\)\[\]\.]*)\s-\s(\d+)\b/g, "$1-$2")
      // Explicitly collapse ion charge written as "X + n" -> "X+n"
      // before splitting on " + " separators.
      .replace(/\b([A-Z][a-z]?[A-Za-z0-9\)\]\}]*)\s*\+\s*(\d+)(?=\s*(?:\+|$))/g, "$1+$2")
      .replace(/\b([A-Z][a-z]?[A-Za-z0-9\)\]\}]*)\s*-\s*(\d+)(?=\s*(?:\+|$))/g, "$1-$2")
      // Re-attach split charge notation before term splitting:
      // "Ca + 2" -> "Ca+2", "Fe 3 +" -> "Fe3+"
      .replace(/([A-Za-z0-9\)\]\}])\s*([+-])\s*(\d+)(?=\s*(?:\+|$))/g, "$1$2$3")
      .replace(/([A-Za-z0-9\)\]\}])\s*(\d+)\s*([+-])(?=\s*(?:\+|$))/g, "$1$2$3")
      .replace(/([A-Za-z0-9\)\]\}])\s*([+-])(?=\s*(?:\+|$))/g, "$1$2")
      // Some sources glue a separator and next coefficient: "...(s)+4 H+"
      .replace(/([^\s])\+([+-]?\d+(?:\.\d+)?)\s+/g, "$1 + $2 ");
    const rawTerms = sideNorm.split(/\s+\+\s+/).map(t => t.trim()).filter(Boolean);
    // Rebuild terms to avoid splitting ionic charges written as "Ca + 2", "Al + 3".
    const terms = [];
    for (let i = 0; i < rawTerms.length; i++) {
      const t = rawTerms[i];
      const next = i + 1 < rawTerms.length ? rawTerms[i + 1] : "";
      const coeffSpecies = t.match(/^([+-]?\d+(?:\.\d+)?)\s+([A-Za-z][A-Za-z0-9\(\)\[\]\.\-]*)$/);
      if (coeffSpecies && /^\d+$/.test(next)) {
        // "3 Ca + 2" -> "3 Ca+2"
        terms.push(`${coeffSpecies[1]} ${coeffSpecies[2]}+${next}`);
        i++;
        continue;
      }
      const looksLikeSpecies =
        /^[A-Za-z][A-Za-z0-9\(\)\[\]\.\-]*$/.test(t) ||
        /^[A-Za-z][A-Za-z0-9\(\)\[\]\.\-]*\s*\([^)]+\)$/.test(t);
      const looksLikeChargeMagnitude = /^\d+$/.test(next);
      if (looksLikeSpecies && looksLikeChargeMagnitude) {
        terms.push(`${t}+${next}`);
        i++;
      } else {
        terms.push(t);
      }
    }
    return terms.map((t) => {
      const m = t.match(/^([+-]?\d+(?:\.\d+)?)\s+(.+)$/);
      if (m) {
        const c = Number(m[1]);
        if (Number.isFinite(c)) return { coeff: c, species: m[2] };
      }
      return { coeff: 1, species: t };
    });
  };

  const fmtTerm = (term) => {
    const c = Number(term.coeff);
    const sp = formatSpeciesChemHtml(term.species);
    if (!Number.isFinite(c)) return sp;
    const a = Math.abs(c);
    if (Math.abs(a - 1) < 1.0e-12) return sp;
    return `${escHtml(formatCoeff(a))} ${sp}`;
  };

  const formatSideTerms = (arr) => {
    const out = arr
      .filter(t => Number.isFinite(Number(t.coeff)) && Math.abs(Number(t.coeff)) > 1.0e-12)
      .map(fmtTerm);
    return out.length > 0 ? out.join(" + ") : "0";
  };

  const parts = raw.split("=");
  if (parts.length !== 2) return formatSpeciesChemHtml(raw);
  const lhs = parseSide(parts[0].trim());
  const rhs = parseSide(parts[1].trim());

  const lhsOut = [];
  const rhsOut = [];
  for (const t of lhs) {
    const c = Number(t.coeff);
    if (Number.isFinite(c) && c < 0) rhsOut.push({ coeff: -c, species: t.species });
    else lhsOut.push(t);
  }
  for (const t of rhs) {
    const c = Number(t.coeff);
    if (Number.isFinite(c) && c < 0) lhsOut.push({ coeff: -c, species: t.species });
    else rhsOut.push(t);
  }

  return `${formatSideTerms(lhsOut)} = ${formatSideTerms(rhsOut)}`;
}

function renderTable() {
  const totalPages = Math.max(1, Math.ceil(filteredRows.length / pageSize));
  if (page > totalPages) page = totalPages;
  const start = (page - 1) * pageSize;
  const end = Math.min(filteredRows.length, start + pageSize);
  const rows = filteredRows.slice(start, end);

  tbody.innerHTML = rows.map((r, idx) => `
    <tr>
      <td class="mono">${start + idx + 1}</td>
      <td class="mono hidden-col">${escHtml(r.p)}</td>
      <td class="mono hidden-col">${escHtml(r.h || "")}</td>
      <td class="mono chem-eq">${equationDisplayMode === "raw" ? escHtml(String(r.e ?? "")) : formatEquationChemHtml(r.e)}</td>
      <td class="mono">${escHtml(formatAvgLogK(r.k))}</td>
      <td class="mono">${escHtml(formatContributingLogK(r.c))}</td>
      <td>${escHtml(formatExpConditions(r.x))}</td>
      <td>${escHtml(r.m)}</td>
      <td class="hidden-col">${escHtml(r.rf)}</td>
    </tr>
  `).join("");

  const pageText = `Page ${page}/${totalPages}`;
  pageInfo.textContent = pageText;
  if (pageInfoBottom) pageInfoBottom.textContent = pageText;
  prevBtn.disabled = page <= 1;
  nextBtn.disabled = page >= totalPages;
  if (prevBtnBottom) prevBtnBottom.disabled = page <= 1;
  if (nextBtnBottom) nextBtnBottom.disabled = page >= totalPages;
  updateCounts();
}

function applyFilterSortAndRender() {
  filteredRows = loadedRows.filter(r => {
    if (!rowHasAllAtoms(r, selectedAtoms)) return false;
    if (!rowHasSelectedSources(r, selectedSources)) return false;
    if (!searchText) return true;
    const blob = [r.p, r.h, r.e, r.k, r.c, r.x, r.rf].join(" ").toLowerCase();
    return blob.includes(searchText);
  });
  filteredRows.sort((a, b) => (sortAsc ? cmp(a, b, sortKey) : -cmp(a, b, sortKey)));
  renderTable();
}

function escapeCsvField(v) {
  const s = String(v ?? "");
  if (s.includes(",") || s.includes("\"") || s.includes("\n") || s.includes("\r")) {
    return `"${s.replace(/"/g, "\"\"")}"`;
  }
  return s;
}

function exportCurrentViewCsv() {
  if (!filteredRows || filteredRows.length === 0) {
    setStatus("No rows to export.");
    return;
  }
  const headers = ["Product", "Hill formulas", "Equation", "Average logK", "logK", "Exp. conditions", "Database comments", "Reference (consolidated)"];
  const lines = [headers.map(escapeCsvField).join(",")];
  for (const r of filteredRows) {
    const row = [r.p, r.h, r.e, r.k, r.c, r.x, r.m, r.rf].map(escapeCsvField).join(",");
    lines.push(row);
  }
  const csv = lines.join("\r\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  a.href = url;
  a.download = `logK25_current_view_${stamp}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  setStatus(`Exported ${filteredRows.length} row(s) to CSV.`);
}

async function fetchJson(path) {
  const sep = path.includes("?") ? "&" : "?";
  const fullPath = dataVersion ? `${path}${sep}v=${encodeURIComponent(dataVersion)}` : path;
  const res = await fetch(fullPath, { cache: "no-store" });
  if (!res.ok) throw new Error(`HTTP ${res.status} on ${path}`);
  const txt = await res.text();
  try {
    return JSON.parse(txt);
  } catch (e) {
    throw new Error(`Invalid JSON in ${path}: ${e.message}`);
  }
}

async function loadChunks(chunkKeys) {
  const wanted = chunkKeys.filter(k => !loadedChunkKeys.has(k));
  if (wanted.length === 0) return;

  const byKey = new Map((manifest.chunks || []).map(c => [c.key, c.file]));
  const batchSize = 8;
  let done = 0;
  for (let i = 0; i < wanted.length; i += batchSize) {
    const batch = wanted.slice(i, i + batchSize);
    setStatus(`Loading chunks ${done + 1}-${Math.min(done + batch.length, wanted.length)} / ${wanted.length}...`);
    const payloads = await Promise.all(batch.map(async key => {
      const file = byKey.get(key);
      if (!file) return [];
      try {
        return await fetchJson(`./data/chunks/${file}`);
      } catch (e) {
        setStatus(`Skipped one bad chunk (${file}). ${e.message}`);
        return [];
      }
    }));
    for (let j = 0; j < batch.length; j++) {
      const key = batch[j];
      const rows = payloads[j] || [];
      rows.forEach(r => loadedRows.push(r));
      loadedChunkKeys.add(key);
    }
    done += batch.length;
    // Give user immediate feedback during long loads.
    applyFilterSortAndRender();
    await new Promise(resolve => setTimeout(resolve, 0));
  }
  setStatus(`Loaded ${wanted.length} new chunk(s).`);
}

function getCandidateChunkKeys() {
  if (!manifest) return [];
  if (selectedSources.size === 0) return [];

  const bySource = new Set();
  for (const s of selectedSources) {
    const arr = (manifest.source_to_chunks && manifest.source_to_chunks[s]) ? manifest.source_to_chunks[s] : [];
    arr.forEach(k => bySource.add(k));
  }

  if (loadAllMode) return [...bySource];
  if (selectedAtoms.size === 0) return [];

  const byAtom = new Set();
  for (const a of selectedAtoms) {
    const arr = (manifest.atom_to_chunks && manifest.atom_to_chunks[a]) ? manifest.atom_to_chunks[a] : [];
    arr.forEach(k => byAtom.add(k));
  }

  return [...byAtom].filter(k => bySource.has(k));
}

async function refreshDataFromSelection() {
  try {
    const candidate = getCandidateChunkKeys();
    if (candidate.length === 0) {
      filteredRows = [];
      renderTable();
      if (selectedSources.size === 0) {
        setStatus("Select at least one database to include.");
      } else if (selectedAtoms.size === 0) {
        setStatus("Select atoms (fast cached mode) or click Load All Data for the full dataset.");
      } else {
        setStatus("No data for selected atom combination.");
      }
      return;
    }
    await loadChunks(candidate);
    setStatus("");
    page = 1;
    applyFilterSortAndRender();
  } catch (err) {
    setStatus(`Load error: ${err.message}`);
  }
}

function buildDatabaseFilters() {
  if (!dbFilters || !manifest) return;
  dbFilters.innerHTML = "";
  const sources = manifest.sources || [];
  for (const src of sources) {
    const id = `db_${src.replace(/[^a-zA-Z0-9_-]/g, "_")}`;
    const label = document.createElement("label");
    label.className = "db-item";
    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.id = id;
    cb.checked = true;
    cb.dataset.source = src;
    selectedSources.add(src);
    cb.addEventListener("change", async () => {
      if (cb.checked) selectedSources.add(src);
      else selectedSources.delete(src);
      page = 1;
      writeUrlState();
      await refreshDataFromSelection();
    });
    const text = document.createElement("span");
    const cnt = manifest && manifest.source_count ? Number(manifest.source_count[src] || 0) : 0;
    text.textContent = cnt > 0 ? `${prettifySourceLabel(src)} (${cnt})` : prettifySourceLabel(src);
    text.title = src;
    label.appendChild(cb);
    label.appendChild(text);
    dbFilters.appendChild(label);
  }
}

function buildPeriodic() {
  periodic.innerHTML = "";
  const isMobile = window.matchMedia("(max-width: 768px)").matches;

  const addAtomButton = (sym) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "el-btn";
    if (selectedAtoms.has(sym)) b.classList.add("sel");
    b.textContent = sym;
    b.dataset.atom = sym;
    b.addEventListener("click", async () => {
      if (selectedAtoms.has(sym)) {
        selectedAtoms.delete(sym);
        b.classList.remove("sel");
      } else {
        selectedAtoms.add(sym);
        b.classList.add("sel");
      }
      loadAllMode = false;
      writeUrlState();
      await refreshDataFromSelection();
    });
    periodic.appendChild(b);
  };

  if (isMobile) {
    const sorted = [...periodicAtoms].sort((a, b) => a.localeCompare(b));
    sorted.forEach(addAtomButton);
    return;
  }

  periodicGrid.forEach(row => {
    row.forEach(sym => {
      if (!sym || !periodicSet.has(sym)) {
        const sp = document.createElement("div");
        sp.className = "periodic-spacer";
        periodic.appendChild(sp);
        return;
      }
      addAtomButton(sym);
    });
  });
}

function bindEvents() {
  headers.forEach(h => h.addEventListener("click", () => {
    const k = h.getAttribute("data-k");
    if (sortKey === k) sortAsc = !sortAsc;
    else { sortKey = k; sortAsc = true; }
    applyFilterSortAndRender();
  }));

  pageSizeSelect.addEventListener("change", () => {
    pageSize = Number(pageSizeSelect.value);
    page = 1;
    writeUrlState();
    renderTable();
  });

  if (eqFmtBtn) {
    eqFmtBtn.addEventListener("click", () => {
      equationDisplayMode = equationDisplayMode === "pretty" ? "raw" : "pretty";
      eqFmtBtn.textContent = `Equation: ${equationDisplayMode === "pretty" ? "Pretty" : "Raw"}`;
      writeUrlState();
      renderTable();
    });
  }

  prevBtn.addEventListener("click", () => {
    if (page > 1) {
      page--;
      renderTable();
    }
  });
  if (prevBtnBottom) {
    prevBtnBottom.addEventListener("click", () => {
      if (page > 1) {
        page--;
        renderTable();
      }
    });
  }

  nextBtn.addEventListener("click", () => {
    const totalPages = Math.max(1, Math.ceil(filteredRows.length / pageSize));
    if (page < totalPages) {
      page++;
      renderTable();
    }
  });
  if (nextBtnBottom) {
    nextBtnBottom.addEventListener("click", () => {
      const totalPages = Math.max(1, Math.ceil(filteredRows.length / pageSize));
      if (page < totalPages) {
        page++;
        renderTable();
      }
    });
  }

  loadAllBtn.addEventListener("click", async () => {
    if (!manifestLoaded) {
      setStatus("Manifest not loaded. Serve via HTTP or GitHub Pages.");
      return;
    }
    loadAllMode = true;
    writeUrlState();
    setStatus("Loading all data chunks...");
    await refreshDataFromSelection();
  });

  exportCsvBtn.addEventListener("click", () => {
    exportCurrentViewCsv();
  });

  if (searchInput) {
    searchInput.addEventListener("input", () => {
      searchText = (searchInput.value || "").trim().toLowerCase();
      page = 1;
      writeUrlState();
      applyFilterSortAndRender();
    });
  }

  if (dbAllBtn) {
    dbAllBtn.addEventListener("click", async () => {
      selectedSources.clear();
      document.querySelectorAll("#dbFilters input[type='checkbox']").forEach(el => {
        el.checked = true;
        selectedSources.add(el.dataset.source);
      });
      page = 1;
      writeUrlState();
      await refreshDataFromSelection();
    });
  }

  if (dbNoneBtn) {
    dbNoneBtn.addEventListener("click", async () => {
      selectedSources.clear();
      document.querySelectorAll("#dbFilters input[type='checkbox']").forEach(el => {
        el.checked = false;
      });
      page = 1;
      writeUrlState();
      await refreshDataFromSelection();
    });
  }

  if (dbToggleBtn) {
    dbToggleBtn.addEventListener("click", () => {
      const next = !dbPanel.classList.contains("collapsed");
      setDbPanelCollapsed(next);
      try {
        localStorage.setItem("dbPanelCollapsed", next ? "1" : "0");
      } catch (_) { /* ignore storage errors */ }
    });
  }
}

async function init() {
  const urlState = readUrlState();
  buildPeriodic();
  bindEvents();
  try {
    const saved = localStorage.getItem("dbPanelCollapsed");
    setDbPanelCollapsed(saved === null ? true : saved === "1");
  } catch (_) {
    setDbPanelCollapsed(true);
  }
  try {
    manifest = await fetchJson("./data/manifest.json");
    manifestLoaded = true;
    dataVersion = manifest.generated_at || "";
    countTotal.textContent = String(manifest.total_rows || 0);
    buildDatabaseFilters();

    if (urlState.pageSize) {
      const allowed = [...pageSizeSelect.options].map(o => Number(o.value));
      if (allowed.includes(urlState.pageSize)) {
        pageSizeSelect.value = String(urlState.pageSize);
        pageSize = urlState.pageSize;
      }
    }
    if (urlState.fmt) {
      equationDisplayMode = urlState.fmt;
    }
    if (eqFmtBtn) {
      eqFmtBtn.textContent = `Equation: ${equationDisplayMode === "pretty" ? "Pretty" : "Raw"}`;
    }
    if (urlState.q && searchInput) {
      searchInput.value = urlState.q;
      searchText = urlState.q.toLowerCase();
    }
    if (urlState.sources.length > 0) {
      selectedSources.clear();
      document.querySelectorAll("#dbFilters input[type='checkbox']").forEach(el => {
        const keep = urlState.sources.includes(el.dataset.source);
        el.checked = keep;
        if (keep) selectedSources.add(el.dataset.source);
      });
    }
    if (urlState.atoms.length > 0) {
      urlState.atoms.forEach(a => selectedAtoms.add(a));
      document.querySelectorAll("#periodic .el-btn").forEach(btn => {
        if (selectedAtoms.has(btn.dataset.atom)) btn.classList.add("sel");
      });
    }
    loadAllMode = urlState.loadAll || (!!searchText && selectedAtoms.size === 0);

    writeUrlState();
    setStatus("Ready. Select atoms (fast cached mode) or click Load All Data for the full dataset.");
    filteredRows = [];
    renderTable();
    if (loadAllMode || selectedAtoms.size > 0) {
      await refreshDataFromSelection();
    }
  } catch (err) {
    if (window.location.protocol === "file:") {
      setStatus("Cannot load data via file://. Use GitHub Pages or run a local HTTP server.");
    } else {
      setStatus(`Failed to load manifest: ${err.message}`);
    }
  }
}

init();
