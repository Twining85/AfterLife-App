import { resourceAAD } from "../support/e2e.js";

export const e2eSectionTypes = Object.freeze([
  "dossier_einstellungen", "dokumente", "profil", "gesundheit", "wuensche",
  "finanzen", "kontakte", "herzensstuecke", "zugaenge"
]);
const visibleTypes = e2eSectionTypes.filter(type => type !== "dossier_einstellungen");
const fail = message => { const error = new Error(message); error.statusCode = 422; throw error; };
function object(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
function keys(value, required, optional = []) {
  if (!object(value) || required.some(key => !(key in value))
      || Object.keys(value).some(key => !required.includes(key) && !optional.includes(key))) fail("Ungültige E2E-Metadaten");
}
function sectionList(value, allowed) {
  if (!Array.isArray(value) || value.length > allowed.length || new Set(value).size !== value.length
      || value.some(type => !allowed.includes(type))) fail("Ungültige Bereichsrechte");
  return [...value].sort();
}

export function normalizeAccessMetadata(sectionType, metadata) {
  if (sectionType === "dossier_einstellungen") {
    keys(metadata, ["version", "activeSectionTypes"]);
    if (metadata.version !== 2) fail("Ungültige Metadatenversion");
    return { version: 2, activeSectionTypes: sectionList(metadata.activeSectionTypes, visibleTypes) };
  }
  if (sectionType === "kontakte") {
    keys(metadata, ["version", "recipients"]);
    if (metadata.version !== 2 || !Array.isArray(metadata.recipients) || metadata.recipients.length > 100) fail("Ungültige Empfängermetadaten");
    const seen = new Set();
    const recipients = metadata.recipients.map(person => {
      keys(person, ["recipientEmail", "visibleSectionTypes"], ["automaticReleaseAllowed"]);
      const email = person.recipientEmail;
      if (typeof email !== "string" || email !== email.trim().toLowerCase() || email.length > 254
          || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || seen.has(email)) fail("Ungültiger oder doppelter Empfänger");
      if (person.automaticReleaseAllowed !== undefined && typeof person.automaticReleaseAllowed !== "boolean") fail("Zustimmung muss Ja oder Nein sein");
      seen.add(email);
      return { recipientEmail: email, visibleSectionTypes: sectionList(person.visibleSectionTypes, visibleTypes),
        automaticReleaseAllowed: person.automaticReleaseAllowed === true };
    }).sort((left, right) => left.recipientEmail.localeCompare(right.recipientEmail, "en"));
    return { version: 2, recipients };
  }
  if (metadata !== undefined && metadata !== null) fail("Dieser Bereich benötigt keine Zugriffsmetadaten");
  return null;
}

export function validateE2EMutation(mutation, environment = process.env) {
  const { payload, accessMetadata, dossierID, sectionType, schemaVersion, operation } = mutation;
  if (operation === "delete") {
    if (accessMetadata !== undefined) fail("Löschung darf keine Zugriffsmetadaten enthalten");
    return mutation;
  }
  if (payload?.formatVersion === undefined) {
    if (accessMetadata !== undefined) fail("Zugriffsmetadaten benötigen ein verschlüsseltes V2-Paket");
    return mutation;
  }
  if (environment.APP_ENV !== "development" || environment.E2E_V2_SYNC_ENABLED !== "true") {
    fail("E2E-V2-Synchronisation ist noch nicht aktiviert");
  }
  keys(payload, ["formatVersion", "algorithm", "context", "ciphertext"]);
  keys(payload.context, ["dossierID", "sectionType", "schemaVersion", "keyVersion", "resourceID"]);
  if (payload.formatVersion !== 2 || payload.algorithm !== "AES-256-GCM"
      || payload.context.dossierID !== dossierID || payload.context.sectionType !== sectionType
      || payload.context.schemaVersion !== schemaVersion || payload.context.resourceID !== "section") fail("E2E-Paket gehört nicht zu diesem Dossierbereich");
  try { resourceAAD(payload.context); } catch { fail("Ungültiger Verschlüsselungskontext"); }
  if (typeof payload.ciphertext !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(payload.ciphertext)) fail("Ungültiges Verschlüsselungspaket");
  const data = Buffer.from(payload.ciphertext, "base64");
  if (data.length < 28 || data.toString("base64") !== payload.ciphertext) fail("Ungültiges Verschlüsselungspaket");
  const normalized = normalizeAccessMetadata(sectionType, accessMetadata);
  return { ...mutation, ...(normalized ? { accessMetadata: normalized } : {}) };
}

export function contactsFromAccessMetadata(metadata) {
  const normalized = normalizeAccessMetadata("kontakte", metadata);
  return { vertrauenspersonen: normalized.recipients.map(person => ({
    email: person.recipientEmail, automatischeVollfreigabeErlaubt: person.automaticReleaseAllowed
  })) };
}

export function visibleTypesFromAccessMetadata(metadata, invitedEmail) {
  const normalized = normalizeAccessMetadata("kontakte", metadata);
  const email = String(invitedEmail || "").trim().toLowerCase();
  return normalized.recipients.find(person => person.recipientEmail === email)?.visibleSectionTypes || [];
}
