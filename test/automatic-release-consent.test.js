import assert from "node:assert/strict";
import fs from "node:fs/promises";
import { afterEach, test } from "node:test";
import { automaticReleaseAllowedForContact, syncAutomaticReleasePolicies, trustAccessGraceSeconds } from "../api/_trust-policy.js";
import { handleInvitationOperation, releaseDueInvitations, sendPendingAccessReminders } from "../api/_invitation-handler.js";
import { databaseHealth, resetDatabasePoolForTests, setDatabasePoolForTests } from "../api/_database.js";
import { applySectionMutation } from "../api/_sync-repository.js";

process.env.NODE_ENV = "test";
afterEach(() => resetDatabasePoolForTests());
const ownerID = "cbcb4c1c-289f-4719-b237-02c9c7534642";
const dossierID = "9ca650a8-a78c-4ef0-b62f-cb640531b667";
const invitation = { id: "invitation-id", invited_email: "trust@example.ch" };
const contact = { email: "TRUST@example.ch", automatischeVollfreigabeErlaubt: true };

test("nur eine ausdrückliche Erlaubnis der passenden Vertrauensperson zählt", () => {
  assert.equal(automaticReleaseAllowedForContact({ vertrauenspersonen: [contact] }, invitation), true);
  for (const value of [false, null, undefined, "true", 1]) {
    assert.equal(automaticReleaseAllowedForContact({ vertrauenspersonen: [{ ...contact, automatischeVollfreigabeErlaubt: value }] }, invitation), false);
  }
  assert.equal(automaticReleaseAllowedForContact({ vertrauenspersonen: [contact] }, { invited_email: "other@example.ch" }), false);
  assert.equal(automaticReleaseAllowedForContact({ vertrauenspersonen: [contact, contact] }, invitation), false);
  assert.equal(automaticReleaseAllowedForContact(null, invitation), false);
  assert.equal(automaticReleaseAllowedForContact({ vertrauenspersonen: [{ ...contact, email: "other@example.ch", einladungsEmail: "trust@example.ch" }] }, invitation), true);
});

test("produktive Zustimmung bedeutet auch bei abweichender Konfiguration sieben Tage", () => {
  assert.equal(trustAccessGraceSeconds({ APP_ENV: "production", TRUST_ACCESS_GRACE_SECONDS: "60" }), 604800);
  assert.equal(trustAccessGraceSeconds({ NODE_ENV: "production" }), 604800);
  assert.equal(trustAccessGraceSeconds({ NODE_ENV: "production", APP_ENV: "development", TRUST_ACCESS_GRACE_SECONDS: "90" }), 90);
  assert.throws(() => trustAccessGraceSeconds({ TRUST_ACCESS_GRACE_SECONDS: "60oops" }), /ungueltig/);
});

for (const engine of ["postgresql", "mysql"]) {
  test(`${engine}: Kontakte-Upload aktualisiert Zustimmung vor der Sync-Erfolgsantwort`, async () => {
    const queries = [];
    let sectionReads = 0;
    const client = {
      engine, async acquireLock() {},
      async query(text, parameters) {
        queries.push({ text, parameters });
        if (text.startsWith("SELECT id FROM dossiers")) return { rows: [{ id: dossierID }] };
        if (text.startsWith("SELECT id, invited_email")) return { rows: [invitation] };
        if (text.startsWith("SELECT schema_version") && ++sectionReads === 1) return { rows: [] };
        if (text.includes("INSERT INTO dossier_sections") || text.startsWith("SELECT schema_version")) {
          return { rows: [{ schema_version: 1, revision: 1, updated_at: new Date(), payload: {} }] };
        }
        if (text.includes("INSERT INTO sync_changes") || text.startsWith("SELECT change_id")) {
          return { insertId: 1, rows: [{ change_id: 1, changed_at: new Date() }] };
        }
        return { rows: [] };
      }
    };
    const result = await applySectionMutation(client, ownerID, {
      idempotencyKey: "consent:1", dossierID, sectionType: "kontakte", operation: "upsert",
      schemaVersion: 1, expectedRevision: 0, payload: { vertrauenspersonen: [contact] }
    });
    assert.equal(result.statusCode, 200);
    const policyIndex = queries.findIndex(({ text }) => text.startsWith("UPDATE dossier_invitations"));
    const receiptIndex = queries.findIndex(({ text }) => text.includes("INSERT INTO sync_idempotency"));
    assert.equal(queries[policyIndex].parameters[0], true);
    assert.ok(policyIndex < receiptIndex);
  });

  test(`${engine}: Änderung der Auswahl hält Anfrage und Teilzugriff unverändert`, async () => {
    const queries = [];
    const client = {
      engine,
      async query(text, parameters) {
        queries.push({ text, parameters });
        return { rows: text.startsWith("SELECT") ? [invitation] : [] };
      }
    };
    for (const consent of [true, false, undefined]) {
      queries.length = 0;
      await syncAutomaticReleasePolicies(client, ownerID, dossierID, { vertrauenspersonen: [{ ...contact, automatischeVollfreigabeErlaubt: consent }] });
      assert.match(queries[0].text, /owner_user_id = \$2/);
      assert.match(queries[0].text, /FOR UPDATE/);
      assert.equal(queries[1].parameters[0], consent === true);
      assert.match(queries[1].text, /WHEN NOT \$1 THEN NULL/);
      assert.match(queries[1].text, /status = 'pending' AND \(NOT automatic_release_allowed OR access_release_at IS NULL\)/);
      assert.match(queries[1].text, /ELSE access_release_at END/);
      assert.doesNotMatch(queries[1].text, /SET status|dossier_access_grants|decided_at/);
    }
  });

  test(`${engine}: ohne Erlaubnis wird selbst eine veraltete Frist nicht automatisch freigegeben`, async () => {
    const queries = [];
    const client = {
      engine, release() {},
      async query(text, parameters) {
        queries.push({ text, parameters });
        // Returning no eligible rows simulates the DB excluding non-consented
        // invitations. Inspect the actual selector, including its lock.
        return { rows: [] };
      }
    };
    let pushes = 0;
    const count = await releaseDueInvitations({ pool: { async connect() { return client; } }, async push() { pushes++; } });
    assert.equal(count, 0);
    assert.equal(pushes, 0);
    assert.match(queries[1].text, /automatic_release_allowed = TRUE/);
    assert.match(queries[1].text, /status = 'pending'/);
    assert.match(queries[1].text, /FOR UPDATE SKIP LOCKED/);
    assert.equal(queries.at(-1).text, "COMMIT");
  });

  test(`${engine}: Erinnerungen laufen bei Nein ohne Frist weiter`, async () => {
    const queries = [];
    const client = {
      engine, release() {},
      async query(text, parameters) {
        queries.push({ text, parameters });
        if (text.includes("RETURNING i.id") || text.startsWith("SELECT id, owner_user_id")) {
          return { rows: [{ ...invitation, owner_user_id: ownerID, requester_name: "Max" }] };
        }
        return { rows: [] };
      }
    };
    const pushes = [];
    const count = await sendPendingAccessReminders({ pool: { async connect() { return client; } }, intervalSeconds: 30, async push(user, payload) { pushes.push({ user, payload }); } });
    assert.equal(count, 1);
    assert.equal(pushes[0].payload.type, "trust_invitation_request_reminder");
    assert.match(queries[1].text, /NOT automatic_release_allowed OR access_release_at IS NULL/);
  });
}

