import assert from "node:assert/strict";
import test from "node:test";
import { hashPassword, saveSession } from "../api/_auth.js";
import {
  authenticateAdmin,
  buildTrustedPeople,
  countRegisteredAccounts,
  lookupSupportUser,
  monitoringSnapshot,
  pendingSubscriptionStatus,
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

test("liefert einen stabilen Platzhalter für die spätere Aboanbindung", () => {
  assert.deepEqual(pendingSubscriptionStatus(), {
    connected: false,
    plan: null,
    status: "not_connected",
    validUntil: null,
    promoCode: null,
    promoRedemptionAvailable: false
  });
});

test("zählt registrierte Benutzerkonten für die Supportübersicht", async () => {
  const pool = { async query() { return { rows: [{ count: "124" }] }; } };
  assert.equal(await countRegisteredAccounts(pool), 124);
});

test("liefert aggregiertes Monitoring ohne personenbezogene Daten", async () => {
  const pool = { async query() { return { rows: [{
    registered_accounts: "124",
    active_dossiers: "98",
    open_invitations: "7",
    pending_requests: "3",
    stored_documents: "42",
    stored_bytes: "2048"
  }] }; } };
  const result = await monitoringSnapshot({
    pool,
    getDatabaseHealth: async () => ({ healthy: true, schemaReady: true }),
    getStorageHealth: async () => ({ configured: true, connected: true }),
    environment: "development"
  });
  assert.equal(result.environment, "development");
  assert.deepEqual(result.services.database, { available: true, schemaReady: true });
  assert.deepEqual(result.metrics, {
    registeredAccounts: 124,
    activeDossiers: 98,
    openInvitations: 7,
    pendingRequests: 3,
    storedDocuments: 42,
    storedBytes: 2048
  });
  assert.doesNotMatch(JSON.stringify(result), /email|name|dossierID/i);
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
    { rows: [{ id: "user-id", email: "owner@example.ch", email_verified_at: new Date(), created_at: new Date(), updated_at: new Date(), disabled_at: null, is_admin: "0" }] },
    { rows: [{ id: "dossier-id", is_primary: 1, is_active: 1, is_released: 0, created_at: new Date(), updated_at: new Date() }] },
    { rows: [{ section_type: "kontakte", schema_version: 1, revision: "2", payload: { hinterbliebene: [], vertrauenspersonen: [{ vorname: "Bea", name: "Beispiel", email: "trust@example.ch", beziehung: "Schwester", istPrimaereVertrauensperson: true }] }, deleted_at: null, updated_at: new Date() }] },
    { rows: [{ status: "accepted", invited_email: "trust@example.ch", requester_email: "trust@example.ch", requester_name: "Bea Registriert", access_active: 1 }] },
    { rows: [{ status: "available", count: "2", bytes: "1200" }] }
  ]);
  const result = await lookupSupportUser({ email: "owner@example.ch", pool, loadPayload: async (payload) => payload });
  assert.equal(result.found, true);
  assert.equal(result.account.admin, false);
  assert.equal(result.dossiers[0].trustedPeople[0].email, null);
  assert.deepEqual(result.dossiers[0].subscription, pendingSubscriptionStatus());
  assert.equal(result.dossiers[0].trustedPeople[0].name, null);
  assert.equal(result.dossiers[0].trustedPeople[0].configured, true);
  assert.equal(result.dossiers[0].trustedPeople[0].primary, true);
  assert.equal(result.dossiers[0].trustedPeople[0].status, "accepted");
  assert.equal(result.dossiers[0].trustedPeople[0].hasEmail, true);
  assert.equal(result.dossiers[0].sections.find((section) => section.type === "kontakte").hasData, true);
  assert.doesNotMatch(JSON.stringify(result), /trust@example\.ch/);
  assert.doesNotMatch(JSON.stringify(result), /Bea|Beispiel|Registriert|Schwester/);
});

test("erkennt MySQL-Adminflags und schützt den Account in der Supportantwort", async () => {
  const pool = scriptedPool([
    { rows: [{ id: "admin-id", email: "admin@example.ch", email_verified_at: new Date(), created_at: new Date(), updated_at: new Date(), disabled_at: null, is_admin: "1" }] },
    { rows: [] }
  ]);
  const result = await lookupSupportUser({ email: "admin@example.ch", pool });
  assert.equal(result.account.admin, true);
});

test("führt hinterlegte Vertrauenspersonen und Einladungen zusammen", () => {
  const people = buildTrustedPeople({
    vertrauenspersonen: [
      { vorname: "Bea", name: "Beispiel", email: "TRUST@example.ch", beziehung: "Schwester", istPrimaereVertrauensperson: true },
      { vorname: "Max", name: "Muster", email: "max@example.ch", beziehung: "Freund", istPrimaereVertrauensperson: false }
    ]
  }, [{
    status: "pending",
    invited_email: "trust@example.ch",
    requester_email: "trust@example.ch",
    requester_name: "Bea Registriert",
    requested_at: new Date("2026-09-28T10:00:00Z"),
    access_release_at: new Date("2026-10-05T10:00:00Z"),
    access_active: 0
  }], true);

  assert.equal(people.length, 2);
  assert.deepEqual(people[0], {
    configured: true,
    primary: true,
    hasName: true,
    name: "Bea Registriert",
    hasEmail: true,
    email: "trust@example.ch",
    relationship: "Schwester",
    status: "pending",
    accessActive: false,
    expiresAt: null,
    requestedAt: new Date("2026-09-28T10:00:00Z"),
    decidedAt: null,
    accessReleaseAt: new Date("2026-10-05T10:00:00Z"),
    autoReleasedAt: null
  });
  assert.equal(people[1].status, null);
  assert.equal(people[1].name, "Max Muster");
});

test("zeigt Name und E-Mail reiner Einladungen nur in DEV-Details", () => {
  const invitation = {
    status: "pending",
    invited_email: "trust@example.ch",
    requester_email: "registered@example.ch",
    requester_name: "Bea Registriert",
    access_active: 0
  };

  const hidden = buildTrustedPeople({}, [invitation], false)[0];
  assert.equal(hidden.hasName, true);
  assert.equal(hidden.hasEmail, true);
  assert.equal(hidden.name, null);
  assert.equal(hidden.email, null);

  const visible = buildTrustedPeople({}, [invitation], true)[0];
  assert.equal(visible.name, "Bea Registriert");
  assert.equal(visible.email, "registered@example.ch");
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
