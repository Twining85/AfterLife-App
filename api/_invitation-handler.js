import crypto from "node:crypto";
import { databasePool } from "./_database.js";
import { pushToUser } from "./_apns.js";

export async function handleInvitationOperation(operation, req, res, user) {
  if (operation === "device") return registerDevice(req, res, user);
  if (operation === "register-invitation") return registerInvitation(req, res, user);
  if (operation === "validate-invitation") return validateInvitation(req, res, user);
  if (operation === "request-invitation") return requestInvitation(req, res, user);
  if (operation === "decide-invitation") return decideInvitation(req, res, user);
  if (operation === "revoke-invitation") return revokeInvitation(req, res, user);
  if (operation === "invitation-status") return invitationStatus(req, res, user);
  if (operation === "shared-dossier") return sharedDossier(req, res, user);
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
  const ownerName = personName(req.body?.ownerName, "Vorsorgende Person");
  if (!token || !/^[0-9a-f-]{36}$/i.test(dossierID) || !email.includes("@")) return res.status(400).json({ error: "Ungültige Einladung" });
  const result = await databasePool().query(
    `WITH ziel_dossier AS (
       SELECT id, owner_user_id FROM dossiers
        WHERE owner_user_id = $4 AND is_active
        ORDER BY (id = $2) DESC, is_primary DESC, created_at ASC LIMIT 1
     ), alte_einladungen AS (
       UPDATE dossier_invitations SET status = 'revoked', updated_at = now()
        WHERE owner_user_id = $4
          AND dossier_id = (SELECT id FROM ziel_dossier)
          AND invited_email = $3
          AND token_hash <> $1
          AND status IN ('open', 'pending')
     )
     INSERT INTO dossier_invitations (token_hash, dossier_id, owner_user_id, invited_email, owner_name, expires_at)
     SELECT $1, id, owner_user_id, $3, $5, now() + interval '30 days' FROM ziel_dossier
     ON CONFLICT (token_hash) DO UPDATE SET
       dossier_id = EXCLUDED.dossier_id,
       owner_user_id = EXCLUDED.owner_user_id,
       invited_email = EXCLUDED.invited_email,
       owner_name = EXCLUDED.owner_name,
       expires_at = EXCLUDED.expires_at,
       status = 'open',
       requester_user_id = NULL,
       requester_email = NULL,
       requester_name = NULL,
       requested_at = NULL,
       decided_at = NULL,
       updated_at = now()
     WHERE dossier_invitations.status = 'open'
     RETURNING id`,
    [hash(token), dossierID, email, user.id, ownerName]
  );
  return result.rows[0] ? res.status(204).end() : res.status(404).json({ error: "Dossier nicht gefunden" });
}

async function requestInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const accountEmail = String(user.email || "").trim().toLowerCase();
  const requesterName = personName(req.body?.requesterName, accountEmail);
  if (!token || !accountEmail) return res.status(400).json({ error: "Ungültige Einladungsanfrage" });
  const result = await databasePool().query(
    `UPDATE dossier_invitations SET requester_user_id = $2, requester_email = $3,
        requester_name = $4, status = 'pending', requested_at = now(), decided_at = NULL, updated_at = now()
      WHERE token_hash = $1
        AND expires_at > now()
        AND invited_email = $3
        AND owner_user_id <> $2
        AND (status = 'open' OR (status IN ('pending', 'declined') AND requester_user_id = $2 AND requester_email = $3))
      RETURNING dossier_id, owner_user_id, invited_email, owner_name, expires_at`,
    [hash(token), user.id, accountEmail, requesterName]
  );
  const invitation = result.rows[0];
  if (!invitation) return res.status(403).json({ error: "Einladung ungültig oder die registrierte Konto-E-Mail stimmt nicht überein" });
  const delivery = await pushToUser(
    invitation.owner_user_id,
    invitationRequestPushPayload({ token, requesterName, requesterEmail: accountEmail, requesterUserID: user.id })
  );
  return res.status(200).json({
    dossierID: invitation.dossier_id,
    ownerUserID: invitation.owner_user_id,
    ownerName: invitation.owner_name,
    invitedEmail: invitation.invited_email,
    expiresAt: invitation.expires_at,
    notificationDelivered: delivery.delivered > 0
  });
}

