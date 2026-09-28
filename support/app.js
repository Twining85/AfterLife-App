const state = {
  token: sessionStorage.getItem("supportToken"),
  environment: sessionStorage.getItem("supportEnvironment"),
  currentAccount: null
};

const elements = {
  loginView: document.querySelector("#login-view"),
  appView: document.querySelector("#app-view"),
  loginForm: document.querySelector("#login-form"),
  loginError: document.querySelector("#login-error"),
  logoutButton: document.querySelector("#logout-button"),
  environmentBadge: document.querySelector("#environment-badge"),
  searchNav: document.querySelector("#search-nav"),
  monitoringNav: document.querySelector("#monitoring-nav"),
  searchView: document.querySelector("#search-view"),
  monitoringView: document.querySelector("#monitoring-view"),
  monitoringRefresh: document.querySelector("#monitoring-refresh"),
  monitoringUpdated: document.querySelector("#monitoring-updated"),
  monitoringError: document.querySelector("#monitoring-error"),
  serviceStatus: document.querySelector("#service-status"),
  monitoringMetrics: document.querySelector("#monitoring-metrics"),
  accountCount: document.querySelector("#account-count"),
  accountCountValue: document.querySelector("#account-count-value"),
  searchForm: document.querySelector("#search-form"),
  searchEmail: document.querySelector("#search-email"),
  includeDetails: document.querySelector("#include-details"),
  detailsOption: document.querySelector("#details-option"),
  notice: document.querySelector("#notice"),
  emptyState: document.querySelector("#empty-state"),
  result: document.querySelector("#result"),
  deleteDialog: document.querySelector("#delete-dialog"),
  deleteForm: document.querySelector("#delete-form"),
  deleteEmail: document.querySelector("#delete-email"),
  deleteConfirmation: document.querySelector("#delete-confirmation"),
  deleteError: document.querySelector("#delete-error"),
  deleteCancel: document.querySelector("#delete-cancel"),
  deleteSubmit: document.querySelector("#delete-submit")
};

elements.loginForm.addEventListener("submit", login);
elements.searchForm.addEventListener("submit", search);
elements.logoutButton.addEventListener("click", logout);
elements.deleteForm.addEventListener("submit", deleteAccount);
elements.deleteCancel.addEventListener("click", closeDeleteDialog);
elements.searchNav.addEventListener("click", () => showView("search"));
elements.monitoringNav.addEventListener("click", () => showView("monitoring"));
elements.monitoringRefresh.addEventListener("click", loadMonitoring);
showAuthenticated(Boolean(state.token));

async function login(event) {
  event.preventDefault();
  const submit = elements.loginForm.querySelector("button[type=submit]");
  setBusy(submit, true, "Anmelden");
  elements.loginError.hidden = true;
  try {
    const form = new FormData(elements.loginForm);
    const response = await request("/api/admin/login", {
      email: form.get("email"),
      password: form.get("password")
    }, false);
    state.token = response.sessionToken;
    state.environment = response.environment;
    sessionStorage.setItem("supportToken", state.token);
    sessionStorage.setItem("supportEnvironment", state.environment);
    elements.loginForm.reset();
    showAuthenticated(true);
  } catch (error) {
    elements.loginError.textContent = error.message;
    elements.loginError.hidden = false;
  } finally {
    setBusy(submit, false, "Anmelden");
  }
}

async function search(event) {
  event.preventDefault();
  const submit = elements.searchForm.querySelector("button[type=submit]");
  setBusy(submit, true, "Suchen");
  hideNotice();
  try {
    const response = await request("/api/admin/users/lookup", {
      email: elements.searchEmail.value,
      includeDetails: elements.includeDetails.checked
    });
    setEnvironment(response.environment);
    elements.detailsOption.hidden = !response.capabilities.devDetails;
    if (!response.found) {
      elements.result.hidden = true;
      elements.emptyState.hidden = true;
      showNotice("Zu dieser E-Mail-Adresse wurde kein Konto gefunden.");
      return;
    }
    renderResult(response);
  } catch (error) {
    if (error.status === 401) {
      logout();
      elements.loginError.textContent = "Die Sitzung ist abgelaufen. Bitte melde dich erneut an.";
      elements.loginError.hidden = false;
    } else {
      showNotice(error.message, true);
    }
  } finally {
    setBusy(submit, false, "Suchen");
  }
}

