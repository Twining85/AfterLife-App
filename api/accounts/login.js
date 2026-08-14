import { saveSession, verifyPassword } from "../_auth.js";
import { databasePool } from "../_database.js";
import { normalizeEmail, rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "account-login", limit: 10, windowMilliseconds: 15 * 60 * 1000 })) return;

  const email = normalizeEmail(req.body?.email);
  const password = String(req.body?.password || "");
  try {
    const result = email ? await databasePool().query(
      `SELECT id, password_hash, password_salt FROM app_users
        WHERE email = $1 AND disabled_at IS NULL`, [email]
    ) : { rows: [] };
    const user = result.rows[0];
    if (!user || !await verifyPassword(password, user.password_salt, user.password_hash)) {
      return res.status(401).json({ error: "E-Mail oder Passwort falsch" });
    }
    const session = await saveSession(user.id);
    return res.status(200).json({ userID: user.id, sessionToken: session.token, expiresAt: session.expiresAt.toISOString() });
  } catch (error) {
    console.error("Anmeldung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
