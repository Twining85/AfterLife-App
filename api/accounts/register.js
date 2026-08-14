import crypto from "node:crypto";
import { hashPassword, saveSession } from "../_auth.js";
import { databasePool } from "../_database.js";
import { verifyRegistrationGrant } from "../email-verification/_challenge.js";
import { normalizeEmail, rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "account-register", limit: 5, windowMilliseconds: 60 * 60 * 1000 })) return;

  const email = normalizeEmail(req.body?.email);
  const password = req.body?.password;
  if (!email || !verifyRegistrationGrant(req.body?.registrationGrant, email)) {
    return res.status(400).json({ error: "E-Mail-Verifizierung ungültig oder abgelaufen" });
  }

  try {
    const passwordData = await hashPassword(password);
    const userID = crypto.randomUUID();
    const dossierID = crypto.randomUUID();
    const client = await databasePool().connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO app_users (id, email, password_hash, password_salt, email_verified_at)
         VALUES ($1, $2, $3, $4, now())`,
        [userID, email, passwordData.hash, passwordData.salt]
      );
      await client.query("SELECT set_config('app.user_id', $1, true)", [userID]);
      await client.query(
        `INSERT INTO dossiers (id, owner_user_id, created_by_user_id, title)
         VALUES ($1, $2, $2, $3)`,
        [dossierID, userID, "Mein Dossier"]
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    const session = await saveSession(userID);
    return res.status(201).json({ userID, dossierID, sessionToken: session.token, expiresAt: session.expiresAt.toISOString() });
  } catch (error) {
    if (error?.code === "23505") return res.status(409).json({ error: "Konto besteht bereits" });
    console.error("Kontoregistrierung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