async function validateInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const accountEmail = String(user.email || "").trim().toLowerCase();
  if (!token || !accountEmail) return res.status(400).json({ error: "Ungültige Einladungsanfrage" });
  const result = await databasePool().query(
    `SELECT i.dossier_id, i.owner_user_id, i.invited_email, i.owner_name, i.expires_at
       FROM dossier_invitations i
      WHERE i.token_hash = $1 AND i.expires_at > now()
        AND i.invited_email = $2 AND i.owner_user_id <> $3
        AND (i.status = 'open' OR (i.status = 'pending' AND i.requester_user_id = $3))`,
    [hash(token), accountEmail, user.id]
  );
  const invitation = result.rows[0];
  if (!invitation) return res.status(403).json({ error: "Einladung ungültig oder die registrierte Konto-E-Mail stimmt nicht überein" });
  return res.status(200).json({
    dossierID: invitation.dossier_id,
    ownerUserID: invitation.owner_user_id,
    ownerName: invitation.owner_name,
    invitedEmail: invitation.invited_email,
    expiresAt: invitation.expires_at,
    notificationDelivered: false
  });
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
        WHERE token_hash = $1 AND owner_user_id = $3
          AND (status = 'pending' OR status = $2)
        RETURNING id, dossier_id, requester_user_id, owner_name, status`,
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
    await pushToUser(
      invitation.requester_user_id,
      invitationDecisionPushPayload({ token, decision, ownerName: invitation.owner_name })
    );
    return res.status(204).end();
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Einladungsentscheidung:", error);
    return res.status(500).json({ error: "Entscheidung konnte nicht gespeichert werden" });
  } finally { client.release(); }
}

async function revokeInvitation(req, res, user) {
  const dossierID = String(req.body?.dossierID || "");
  const email = String(req.body?.email || "").trim().toLowerCase();
  if (!/^[0-9a-f-]{36}$/i.test(dossierID) || !email.includes("@")) {
    return res.status(400).json({ error: "Ungültiger Widerruf" });
  }
  try {
    await revokeInvitationForOwner({ userID: user.id, dossierID, email });
    return res.status(204).end();
  } catch (error) {
    console.error("Einladungswiderruf:", error);
    return res.status(500).json({ error: "Zugriff konnte nicht widerrufen werden" });
  }
}

export async function revokeInvitationForOwner({
  userID,
  dossierID,
  email,
  pool = databasePool(),
  push = pushToUser
}) {
  const client = await pool.connect();
  let revoked = [];
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `UPDATE dossier_invitations
          SET status = 'revoked', decided_at = now(), updated_at = now()
        WHERE owner_user_id = $1 AND dossier_id = $2 AND invited_email = $3
          AND status <> 'revoked'
        RETURNING id, requester_user_id, owner_name`,
      [userID, dossierID, email]
    );
    revoked = result.rows;
    if (revoked.length > 0) {
      await client.query(
        `UPDATE dossier_access_grants
            SET revoked_at = now()
          WHERE invitation_id = ANY($1::uuid[]) AND revoked_at IS NULL`,
        [revoked.map((invitation) => invitation.id)]
      );
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  const recipients = new Map();
  for (const invitation of revoked) {
    if (invitation.requester_user_id) {
      recipients.set(invitation.requester_user_id, invitation.owner_name);
    }
  }
  await Promise.all([...recipients].map(([requesterUserID, ownerName]) =>
    push(requesterUserID, {
      aps: {
        alert: {
          title: "Dossierzugriff widerrufen",
          body: `${ownerName} hat deinen Zugriff auf das Vorsorge-Dossier aufgehoben.`
        },
        sound: "default"
      },
      type: "trust_invitation_revoked",
      dossierID
    })
  ));
  return revoked.length;
}

async function invitationStatus(req, res, user) {
  const token = String(req.body?.token || "").trim();
  if (!token) return res.status(400).json({ error: "Einladungstoken fehlt" });
  const result = await databasePool().query(
    `SELECT i.dossier_id, i.owner_user_id, i.requester_user_id, i.invited_email,
            i.requester_email, i.requester_name, i.owner_name, i.status, i.expires_at, d.title,
            owner.email AS owner_email
       FROM dossier_invitations i
       JOIN dossiers d ON d.id = i.dossier_id
       JOIN app_users owner ON owner.id = i.owner_user_id
      WHERE i.token_hash = $1
        AND (i.owner_user_id = $2 OR i.requester_user_id = $2)`,
    [hash(token), user.id]
  );
  const invitation = result.rows[0];
  if (!invitation) return res.status(404).json({ error: "Einladung nicht gefunden" });
  return res.status(200).json(invitationResponse(invitation));
}

async function sharedDossier(req, res, user) {
  const token = String(req.body?.token || "").trim();
  if (!token) return res.status(400).json({ error: "Einladungstoken fehlt" });
  const invitationResult = await databasePool().query(
    `SELECT i.dossier_id, i.owner_user_id, i.invited_email, i.owner_name, i.status, d.title,
            owner.email AS owner_email
       FROM dossier_invitations i
       JOIN dossier_access_grants g ON g.invitation_id = i.id
       JOIN dossiers d ON d.id = i.dossier_id AND d.is_active
       JOIN app_users owner ON owner.id = i.owner_user_id
      WHERE i.token_hash = $1 AND g.user_id = $2 AND g.revoked_at IS NULL
        AND i.status = 'accepted'`,
    [hash(token), user.id]
  );
  const invitation = invitationResult.rows[0];
  if (!invitation) return res.status(403).json({ error: "Kein aktiver Dossierzugriff" });
  const sections = await databasePool().query(
    `SELECT section_type, schema_version, revision, payload, deleted_at, updated_at
       FROM dossier_sections WHERE dossier_id = $1 ORDER BY section_type`,
    [invitation.dossier_id]
  );
  return res.status(200).json({
    dossierID: invitation.dossier_id,
    ownerUserID: invitation.owner_user_id,
    ownerEmail: invitation.owner_email,
    ownerName: invitation.owner_name,
    title: invitation.title,
    sections: sections.rows.map((row) => ({
      sectionType: row.section_type,
      schemaVersion: Number(row.schema_version),
      revision: Number(row.revision),
      payload: row.deleted_at ? null : row.payload,
      deleted: Boolean(row.deleted_at),
      updatedAt: row.updated_at
    }))
  });
}

function invitationResponse(invitation) {
  return {
    dossierID: invitation.dossier_id,
    ownerUserID: invitation.owner_user_id,
    requesterUserID: invitation.requester_user_id,
    invitedEmail: invitation.invited_email,
    requesterEmail: invitation.requester_email,
    requesterName: invitation.requester_name,
    status: invitation.status,
    expiresAt: invitation.expires_at,
    title: invitation.title,
    ownerEmail: invitation.owner_email,
    ownerName: invitation.owner_name
  };
}

function hash(token) { return crypto.createHash("sha256").update(token).digest("hex"); }

export function invitationRequestPushPayload({ token, requesterName, requesterEmail, requesterUserID }) {
  return {
    aps: {
      alert: {
        title: "Datenzugriff angefragt",
        body: `${requesterName} möchte das Vorsorge-Dossier aus der Cloud laden.`
      },
      sound: "default",
      category: "TRUST_INVITATION_REQUEST"
    },
    type: "trust_invitation_request",
    invitationToken: token,
    requesterEmail,
    requesterUserID
  };
}

export function invitationDecisionPushPayload({ token, decision, ownerName }) {
  return {
    aps: {
      alert: {
        title: decision === "accepted" ? "Einladung bestätigt" : "Einladung abgelehnt",
        body: decision === "accepted"
          ? `${ownerName} hat deine Anfrage angenommen. Das Vorsorge-Dossier ist jetzt auf deinem Homescreen verfügbar.`
          : `${ownerName} hat deine Anfrage abgelehnt.`
      },
      sound: "default"
    },
    type: "trust_invitation_decision",
    invitationToken: token,
    decision
  };
}

function personName(value, fallback) {
  const name = String(value || "").trim().replace(/\s+/g, " ").slice(0, 120);
  return name || fallback;
}
