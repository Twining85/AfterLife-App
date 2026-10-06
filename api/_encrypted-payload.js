// This detects ciphertext for support redaction only; it is not format validation.
export function isEncryptedPayload(payload) {
  return Boolean(payload && typeof payload === "object" && (
    payload.formatVersion === 2
    || (payload.algorithmus === "AES-256-GCM" && typeof payload.daten === "string")
    || (payload.algorithm === "AES-256-GCM" && typeof payload.ciphertext === "string")
  ));
}
