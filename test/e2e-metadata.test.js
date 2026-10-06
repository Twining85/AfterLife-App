import assert from "node:assert/strict";
import test from "node:test";
import { readFile } from "node:fs/promises";
import { normalizeAccessMetadata, contactsFromAccessMetadata, visibleTypesFromAccessMetadata } from "../api/_e2e-contract.js";
import { parseMutation, mutationHash } from "../api/_sync-contract.js";
import { applySectionMutation, changesSince, currentSnapshot } from "../api/_sync-repository.js";
import { loadAccessMetadata } from "../api/_access-metadata.js";
import { automaticReleaseAllowedForContact } from "../api/_trust-policy.js";
import { partialVisibleSectionTypes, releaseAllWishDocuments } from "../api/_invitation-handler.js";

process.env.NODE_ENV = "test";

const dossierID = "11111111-1111-4111-8111-111111111111";
const ownerID = "22222222-2222-4222-8222-222222222222";
const environment = { APP_ENV: "development", E2E_V2_SYNC_ENABLED: "true" };
const metadata = (allowed = true) => ({ version: 2, recipients: [{ recipientEmail: "tester@example.ch", visibleSectionTypes: ["profil", "gesundheit"], ...(allowed === undefined ? {} : { automaticReleaseAllowed: allowed }) }] });
const envelope = sectionType => ({ formatVersion: 2, algorithm: "AES-256-GCM", context: {
  dossierID, sectionType, schemaVersion: 1, keyVersion: 1, resourceID: "section"
}, ciphertext: Buffer.alloc(40, 1).toString("base64") });
const input = (sectionType = "kontakte", accessMetadata = metadata()) => ({ dossierID, sectionType, operation: "upsert", schemaVersion: 1, expectedRevision: 0, payload: envelope(sectionType), accessMetadata });

function withEnvironment(callback) {
  const previous = Object.fromEntries(["APP_ENV", "E2E_V2_SYNC_ENABLED", "TRUST_ACCESS_GRACE_SECONDS"].map(key => [key, process.env[key]]));
  Object.assign(process.env, environment, { TRUST_ACCESS_GRACE_SECONDS: "90" });
  return Promise.resolve().then(callback).finally(() => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  });
}

function clientFor(engine, current) {
  const calls = [];
  const client = { engine, calls, async acquireLock() {}, async query(text, parameters = []) {
    calls.push({ text, parameters });
    if (text.includes("SELECT id FROM dossiers")) return { rows: [{ id: dossierID }] };
    if (text.includes("SELECT schema_version")) {
      if (!calls.some(call => call.text.includes("INSERT INTO dossier_sections"))) return { rows: current ? [current] : [] };
      return { rows: [{ schema_version: 1, revision: 1, encryption_version: 2, payload: envelope("kontakte"), updated_at: new Date() }] };
    }
    if (text.includes("INSERT INTO dossier_sections") && engine !== "mysql") return { rows: [{ schema_version: 1, revision: 1, encryption_version: 2, payload: envelope("kontakte"), updated_at: new Date() }] };
    if (text.includes("SELECT id, invited_email")) return { rows: [{ id: "invitation", invited_email: "tester@example.ch" }] };
    if (text.includes("INSERT INTO sync_changes")) return { rows: [{ change_id: 1, changed_at: new Date() }], insertId: 1 };
    if (text.includes("SELECT change_id, changed_at")) return { rows: [{ change_id: 1, changed_at: new Date() }] };
    return { rows: [] };
  } };
  return client;
}

test("V2 is explicitly gated to DEV and validates its dossier/section binding", () => {
  for (const env of [{}, { APP_ENV: "production", E2E_V2_SYNC_ENABLED: "true" }, { APP_ENV: "development" }]) {
    assert.throws(() => parseMutation(input(), "test:1", env), /nicht aktiviert/);
  }
  assert.equal(parseMutation(input(), "test:1", environment).payload.formatVersion, 2);
  for (const change of [{ dossierID: ownerID }, { sectionType: "finanzen" }, { schemaVersion: 2 }, { resourceID: ownerID }]) {
    const request = input(); request.payload.context = { ...request.payload.context, ...change };
    assert.throws(() => parseMutation(request, "test:1", environment));
  }
  const cleartext = input(); cleartext.payload.name = "leak";
  assert.throws(() => parseMutation(cleartext, "test:1", environment), /Metadaten/);
});

