import pg from "pg";

const { Pool } = pg;
let pool;

export function databasePool() {
  if (pool) return pool;
  const connectionString = process.env.TSCHLUESSLI_DATABASE_URL
    || process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Datenbankverbindung fehlt");
  pool = new Pool({
    connectionString,
    max: 5,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    ssl: process.env.DATABASE_SSL === "disable" ? false : { rejectUnauthorized: true }
  });
  return pool;
}

export async function withUserTransaction(userID, operation) {
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(String(userID))) {
    throw new Error("Ungültiger Benutzerkontext");
  }
  const client = await databasePool().connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.user_id', $1, true)", [userID]);
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

export function resetDatabasePoolForTests() {
  pool = undefined;
}
