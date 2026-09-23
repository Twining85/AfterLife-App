import crypto from "node:crypto";
import { authenticatedUser, refreshSession, saveSession, verifyPassword } from "../_auth.js";
import { databasePool, withUserTransaction } from "../_database.js";
import { sendEmail } from "../_email-service.js";
import { createActionGrant, createChallenge, createCode, expiresAt, readVerifiedChallenge, verifyActionGrant } from "../email-verification/_challenge.js";
import { normalizeEmail, rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (req.method === "DELETE") return handleAccountDelete(req, res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (req.body?.action === "refresh-session") return handleSessionRefresh(req, res);
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
    return res.status(200).json({
      userID: user.id,
      dossierID,
      sessionToken: session.token,
      expiresAt: session.expiresAt.toISOString(),
      refreshToken: session.refreshToken,
      refreshExpiresAt: session.refreshExpiresAt.toISOString()
    });
  } catch (error) {
    console.error("Anmeldung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}

async function handleSessionRefresh(req, res) {
  if (!rateLimit(req, res, {
    namespace: "account-refresh",
    limit: 20,
    windowMilliseconds: 15 * 60 * 1000
  })) return;

  try {
    const session = await refreshSession(req.body?.refreshToken);
    if (!session) return res.status(401).json({ error: "Sitzung kann nicht erneuert werden" });
    return res.status(200).json({
      userID: session.userID,
      sessionToken: session.token,
      expiresAt: session.expiresAt.toISOString(),
      refreshToken: session.refreshToken,
      refreshExpiresAt: session.refreshExpiresAt.toISOString()
    });
  } catch (error) {
    console.error("Sitzungserneuerung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}

export async function deleteAccountForUser({ userID, pool = databasePool() }) {
  const client = await pool.connect();
  const isMySQL = client.engine === "mysql";
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.user_id', $1, true)", [userID]);

    const userResult = await client.query("SELECT email FROM app_users WHERE id = $1 FOR UPDATE", [userID]);
    const email = userResult.rows[0]?.email;
    if (!email) throw new Error("Konto nicht gefunden");

    const dossierResult = await client.query(
      "SELECT id FROM dossiers WHERE owner_user_id = $1 FOR UPDATE",
      [userID]
    );
    const dossierIDs = dossierResult.rows.map((row) => row.id);

    // Beziehungen zu fremden Dossiers zuerst entfernen. Ein gelöschter Benutzer
    // darf weder als Vertrauensperson noch als eingeladene Person zurückbleiben.
    await client.query("DELETE FROM dossier_access_grants WHERE user_id = $1", [userID]);
    if (isMySQL) await client.query("DELETE FROM dossier_key_envelopes WHERE recipient_user_id = $1", [userID]);
    await client.query(
      `DELETE FROM dossier_access_grants
        WHERE invitation_id IN (
          SELECT id FROM dossier_invitations
           WHERE requester_user_id = $1 OR invited_email = $2 OR requester_email = $2
        )`,
      [userID, email]
    );
    await client.query(
      "DELETE FROM dossier_invitations WHERE requester_user_id = $1 OR invited_email = $2 OR requester_email = $2",
      [userID, email]
    );

    // Nicht jedes bestehende DEV-Schema besitzt garantiert alle CASCADE-Regeln.
    // Deshalb werden sämtliche dossierbezogenen Tabellen explizit bereinigt.
    for (const dossierID of dossierIDs) {
      await client.query("DELETE FROM dossier_access_grants WHERE dossier_id = $1", [dossierID]);
      if (isMySQL) {
        await client.query("DELETE FROM dossier_key_envelopes WHERE dossier_id = $1", [dossierID]);
        await client.query("DELETE FROM stored_files WHERE dossier_id = $1", [dossierID]);
      }
      await client.query("DELETE FROM dossier_invitations WHERE dossier_id = $1", [dossierID]);
      await client.query("DELETE FROM sync_changes WHERE dossier_id = $1", [dossierID]);
      await client.query("DELETE FROM dossier_sections WHERE dossier_id = $1", [dossierID]);
      if (isMySQL) await client.query("DELETE FROM audit_log WHERE target_dossier_id = $1", [dossierID]);
      await client.query("DELETE FROM dossiers WHERE id = $1", [dossierID]);
    }

    await client.query("DELETE FROM sync_idempotency WHERE owner_user_id = $1", [userID]);
    await client.query("DELETE FROM push_device_tokens WHERE user_id = $1", [userID]);
    await client.query("DELETE FROM password_reset_challenges WHERE user_id = $1", [userID]);
    await client.query("DELETE FROM user_sessions WHERE user_id = $1", [userID]);
    if (isMySQL) {
      await client.query("DELETE FROM admin_users WHERE user_id = $1", [userID]);
      await client.query("DELETE FROM audit_log WHERE actor_user_id = $1 OR target_user_id = $1", [userID]);
    }

    // Falls der Benutzer ein fremdes Dossier ursprünglich angelegt hat, wird nur
    // die Erstellerreferenz neutralisiert; das Dossier des anderen Users bleibt bestehen.
    await client.query(
      "UPDATE dossiers SET created_by_user_id = owner_user_id WHERE created_by_user_id = $1 AND owner_user_id <> $1",
      [userID]
    );

    const result = client.engine === "mysql"
      ? await client.query("DELETE FROM app_users WHERE id = $1", [userID])
      : await client.query("DELETE FROM app_users WHERE id = $1 RETURNING id", [userID]);
    if (result.rowCount !== 1) throw new Error("Konto nicht gefunden");

    await verifyAccountDeletion(client, { userID, email, dossierIDs, isMySQL });
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function verifyAccountDeletion(client, { userID, email, dossierIDs, isMySQL }) {
  const checks = [
    ["SELECT COUNT(*) AS count FROM app_users WHERE id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM dossiers WHERE owner_user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM dossier_sections WHERE owner_user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM sync_changes WHERE owner_user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM sync_idempotency WHERE owner_user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM dossier_access_grants WHERE user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM dossier_invitations WHERE owner_user_id = $1 OR requester_user_id = $1 OR invited_email = $2 OR requester_email = $2", [userID, email]],
    ["SELECT COUNT(*) AS count FROM user_sessions WHERE user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM password_reset_challenges WHERE user_id = $1", [userID]],
    ["SELECT COUNT(*) AS count FROM push_device_tokens WHERE user_id = $1", [userID]]
  ];
  if (isMySQL) {
    checks.push(["SELECT COUNT(*) AS count FROM stored_files WHERE owner_user_id = $1", [userID]]);
    checks.push(["SELECT COUNT(*) AS count FROM dossier_key_envelopes WHERE recipient_user_id = $1", [userID]]);
    checks.push(["SELECT COUNT(*) AS count FROM audit_log WHERE actor_user_id = $1 OR target_user_id = $1", [userID]]);
  }
  for (const dossierID of dossierIDs) {
    checks.push(["SELECT COUNT(*) AS count FROM dossier_sections WHERE dossier_id = $1", [dossierID]]);
    checks.push(["SELECT COUNT(*) AS count FROM sync_changes WHERE dossier_id = $1", [dossierID]]);
    checks.push(["SELECT COUNT(*) AS count FROM dossier_invitations WHERE dossier_id = $1", [dossierID]]);
    checks.push(["SELECT COUNT(*) AS count FROM dossier_access_grants WHERE dossier_id = $1", [dossierID]]);
    if (isMySQL) {
      checks.push(["SELECT COUNT(*) AS count FROM stored_files WHERE dossier_id = $1", [dossierID]]);
      checks.push(["SELECT COUNT(*) AS count FROM dossier_key_envelopes WHERE dossier_id = $1", [dossierID]]);
      checks.push(["SELECT COUNT(*) AS count FROM audit_log WHERE target_dossier_id = $1", [dossierID]]);
    }
  }
  for (const [sql, parameters] of checks) {
    const result = await client.query(sql, parameters);
    if (Number(result.rows[0]?.count || 0) !== 0) {
      throw new Error("Kontolöschung hinterliess Cloud-Daten");
    }
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