function renderResult(data) {
  const account = data.account;
  state.currentAccount = account;
  elements.emptyState.hidden = true;
  elements.result.hidden = false;
  elements.result.replaceChildren();

  const summary = node("section", "account-summary");
  summary.append(
    summaryItem("Konto", account.email),
    summaryItem("Status", statusText(account.active ? "Aktiv" : "Deaktiviert", account.active ? "good" : "bad"), true),
    summaryItem("E-Mail", statusText(account.verified ? "Bestätigt" : "Nicht bestätigt", account.verified ? "good" : "warn"), true),
    summaryItem("Registriert", formatDate(account.createdAt))
  );
  elements.result.append(summary);

  if (data.dossiers.length === 0) {
    const noDossier = node("div", "notice");
    noDossier.textContent = "Für dieses Konto ist kein Dossier vorhanden.";
    elements.result.append(noDossier);
  }
  data.dossiers.forEach((dossier, index) => elements.result.append(renderDossier(dossier, index)));

  const actions = node("section", "safe-actions");
  const actionCopy = node("div");
  const protectedAccount = account.admin || !data.capabilities.accountDeletion;
  const actionText = account.admin
    ? "Administratorkonten sind vor der Löschung über die Supportwebsite geschützt."
    : "Entfernt den Account und alle zugehörigen Cloud- und Dossierdaten endgültig.";
  actionCopy.append(node("h3", "", "Kontolöschung"), node("p", "", actionText));
  const deleteButton = node("button", protectedAccount ? "disabled-button" : "danger-button", account.admin ? "Admin geschützt" : "Konto löschen");
  deleteButton.type = "button";
  deleteButton.disabled = protectedAccount;
  if (!protectedAccount) deleteButton.addEventListener("click", openDeleteDialog);
  actions.append(actionCopy, deleteButton);
  elements.result.append(actions);
}

function openDeleteDialog() {
  if (!state.currentAccount || state.currentAccount.admin) return;
  elements.deleteEmail.textContent = state.currentAccount.email;
  elements.deleteConfirmation.value = "";
  elements.deleteError.hidden = true;
  elements.deleteDialog.showModal();
  elements.deleteConfirmation.focus();
}

function closeDeleteDialog() {
  if (!elements.deleteSubmit.disabled) elements.deleteDialog.close();
}

async function deleteAccount(event) {
  event.preventDefault();
  if (!state.currentAccount || state.currentAccount.admin) return;
  elements.deleteError.hidden = true;
  setBusy(elements.deleteSubmit, true, "Endgültig löschen");
  elements.deleteCancel.disabled = true;
  try {
    await request("/api/admin/users/delete", {
      userID: state.currentAccount.id,
      email: state.currentAccount.email,
      confirmation: elements.deleteConfirmation.value
    });
    const deletedEmail = state.currentAccount.email;
    state.currentAccount = null;
    elements.deleteDialog.close();
    elements.result.hidden = true;
    elements.result.replaceChildren();
    elements.emptyState.hidden = false;
    elements.searchForm.reset();
    showNotice(`Das Konto ${deletedEmail} und sämtliche zugehörigen Daten wurden vollständig gelöscht.`);
  } catch (error) {
    elements.deleteError.textContent = error.message;
    elements.deleteError.hidden = false;
  } finally {
    elements.deleteCancel.disabled = false;
    setBusy(elements.deleteSubmit, false, "Endgültig löschen");
  }
}

