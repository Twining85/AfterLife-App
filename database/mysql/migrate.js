import crypto from "node:crypto";
import fsSync from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import mysql from "mysql2/promise";

const migrationPattern = /^(\d{3,})_([a-z0-9_]+)\.sql$/;

export async function discoverMySQLMigrations(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const migrations = [];
  for (const entry of entries) {
    const match = entry.isFile() ? entry.name.match(migrationPattern) : null;
    if (!match) continue;
    const sql = await fs.readFile(path.join(directory, entry.name), "utf8");
    migrations.push({
      version: Number(match[1]),
      name: match[2],
      filename: entry.name,
      checksum: crypto.createHash("sha256").update(sql, "utf8").digest("hex"),
      sql
    });
  }
  migrations.sort((left, right) => left.version - right.version);
  for (let index = 1; index < migrations.length; index += 1) {
    if (migrations[index - 1].version === migrations[index].version) {
      throw new Error(`Doppelte MySQL-Migrationsversion ${migrations[index].version}`);
    }
  }
  return migrations;
}

export async function runMySQLMigrations(connection, migrations) {
  const [lockRows] = await connection.query(
    "SELECT GET_LOCK('tschluessli_schema_migrations', 30) AS acquired"
  );
  if (Number(lockRows[0]?.acquired) !== 1) throw new Error("Migrationssperre nicht erhalten");
  try {
    await connection.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INT UNSIGNED PRIMARY KEY,
        name VARCHAR(190) NOT NULL,
        checksum CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        applied_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
      ) ENGINE=InnoDB
    `);
    const [rows] = await connection.query(
      "SELECT version, name, checksum FROM schema_migrations ORDER BY version"
    );
    const applied = new Map(rows.map((row) => [Number(row.version), row]));
    for (const migration of migrations) {
      const existing = applied.get(migration.version);
      if (existing) {
        if (existing.name !== migration.name || existing.checksum !== migration.checksum) {
          throw new Error(`Migration ${migration.filename} wurde nachtraeglich veraendert`);
        }
        continue;
      }
      await connection.query(migration.sql);
      if (migration.version === 1) await verifyInitialSchema(connection);
      await connection.execute(
        "INSERT INTO schema_migrations (version, name, checksum) VALUES (?, ?, ?)",
        [migration.version, migration.name, migration.checksum]
      );
    }
  } finally {
    await connection.query("SELECT RELEASE_LOCK('tschluessli_schema_migrations')");
  }
}

async function verifyInitialSchema(connection) {
  const expected = [
    "app_users", "user_sessions", "password_reset_challenges", "dossiers",
    "dossier_sections", "sync_changes", "sync_idempotency", "push_device_tokens",
    "dossier_invitations", "dossier_access_grants", "dossier_key_envelopes",
    "stored_files", "admin_users", "audit_log"
  ];
  const placeholders = expected.map(() => "?").join(",");
  const [rows] = await connection.execute(
    `SELECT table_name FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name IN (${placeholders})`,
    expected
  );
  const actual = new Set(rows.map((row) => row.TABLE_NAME || row.table_name));
  const missing = expected.filter((table) => !actual.has(table));
  if (missing.length) throw new Error(`Initialschema unvollstaendig: ${missing.join(", ")}`);
}

function connectionOptions() {
  const uri = process.env.MYSQL_DIRECT_URL || process.env.MYSQL_URL;
  if (!uri) throw new Error("MYSQL_DIRECT_URL oder MYSQL_URL fehlt");
  const parsed = new URL(uri);
  const database = decodeURIComponent(parsed.pathname.replace(/^\//, ""));
  const expected = process.env.MYSQL_EXPECTED_DATABASE;
  if (!expected && process.env.NODE_ENV !== "test") throw new Error("MYSQL_EXPECTED_DATABASE fehlt");
  if (process.env.NODE_ENV !== "test" && !["development", "staging", "production"].includes(process.env.APP_ENV)) {
    throw new Error("APP_ENV muss development, staging oder production sein");
  }
  if (parsed.protocol !== "mysql:" || !database || (expected && database !== expected)) {
    throw new Error("MySQL-Migrations-URL verwendet nicht die erwartete Datenbank");
  }
  const caPath = process.env.MYSQL_SSL_CA_PATH;
  const ca = caPath
    ? fsSync.readFileSync(caPath, "utf8")
    : process.env.MYSQL_SSL_CA?.replace(/\\n/g, "\n");
  if (process.env.MYSQL_SSL_MODE !== "disable" && (!ca || !ca.includes("BEGIN CERTIFICATE"))) {
    throw new Error("Gueltige MySQL-CA fehlt");
  }
  return {
    uri,
    multipleStatements: true,
    ssl: process.env.MYSQL_SSL_MODE === "disable" ? undefined : { rejectUnauthorized: true, ...(ca ? { ca } : {}) }
  };
}

async function main() {
  const directory = path.dirname(fileURLToPath(import.meta.url));
  const migrations = await discoverMySQLMigrations(path.join(directory, "migrations"));
  const options = connectionOptions();
  const connection = await mysql.createConnection(options);
  try {
    await runMySQLMigrations(connection, migrations);
  } finally {
    await connection.end();
  }
}

const isCommandLine = process.argv[1]
  && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isCommandLine) {
  main().catch((error) => {
    console.error(`MySQL-Migration fehlgeschlagen: ${error.message}`);
    process.exitCode = 1;
  });
}
