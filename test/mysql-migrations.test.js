import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { discoverMySQLMigrations, runMySQLMigrations } from "../database/mysql/migrate.js";

test("entdeckt MySQL-Migrationen sortiert und lehnt doppelte Versionen ab", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "tschluessli-mysql-"));
  try {
    await fs.writeFile(path.join(directory, "002_zweite.sql"), "SELECT 2;");
    await fs.writeFile(path.join(directory, "001_erste.sql"), "SELECT 1;");
    const migrations = await discoverMySQLMigrations(directory);
    assert.deepEqual(migrations.map(({ version, name }) => ({ version, name })), [
      { version: 1, name: "erste" },
      { version: 2, name: "zweite" }
    ]);
    assert.match(migrations[0].checksum, /^[0-9a-f]{64}$/);
    await fs.writeFile(path.join(directory, "001_doppelt.sql"), "SELECT 3;");
    await assert.rejects(
      () => discoverMySQLMigrations(directory),
      /Doppelte MySQL-Migrationsversion/
    );
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
});

test("protokolliert eine neue MySQL-Migration unter einer Datenbanksperre", async () => {
  const calls = [];
  const connection = {
    async query(sql) {
      calls.push(String(sql).trim());
      if (String(sql).includes("GET_LOCK")) return [[{ acquired: 1 }]];
      if (String(sql).includes("SELECT version")) return [[]];
      return [[]];
    },
    async execute(sql, parameters) {
      calls.push(String(sql).trim());
      assert.deepEqual(parameters, [2, "next", "a".repeat(64)]);
      return [[]];
    }
  };
  await runMySQLMigrations(connection, [{
    version: 2,
    name: "next",
    filename: "002_next.sql",
    checksum: "a".repeat(64),
    sql: "SELECT 1;"
  }]);
  assert.ok(calls.some((call) => call.includes("GET_LOCK")));
  assert.ok(calls.includes("SELECT 1;"));
  assert.ok(calls.some((call) => call.includes("INSERT INTO schema_migrations")));
  assert.ok(calls.some((call) => call.includes("RELEASE_LOCK")));
});

test("MySQL-Initialschema umfasst Autorisierung, Sync, Dateien und Audit", async () => {
  const schema = await fs.readFile(
    new URL("../database/mysql/migrations/001_initial.sql", import.meta.url),
    "utf8"
  );
  for (const table of [
    "app_users",
    "dossier_sections",
    "sync_changes",
    "dossier_invitations",
    "dossier_access_grants",
    "dossier_key_envelopes",
    "stored_files",
    "admin_users",
    "audit_log"
  ]) {
    assert.match(schema, new RegExp(`CREATE TABLE IF NOT EXISTS ${table} \\(`));
  }
  assert.doesNotMatch(schema, /CREATE ROLE|GRANT .*admin/i);
});