function renderDossier(dossier, index) {
  const band = node("section", "dossier-band");
  const header = node("header", "dossier-header");
  const title = node("div");
  title.append(node("h2", "", `Dossier ${index + 1}`), node("p", "eyebrow", dossier.primary ? "Hauptdossier" : "Weiteres Dossier"));
  const meta = node("div", "dossier-meta");
  meta.append(
    statusText(dossier.active ? "Aktiv" : "Inaktiv", dossier.active ? "good" : "warn"),
    statusText(dossier.released ? "Freigegeben" : "Nicht freigegeben", dossier.released ? "warn" : "good")
  );
  header.append(title, meta);
  band.append(header, node("div", "section-title", "Dossierbereiche"));

  const table = node("table", "section-table");
  const thead = document.createElement("thead");
  const headingRow = document.createElement("tr");
  ["Bereich", "Status", "Letzte Änderung"].forEach((label) => headingRow.append(node("th", "", label)));
  thead.append(headingRow);
  const tbody = document.createElement("tbody");
  dossier.sections.forEach((section) => tbody.append(renderSection(section)));
  table.append(thead, tbody);
  band.append(table);

  band.append(node("div", "section-title", "Abos"), renderSubscription(dossier.subscription, index));

  band.append(node("div", "section-title", `Vertrauenspersonen (${dossier.trustedPeople.length})`));
  const trustGrid = node("div", "trust-grid");
  if (dossier.trustedPeople.length === 0) {
    trustGrid.append(node("p", "", "Keine Einladung oder Vertrauensperson hinterlegt."));
  } else {
    dossier.trustedPeople.forEach((person, personIndex) => {
      const item = node("article", "trust-item");
      const title = person.name || person.email || `Vertrauensperson ${personIndex + 1}`;
      const subtitle = [person.name ? person.email : null, person.relationship].filter(Boolean).join(" · ");
      item.append(node("h3", "", title));
      if (subtitle) item.append(node("p", "trust-identity", subtitle));
      const facts = node("dl", "trust-facts");
      appendFact(facts, "Hinterlegt", person.configured ? "Ja" : "Nein");
      appendFact(facts, "Primär", person.primary ? "Ja" : "Nein");
      appendFact(facts, "Einladung", invitationLabel(person.status));
      appendFact(facts, "Zugriff", person.accessActive ? "Aktiv" : "Nicht aktiv");
      if (person.requestedAt) appendFact(facts, "Angefragt", formatDate(person.requestedAt));
      if (person.decidedAt) appendFact(facts, "Entschieden", formatDate(person.decidedAt));
      if (person.expiresAt) appendFact(facts, "Einladung gültig bis", formatDate(person.expiresAt));
      if (person.accessReleaseAt && !person.accessActive) appendFact(facts, "Freigabe geplant", formatDate(person.accessReleaseAt));
      if (person.autoReleasedAt) appendFact(facts, "Automatisch freigegeben", formatDate(person.autoReleasedAt));
      item.append(facts);
      const privacy = person.email
        ? "Personendaten sind nur in DEV sichtbar."
        : person.hasEmail || person.hasName
          ? "Name und E-Mail sind in dieser Umgebung ausgeblendet."
          : "Keine Kontaktdaten hinterlegt.";
      item.append(node("p", "trust-privacy", privacy));
      trustGrid.append(item);
    });
  }
  band.append(trustGrid);
  return band;
}

function renderSubscription(subscription = {}, dossierIndex = 0) {
  const panel = node("section", "subscription-panel");
  const summary = node("dl", "subscription-summary");
  appendFact(summary, "Aktuelles Abo", subscription.plan || "Noch nicht angebunden");
  appendFact(summary, "Status", subscriptionStatusLabel(subscription.status));
  appendFact(summary, "Gültig bis", formatDate(subscription.validUntil));
  appendFact(summary, "Promocode", subscription.promoCode || "Keiner hinterlegt");

  const promo = node("div", "promo-control");
  const label = node("label", "", "Promocode");
  const inputID = `promo-code-${dossierIndex}`;
  label.htmlFor = inputID;
  const input = document.createElement("input");
  input.id = inputID;
  input.type = "text";
  input.placeholder = "Promocode eingeben";
  input.autocomplete = "off";
  input.disabled = !subscription.promoRedemptionAvailable;
  const button = node("button", subscription.promoRedemptionAvailable ? "primary-button" : "disabled-button", "Einlösen");
  button.type = "button";
  button.disabled = !subscription.promoRedemptionAvailable;
  promo.append(label, input, button);
  panel.append(summary, promo);
  return panel;
}

function renderSection(section) {
  const fragment = document.createDocumentFragment();
  const row = document.createElement("tr");
  const nameCell = document.createElement("td");
  const name = node("div", "section-name", section.label);
  name.append(node("small", "", section.selected ? "In der App gewählt" : "Nicht gewählt"));
  nameCell.append(name);
  const statusCell = document.createElement("td");
  statusCell.append(sectionStatus(section));
  const dateCell = document.createElement("td");
  dateCell.textContent = formatDate(section.updatedAt);
  row.append(nameCell, statusCell, dateCell);
  fragment.append(row);
  if (section.details) fragment.append(renderSectionDetails(section));
  return fragment;
}

function renderSectionDetails(section) {
  const row = node("tr", "detail-row-container");
  const cell = document.createElement("td");
  cell.colSpan = 3;
  const disclosure = node("details", "detail-disclosure");
  const summary = document.createElement("summary");
  summary.textContent = `${section.label}: DEV-Daten anzeigen`;
  disclosure.append(summary, renderDetailValue(section.details));
  cell.append(disclosure);
  row.append(cell);
  return row;
}

