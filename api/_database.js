import fs from "node:fs";
import crypto from "node:crypto";
import pg from "pg";
import mysql from "mysql2/promise";

const { Pool: PostgreSQLPool } = pg;
let pool;

export function databaseEngine() {
  const configured = String(process.env.DATABASE_ENGINE || "").toLowerCase();
  if (configured) {
    if (!["postgresql", "mysql"].includes(configured)) throw new Error("DATABASE_ENGINE muss postgresql oder mysql sein");
    return configured;
  }
  return process.env.MYSQL_URL ? "mysql" : "postgresql";
}

export function databasePool() {
  if (pool) return pool;
  pool = databaseEngine() === "mysql" ? createMySQLPool() : createPostgreSQLPool();
  return pool;
}

function createPostgreSQLPool() {
  const connectionString = process.env.TSCHLUESSLI_DATABASE_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("PostgreSQL-Verbindung fehlt");
  return new PostgreSQLPool({
    connectionString,
    max: positiveInteger(process.env.DATABASE_POOL_MAX, 5),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    ssl: process.env.DATABASE_SSL === "disable" ? false : { rejectUnauthorized: true }
  });
}

function createMySQLPool() {
  validateApplicationEnvironment();
  const uri = process.env.MYSQL_URL;
  if (!uri) throw new Error("MYSQL_URL fehlt");
  const parsed = new URL(uri);
  if (parsed.protocol !== "mysql:") throw new Error("MYSQL_URL muss mysql:// verwenden");
  const database = decodeURIComponent(parsed.pathname.replace(/^\//, ""));
  const expected = process.env.MYSQL_EXPECTED_DATABASE;
  if (!expected && process.env.NODE_ENV !== "test") throw new Error("MYSQL_EXPECTED_DATABASE fehlt");
  if (!database || (expected && database !== expected)) throw new Error("MYSQL_URL verwendet nicht die erwartete Datenbank");
  return new MySQLPoolAdapter(mysql.createPool({
    uri,
    waitForConnections: true,
    connectionLimit: positiveInteger(process.env.DATABASE_POOL_MAX, 5),
    queueLimit: 20,
    enableKeepAlive: true,
    ssl: mysqlTLSOptions(),
    supportBigNumbers: true,
    bigNumberStrings: true
  }), database);
}

function validateApplicationEnvironment() {
  if (process.env.NODE_ENV === "test") return;
  if (!["development", "staging", "production"].includes(process.env.APP_ENV)) {
    throw new Error("APP_ENV muss development, staging oder production sein");
  }
}

function mysqlTLSOptions() {
  if (process.env.MYSQL_SSL_MODE === "disable") {
    if (process.env.NODE_ENV !== "test") throw new Error("MySQL-TLS darf ausserhalb von Tests nicht deaktiviert werden");
    return undefined;
  }
  const caPath = process.env.MYSQL_SSL_CA_PATH;
  const inlineCA = process.env.MYSQL_SSL_CA?.replace(/\\n/g, "\n");
  if (!caPath && !inlineCA) throw new Error("MYSQL_SSL_CA_PATH oder MYSQL_SSL_CA fehlt");
  const ca = caPath ? fs.readFileSync(caPath, "utf8") : inlineCA;
  if (!ca.includes("BEGIN CERTIFICATE")) throw new Error("MySQL-CA ist ungueltig");
  return { ca, rejectUnauthorized: true };
}

class MySQLPoolAdapter {
  constructor(nativePool, database) { this.nativePool = nativePool; this.database = database; this.engine = "mysql"; }
  async query(text, parameters = []) {
    const connection = await this.nativePool.getConnection();
    try { return await mysqlQuery(connection, text, parameters); } finally { connection.release(); }
  }
  async connect() { return new MySQLClientAdapter(await this.nativePool.getConnection(), this.database); }
  async end() { await this.nativePool.end(); }
}

class MySQLClientAdapter {
  constructor(connection, database) { this.connection = connection; this.database = database; this.engine = "mysql"; this.locks = new Set(); }
  async query(text, parameters = []) {
    const command = String(text).trim().toUpperCase();
    if (command === "BEGIN") { await this.connection.beginTransaction(); return emptyResult(); }
    if (command === "COMMIT") { await this.connection.commit(); await this.releaseLocks(); return emptyResult(); }
    if (command === "ROLLBACK") { await this.connection.rollback(); await this.releaseLocks(); return emptyResult(); }
    if (String(text).includes("set_config('app.user_id'")) return emptyResult();
    return mysqlQuery(this.connection, text, parameters);
  }
  async acquireLock(name, timeoutSeconds = 10) {
    const lockName = mysqlLockName(name);
    const [rows] = await this.connection.execute("SELECT GET_LOCK(?, ?) AS acquired", [lockName, timeoutSeconds]);
    if (Number(rows[0]?.acquired) !== 1) throw new Error("Datenbanksperre konnte nicht bezogen werden");
    this.locks.add(lockName);
  }
  async releaseLocks() {
    for (const name of this.locks) await this.connection.execute("SELECT RELEASE_LOCK(?)", [name]);
    this.locks.clear();
  }
  release() { this.connection.release(); }
}

export function mysqlLockName(name) {
  const digest = crypto.createHash("sha256").update(String(name)).digest("hex");
  return `tschluessli:${digest.slice(0, 52)}`;
}

async function mysqlQuery(connection, text, parameters) {
  const converted = convertPostgreSQLQuery(text, parameters);
  const [rows] = await connection.execute(converted.sql, converted.parameters);
  if (Array.isArray(rows)) return { rows, rowCount: rows.length };
  return { rows: [], rowCount: Number(rows.affectedRows || 0), insertId: rows.insertId, changedRows: Number(rows.changedRows || 0) };
}

export function convertPostgreSQLQuery(text, parameters = []) {
  const reordered = [];
  const sql = String(text)
    .replace(/\$(\d+)(?:::(?:jsonb|bigint|integer))?/g, (_, index) => { reordered.push(parameters[Number(index) - 1]); return "?"; })
    .replace(/FOR UPDATE OF\s+\w+/gi, "FOR UPDATE")
    .replace(/\bnow\(\)/gi, "CURRENT_TIMESTAMP(6)");
  return { sql, parameters: reordered };
}

export async function withUserTransaction(userID, operation) {
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(String(userID))) {
    throw new Error("Ungültiger Benutzerkontext");
  }
  const client = await databasePool().connect();
  try {
    await client.query("BEGIN");
    if (client.engine !== "mysql") await client.query("SELECT set_config('app.user_id', $1, true)", [userID]);
    const result = await operation(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function databaseHealth() {
  const engine = databaseEngine();
  const result = engine === "mysql"
    ? await databasePool().query(
      "SELECT DATABASE() AS database_name, 1 AS healthy, (SELECT MAX(version) FROM schema_migrations) AS schema_version"
    )
    : await databasePool().query(
      "SELECT current_database() AS database_name, 1 AS healthy, (SELECT MAX(version) FROM schema_migrations) AS schema_version"
    );
  const minimumSchemaVersion = engine === "mysql" ? 1 : 8;
  return {
    engine,
    database: result.rows[0]?.database_name,
    healthy: Number(result.rows[0]?.healthy) === 1,
    schemaReady: Number(result.rows[0]?.schema_version) >= minimumSchemaVersion
  };
}

function positiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}
function emptyResult() { return { rows: [], rowCount: 0 }; }

export function resetDatabasePoolForTests() {
  pool = undefined;
}

export function setDatabasePoolForTests(testPool) {
  if (process.env.NODE_ENV !== "test") throw new Error("Test-Datenbank darf nur in Tests gesetzt werden");
  pool = testPool;
}
