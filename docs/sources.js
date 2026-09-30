function statusClass(status) {
  if (status === "documented") return "documented";
  if (status === "documented_noncommercial" || status === "custom_permission" || status === "source_notice") return "conditional";
  return "review-required";
}

function statusLabel(status) {
  if (status === "documented") return "Documented";
  if (status === "documented_noncommercial") return "Non-commercial conditions";
  if (status === "custom_permission") return "Custom permission";
  if (status === "source_notice") return "Source-specific notice";
  if (status === "documented_restricted") return "Documented restriction";
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

function addAuthors(parent, authors) {
  if (!Array.isArray(authors) || authors.length === 0) return;
  addText(parent, "Authors / responsible organisations", authors.join("; "));
}

function addReferences(parent, references) {
  if (!Array.isArray(references) || references.length === 0) return;

  const heading = document.createElement("h3");
  heading.className = "legal-references-title";
  heading.textContent = "Reference publications";
  parent.appendChild(heading);

  const list = document.createElement("ul");
  list.className = "legal-references";
  for (const reference of references) {
    if (!reference || !reference.citation) continue;
    const item = document.createElement("li");
    if (reference.scope) {
      const scope = document.createElement("strong");
      scope.textContent = `${reference.scope}: `;
      item.appendChild(scope);
    }
    if (reference.url) {
      const link = document.createElement("a");
      link.href = reference.url;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = reference.citation;
      item.appendChild(link);
    } else {
      item.appendChild(document.createTextNode(reference.citation));
    }
    list.appendChild(item);
  }
  if (list.childElementCount > 0) parent.appendChild(list);
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
      addAuthors(card, source.authors);
      addText(card, "Known conditions", source.license_label);
      addText(card, "Reuse", source.reuse_summary);
      addText(card, "Attribution", source.attribution);
      addText(card, "Scope", source.scope_note, "legal-scope");
      addReferences(card, source.reference_publications);

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