function renderDetailValue(value) {
  const container = node("div", "detail-fields");
  if (!value || typeof value !== "object") {
    container.append(detailField("Wert", displayDetailValue(value)));
    return container;
  }
  const entries = Array.isArray(value) ? value.map((item, index) => [String(index), item]) : Object.entries(value);
  if (entries.length === 0) {
    container.append(node("p", "detail-empty", "Keine Einträge"));
    return container;
  }
  entries.forEach(([key, item], index) => {
    if (item && typeof item === "object") {
      const group = node("section", "detail-group");
      group.append(node("h4", "", Array.isArray(value) ? detailItemTitle(item, index) : fieldLabel(key)));
      group.append(renderDetailValue(item));
      container.append(group);
    } else {
      container.append(detailField(Array.isArray(value) ? `Eintrag ${index + 1}` : fieldLabel(key), displayDetailValue(item)));
    }
  });
  return container;
}

function detailField(label, value) {
  const row = node("div", "detail-field");
  row.append(node("span", "", label), node("strong", "", value));
  return row;
}

function detailItemTitle(item, index) {
  const identifyingValue = item?.dateiName || item?.titel || item?.name || item?.vorname;
  return identifyingValue ? String(identifyingValue) : `Eintrag ${index + 1}`;
}

function displayDetailValue(value) {
  if (value === null || value === undefined || value === "") return "Nicht erfasst";
  if (typeof value === "boolean") return value ? "Ja" : "Nein";
  if (typeof value === "number") return formatNumber(value);
  const text = String(value);
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(text)) return formatDate(text);
  return text;
}

