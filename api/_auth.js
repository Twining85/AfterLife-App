import crypto from "node:crypto";
import { promisify } from "node:util";
import { databasePool } from "./_database.js";

const scrypt = promisify(crypto.scrypt);
const sessionLifetimeMilliseconds = 30 * 24 * 60 * 60 * 1000;
const refreshLifetimeMilliseconds = 180 * 24 * 60 * 60 * 1000;

export async function hashPassword(password, salt = crypto.randomBytes(16).toString("base64url")) {
  if (typeof password !== "string" || password.length < 12 || password.length > 128) {
    throw new Error("Das Passwort muss 12 bis 128 Zeichen lang sein");
  }
  const derived = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return { salt, hash: Buffer.from(derived).toString("base64url") };
}

export async function verifyPassword(password, salt, expectedHash) {
  try {
    const { hash } = await hashPassword(password, salt);
    return safeEqual(hash, expectedHash);
  } catch {
    return false;
  }
}

export function createSessionToken() {
  return crypto.randomBytes(32).toString("base64url");
}

export function createRefreshToken() {
  return crypto.randomBytes(64).toString("base64url");
}

export function hashSessionToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

export async function saveSession(userID) {
  const token = createSessionToken();
  const refreshToken = createRefreshToken();
  const expiresAt = new Date(Date.now() + sessionLifetimeMilliseconds);
  const refreshExpiresAt = new Date(Date.now() + refreshLifetimeMilliseconds);
  await databasePool().query(
    `INSERT INTO user_sessions (
       user_id, token_hash, expires_at, refresh_token_hash, refresh_expires_at
     ) VALUES ($1, $2, $3, $4, $5)`,
    [userID, hashSessionToken(token), expiresAt, hashSessionToken(refreshToken), refreshExpiresAt]
  );
  return { token, expiresAt, refreshToken, refreshExpiresAt };
}

export async function refreshSession(refreshToken, pool = databasePool()) {
  if (!/^[A-Za-z0-9_-]{86}$/.test(String(refreshToken))) return null;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `SELECT s.id, s.user_id
         FROM user_sessions s
         JOIN app_users u ON u.id = s.user_id
        WHERE s.refresh_token_hash = $1
          AND s.refresh_expires_at > now()
          AND s.revoked_at IS NULL
          AND u.disabled_at IS NULL
        FOR UPDATE OF s`,
      [hashSessionToken(refreshToken)]
    );
    const session = result.rows[0];
    if (!session) {
      await client.query("ROLLBACK");
      return null;
    }

    const token = createSessionToken();
    const nextRefreshToken = createRefreshToken();
    const expiresAt = new Date(Date.now() + sessionLifetimeMilliseconds);
    const refreshExpiresAt = new Date(Date.now() + refreshLifetimeMilliseconds);
    await client.query(
      `UPDATE user_sessions
          SET token_hash = $1,
              expires_at = $2,
              refresh_token_hash = $3,
              refresh_expires_at = $4
        WHERE id = $5`,
      [
        hashSessionToken(token),
        expiresAt,
        hashSessionToken(nextRefreshToken),
        refreshExpiresAt,
        session.id
      ]
    );
    await client.query("COMMIT");
    return {
      userID: session.user_id,
      token,
      expiresAt,
      refreshToken: nextRefreshToken,
      refreshExpiresAt
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function authenticatedUser(req) {
  const authorization = String(req.headers?.authorization || "");
  const match = authorization.match(/^Bearer ([A-Za-z0-9_-]{43})$/);
  if (!match) return null;
  const result = await databasePool().query(
    `SELECT u.id, u.email
       FROM user_sessions s
       JOIN app_users u ON u.id = s.user_id
      WHERE s.token_hash = $1
        AND s.revoked_at IS NULL
        AND s.expires_at > now()
        AND u.disabled_at IS NULL`,
    [hashSessionToken(match[1])]
  );
  return result.rows[0] || null;
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left));
  const b = Buffer.from(String(right));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
