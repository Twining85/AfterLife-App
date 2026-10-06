import assert from "node:assert/strict";
import test from "node:test";
import { createCipheriv, hkdfSync, randomBytes } from "node:crypto";
import { decryptResource, decryptGrant, resourceAAD, grantAAD } from "../support/e2e.js";
import { isEncryptedPayload } from "../api/_encrypted-payload.js";
import { payloadHasData } from "../api/admin/support.js";

const dossierID = "11111111-1111-4111-8111-111111111111";
const context = { dossierID, sectionType: "gesundheit", schemaVersion: 1, keyVersion: 1, resourceID: "section" };
const grantContext = { dossierID, invitationID: "22222222-2222-4222-8222-222222222222", recipientEmail: "tester@example.ch", grantVersion: 1, scope: "partial" };
const root = Buffer.alloc(32, 7);
function derive(context) {
  return Buffer.from(hkdfSync("sha256", root, "Tschluessli-E2E-resource-key-v2", resourceAAD(context), 32));
}
function seal(data, key, context, aadFor = resourceAAD, nonce = randomBytes(12)) {
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  cipher.setAAD(aadFor(context));
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  return { formatVersion: 2, algorithm: "AES-256-GCM", context, ciphertext: Buffer.concat([nonce, encrypted, cipher.getAuthTag()]).toString("base64") };
}

test("V2 WebCrypto decrypts the independent Node AES-GCM representation", async () => {
  const message = Buffer.from('{"notiz":"Nur auf dem Gerät sichtbar"}');
  const envelope = seal(message, derive(context), context);
  assert.deepEqual(Buffer.from(await decryptResource(envelope, derive(context), context)), message);
  assert.equal(JSON.stringify(envelope).includes("sichtbar"), false);
});

test("V2 refuses tampering, wrong keys, changed context and downgraded format", async () => {
  const key = derive(context);
  const envelope = seal(Buffer.from("private"), key, context);
  const altered = Buffer.from(envelope.ciphertext, "base64");
  altered[14] ^= 1;
  await assert.rejects(decryptResource({ ...envelope, ciphertext: altered.toString("base64") }, key, context));
  await assert.rejects(decryptResource(envelope, Buffer.alloc(32, 9), context));
  for (const changed of [
    { dossierID: "33333333-3333-4333-8333-333333333333" }, { sectionType: "finanzen" },
    { schemaVersion: 2 }, { keyVersion: 2 }, { resourceID: "22222222-2222-4222-8222-222222222222" }
  ]) {
    await assert.rejects(decryptResource(envelope, key, { ...context, ...changed }));
    // Even rewriting the envelope context cannot bypass the authenticated binding.
    await assert.rejects(decryptResource({ ...envelope, context: { ...context, ...changed } }, key, { ...context, ...changed }));
  }
  await assert.rejects(decryptResource({ ...envelope, formatVersion: 1 }, key, context));
  await assert.rejects(decryptResource({ ...envelope, algorithm: "AES-CBC" }, key, context));
});

test("Derived keys isolate dossiers, sections, documents and rotations", async () => {
  const envelope = seal(Buffer.from("private"), derive(context), context);
  for (const changed of [
    { dossierID: "33333333-3333-4333-8333-333333333333" }, { sectionType: "finanzen" },
    { keyVersion: 2 }, { resourceID: "22222222-2222-4222-8222-222222222222" }
  ]) {
    const otherKey = derive({ ...context, ...changed });
    assert.notDeepEqual(otherKey, derive(context));
    await assert.rejects(decryptResource(envelope, otherKey, context));
  }
});

