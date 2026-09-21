import assert from "node:assert/strict";
import test from "node:test";
import { convertPostgreSQLQuery, databaseEngine, mysqlLockName } from "../api/_database.js";
import { storageConfiguration, storageService, StorageUnavailableError } from "../api/_storage.js";

test("ordnet PostgreSQL-Platzhalter fuer MySQL korrekt und mehrfach an", () => {
  const result = convertPostgreSQLQuery(
    "SELECT * FROM dossiers WHERE owner_user_id = $2 AND (id = $1 OR created_by_user_id = $2) FOR UPDATE OF dossiers",
    ["dossier", "user"]
  );
  assert.equal(
    result.sql,
    "SELECT * FROM dossiers WHERE owner_user_id = ? AND (id = ? OR created_by_user_id = ?) FOR UPDATE"
  );
  assert.deepEqual(result.parameters, ["user", "dossier", "user"]);
});

test("begrenzt MySQL-Sperrnamen deterministisch auf 64 Zeichen", () => {
  const lang = `idempotency:${"a".repeat(36)}:${"b".repeat(36)}:14`;
  const ersterName = mysqlLockName(lang);
  assert.equal(ersterName.length, 64);
  assert.equal(mysqlLockName(lang), ersterName);
  assert.notEqual(mysqlLockName(`${lang}-anders`), ersterName);
});

test("waehlt MySQL explizit und behaelt PostgreSQL als Standard-Fallback", () => {
  const previousEngine = process.env.DATABASE_ENGINE;
  const previousURL = process.env.MYSQL_URL;
  try {
    delete process.env.DATABASE_ENGINE;
    delete process.env.MYSQL_URL;
    assert.equal(databaseEngine(), "postgresql");
    process.env.DATABASE_ENGINE = "mysql";
    assert.equal(databaseEngine(), "mysql");
    process.env.DATABASE_ENGINE = "ungueltig";
    assert.throws(() => databaseEngine(), /postgresql oder mysql/);
  } finally {
    if (previousEngine === undefined) delete process.env.DATABASE_ENGINE;
    else process.env.DATABASE_ENGINE = previousEngine;
    if (previousURL === undefined) delete process.env.MYSQL_URL;
    else process.env.MYSQL_URL = previousURL;
  }
});

test("Object Storage bleibt ohne expliziten Adapter sicher deaktiviert", async () => {
  assert.deepEqual(storageConfiguration({}), { driver: "disabled", configured: false });
  assert.deepEqual(
    storageConfiguration({
      STORAGE_DRIVER: "infomaniak",
      OBJECT_STORAGE_CONTAINER: "files-a",
      OBJECT_STORAGE_EXPECTED_CONTAINER: "files-a"
    }),
    { driver: "infomaniak", container: "files-a", configured: true }
  );
  await assert.rejects(() => storageService().initiateUpload(), StorageUnavailableError);
});
