import { hashPassword, hashSessionToken } from "../../_auth.js";
import { databasePool } from "../../_database.js";
import { rateLimit, requireJSON, requireMethod, secureResponse } from "../../_security.js";
import { readVerifiedChallenge } from "../../email-verification/_challenge.js";

export async function resetPassword({ challengeToken, code, newPassword, pool = databasePool() }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `SELECT c.id, c.user_id, c.attempts, u.email
         FROM password_reset_challenges c
         JOIN app_users u ON u.id = c.user_id
        WHERE c.token_hash = $1
          AND c.consumed_at IS NULL
          AND c.expires_at > now()
          AND u.disabled_at IS NULL
        FOR UPDATE`,
      [hashSessionToken(challengeToken)]
    );
    const challenge = result.rows[0];
    const verified = /^\d{6}$/.test(String(code))
      ? readVerifiedChallenge(challengeToken, String(code), "password-reset")
      : null;
    if (!challenge || challenge.attempts >= 5 || !verified || verified.email !== challenge.email) {
      if (challenge && challenge.attempts < 5) {
        await client.query(
          `UPDATE password_reset_challenges SET attempts = attempts + 1 WHERE id = $1`,
          [challenge.id]
        );
      }
      await client.query("COMMIT");
      const error = new Error("Code ungültig oder abgelaufen");
      error.code = "INVALID_RESET_CODE";
      throw error;
    }
    const password = await hashPassword(newPassword);
    await client.query(
      `UPDATE app_users
          SET password_hash = $2, password_salt = $3, updated_at = now()
        WHERE id = $1`,
      [challenge.user_id, password.hash, password.salt]
    );
    await client.query(
      `UPDATE password_reset_challenges SET consumed_at = now() WHERE id = $1`,
      [challenge.id]
    );
    await client.query(
      `UPDATE user_sessions SET revoked_at = now()
        WHERE user_id = $1 AND revoked_at IS NULL`,
      [challenge.user_id]
    );
    await client.query("COMMIT");
  } catch (error) {
    if (error?.code === "INVALID_RESET_CODE") throw error;
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "password-reset-confirm", limit: 10, windowMilliseconds: 30 * 60 * 1000 })) return;
  try {
    await resetPassword({
      challengeToken: String(req.body?.challengeToken || ""),
      code: String(req.body?.code || "").trim(),
      newPassword: req.body?.newPassword
    });
    return res.status(204).end();
  } catch (error) {
    if (error?.code === "INVALID_RESET_CODE") return res.status(400).json({ error: error.message });
    if (/12 bis 128/.test(String(error?.message))) return res.status(400).json({ error: error.message });
    console.error("Passwort-Reset bestätigen:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
