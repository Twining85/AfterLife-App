import crypto from "node:crypto";

export const supportedSectionVersions = Object.freeze({
  profil: 1,
  gesundheit: 1,
  wuensche: 1,
  finanzen: 1,
  kontakte: 1,
  herzensstuecke: 1,
  zugaenge: 1
});

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const idempotencyPattern = /^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$/;

export function parseMutation(body, idempotencyKey) {
  if (!idempotencyPattern.test(String(idempotencyKey || ""))) {
    throw contractError(400, "Gültiger Idempotency-Key erforderlich");
  }

  const dossierID = String(body?.dossierID || "").toLowerCase();
  const sectionType = String(body?.sectionType || "");
  const operation = String(body?.operation || "");
  const schemaVersion = Number(body?.schemaVersion);
  const expectedRevision = Number(body?.expectedRevision);
  const payload = body?.payload;

  if (!uuidPattern.test(dossierID) || !(sectionType in supportedSectionVersions)) {
    throw contractError(400, "Ungültiger Dossierbereich");
  }
  if (operation !== "upsert" && operation !== "delete") {
    throw contractError(400, "Ungültiger Sync-Vorgang");
  }
  if (!Number.isSafeInteger(expectedRevision) || expectedRevision < 0) {
    throw contractError(400, "Ungültige erwartete Revision");
  }
  if (!Number.isSafeInteger(schemaVersion) || schemaVersion < 1) {
    throw contractError(400, "Ungültige Schema-Version");
  }
  if (schemaVersion !== supportedSectionVersions[sectionType]) {
    throw contractError(422, "Schema-Version wird nicht unterstützt");
  }
  if (operation === "upsert" && (!isObject(payload))) {
    throw contractError(400, "Upload benötigt ein JSON-Objekt");
  }
  if (operation === "delete" && payload !== undefined && payload !== null) {
    throw contractError(400, "Löschung darf keinen Payload enthalten");
  }

  return {
    idempotencyKey: String(idempotencyKey),
    dossierID,
    sectionType,
    operation,
    schemaVersion,
    expectedRevision,
    payload: operation === "upsert" ? payload : null
  };
}

export function parseCursor(value) {
  const cursor = String(value ?? "0");
  if (!/^(0|[1-9][0-9]{0,18})$/.test(cursor)) {
    throw contractError(400, "Ungültiger Sync-Cursor");
  }
  return cursor;
}

export function mutationHash(mutation) {
  const serialized = canonicalJSON({
    dossierID: mutation.dossierID,
    sectionType: mutation.sectionType,
    operation: mutation.operation,
    schemaVersion: mutation.schemaVersion,
    expectedRevision: mutation.expectedRevision,
    payload: mutation.payload
  });
  return crypto.createHash("sha256").update(serialized).digest("hex");
}

export function canonicalJSON(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJSON).join(",")}]`;
  if (isObject(value)) {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJSON(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

export function contractError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
