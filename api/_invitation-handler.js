import crypto from "node:crypto";
import { databasePool } from "./_database.js";
import { pushToUser } from "./_apns.js";

export async function handleInvitationOperation(operation, req, res, user) {
  if (operation === "device") return registerDevice(req, res, user);
  if (operation === "register-invitation") return registerInvitation(req, res, user);
  if (operation === "request-invitation") return requestInvitation(req, res, user);
  if (operation === "decide-invitation") return decideInvitation(req, res, user);
  return res.status(400).json({ error: "Unbekannte Push-Operation" });
}

async function registerDevice(req, res, user) {
  const token = String(req.body?.deviceToken || "").toLowerCase();
  const environment = String(req.body?.environment || "");
  if (!/^[0-9a-f]{64,256}$/.test(token) || !["sandbox", "production"].includes(environment)) return res.status(400).json({ error: "Ungültiges Gerätetoken" });
  await databasePool().query(
    `INSERT INTO push_device_tokens (user_id, device_token, environment) VALUES ($1, $2, $3)
     ON CONFLICT (device_token, environment) DO UPDATE SET user_id = EXCLUDED.user_id, updated_at = now()`,
    [user.id, token, environment]
  );
  return res.status(204).end();
}

async function registerInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const dossierID = String(req.body?.dossierID || "");
  const email = String(req.body?.email || "").trim().toLowerCase();
  if (!token || !/^[0-9a-f-]{36}$/i.test(dossierID) || !email.includes("@")) return res.status(400).json({ error: "Ungültige Einladung" });
  const result = await databasePool().query(
    `WITH ziel_dossier AS (
       SELECT id, owner_user_id FROM dossiers
        WHERE owner_user_id = $4 AND is_active
        ORDER BY (id = $2) DESC, is_primary DESC, created_at ASC LIMIT 1
     )
     INSERT INTO dossier_invitations (token_hash, dossier_id, owner_user_id, invited_email, expires_at)
     SELECT $1, id, owner_user_id, $3, now() + interval '30 days' FROM ziel_dossier
     ON CONFLICT (token_hash) DO UPDATE SET
       dossier_id = EXCLUDED.dossier_id,
       owner_user_id = EXCLUDED.owner_user_id,
       invited_email = EXCLUDED.invited_email,
       expires_at = EXCLUDED.expires_at,
       status = 'open',
       requester_user_id = NULL,
       requester_email = NULL,
       requested_at = NULL,
       decided_at = NULL,
       updated_at = now()
     RETURNING id`,
    [hash(token), dossierID, email, user.id]
  );
  return result.rows[0] ? res.status(204).end() : res.status(404).json({ error: "Dossier nicht gefunden" });
}

async function requestInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const profileEmail = String(req.body?.profileEmail || "").trim().toLowerCase();
  if (!profileEmail || !profileEmail.includes("@")) return res.status(400).json({ error: "Profil-E-Mail fehlt" });
  const result = await databasePool().query(
    `UPDATE dossier_invitations SET requester_user_id = $2, requester_email = $3, status = 'pending', requested_at = now(), updated_at = now()
      WHERE token_hash = $1
        AND expires_at > now()
        AND invited_email = $3
        AND (status = 'open' OR (status = 'pending' AND requester_user_id = $2 AND requester_email = $3))
      RETURNING dossier_id, owner_user_id, invited_email, expires_at`,
    [hash(token), user.id, profileEmail]
  );
  const invitation = result.rows[0];
  if (!invitation) return res.status(403).json({ error: "Einladung ungültig oder E-Mail stimmt nicht überein" });
  await pushToUser(invitation.owner_user_id, {
    aps: { alert: { title: "Anfrage einer Vertrauensperson", body: `${profileEmail} möchte deine Einladung annehmen.` }, sound: "default" },
    type: "trust_invitation_request", invitationToken: token, requesterEmail: profileEmail, requesterUserID: user.id
  });
  return res.status(200).json({ dossierID: invitation.dossier_id, ownerUserID: invitation.owner_user_id, invitedEmail: invitation.invited_email, expiresAt: invitation.expires_at });
}

async function decideInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const decision = String(req.body?.decision || "");
  if (!["accepted", "declined"].includes(decision)) return res.status(400).json({ error: "Ungültige Entscheidung" });
  const client = await databasePool().connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `UPDATE dossier_invitations SET status = $2, decided_at = now(), updated_at = now()
        WHERE token_hash = $1 AND owner_user_id = $3 AND status = 'pending' RETURNING id, dossier_id, requester_user_id`,
      [hash(token), decision, user.id]
    );
    const invitation = result.rows[0];
    if (!invitation) { await client.query("ROLLBACK"); return res.status(404).json({ error: "Offene Anfrage nicht gefunden" }); }
    if (decision === "accepted") await client.query(
      `INSERT INTO dossier_access_grants (dossier_id, user_id, invitation_id) VALUES ($1, $2, $3)
       ON CONFLICT (dossier_id, user_id) DO UPDATE SET revoked_at = NULL, granted_at = now(), invitation_id = EXCLUDED.invitation_id`,
      [invitation.dossier_id, invitation.requester_user_id, invitation.id]
    );
    await client.query("COMMIT");
    await pushToUser(invitation.requester_user_id, {
      aps: { alert: { title: decision === "accepted" ? "Einladung bestätigt" : "Einladung abgelehnt", body: decision === "accepted" ? "Das Vorsorge-Dossier ist jetzt auf deinem Homescreen verfügbar." : "Die vorsorgende Person hat die Anfrage abgelehnt." }, sound: "default" },
      type: "trust_invitation_decision", invitationToken: token, decision
    });
    return res.status(204).end();
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Einladungsentscheidung:", error);
    return res.status(500).json({ error: "Entscheidung konnte nicht gespeichert werden" });
  } finally { client.release(); }
}

function hash(token) { return crypto.createHash("sha256").update(token).digest("hex"); }
