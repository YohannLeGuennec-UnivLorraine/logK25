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
  return {
    q,
    atoms: atomsRaw ? atomsRaw.split(",").map(s => s.trim()).filter(Boolean) : [],
    sources: srcRaw ? srcRaw.split(",").map(s => s.trim()).filter(Boolean) : [],
    loadAll,
    pageSize: Number.isFinite(ps) && ps > 0 ? ps : null
  };
}

function writeUrlState() {
  const p = new URLSearchParams();
  if (searchText) p.set("q", searchText);
  if (selectedAtoms.size > 0) p.set("a", [...selectedAtoms].sort().join(","));
  if (loadAllMode) p.set("all", "1");
  if (pageSize !== defaultPageSize) p.set("ps", String(pageSize));
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
      <td class="mono">${escHtml(r.e)}</td>
      <td class="mono">${escHtml(r.k)}</td>
      <td class="mono">${escHtml(r.c)}</td>
      <td>${escHtml(r.x)}</td>
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
    const blob = [r.p, r.h, r.e, r.k, r.c, r.x, r.m, r.rf].join(" ").toLowerCase();
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
    text.textContent = src;
    label.appendChild(cb);
    label.appendChild(text);
    dbFilters.appendChild(label);
  }
}

function buildPeriodic() {
  periodicGrid.forEach(row => {
    row.forEach(sym => {
      if (!sym) {
        const sp = document.createElement("div");
        sp.className = "periodic-spacer";
        periodic.appendChild(sp);
        return;
      }
      if (!periodicSet.has(sym)) {
        const sp = document.createElement("div");
        sp.className = "periodic-spacer";
        periodic.appendChild(sp);
        return;
      }
      const b = document.createElement("button");
      b.type = "button";
      b.className = "el-btn";
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