test("Permissions whitelist rejects personal contents and ambiguous recipient matching", () => {
  for (const extra of [{ vorname: "private" }, { telefon: "private" }, { token: "private" }, { key: "private" }]) {
    const raw = metadata(); Object.assign(raw.recipients[0], extra);
    assert.throws(() => normalizeAccessMetadata("kontakte", raw));
  }
  const duplicates = metadata(); duplicates.recipients.push({ ...duplicates.recipients[0] });
  assert.throws(() => normalizeAccessMetadata("kontakte", duplicates), /doppelter/);
  assert.throws(() => normalizeAccessMetadata("kontakte", metadata("true")), /Ja oder Nein/);
  assert.throws(() => normalizeAccessMetadata("kontakte", { version: 2, recipients: [{ recipientEmail: "tester@example.ch", visibleSectionTypes: ["dossier_einstellungen"] }] }));
});

test("Only explicit true in separate metadata permits automatic release", () => {
  for (const choice of [false, true]) {
    const contacts = contactsFromAccessMetadata(metadata(choice));
    assert.equal(automaticReleaseAllowedForContact(contacts, { invited_email: "tester@example.ch" }), choice);
  }
  const unset = metadata(); delete unset.recipients[0].automaticReleaseAllowed;
  assert.equal(contactsFromAccessMetadata(unset).vertrauenspersonen[0].automatischeVollfreigabeErlaubt, false);
  assert.deepEqual(visibleTypesFromAccessMetadata(metadata(), "other@example.ch"), []);
});

test("Metadata changes are included in the idempotency checksum", () => {
  const yes = parseMutation(input("kontakte", metadata(true)), "test:1", environment);
  const no = parseMutation(input("kontakte", metadata(false)), "test:1", environment);
  assert.notEqual(mutationHash(yes), mutationHash(no));
});

for (const engine of ["mysql", "postgresql"]) {
  test(`${engine}: encrypted contact write saves revision-matched metadata and consent in one transaction`, () => withEnvironment(async () => {
    const client = clientFor(engine);
    const mutation = parseMutation(input(), "test:1", environment);
    const result = await applySectionMutation(client, ownerID, mutation);
    assert.equal(result.statusCode, 200);
    const saved = client.calls.find(call => call.text.includes("INSERT INTO dossier_access_metadata"));
    assert.ok(saved);
    assert.equal(saved.parameters[1], ownerID);
    assert.equal(saved.parameters[3], 1);
    assert.equal(JSON.parse(saved.parameters[4]).recipients[0].automaticReleaseAllowed, true);
    const updated = client.calls.find(call => call.text.includes("UPDATE dossier_invitations"));
    assert.equal(updated.parameters[0], true);
    assert.match(updated.text, /status = 'pending'/);
    assert.match(updated.text, /ELSE access_release_at END/);
    assert.doesNotMatch(updated.text, /SET status|dossier_access_grants/);
    const event = client.calls.find(call => call.text.includes("INSERT INTO sync_changes"));
    assert.equal(JSON.parse(event.parameters[7]).version, 2);
  }));

  test(`${engine}: deleting encrypted contacts clears consent; tombstone retains encryption floor`, () => withEnvironment(async () => {
    const client = clientFor(engine, { encryption_version: 2, revision: 1, schema_version: 1 });
    const mutation = { dossierID, sectionType: "kontakte", operation: "delete", schemaVersion: 1, expectedRevision: 1, payload: null, idempotencyKey: "test:2" };
    await applySectionMutation(client, ownerID, mutation);
    assert.ok(client.calls.some(call => call.text.includes("DELETE FROM dossier_access_metadata")));
    assert.equal(client.calls.find(call => call.text.includes("UPDATE dossier_invitations")).parameters[0], false);
    const saved = client.calls.find(call => call.text.includes("INSERT INTO dossier_sections"));
    assert.equal(saved.parameters[7], 2);
  }));

  test(`${engine}: old client cannot replace a migrated or deleted section with plaintext`, async () => {
    for (const deleted_at of [null, new Date()]) {
      const client = clientFor(engine, { encryption_version: 2, revision: 3, schema_version: 1, deleted_at });
      const mutation = { dossierID, sectionType: "kontakte", operation: "upsert", schemaVersion: 1, expectedRevision: 3, payload: { vertrauenspersonen: [] }, idempotencyKey: "test:3" };
      const result = await applySectionMutation(client, ownerID, mutation);
      assert.equal(result.statusCode, 422);
      assert.equal(result.body.code, "encryption_downgrade");
      assert.equal(client.calls.some(call => call.text.includes("INSERT INTO dossier_sections")), false);
      assert.equal(client.calls.some(call => call.text.includes("UPDATE dossier_invitations")), false);
    }
  });
}

test("Encrypted contacts never use permissive legacy visibility defaults", () => {
  const sections = [{ sectionType: "kontakte", payload: envelope("kontakte"), deleted: false }];
  assert.deepEqual(partialVisibleSectionTypes(sections, "tester@example.ch", ownerID), []);
  assert.deepEqual(partialVisibleSectionTypes(sections, "tester@example.ch", ownerID, metadata()), ["gesundheit", "profil"]);
  const encryptedWishes = { sectionType: "wuensche", payload: envelope("wuensche") };
  assert.deepEqual(releaseAllWishDocuments(encryptedWishes), encryptedWishes);
});

