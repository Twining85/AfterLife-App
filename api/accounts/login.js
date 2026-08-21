import crypto from "node:crypto";
import { authenticatedUser, saveSession, verifyPassword } from "../_auth.js";
import { databasePool, withUserTransaction } from "../_database.js";
import { sendEmail } from "../_email-service.js";
import { createActionGrant, createChallenge, createCode, expiresAt, readVerifiedChallenge, verifyActionGrant } from "../email-verification/_challenge.js";
import { normalizeEmail, rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (req.method === "DELETE") return handleAccountDelete(req, res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (String(req.body?.action || "").startsWith("dossier-reset-")) {
    return handleDossierReset(req, res);
  }
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
    const client = await databasePool().connect();
    let dossierID = null;
    try {
      await client.query("BEGIN");
      await client.query("SELECT set_config('app.user_id', $1, true)", [user.id]);
      const dossierResult = await client.query(
        `SELECT id FROM dossiers
          WHERE owner_user_id = $1 AND is_primary AND is_active
          ORDER BY created_at ASC LIMIT 1`,
        [user.id]
      );
      dossierID = dossierResult.rows[0]?.id || null;
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    const session = await saveSession(user.id);
    return res.status(200).json({ userID: user.id, dossierID, sessionToken: session.token, expiresAt: session.expiresAt.toISOString() });
  } catch (error) {
    console.error("Anmeldung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}

export async function deleteAccountForUser({ userID, pool = databasePool() }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.user_id', $1, true)", [userID]);
    await client.query("DELETE FROM dossiers WHERE owner_user_id = $1", [userID]);
    const result = await client.query(
      "DELETE FROM app_users WHERE id = $1 RETURNING id",
      [userID]
    );
    if (result.rowCount !== 1) throw new Error("Konto nicht gefunden");
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function handleAccountDelete(req, res) {
  if (!rateLimit(req, res, {
    namespace: "account-delete",
    limit: 3,
    windowMilliseconds: 60 * 60 * 1000
  })) return;
  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });
  try {
    await deleteAccountForUser({ userID: user.id });
    return res.status(204).end();
  } catch (error) {
    console.error("Kontolöschung:", error);
    return res.status(500).json({ error: "Das Konto konnte nicht vollständig gelöscht werden" });
  }
}

async function handleDossierReset(req, res) {
  const action = String(req.body?.action || "");
  if (!rateLimit(req, res, { namespace: action, limit: action === "dossier-reset-confirm" ? 10 : 3, windowMilliseconds: 60 * 60 * 1000 })) return;
  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });
  try {
    if (action === "dossier-reset-request") {
      const code = createCode();
      const challengeToken = createChallenge(user.email, code, "dossier-reset");
      await sendEmail({
        to: user.email,
        subject: `${code} ist dein Code zum Zurücksetzen des Dossiers`,
        text: `Mit diesem Code bestätigst du das Zurücksetzen deines Tschlüssli-Dossiers:\n\n${code}\n\nDer Code ist 10 Minuten gültig. Wenn du dies nicht angefordert hast, ignoriere diese E-Mail.`,
        html: `<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#1f1f1d;text-align:center;line-height:1.5"><p>Code zum Zurücksetzen deines Tschlüssli-Dossiers:</p><p style="font-size:32px;font-weight:700;letter-spacing:6px;color:#295c6b">${code}</p><p>Der Code ist 10 Minuten gültig. Wenn du dies nicht angefordert hast, ignoriere diese E-Mail.</p></div>`
      });
      return res.status(200).json({ challengeToken, expiresAt: expiresAt() });
    }
    if (action === "dossier-reset-confirm") {
      const code = String(req.body?.code || "").trim();
      const verified = /^\d{6}$/.test(code) ? readVerifiedChallenge(req.body?.challengeToken, code, "dossier-reset") : null;
      if (!verified || verified.email !== user.email) return res.status(400).json({ error: "Code ungültig oder abgelaufen" });
      return res.status(200).json({ resetGrant: createActionGrant(user.email, "dossier-reset") });
    }
    if (action === "dossier-reset-execute") {
      if (req.body?.confirmation !== "DOSSIER LÖSCHEN" || !verifyActionGrant(req.body?.resetGrant, user.email, "dossier-reset")) {
        return res.status(400).json({ error: "Bestätigung ungültig oder abgelaufen" });
      }
      const dossierID = crypto.randomUUID();
      await withUserTransaction(user.id, async (client) => {
        await client.query("DELETE FROM dossiers WHERE owner_user_id = $1", [user.id]);
        await client.query(`INSERT INTO dossiers (id, owner_user_id, created_by_user_id, title) VALUES ($1, $2, $2, $3)`, [dossierID, user.id, "Mein Dossier"]);
      });
      return res.status(200).json({ dossierID });
    }
    return res.status(400).json({ error: "Ungültige Reset-Aktion" });
  } catch (error) {
    console.error("Dossier zurücksetzen:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