function fieldLabel(key) {
  const labels = {
    id: "ID",
    vorname: "Vorname",
    name: "Name",
    email: "E-Mail-Adresse",
    telefon: "Telefon",
    dateiName: "Dateiname",
    dateiTyp: "Dateityp",
    dateiDaten: "Dateiinhalt",
    bildDaten: "Bildinhalt",
    audioDaten: "Audioinhalt",
    hochgeladenAm: "Hochgeladen am",
    hinzugefuegtAm: "Hinzugefügt am",
    erstelltAm: "Erstellt am",
    aktualisiertAm: "Aktualisiert am"
  };
  if (labels[key]) return labels[key];
  const words = String(key).replace(/([a-zäöü])([A-ZÄÖÜ])/g, "$1 $2").replace(/_/g, " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function sectionStatus(section) {
  if (!section.stored) return statusText("Nicht synchronisiert", "warn");
  if (section.encrypted) return statusText("Verschlüsselt synchronisiert", "good");
  return section.hasData ? statusText("Daten vorhanden", "good") : statusText("Leer", "warn");
}

function summaryItem(label, value, valueIsNode = false) {
  const item = node("div", "summary-item");
  item.append(node("span", "", label));
  const strong = document.createElement("strong");
  valueIsNode ? strong.append(value) : strong.append(document.createTextNode(value));
  item.append(strong);
  return item;
}

function statusText(label, tone) {
  const wrapper = node("span", "status-line");
  wrapper.append(node("span", `status-dot ${tone}`), document.createTextNode(label));
  return wrapper;
}

function invitationLabel(status) {
  if (!status) return "Noch nicht eingeladen";
  return ({ open: "Einladung offen", pending: "Anfrage offen", accepted: "Angenommen", declined: "Abgelehnt", revoked: "Widerrufen" })[status] || status;
}

function subscriptionStatusLabel(status) {
  return ({ active: "Aktiv", expired: "Abgelaufen", cancelled: "Gekündigt", promotional: "Promozugang", not_connected: "Noch nicht verfügbar" })[status] || "Unbekannt";
}

function appendFact(list, label, value) {
  list.append(node("dt", "", label), node("dd", "", value));
}

function formatDate(value) {
  if (!value) return "–";
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? "–" : new Intl.DateTimeFormat("de-CH", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function showAuthenticated(authenticated) {
  elements.loginView.hidden = authenticated;
  elements.appView.hidden = !authenticated;
  if (authenticated) {
    setEnvironment(state.environment || "unbekannt");
    void loadSummary();
    elements.searchEmail.focus();
  } else {
    elements.accountCount.hidden = true;
  }
}

async function loadSummary() {
  try {
    const summary = await request("/api/admin/summary", {});
    elements.accountCountValue.textContent = new Intl.NumberFormat("de-CH").format(summary.registeredAccounts);
    elements.accountCount.hidden = false;
  } catch (error) {
    elements.accountCount.hidden = true;
    if (error.status === 401) logout();
  }
}

function showView(view) {
  const monitoring = view === "monitoring";
  elements.searchView.hidden = monitoring;
  elements.monitoringView.hidden = !monitoring;
  elements.searchNav.classList.toggle("active", !monitoring);
  elements.monitoringNav.classList.toggle("active", monitoring);
  elements.searchNav.toggleAttribute("aria-current", !monitoring);
  elements.monitoringNav.toggleAttribute("aria-current", monitoring);
  if (monitoring) void loadMonitoring();
  else elements.searchEmail.focus();
}

async function loadMonitoring() {
  setBusy(elements.monitoringRefresh, true, "Aktualisieren");
  elements.monitoringError.hidden = true;
  try {
    const data = await request("/api/admin/monitoring", {});
    setEnvironment(data.environment);
    renderServices(data.services);
    renderMonitoringMetrics(data.metrics);
    elements.monitoringUpdated.textContent = `Zuletzt geprüft: ${formatDate(data.checkedAt)}`;
  } catch (error) {
    if (error.status === 401) return logout();
    elements.monitoringError.textContent = error.message;
    elements.monitoringError.hidden = false;
  } finally {
    setBusy(elements.monitoringRefresh, false, "Aktualisieren");
  }
}

function renderServices(services) {
  elements.serviceStatus.replaceChildren(
    serviceItem("API", services.api.available, services.api.available ? "Erreichbar" : "Nicht erreichbar"),
    serviceItem(
      "Datenbank",
      services.database.available && services.database.schemaReady,
      !services.database.available ? "Nicht verbunden" : services.database.schemaReady ? "Verbunden" : "Schema nicht bereit"
    ),
    serviceItem(
      "Object Storage",
      services.objectStorage.available,
      services.objectStorage.available ? "Verbunden" : services.objectStorage.configured ? "Nicht verbunden" : "Nicht konfiguriert"
    )
  );
}

function serviceItem(label, healthy, status) {
  const item = node("article", "service-item");
  item.append(node("h2", "", label), statusText(status, healthy ? "good" : "bad"));
  return item;
}

function renderMonitoringMetrics(metrics) {
  const values = [
    ["Benutzerkonten", formatNumber(metrics.registeredAccounts)],
    ["Aktive Dossiers", formatNumber(metrics.activeDossiers)],
    ["Offene Einladungen", formatNumber(metrics.openInvitations)],
    ["Offene Anfragen", formatNumber(metrics.pendingRequests)],
    ["Dokumente", formatNumber(metrics.storedDocuments)],
    ["Belegter Speicher", formatBytes(metrics.storedBytes)]
  ];
  elements.monitoringMetrics.replaceChildren(...values.map(([label, value]) => {
    const item = node("article", "metric-item");
    item.append(node("span", "", label), node("strong", "", value));
    return item;
  }));
}

function formatNumber(value) {
  return new Intl.NumberFormat("de-CH").format(Number(value || 0));
}

function formatBytes(value) {
  const bytes = Number(value || 0);
  if (bytes < 1024) return `${formatNumber(bytes)} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let amount = bytes / 1024;
  let unit = units[0];
  for (let index = 1; amount >= 1024 && index < units.length; index += 1) {
    amount /= 1024;
    unit = units[index];
  }
  return `${new Intl.NumberFormat("de-CH", { maximumFractionDigits: 1 }).format(amount)} ${unit}`;
}

function setEnvironment(environment) {
  state.environment = environment;
  elements.environmentBadge.textContent = environment === "production" ? "Produktion" : environment === "development" ? "DEV" : environment;
  elements.environmentBadge.className = `environment-badge ${environment}`;
}

function logout() {
  state.token = null;
  state.currentAccount = null;
  sessionStorage.removeItem("supportToken");
  sessionStorage.removeItem("supportEnvironment");
  elements.result.hidden = true;
  elements.emptyState.hidden = false;
  showView("search");
  showAuthenticated(false);
}

async function request(url, body, authenticated = true) {
  const headers = { "Content-Type": "application/json" };
  if (authenticated && state.token) headers.Authorization = `Bearer ${state.token}`;
  const response = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data.error || "Anfrage fehlgeschlagen");
    error.status = response.status;
    throw error;
  }
  return data;
}

function setBusy(button, busy, label) {
  button.disabled = busy;
  button.textContent = busy ? "Bitte warten…" : label;
}

function showNotice(message, error = false) {
  elements.notice.textContent = message;
  elements.notice.className = error ? "notice error" : "notice";
  elements.notice.hidden = false;
}

function hideNotice() {
  elements.notice.hidden = true;
  elements.notice.textContent = "";
}

function node(tag, className = "", text = "") {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text) element.textContent = text;
  return element;
}
