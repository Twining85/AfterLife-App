const state = {
  token: sessionStorage.getItem("supportToken"),
  environment: sessionStorage.getItem("supportEnvironment")
};

const elements = {
  loginView: document.querySelector("#login-view"),
  appView: document.querySelector("#app-view"),
  loginForm: document.querySelector("#login-form"),
  loginError: document.querySelector("#login-error"),
  logoutButton: document.querySelector("#logout-button"),
  environmentBadge: document.querySelector("#environment-badge"),
  searchForm: document.querySelector("#search-form"),
  searchEmail: document.querySelector("#search-email"),
  includeDetails: document.querySelector("#include-details"),
  detailsOption: document.querySelector("#details-option"),
  notice: document.querySelector("#notice"),
  emptyState: document.querySelector("#empty-state"),
  result: document.querySelector("#result")
};

elements.loginForm.addEventListener("submit", login);
elements.searchForm.addEventListener("submit", search);
elements.logoutButton.addEventListener("click", logout);
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
  actionCopy.append(node("h3", "", "Kontolöschung"), node("p", "", "Die Diagnoseansicht führt keine Löschung aus. Löschungen benötigen einen separat bestätigten Supportprozess."));
  const disabled = node("button", "disabled-button", "Löschung nicht freigeschaltet");
  disabled.type = "button";
  disabled.disabled = true;
  actions.append(actionCopy, disabled);
  elements.result.append(actions);
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
  const row = document.createElement("tr");
  const nameCell = document.createElement("td");
  const name = node("div", "section-name", section.label);
  name.append(node("small", "", section.selected ? "In der App gewählt" : "Nicht gewählt"));
  nameCell.append(name);
  if (section.details) {
    const disclosure = node("details", "detail-disclosure");
    const summary = document.createElement("summary");
    summary.textContent = "DEV-Daten prüfen";
    const pre = document.createElement("pre");
    pre.textContent = JSON.stringify(section.details, null, 2);
    disclosure.append(summary, pre);
    nameCell.append(disclosure);
  }
  const statusCell = document.createElement("td");
  statusCell.append(sectionStatus(section));
  const dateCell = document.createElement("td");
  dateCell.textContent = formatDate(section.updatedAt);
  row.append(nameCell, statusCell, dateCell);
  return row;
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
    elements.searchEmail.focus();
  }
}

function setEnvironment(environment) {
  state.environment = environment;
  elements.environmentBadge.textContent = environment === "production" ? "Produktion" : environment === "development" ? "DEV" : environment;
  elements.environmentBadge.className = `environment-badge ${environment}`;
}

function logout() {
  state.token = null;
  sessionStorage.removeItem("supportToken");
  sessionStorage.removeItem("supportEnvironment");
  elements.result.hidden = true;
  elements.emptyState.hidden = false;
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