test("Metadata reads enforce owner and exact content revision", async () => {
  let query;
  const result = await loadAccessMetadata({ async query(text, parameters) { query = { text, parameters }; return { rows: [{ section_type: "kontakte", metadata: JSON.stringify(metadata()) }] }; } }, ownerID, dossierID);
  assert.equal(result.kontakte.version, 2);
  assert.deepEqual(query.parameters, [ownerID, dossierID]);
  assert.match(query.text, /s\.revision = m\.revision/);
  assert.match(query.text, /s\.encryption_version = 2/);
});

test("Pull and snapshot carry the correct revision metadata without decrypted contents", async () => {
  const change = { change_id: 1, dossier_id: dossierID, section_type: "kontakte", schema_version: 1, revision: 1,
    operation: "upsert", payload: envelope("kontakte"), access_metadata: metadata(), changed_at: new Date(), updated_at: new Date() };
  const pull = await changesSince({ async query() { return { rows: [change] }; } }, ownerID, "0");
  assert.deepEqual(pull.changes[0].accessMetadata, metadata());
  let count = 0;
  const snapshot = await currentSnapshot({ async query() { return { rows: ++count === 1 ? [{ sync_cursor: 1 }] : [change] }; } }, ownerID, dossierID);
  assert.deepEqual(snapshot.changes[0].accessMetadata, metadata());
});

test("Both SQL migrations retain encryption through old-image updates", async () => {
  for (const file of ["database/migrations/012_e2e_access_metadata.sql", "database/mysql/migrations/005_e2e_access_metadata.sql"]) {
    const sql = await readFile(file, "utf8");
    assert.match(sql, /dossier_sections_v2_ciphertext/);
    if (file.includes("/mysql/")) assert.doesNotMatch(sql, /CREATE TRIGGER/);
    else assert.match(sql, /CREATE TRIGGER dossier_sections_encryption_floor BEFORE UPDATE/);
    assert.match(sql, /access_metadata/);
    assert.doesNotMatch(sql, /DROP TABLE|DELETE FROM|TRUNCATE/);
  }
});

test("The legacy PUT endpoint cannot bypass the encryption floor", async () => {
  const { default: handler } = await import("../api/dossiers/sections.js");
  const { setDatabasePoolForTests, resetDatabasePoolForTests } = await import("../api/_database.js");
  const client = clientFor("mysql", { encryption_version: 2, revision: 3, schema_version: 1 });
  client.release = () => {};
  setDatabasePoolForTests({ engine: "mysql", async query() { return { rows: [{ id: ownerID, email: "owner@example.ch" }] }; }, async connect() { return client; } });
  try {
    const req = { method: "PUT", headers: { authorization: `Bearer ${"A".repeat(43)}`, "content-type": "application/json" },
      query: { dossierID, sectionType: "kontakte" }, body: { schemaVersion: 1, expectedRevision: 3, payload: { vertrauenspersonen: [] } } };
    const res = { setHeader() {}, status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } };
    await handler(req, res);
    assert.equal(res.code, 422);
    assert.equal(res.body.code, "encryption_downgrade");
    assert.equal(client.calls.some(call => call.text.includes("INSERT INTO dossier_sections")), false);
  } finally { resetDatabasePoolForTests(); }
});

test("A legacy invitation receives no V2 ciphertext or old master package", async () => {
  const { handleInvitationOperation } = await import("../api/_invitation-handler.js");
  const { setDatabasePoolForTests, resetDatabasePoolForTests } = await import("../api/_database.js");
  let count = 0;
  setDatabasePoolForTests({ engine: "mysql", async query() {
    return { rows: ++count === 1
      ? [{ dossier_id: dossierID, owner_user_id: ownerID, invited_email: "tester@example.ch", status: "accepted", shared_key_package: "LEGACY_MASTER_KEY" }]
      : [{ section_type: "kontakte", schema_version: 1, revision: 1, payload: envelope("kontakte") }] };
  } });
  try {
    const res = { status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } };
    await handleInvitationOperation("shared-dossier", { body: { token: "legacy-token" } }, res, { id: ownerID });
    assert.equal(res.code, 409);
    assert.equal(res.body.code, "e2e_invitation_migration_required");
    assert.equal(JSON.stringify(res.body).includes("LEGACY_MASTER_KEY"), false);
    assert.equal(JSON.stringify(res.body).includes("ciphertext"), false);
  } finally { resetDatabasePoolForTests(); }
});
