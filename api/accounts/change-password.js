import { authenticatedUser, hashPassword, verifyPassword } from "../_auth.js";
import { databasePool } from "../_database.js";
import { rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";

export async function changePasswordForUser({ userID, currentPassword, newPassword, pool = databasePool() }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `SELECT password_hash, password_salt
         FROM app_users
        WHERE id = $1 AND disabled_at IS NULL
        FOR UPDATE`,
      [userID]
    );
    const user = result.rows[0];
    if (!user || !await verifyPassword(currentPassword, user.password_salt, user.password_hash)) {
      const error = new Error("Das bisherige Passwort ist nicht korrekt");
      error.code = "INVALID_CURRENT_PASSWORD";
      throw error;
    }
    if (currentPassword === newPassword) {
      const error = new Error("Das neue Passwort muss sich vom bisherigen Passwort unterscheiden");
      error.code = "PASSWORD_UNCHANGED";
      throw error;
    }
    const password = await hashPassword(newPassword);
    await client.query(
      `UPDATE app_users
          SET password_hash = $2, password_salt = $3, updated_at = now()
        WHERE id = $1`,
      [userID, password.hash, password.salt]
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "account-change-password", limit: 5, windowMilliseconds: 15 * 60 * 1000 })) return;

  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung abgelaufen" });

  const currentPassword = String(req.body?.currentPassword || "");
  const newPassword = String(req.body?.newPassword || "");
  try {
    await changePasswordForUser({ userID: user.id, currentPassword, newPassword });
    return res.status(204).end();
  } catch (error) {
    if (error?.code === "INVALID_CURRENT_PASSWORD") {
      return res.status(401).json({ error: error.message });
    }
    if (error?.code === "PASSWORD_UNCHANGED" || /12 bis 128/.test(String(error?.message))) {
      return res.status(400).json({ error: error.message });
    }
    console.error("Passwortänderung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
