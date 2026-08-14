import crypto from "node:crypto";
import { promisify } from "node:util";
import { databasePool } from "./_database.js";

const scrypt = promisify(crypto.scrypt);
const sessionLifetimeMilliseconds = 30 * 24 * 60 * 60 * 1000;

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

export function hashSessionToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

export async function saveSession(userID) {
  const token = createSessionToken();
  const expiresAt = new Date(Date.now() + sessionLifetimeMilliseconds);
  await databasePool().query(
    `INSERT INTO user_sessions (user_id, token_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [userID, hashSessionToken(token), expiresAt]
  );
  return { token, expiresAt };
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
