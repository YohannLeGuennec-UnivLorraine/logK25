function statusClass(status) {
  if (status === "documented") return "documented";
  if (status === "documented_noncommercial" || status === "custom_permission") return "conditional";
  return "review-required";
}

function statusLabel(status) {
  if (status === "documented") return "Documented";
  if (status === "documented_noncommercial") return "Non-commercial conditions";
  if (status === "custom_permission") return "Custom permission";
  return "Institutional review required";
}

function addText(parent, label, value, className = "") {
  if (value === null || value === undefined || value === "") return;
  const p = document.createElement("p");
  if (className) p.className = className;
  const strong = document.createElement("strong");
  strong.textContent = `${label}: `;
  p.appendChild(strong);
  p.appendChild(document.createTextNode(String(value)));
  parent.appendChild(p);
}

async function initSourcesPage() {
  const status = document.getElementById("legalStatus");
  const grid = document.getElementById("legalGrid");
  const reviewedAt = document.getElementById("reviewedAt");
  try {
    const response = await fetch("./data/sources.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const registry = await response.json();
    reviewedAt.textContent = registry.reviewed_at || "unknown";
    status.textContent = registry.notice || "Source-specific conditions apply.";

    for (const source of registry.sources || []) {
      const card = document.createElement("article");
      card.className = "legal-card";
      const title = document.createElement("h2");
      title.textContent = source.display_name;
      card.appendChild(title);

      const badge = document.createElement("span");
      badge.className = `source-rights-badge ${statusClass(source.legal_status)}`;
      badge.textContent = statusLabel(source.legal_status);
      card.appendChild(badge);

      addText(card, "Version", source.version, "legal-meta");
      addText(card, "Known conditions", source.license_label);
      addText(card, "Reuse", source.reuse_summary);
      addText(card, "Attribution", source.attribution);

      const links = document.createElement("p");
      links.className = "legal-meta";
      const sourceLink = document.createElement("a");
      sourceLink.href = source.source_url;
      sourceLink.target = "_blank";
      sourceLink.rel = "noopener noreferrer";
      sourceLink.textContent = "Official source";
      links.appendChild(sourceLink);
      if (source.license_url) {
        links.appendChild(document.createTextNode(" · "));
        const licenceLink = document.createElement("a");
        licenceLink.href = source.license_url;
        licenceLink.target = "_blank";
        licenceLink.rel = "noopener noreferrer";
        licenceLink.textContent = "Licence or terms";
        links.appendChild(licenceLink);
      }
      card.appendChild(links);
      grid.appendChild(card);
    }
  } catch (error) {
    status.textContent = `Unable to load the source register: ${error.message}`;
  }
}

initSourcesPage();
