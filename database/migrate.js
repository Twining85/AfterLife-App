import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const { Client } = pg;
const migrationPattern = /^(\d{3,})_([a-z0-9_]+)\.sql$/;

export async function discoverMigrations(migrationsDirectory) {
  const entries = await fs.readdir(migrationsDirectory, { withFileTypes: true });
  const migrations = [];

  for (const entry of entries) {
    if (!entry.isFile()) continue;
    const match = entry.name.match(migrationPattern);
    if (!match) continue;
    const sql = await fs.readFile(path.join(migrationsDirectory, entry.name), "utf8");
    migrations.push({
      version: Number(match[1]),
      name: match[2],
      filename: entry.name,
      checksum: checksum(sql),
      sql
    });
  }

  migrations.sort((left, right) => left.version - right.version);
  for (let index = 0; index < migrations.length; index += 1) {
    if (index > 0 && migrations[index - 1].version === migrations[index].version) {
      throw new Error(`Doppelte Migrationsversion ${migrations[index].version}`);
    }
  }
  return migrations;
}

export function checksum(sql) {
  return crypto.createHash("sha256").update(sql, "utf8").digest("hex");
}

export async function runMigrations(client, migrations, { baselineExisting = false } = {}) {
  await client.query("SELECT pg_advisory_lock(hashtext('tschluessli_schema_migrations'))");
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version integer PRIMARY KEY CHECK (version > 0),
        name text NOT NULL,
        checksum text NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}$'),
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    if (baselineExisting) await baselineInitialMigration(client, migrations);

    const appliedResult = await client.query(
      "SELECT version, name, checksum FROM schema_migrations ORDER BY version"
    );
    const applied = new Map(appliedResult.rows.map((row) => [Number(row.version), row]));

    for (const migration of migrations) {
      const existing = applied.get(migration.version);
      if (existing) {
        if (existing.name !== migration.name || existing.checksum !== migration.checksum) {
          throw new Error(`Migration ${migration.filename} wurde nachtraeglich veraendert`);
        }
        continue;
      }

      await client.query("BEGIN");
      try {
        await client.query(migration.sql);
        await client.query(
          `INSERT INTO schema_migrations (version, name, checksum)
           VALUES ($1, $2, $3)`,
          [migration.version, migration.name, migration.checksum]
        );
        await client.query("COMMIT");
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }
  } finally {
    await client.query("SELECT pg_advisory_unlock(hashtext('tschluessli_schema_migrations'))");
  }
}

async function baselineInitialMigration(client, migrations) {
  const initial = migrations.find((migration) => migration.version === 1);
  if (!initial) throw new Error("Initialmigration 001 fehlt");

  const existing = await client.query("SELECT 1 FROM schema_migrations WHERE version = 1");
  if (existing.rows.length > 0) return;

  const schemaResult = await client.query(
    `SELECT to_regclass('public.app_users') AS app_users,
            to_regclass('public.user_sessions') AS user_sessions,
            to_regclass('public.dossiers') AS dossiers,
            to_regclass('public.dossier_sections') AS dossier_sections`
  );
  const schema = schemaResult.rows[0] || {};
  if (!schema.app_users || !schema.user_sessions || !schema.dossiers || !schema.dossier_sections) {
    throw new Error("Baseline abgelehnt: bestehendes Initialschema ist unvollstaendig");
  }

  await client.query(
    `INSERT INTO schema_migrations (version, name, checksum)
     VALUES ($1, $2, $3)`,
    [initial.version, initial.name, initial.checksum]
  );
}

function sslOptions() {
  if (process.env.DATABASE_SSL_MODE === "disable") return false;
  const ca = process.env.DATABASE_SSL_CA?.replace(/\\n/g, "\n");
  return ca ? { rejectUnauthorized: true, ca } : { rejectUnauthorized: true };
}

async function main() {
  const connectionString = firstPostgresConnectionString(
    process.env.DATABASE_DIRECT_URL,
    process.env.DATABASE_URL_UNPOOLED,
    process.env.POSTGRES_URL_NON_POOLING,
    process.env.TSCHLUESSLI_DATABASE_URL
  );
  if (!connectionString) {
    throw new Error("DATABASE_DIRECT_URL oder direkte Anbieter-URL fehlt");
  }

  const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
  const migrations = await discoverMigrations(path.join(currentDirectory, "migrations"));
  const client = new Client({ connectionString, ssl: sslOptions() });
  await client.connect();
  try {
    await runMigrations(client, migrations, {
      baselineExisting: process.argv.includes("--baseline-existing")
    });
  } finally {
    await client.end();
  }
}

export function firstPostgresConnectionString(...candidates) {
  for (const candidate of candidates) {
    if (!candidate) continue;
    try {
      const parsed = new URL(candidate);
      if (
        (parsed.protocol === "postgres:" || parsed.protocol === "postgresql:")
        && parsed.hostname.includes(".")
      ) {
        return candidate;
      }
    } catch {
      // Ungueltige Marketplace-Platzhalter werden zugunsten der naechsten URL ignoriert.
    }
  }
  return null;
}

const isCommandLine = process.argv[1]
  && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isCommandLine) {
  main().catch((error) => {
    console.error(`Datenbankmigration fehlgeschlagen: ${error.message}`);
    process.exitCode = 1;
  });
}