test("Einladungsregistrierung speichert Ja und Nein, alte Apps erhalten keine implizite Erlaubnis", async () => {
  for (const value of [true, false, undefined]) {
    let parameters;
    setDatabasePoolForTests({ async query(text, args) { parameters = args; return { rows: [{ id: "invitation" }] }; } });
    const res = response();
    await handleInvitationOperation("register-invitation", { body: {
      token: "token", dossierID, email: "trust@example.ch", sharedKeyPackage: Buffer.alloc(60).toString("base64"), automaticReleaseAllowed: value
    } }, res, { id: ownerID });
    assert.equal(res.statusCode, 204);
    assert.equal(parameters[6], value === true);
  }
  const res = response();
  await handleInvitationOperation("register-invitation", { body: { automaticReleaseAllowed: "true" } }, res, { id: ownerID });
  assert.equal(res.statusCode, 400);
});

test("Request erstellt nur bei Erlaubnis eine Frist und setzt eine offene Frist nicht zurück", async () => {
  const queries = [];
  setDatabasePoolForTests({
    async query(text, parameters) {
      queries.push({ text, parameters });
      return { rows: text.startsWith("UPDATE") ? [{ dossier_id: dossierID, owner_user_id: ownerID, access_release_at: null }] : [] };
    }
  });
  const res = response();
  await handleInvitationOperation("request-invitation", { body: { token: "token" } }, res, { id: "trust-user", email: "trust@example.ch" });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.accessReleaseAt, null);
  assert.match(queries[0].text, /CASE WHEN automatic_release_allowed THEN/);
  assert.match(queries[0].text, /status = 'pending' AND access_release_at IS NOT NULL THEN access_release_at/);
  assert.match(queries[0].text, /END ELSE NULL END/);
});

test("Migrationen schalten alte offene Anfragen aus, erhalten aber vorhandene Freigaben", async () => {
  for (const path of ["../database/migrations/011_automatic_release_consent.sql", "../database/mysql/migrations/004_automatic_release_consent.sql"]) {
    const sql = await fs.readFile(new URL(path, import.meta.url), "utf8");
    assert.match(sql, /automatic_release_allowed.*DEFAULT false/i);
    assert.match(sql, /SET access_release_at = NULL/);
    assert.doesNotMatch(sql, /SET status|DELETE|dossier_access_grants/);
  }
});

test("Readiness lehnt eine Datenbank ohne Zustimmungs-Migration ab", async () => {
  const previous = process.env.DATABASE_ENGINE;
  try {
    for (const [engine, version] of [["mysql", 3], ["postgresql", 10]]) {
      process.env.DATABASE_ENGINE = engine;
      setDatabasePoolForTests({ async query() { return { rows: [{ healthy: 1, schema_version: version }] }; } });
      assert.equal((await databaseHealth()).schemaReady, false);
    }
  } finally {
    if (previous === undefined) delete process.env.DATABASE_ENGINE;
    else process.env.DATABASE_ENGINE = previous;
  }
});

function response() {
  return { statusCode: 200, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }, end() { return this; } };
}
