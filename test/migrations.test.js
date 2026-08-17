import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { checksum, discoverMigrations, runMigrations } from "../database/migrate.js";

test("entdeckt Migrationen sortiert und mit stabiler Pruefsumme", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "tschluessli-migrations-"));
  try {
    await fs.writeFile(path.join(directory, "002_zweite.sql"), "SELECT 2;\n");
    await fs.writeFile(path.join(directory, "001_erste.sql"), "SELECT 1;\n");
    await fs.writeFile(path.join(directory, "not-a-migration.txt"), "ignorieren");

    const migrations = await discoverMigrations(directory);
    assert.deepEqual(migrations.map(({ version, name }) => ({ version, name })), [
      { version: 1, name: "erste" },
      { version: 2, name: "zweite" }
    ]);
    assert.equal(migrations[0].checksum, checksum("SELECT 1;\n"));
    assert.match(migrations[0].checksum, /^[0-9a-f]{64}$/);
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
});

test("lehnt doppelte Migrationsversionen ab", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "tschluessli-migrations-"));
  try {
    await fs.writeFile(path.join(directory, "001_erste.sql"), "SELECT 1;");
    await fs.writeFile(path.join(directory, "001_doppelt.sql"), "SELECT 2;");
    await assert.rejects(() => discoverMigrations(directory), /Doppelte Migrationsversion/);
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
});

test("stoppt bei veraenderter bereits angewendeter Migration", async () => {
  const migration = {
    version: 1,
    name: "initial",
    filename: "001_initial.sql",
    checksum: checksum("SELECT 1;"),
    sql: "SELECT 1;"
  };
  const client = fakeClient([
    { rows: [] },
    { rows: [] },
    { rows: [{ version: 1, name: "initial", checksum: checksum("ALTERED") }] },
    { rows: [] }
  ]);

  await assert.rejects(() => runMigrations(client, [migration]), /nachtraeglich veraendert/);
});

test("wendet neue Migration und Protokolleintrag in einer Transaktion an", async () => {
  const migration = {
    version: 2,
    name: "sync",
    filename: "002_sync.sql",
    checksum: checksum("SELECT 2;"),
    sql: "SELECT 2;"
  };
  const calls = [];
  const client = {
    async query(text, parameters) {
      calls.push({ text: String(text).trim(), parameters });
      if (String(text).includes("SELECT version, name, checksum")) return { rows: [] };
      return { rows: [] };
    }
  };

  await runMigrations(client, [migration]);

  const statements = calls.map((call) => call.text);
  const begin = statements.indexOf("BEGIN");
  const sql = statements.indexOf("SELECT 2;");
  const insert = statements.findIndex((statement) => statement.startsWith("INSERT INTO schema_migrations"));
  const commit = statements.indexOf("COMMIT");
  assert.ok(begin < sql && sql < insert && insert < commit);
  assert.deepEqual(calls[insert].parameters, [2, "sync", migration.checksum]);
});

function fakeClient(responses) {
  return {
    async query() {
      return responses.shift() || { rows: [] };
    }
  };
}
