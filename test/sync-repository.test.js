import assert from "node:assert/strict";
import test from "node:test";
import { applySectionMutation, changesSince } from "../api/_sync-repository.js";

const userID = "cbcb4c1c-289f-4719-b237-02c9c7534642";
const dossierID = "9ca650a8-a78c-4ef0-b62f-cb640531b667";

function mutation(overrides = {}) {
  return {
    idempotencyKey: "auftrag:123:1",
    dossierID,
    sectionType: "wuensche",
    operation: "upsert",
    schemaVersion: 1,
    expectedRevision: 0,
    payload: { bestattung: "Wald" },
    ...overrides
  };
}

test("speichert Upload, Änderungsereignis und Idempotenzantwort", async () => {
  const client = scriptedClient([
    { rows: [] },
    { rows: [] },
    { rows: [] },
    { rows: [] },
    { rows: [{ id: dossierID }] },
    { rows: [] },
    { rows: [{ schema_version: 1, revision: "1", payload: { bestattung: "Wald" }, deleted_at: null, updated_at: new Date("2026-08-17T10:00:00Z") }] },
    { rows: [{ change_id: "42", changed_at: new Date("2026-08-17T10:00:00Z") }] },
    { rows: [] }
  ]);

  const response = await applySectionMutation(client, userID, mutation());
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.revision, 1);
  assert.equal(response.body.cursor, "42");
  assert.deepEqual(response.body.payload, { bestattung: "Wald" });
  assert.ok(client.calls.some(({ text }) => text.includes("INSERT INTO sync_changes")));
  assert.ok(client.calls.some(({ text }) => text.includes("INSERT INTO sync_idempotency")));
});

test("wiederholt eine gespeicherte Antwort ohne erneutes Schreiben", async () => {
  const storedBody = { dossierID, sectionType: "profil", revision: 4 };
  const initial = mutation({ sectionType: "profil", expectedRevision: 3, payload: { name: "Test" } });
  const { mutationHash } = await import("../api/_sync-contract.js");
  const client = scriptedClient([
    { rows: [] },
    { rows: [] },
    { rows: [{ request_hash: mutationHash(initial), response_status: 200, response_body: storedBody }] }
  ]);

  const response = await applySectionMutation(client, userID, initial);
  assert.equal(response.replayed, true);
  assert.deepEqual(response.body, storedBody);
  assert.equal(client.calls.some(({ text }) => text.includes("INSERT INTO sync_changes")), false);
});

test("liefert bei Revisionskonflikt den aktuellen Serverstand", async () => {
  const client = scriptedClient([
    { rows: [] },
    { rows: [] },
    { rows: [] },
    { rows: [] },
    { rows: [{ id: dossierID }] },
    { rows: [{ schema_version: 1, revision: "3", payload: { bestattung: "See" }, deleted_at: null, updated_at: new Date("2026-08-17T11:00:00Z") }] },
    { rows: [] }
  ]);

  const response = await applySectionMutation(client, userID, mutation({ expectedRevision: 2 }));
  assert.equal(response.statusCode, 409);
  assert.equal(response.body.code, "revision_conflict");
  assert.equal(response.body.current.revision, 3);
  assert.deepEqual(response.body.current.payload, { bestattung: "See" });
});

test("speichert eine Löschung als versionierten Tombstone", async () => {
  const client = scriptedClient([
    { rows: [] },
    { rows: [] },
    { rows: [] },
    { rows: [] },
    { rows: [{ id: dossierID }] },
    { rows: [{ schema_version: 1, revision: "2", payload: { alt: true }, deleted_at: null, updated_at: new Date("2026-08-17T11:00:00Z") }] },
    { rows: [{ schema_version: 1, revision: "3", payload: {}, deleted_at: new Date("2026-08-17T11:05:00Z"), updated_at: new Date("2026-08-17T11:05:00Z") }] },
    { rows: [{ change_id: "44", changed_at: new Date("2026-08-17T11:05:00Z") }] },
    { rows: [] }
  ]);

  const response = await applySectionMutation(client, userID, mutation({
    operation: "delete",
    expectedRevision: 2,
    payload: null
  }));
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.revision, 3);
  assert.equal(response.body.deleted, true);
  assert.equal(response.body.payload, null);
});

test("liefert Upserts und Tombstones seitenweise seit dem Cursor", async () => {
  const client = scriptedClient([{ rows: [
    { change_id: "8", dossier_id: dossierID, section_type: "profil", schema_version: 1, revision: "2", operation: "upsert", payload: { name: "Test" }, changed_at: new Date("2026-08-17T12:00:00Z") },
    { change_id: "9", dossier_id: dossierID, section_type: "zugaenge", schema_version: 1, revision: "5", operation: "delete", payload: null, changed_at: new Date("2026-08-17T12:01:00Z") }
  ] }]);

  const response = await changesSince(client, userID, "7", 1);
  assert.equal(response.changes.length, 1);
  assert.equal(response.nextCursor, "8");
  assert.equal(response.hasMore, true);
  assert.equal(response.changes[0].operation, "upsert");
});

function scriptedClient(responses) {
  return {
    calls: [],
    async query(text, parameters) {
      this.calls.push({ text: String(text), parameters });
      const response = responses.shift();
      if (!response) throw new Error(`Unerwartete Query: ${text}`);
      return response;
    }
  };
}