test("Grant contains selected resource keys and requires an independent secret", async () => {
  const secret = randomBytes(32);
  const selected = [{ context, key: derive(context).toString("base64") }];
  const wrapping = Buffer.from(hkdfSync("sha256", secret, "Tschluessli-E2E-grant-key-v2", grantAAD(grantContext), 32));
  const envelope = seal(Buffer.from(JSON.stringify(selected)), wrapping, grantContext, grantAAD);
  assert.deepEqual(await decryptGrant(envelope, secret, grantContext), selected);
  assert.equal(JSON.stringify(envelope).includes(selected[0].key), false);
  await assert.rejects(decryptGrant(envelope, Buffer.alloc(32), grantContext));
  for (const change of [{ scope: "full" }, { recipientEmail: "other@example.ch" }, { grantVersion: 2 }]) {
    await assert.rejects(decryptGrant(envelope, secret, { ...grantContext, ...change }));
  }
  // A grant for one resource cannot open another section with the shared key.
  const otherContext = { ...context, sectionType: "finanzen" };
  await assert.rejects(decryptResource(seal(Buffer.from("bank"), derive(otherContext), otherContext), derive(context), otherContext));
});

test("Grant rejects duplicate keys and keys from another dossier", async () => {
  const secret = randomBytes(32);
  const wrapping = Buffer.from(hkdfSync("sha256", secret, "Tschluessli-E2E-grant-key-v2", grantAAD(grantContext), 32));
  const entry = { context, key: derive(context).toString("base64") };
  for (const keys of [[], [entry, entry], [{ ...entry, context: { ...context, dossierID: "33333333-3333-4333-8333-333333333333" } }]]) {
    const envelope = seal(Buffer.from(JSON.stringify(keys)), wrapping, grantContext, grantAAD);
    await assert.rejects(decryptGrant(envelope, secret, grantContext));
  }
});

test("Support treats every V2 section as opaque, never as readable dossier content", () => {
  const envelope = seal(Buffer.from("private"), derive(context), context);
  assert.equal(isEncryptedPayload(envelope), true);
  assert.equal(isEncryptedPayload({ algorithmus: "AES-256-GCM", daten: "legacy" }), true);
  assert.equal(isEncryptedPayload({ items: [] }), false);
  for (const section of ["profil", "gesundheit", "kontakte", "dossier_einstellungen", "finanzen", "dokumente", "wuensche", "zugaenge"]) {
    assert.equal(payloadHasData(section, envelope), null);
  }
});

// Fixed interoperability vector is shared with the Swift CryptoKit tests.
test("Fixed V2 interoperability vector", async () => {
  const key = derive(context);
  assert.equal(key.toString("hex"), "644f1449eb5ffc35fb59fa57325fb61d8645d50744908f8d58a358c78b0a95be");
  const envelope = seal(Buffer.from("V2-Test"), key, context, resourceAAD, Buffer.alloc(12, 3));
  assert.equal(envelope.ciphertext, "AwMDAwMDAwMDAwMDU1HO4loIEx1x27mSGC0ZXsh55rhmrho=");
  assert.equal(new TextDecoder().decode(await decryptResource(envelope, key, context)), "V2-Test");
});

test("Support lookup redacts V2 ciphertext while preserving its encryption status", async () => {
  const { lookupSupportUser } = await import("../api/admin/support.js");
  const envelope = seal(Buffer.from("private"), derive(context), context);
  const responses = [
    { rows: [{ id: "owner", email: "owner@example.ch", is_admin: 0 }] },
    { rows: [{ id: dossierID, is_primary: 1 }] },
    { rows: [{ section_type: "gesundheit", schema_version: 1, revision: 1, payload: envelope }] },
    { rows: [] }, { rows: [] }
  ];
  const pool = { async query() { const result = responses.shift(); assert.ok(result); return result; } };
  const result = await lookupSupportUser({ email: "owner@example.ch", includeDetails: true, pool, loadPayload: async value => value });
  const section = result.dossiers[0].sections.find(value => value.type === "gesundheit");
  assert.equal(section.encrypted, true);
  assert.equal(section.hasData, null);
  assert.equal(section.details.ciphertext, "[ausgeblendet]");
  assert.equal(JSON.stringify(result).includes(envelope.ciphertext), false);
});
