import assert from "node:assert/strict";
import test from "node:test";
import { deleteAccountForUser } from "../api/accounts/login.js";

test("löscht alle Konto- und Dossierdaten und prüft das Ergebnis vor dem Commit", async () => {
  const queries = [];
  const userID = "00000000-0000-0000-0000-000000000001";
  const client = {
    engine: "mysql",
    async query(sql, params = []) {
      queries.push({ sql, params });
      if (sql.includes("SELECT email FROM app_users")) {
        return { rowCount: 1, rows: [{ email: "delete@example.ch" }] };
      }
      if (sql.includes("SELECT id FROM dossiers")) {
        return { rowCount: 1, rows: [{ id: "00000000-0000-0000-0000-000000000002" }] };
      }
      if (sql.includes("COUNT(*)")) return { rowCount: 1, rows: [{ count: 0 }] };
      if (sql.includes("DELETE FROM app_users")) {
        return { rowCount: 1, rows: [{ id: userID }] };
      }
      return { rowCount: 0, rows: [] };
    },
    release() {}
  };

  await deleteAccountForUser({
    userID,
    pool: { async connect() { return client; } }
  });

  assert.equal(queries[0].sql, "BEGIN");
  assert.match(queries[1].sql, /set_config/);
  const sql = queries.map((query) => query.sql);
  assert.ok(sql.some((value) => value.includes("DELETE FROM dossier_sections")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM stored_files")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM dossier_key_envelopes")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM dossier_access_grants")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM dossier_invitations")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM sync_changes")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM user_sessions")));
  assert.ok(sql.some((value) => value.includes("DELETE FROM app_users")));
  assert.ok(sql.some((value) => value.includes("COUNT(*)")));
  assert.equal(sql.at(-1), "COMMIT");
});

test("führt bei unvollständiger Kontolöschung einen Rollback aus", async () => {
  const queries = [];
  const client = {
    engine: "mysql",
    async query(sql) {
      queries.push(sql);
      if (sql.includes("DELETE FROM app_users")) return { rowCount: 0, rows: [] };
      return { rowCount: 0, rows: [] };
    },
    release() {}
  };

  await assert.rejects(
    () => deleteAccountForUser({
      userID: "00000000-0000-0000-0000-000000000001",
      pool: { async connect() { return client; } }
    }),
    /Konto nicht gefunden/
  );
  assert.equal(queries.at(-1), "ROLLBACK");
});

test("rollt zurück, wenn die Abschlusskontrolle Restdaten findet", async () => {
  const queries = [];
  const client = {
    engine: "mysql",
    async query(sql) {
      queries.push(sql);
      if (sql.includes("SELECT email FROM app_users")) return { rows: [{ email: "delete@example.ch" }], rowCount: 1 };
      if (sql.includes("SELECT id FROM dossiers")) return { rows: [], rowCount: 0 };
      if (sql.includes("DELETE FROM app_users")) return { rows: [], rowCount: 1 };
      if (sql.includes("COUNT(*)")) return { rows: [{ count: 1 }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    },
    release() {}
  };

  await assert.rejects(
    () => deleteAccountForUser({
      userID: "00000000-0000-0000-0000-000000000001",
      pool: { async connect() { return client; } }
    }),
    /hinterliess Cloud-Daten/
  );
  assert.equal(queries.at(-1), "ROLLBACK");
  assert.ok(!queries.includes("COMMIT"));
});
