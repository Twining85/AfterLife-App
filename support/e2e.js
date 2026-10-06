// Local-only V2 decryption primitives. No fetch, storage, logging or key upload.
// Not yet connected to the support UI or the legacy sync protocol.
const encoder = new TextEncoder();
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const sections = new Set([
  "dossier_einstellungen", "profil", "gesundheit", "wuensche", "finanzen",
  "dokumente", "kontakte", "herzensstuecke", "zugaenge"
]);
const integer = value => Number.isInteger(value) && value > 0 && value <= 1_000_000;
const bytes = value => {
  if (!(value instanceof Uint8Array) || value.length !== 32) throw new Error("Ungültiger Schlüssel");
  return value;
};

export function decodeBase64(value) {
  if (typeof value !== "string" || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
    throw new Error("Ungültiges Base64-Paket");
  }
  const text = atob(value);
  if (btoa(text) !== value) throw new Error("Ungültiges Base64-Paket");
  return Uint8Array.from(text, char => char.charCodeAt(0));
}

export function resourceAAD(context) {
  if (!context || !uuid.test(context.dossierID) || !sections.has(context.sectionType)
      || !integer(context.schemaVersion) || !integer(context.keyVersion)
      || !(context.resourceID === "section" || (typeof context.resourceID === "string"
           && uuid.test(context.resourceID) && context.resourceID === context.resourceID.toLowerCase()))) {
    throw new Error("Ungültiger Ressourcenkontext");
  }
  return encoder.encode(`Tschluessli-E2E-v2\n${context.dossierID.toLowerCase()}\n${context.sectionType}\n${context.schemaVersion}\n${context.keyVersion}\n${context.resourceID}`);
}

export function grantAAD(context) {
  if (!context || !uuid.test(context.dossierID) || !uuid.test(context.invitationID)
      || !integer(context.grantVersion) || !["partial", "full"].includes(context.scope)
      || typeof context.recipientEmail !== "string" || context.recipientEmail.length > 254
      || context.recipientEmail !== context.recipientEmail.trim().toLowerCase()
      || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(context.recipientEmail)) {
    throw new Error("Ungültiger Freigabekontext");
  }
  return encoder.encode(`Tschluessli-E2E-grant-v2\n${context.dossierID.toLowerCase()}\n${context.invitationID.toLowerCase()}\n${context.recipientEmail}\n${context.grantVersion}\n${context.scope}`);
}

function equalBytes(left, right) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

async function open(envelope, key, expectedContext, aadFor) {
  if (envelope?.formatVersion !== 2 || envelope?.algorithm !== "AES-256-GCM") throw new Error("Ungültiges Verschlüsselungsformat");
  const aad = aadFor(expectedContext);
  if (!equalBytes(aadFor(envelope.context), aad)) throw new Error("Paket gehört zu einem anderen Kontext");
  const combined = decodeBase64(envelope.ciphertext);
  if (combined.length < 28) throw new Error("Unvollständiges Verschlüsselungspaket");
  const imported = await crypto.subtle.importKey("raw", bytes(key), "AES-GCM", false, ["decrypt"]);
  return new Uint8Array(await crypto.subtle.decrypt({
    name: "AES-GCM", iv: combined.slice(0, 12), additionalData: aad, tagLength: 128
  }, imported, combined.slice(12)));
}

export async function decryptResource(envelope, resourceKey, expectedContext) {
  return open(envelope, resourceKey, expectedContext, resourceAAD);
}

export async function decryptGrant(envelope, invitationSecret, expectedContext) {
  const aad = grantAAD(expectedContext);
  const material = await crypto.subtle.importKey("raw", bytes(invitationSecret), "HKDF", false, ["deriveBits"]);
  const wrapping = new Uint8Array(await crypto.subtle.deriveBits({
    name: "HKDF", hash: "SHA-256", salt: encoder.encode("Tschluessli-E2E-grant-key-v2"), info: aad
  }, material, 256));
  try {
    const cleartext = await open(envelope, wrapping, expectedContext, grantAAD);
    const keys = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(cleartext));
    if (!Array.isArray(keys) || !keys.length || keys.length > 1024) throw new Error("Ungültiges Freigabepaket");
    const seen = new Set();
    for (const entry of keys) {
      const id = new TextDecoder().decode(resourceAAD(entry.context));
      if (entry.context.dossierID.toLowerCase() !== expectedContext.dossierID.toLowerCase()
          || seen.has(id)) throw new Error("Ungültige Ressourcenfreigabe");
      bytes(decodeBase64(entry.key));
      seen.add(id);
    }
    return keys;
  } finally {
    wrapping.fill(0);
  }
}
