import assert from "node:assert/strict";
import test from "node:test";
import { deleteAccountForUser } from "../api/accounts/delete.js";

test("löscht zuerst alle eigenen Dossiers und danach den Benutzer", async () => {
  const queries = [];
  const userID = "00000000-0000-0000-0000-000000000001";
  const client = {
    async query(sql, params = []) {
      queries.push({ sql, params });
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
  assert.match(queries[2].sql, /DELETE FROM dossiers/);
  assert.deepEqual(queries[2].params, [userID]);
  assert.match(queries[3].sql, /DELETE FROM app_users/);
  assert.equal(queries[4].sql, "COMMIT");
});

test("führt bei unvollständiger Kontolöschung einen Rollback aus", async () => {
  const queries = [];
  const client = {
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
