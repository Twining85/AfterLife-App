import assert from "node:assert/strict";
import test from "node:test";
import { hashPassword, saveSession } from "../api/_auth.js";
import {
  authenticateAdmin,
  lookupSupportUser,
  payloadHasData,
  supportEnvironment,
  supportSiteEnabled
} from "../api/admin/support.js";
import { resetDatabasePoolForTests, setDatabasePoolForTests } from "../api/_database.js";

test("meldet nur aktive Benutzer aus admin_users an", async () => {
  const password = await hashPassword("sicheres Support Passwort 123");
  const pool = {
    async query() {
      return { rows: [{ id: "admin-id", password_hash: password.hash, password_salt: password.salt }], rowCount: 1 };
    }
  };
  assert.deepEqual(await authenticateAdmin({ email: "admin@example.ch", password: "sicheres Support Passwort 123", pool }), { id: "admin-id" });
  assert.equal(await authenticateAdmin({ email: "admin@example.ch", password: "falsch", pool }), null);
});

test("erzeugt eine nicht erneuerbare Support-Sitzung", async () => {
  process.env.NODE_ENV = "test";
  let inserted;
  setDatabasePoolForTests({
    async query(_sql, parameters) { inserted = parameters; return { rows: [], rowCount: 1 }; }
  });
  try {
    const session = await saveSession("admin-id", { lifetimeMilliseconds: 8 * 60 * 60 * 1000, refresh: false });
    assert.equal(session.refreshToken, null);
    assert.equal(inserted[3], null);
    assert.ok(session.expiresAt.getTime() - Date.now() <= 8 * 60 * 60 * 1000);
  } finally {
    resetDatabasePoolForTests();
  }
});

test("klassifiziert Bereichspayloads ohne Inhalte offenzulegen", () => {
  assert.equal(payloadHasData("gesundheit", { items: [] }), false);
  assert.equal(payloadHasData("gesundheit", { items: [{ id: "1" }] }), true);
  assert.equal(payloadHasData("kontakte", { hinterbliebene: [], vertrauenspersonen: [{ email: "person@example.ch" }] }), true);
  assert.equal(payloadHasData("finanzen", { bankkonten: [], schulden: [], versicherungen: [], liegenschaften: [], wertsachen: [], steuerdokumente: [] }), false);
  assert.equal(payloadHasData("dokumente", { dokumente: [{ id: "1" }], fotos: [] }), true);
});

test("erkennt die Supportumgebung konservativ", () => {
  assert.equal(supportEnvironment({ APP_ENV: "development" }), "development");
  assert.equal(supportEnvironment({ APP_ENV: "production" }), "production");
  assert.equal(supportEnvironment({ NODE_ENV: "production" }), "production");
  assert.equal(supportSiteEnabled({ SUPPORT_SITE_ENABLED: "true" }), true);
  assert.equal(supportSiteEnabled({ SUPPORT_SITE_ENABLED: "false" }), false);
  assert.equal(supportSiteEnabled({}), false);
});

test("liefert in Produktion nur Status und keine Vertrauensperson-E-Mail", async () => {
  const pool = scriptedPool([
    { rows: [{ id: "user-id", email: "owner@example.ch", email_verified_at: new Date(), created_at: new Date(), updated_at: new Date(), disabled_at: null }] },
    { rows: [{ id: "dossier-id", is_primary: 1, is_active: 1, is_released: 0, created_at: new Date(), updated_at: new Date() }] },
    { rows: [{ section_type: "kontakte", schema_version: 1, revision: "2", payload: { hinterbliebene: [], vertrauenspersonen: [{ email: "trust@example.ch" }] }, deleted_at: null, updated_at: new Date() }] },
    { rows: [{ status: "accepted", invited_email: "trust@example.ch", requester_email: "trust@example.ch", access_active: 1 }] },
    { rows: [{ status: "available", count: "2", bytes: "1200" }] }
  ]);
  const result = await lookupSupportUser({ email: "owner@example.ch", pool, loadPayload: async (payload) => payload });
  assert.equal(result.found, true);
  assert.equal(result.dossiers[0].trustedPeople[0].email, null);
  assert.equal(result.dossiers[0].trustedPeople[0].hasEmail, true);
  assert.equal(result.dossiers[0].sections.find((section) => section.type === "kontakte").hasData, true);
  assert.doesNotMatch(JSON.stringify(result), /trust@example\.ch/);
});

function scriptedPool(responses) {
  return {
    async query() {
      const response = responses.shift();
      if (!response) throw new Error("Unerwartete Abfrage");
      return { rowCount: response.rows.length, ...response };
    }
  };
}
