import crypto from "node:crypto";
import { databasePool } from "./_database.js";
import { pushToUser } from "./_apns.js";

export async function handleInvitationOperation(operation, req, res, user) {
  if (operation === "device") return registerDevice(req, res, user);
  if (operation === "register-invitation") return registerInvitation(req, res, user);
  if (operation === "share-invitation-key") return shareInvitationKey(req, res, user);
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
  const pool = databasePool();
  await pool.query(
    pool.engine === "mysql"
      ? `INSERT INTO push_device_tokens (user_id, device_token, environment) VALUES ($1, $2, $3)
         ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), updated_at = CURRENT_TIMESTAMP(6)`
      : `INSERT INTO push_device_tokens (user_id, device_token, environment) VALUES ($1, $2, $3)
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
  const sharedKeyPackage = validSharedKeyPackage(req.body?.sharedKeyPackage);
  if (!token || !/^[0-9a-f-]{36}$/i.test(dossierID) || !email.includes("@") || !sharedKeyPackage) return res.status(400).json({ error: "Ungültige Einladung" });
  if (databasePool().engine === "mysql") {
    const found = await registerMySQLInvitation({ token, dossierID, email, ownerName, sharedKeyPackage, userID: user.id });
    return found ? res.status(204).end() : res.status(404).json({ error: "Dossier nicht gefunden" });
  }
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
     INSERT INTO dossier_invitations (token_hash, dossier_id, owner_user_id, invited_email, owner_name, shared_key_package, expires_at)
     SELECT $1, id, owner_user_id, $3, $5, decode($6, 'base64'), now() + interval '30 days' FROM ziel_dossier
     ON CONFLICT (token_hash) DO UPDATE SET
       dossier_id = EXCLUDED.dossier_id,
       owner_user_id = EXCLUDED.owner_user_id,
       invited_email = EXCLUDED.invited_email,
       owner_name = EXCLUDED.owner_name,
       shared_key_package = EXCLUDED.shared_key_package,
       expires_at = EXCLUDED.expires_at,
       status = 'open',
       requester_user_id = NULL,
       requester_email = NULL,
       requester_name = NULL,
       requested_at = NULL,
       decided_at = NULL,
       access_release_at = NULL,
       auto_released_at = NULL,
       updated_at = now()
     WHERE dossier_invitations.status = 'open'
     RETURNING id`,
    [hash(token), dossierID, email, user.id, ownerName, sharedKeyPackage]
  );
  return result.rows[0] ? res.status(204).end() : res.status(404).json({ error: "Dossier nicht gefunden" });
}

async function shareInvitationKey(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const sharedKeyPackage = validSharedKeyPackage(req.body?.sharedKeyPackage);
  if (!token || !sharedKeyPackage) return res.status(400).json({ error: "Ungültige Schlüsselfreigabe" });
  const pool = databasePool();
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const selected = await client.query(
      `SELECT id, dossier_id, requester_user_id FROM dossier_invitations
        WHERE token_hash = $1 AND owner_user_id = $2 AND status <> 'revoked' FOR UPDATE`,
      [hash(token), user.id]
    );
    const invitation = selected.rows[0];
    if (!invitation) { await client.query("ROLLBACK"); return res.status(404).json({ error: "Aktive Einladung nicht gefunden" }); }
    await client.query(
      pool.engine === "mysql"
        ? "UPDATE dossier_invitations SET shared_key_package = FROM_BASE64($1), updated_at = CURRENT_TIMESTAMP(6) WHERE id = $2"
        : "UPDATE dossier_invitations SET shared_key_package = decode($1, 'base64'), updated_at = now() WHERE id = $2",
      [sharedKeyPackage, invitation.id]
    );
    if (invitation.requester_user_id) {
      await upsertKeyEnvelope(client, pool.engine, invitation.dossier_id, invitation.requester_user_id, sharedKeyPackage);
    }
    await client.query("COMMIT");
    return res.status(204).end();
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Schlüsselfreigabe:", error);
    return res.status(500).json({ error: "Schlüsselfreigabe konnte nicht gespeichert werden" });
  } finally { client.release(); }
}

async function requestInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const accountEmail = String(user.email || "").trim().toLowerCase();
  const requesterName = personName(req.body?.requesterName, accountEmail);
  if (!token || !accountEmail) return res.status(400).json({ error: "Ungültige Einladungsanfrage" });
  const graceSeconds = trustAccessGraceSeconds();
  if (databasePool().engine === "mysql") {
    const invitation = await requestMySQLInvitation({ token, userID: user.id, accountEmail, requesterName, graceSeconds });
    if (!invitation) return res.status(403).json({ error: "Einladung ungültig oder die registrierte Konto-E-Mail stimmt nicht überein" });
    const delivery = await pushToUser(invitation.owner_user_id,
      invitationRequestPushPayload({ token, requesterName, requesterEmail: accountEmail, requesterUserID: user.id }));
    return res.status(200).json({
      dossierID: invitation.dossier_id, ownerUserID: invitation.owner_user_id,
      ownerName: invitation.owner_name, invitedEmail: invitation.invited_email,
      expiresAt: invitation.expires_at, accessReleaseAt: invitation.access_release_at,
      notificationDelivered: delivery.delivered > 0
    });
  }
  const result = await databasePool().query(
    `UPDATE dossier_invitations SET requester_user_id = $2, requester_email = $3,
        requester_name = $4, status = 'pending', requested_at = now(), decided_at = NULL,
        access_release_at = now() + ($5::integer * interval '1 second'),
        auto_released_at = NULL, updated_at = now()
      WHERE token_hash = $1
        AND expires_at > now()
        AND invited_email = $3
        AND owner_user_id <> $2
        AND (status = 'open' OR (status IN ('pending', 'declined') AND requester_user_id = $2 AND requester_email = $3))
      RETURNING dossier_id, owner_user_id, invited_email, owner_name, expires_at, access_release_at`,
    [hash(token), user.id, accountEmail, requesterName, graceSeconds]
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
    accessReleaseAt: invitation.access_release_at,
    notificationDelivered: delivery.delivered > 0
  });
}

async function validateInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const accountEmail = String(user.email || "").trim().toLowerCase();
  if (!token || !accountEmail) return res.status(400).json({ error: "Ungültige Einladungsanfrage" });
  const pool = databasePool();
  const client = await pool.connect();
  const isMySQL = client.engine === "mysql" || pool.engine === "mysql";
  try {
    await client.query("BEGIN");
    const result = await client.query(
      `SELECT i.id, i.dossier_id, i.owner_user_id, i.invited_email, i.owner_name, i.expires_at,
              ${isMySQL ? "REPLACE(TO_BASE64(i.shared_key_package), CHAR(10), '')" : "encode(i.shared_key_package, 'base64')"} AS shared_key_package
         FROM dossier_invitations i
        WHERE i.token_hash = $1 AND i.expires_at > now()
          AND i.invited_email = $2 AND i.owner_user_id <> $3
          AND (i.status = 'open' OR (i.status IN ('pending', 'declined') AND i.requester_user_id = $3))
        FOR UPDATE`,
      [hash(token), accountEmail, user.id]
    );
    const invitation = result.rows[0];
    if (!invitation) {
      await client.query("ROLLBACK");
      return res.status(403).json({ error: "Einladung ungültig oder die registrierte Konto-E-Mail stimmt nicht überein" });
    }
    await client.query(
      `UPDATE dossier_invitations SET requester_user_id = $1, requester_email = $2, updated_at = ${isMySQL ? "CURRENT_TIMESTAMP(6)" : "now()"}
        WHERE id = $3 AND status = 'open'`,
      [user.id, accountEmail, invitation.id]
    );
    await client.query(
      isMySQL
        ? `INSERT INTO dossier_access_grants (dossier_id, user_id, invitation_id) VALUES ($1, $2, $3)
           ON DUPLICATE KEY UPDATE revoked_at = NULL, invitation_id = VALUES(invitation_id)`
        : `INSERT INTO dossier_access_grants (dossier_id, user_id, invitation_id) VALUES ($1, $2, $3)
           ON CONFLICT (dossier_id, user_id) DO UPDATE SET revoked_at = NULL, invitation_id = EXCLUDED.invitation_id`,
      [invitation.dossier_id, user.id, invitation.id]
    );
    if (invitation.shared_key_package) {
      await upsertKeyEnvelope(client, isMySQL ? "mysql" : "postgres", invitation.dossier_id, user.id, invitation.shared_key_package);
    }
    await client.query("COMMIT");
    return res.status(200).json({
      dossierID: invitation.dossier_id,
      ownerUserID: invitation.owner_user_id,
      ownerName: invitation.owner_name,
      invitedEmail: invitation.invited_email,
      expiresAt: invitation.expires_at,
      notificationDelivered: false
    });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Einladungszugriff aktivieren:", error);
    return res.status(500).json({ error: "Der Dossierzugriff konnte nicht aktiviert werden" });
  } finally {
    client.release();
  }
}

async function decideInvitation(req, res, user) {
  const token = String(req.body?.token || "").trim();
  const decision = String(req.body?.decision || "");
  const sharedKeyPackage = String(req.body?.sharedKeyPackage || "").trim();
  if (!["accepted", "declined"].includes(decision)) return res.status(400).json({ error: "Ungültige Entscheidung" });
  if (decision === "accepted" && !/^[A-Za-z0-9+/=]{40,512}$/.test(sharedKeyPackage)) {
    return res.status(400).json({ error: "Verschlüsselte Schlüsselfreigabe fehlt" });
  }
  if (databasePool().engine === "mysql") return decideMySQLInvitation({ token, decision, sharedKeyPackage, user, res });
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
  const token = String(req.body?.token || "").trim();
  const dossierID = String(req.body?.dossierID || "");
  const email = String(req.body?.email || "").trim().toLowerCase();
  if (!/^[0-9a-f-]{36}$/i.test(dossierID) || !email.includes("@")) {
    return res.status(400).json({ error: "Ungültiger Widerruf" });
  }
  try {
    const revoked = await revokeInvitationForOwner({ userID: user.id, dossierID, email, token });
    if (revoked === 0) {
      return res.status(404).json({ error: "Keine passende aktive Einladung gefunden" });
    }
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
  token,
  pool = databasePool(),
  push = pushToUser
}) {
  const client = await pool.connect();
  let revoked = [];
  try {
    await client.query("BEGIN");
    if (client.engine === "mysql") {
      const selected = await client.query(
        `SELECT id, requester_user_id, owner_name FROM dossier_invitations
          WHERE owner_user_id = $1 AND dossier_id = $2 AND invited_email = $3
            AND status <> 'revoked' FOR UPDATE`,
        [userID, dossierID, email]
      );
      revoked = selected.rows;
      if (revoked.length > 0) {
        const ids = revoked.map((invitation) => invitation.id);
        await client.query(
          `UPDATE dossier_invitations SET status = 'revoked', decided_at = CURRENT_TIMESTAMP(6),
             updated_at = CURRENT_TIMESTAMP(6) WHERE id IN (${ids.map((_, index) => `$${index + 1}`).join(",")})`,
          ids
        );
        await client.query(
          `UPDATE dossier_access_grants SET revoked_at = CURRENT_TIMESTAMP(6)
            WHERE invitation_id IN (${ids.map((_, index) => `$${index + 1}`).join(",")}) AND revoked_at IS NULL`,
          ids
        );
      }
      await client.query("COMMIT");
    } else {
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
    }
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
  const accountEmail = String(user.email || "").trim().toLowerCase();
  if (!token) return res.status(400).json({ error: "Einladungstoken fehlt" });
  // Aktive Apps müssen nicht bis zum täglichen Vercel-Backstop warten. Die
  // transaktionale Freigabe ist idempotent; parallele Statusabfragen können
  // deshalb gefahrlos dieselbe Fälligkeit prüfen.
  try {
    await releaseDueInvitations({ limit: 100 });
  } catch (error) {
    console.error("Fällige Freigaben beim Statusabruf:", error);
  }
  const result = await databasePool().query(
    `SELECT i.dossier_id, i.owner_user_id, i.requester_user_id, i.invited_email,
            i.requester_email, i.requester_name, i.owner_name, i.status, i.expires_at,
            i.access_release_at, i.updated_at AS invitation_updated_at, d.title,
            owner.email AS owner_email
       FROM dossier_invitations i
      JOIN dossiers d ON d.id = i.dossier_id
      JOIN app_users owner ON owner.id = i.owner_user_id
      WHERE i.token_hash = $1
        AND (i.owner_user_id = $2 OR i.requester_user_id = $2
          OR (i.invited_email = $3 AND i.status IN ('open', 'revoked')))`,
    [hash(token), user.id, accountEmail]
  );
  const invitation = result.rows[0];
  if (!invitation) return res.status(404).json({ error: "Einladung nicht gefunden" });
  const metadata = await dossierStatusMetadata(invitation.dossier_id, invitation.owner_user_id);
  return res.status(200).json(invitationResponse(invitation, metadata));
}

async function sharedDossier(req, res, user) {
  const token = String(req.body?.token || "").trim();
  if (!token) return res.status(400).json({ error: "Einladungstoken fehlt" });
  const keyPackageSelection = databasePool().engine === "mysql"
    ? `, (SELECT REPLACE(TO_BASE64(k.encrypted_key), CHAR(10), '') FROM dossier_key_envelopes k
          WHERE k.dossier_id = i.dossier_id AND k.recipient_user_id = g.user_id
            AND k.revoked_at IS NULL ORDER BY k.key_version DESC LIMIT 1) AS shared_key_package`
    : `, NULL AS shared_key_package`;
  const invitationResult = await databasePool().query(
    `SELECT i.dossier_id, i.owner_user_id, i.invited_email, i.owner_name, i.status, d.title,
            owner.email AS owner_email
            ${keyPackageSelection}
       FROM dossier_invitations i
       JOIN dossier_access_grants g ON g.dossier_id = i.dossier_id AND g.user_id = $2
       JOIN dossiers d ON d.id = i.dossier_id AND d.is_active
       JOIN app_users owner ON owner.id = i.owner_user_id
      WHERE i.token_hash = $1 AND i.requester_user_id = $2 AND g.revoked_at IS NULL
        AND i.status IN ('open', 'pending', 'declined', 'accepted')`,
    [hash(token), user.id]
  );
  const invitation = invitationResult.rows[0];
  if (!invitation) return res.status(403).json({ error: "Kein aktiver Dossierzugriff" });
  const sections = await databasePool().query(
    `SELECT section_type, schema_version, revision, payload, deleted_at, updated_at
       FROM dossier_sections WHERE dossier_id = $1 ORDER BY section_type`,
    [invitation.dossier_id]
  );
  const allSections = sections.rows.map((row) => ({
    sectionType: row.section_type,
    schemaVersion: Number(row.schema_version),
    revision: Number(row.revision),
    payload: row.deleted_at ? null : row.payload,
    deleted: Boolean(row.deleted_at),
    updatedAt: row.updated_at
  }));
  const availableSectionTypes = dossierSectionTypes(allSections);
  const ownerName = ownerNameFromSections(allSections, invitation.owner_user_id, invitation.owner_name);
  const visibleSectionTypes = invitation.status === "accepted"
    ? allSections.map((section) => section.sectionType).filter((type) => type !== "dossier_einstellungen")
    : partialVisibleSectionTypes(allSections, invitation.invited_email, user.id);
  return res.status(200).json({
    dossierID: invitation.dossier_id,
    ownerUserID: invitation.owner_user_id,
    ownerEmail: invitation.owner_email,
    ownerName,
    title: `Dossier von ${ownerName}`,
    sharedKeyPackage: visibleSectionTypes.includes("zugaenge") ? invitation.shared_key_package : null,
    availableSectionTypes,
    visibleSectionTypes,
    sections: allSections.filter((section) => visibleSectionTypes.includes(section.sectionType))
  });
}

function dossierSectionTypes(sections) {
  const settings = sections.find((section) => section.sectionType === "dossier_einstellungen" && !section.deleted);
  let payload = settings?.payload;
  if (typeof payload === "string") {
    try { payload = JSON.parse(payload); } catch { payload = null; }
  }
  const mapping = { hinterbliebene: "kontakte", abos: "zugaenge" };
  const configured = Array.isArray(payload?.homeAktiveBereiche) ? payload.homeAktiveBereiche : [];
  const available = configured.map((type) => mapping[type] || type)
    .filter((type) => type && type !== "dossier_einstellungen");
  return [...new Set(["profil", ...available])];
}

function partialVisibleSectionTypes(sections, invitedEmail, requesterUserID) {
  const visible = new Set(["profil"]);
  const kontakte = sections.find((section) => section.sectionType === "kontakte" && !section.deleted);
  let payload = kontakte?.payload;
  if (typeof payload === "string") {
    try { payload = JSON.parse(payload); } catch { payload = null; }
  }
  const personen = Array.isArray(payload?.vertrauenspersonen) ? payload.vertrauenspersonen : [];
  const normalizedEmail = String(invitedEmail || "").trim().toLowerCase();
  const person = personen.find((entry) =>
    String(entry?.vertrauenspersonUserID || "") === String(requesterUserID) ||
    [entry?.email, entry?.einladungsEmail].some((email) => String(email || "").trim().toLowerCase() === normalizedEmail)
  );
  const enabled = (key, fallback) => person?.[key] ?? fallback;
  if (enabled("wuenscheSichtbarBeiDossierfreigabe", true)) visible.add("wuensche");
  if (enabled("menschenDesVertrauensSichtbarBeiDossierfreigabe", true)) visible.add("kontakte");
  if (enabled("finanzenSichtbarBeiDossierfreigabe", false)) visible.add("finanzen");
  if (enabled("dokumenteSichtbarBeiDossierfreigabe", false)) visible.add("dokumente");
  if (enabled("abosUndProfileSichtbarBeiDossierfreigabe", false)) visible.add("zugaenge");
  if (enabled("herzensstueckeSichtbarBeiDossierfreigabe", true)) visible.add("herzensstuecke");
  if (enabled("gesundheitSichtbarBeiDossierfreigabe", true)) visible.add("gesundheit");
  return [...visible];
}

function invitationResponse(invitation, metadata = {}) {
  const ownerName = metadata.ownerName || invitation.owner_name;
  return {
    dossierID: invitation.dossier_id,
    ownerUserID: invitation.owner_user_id,
    requesterUserID: invitation.requester_user_id,
    invitedEmail: invitation.invited_email,
    requesterEmail: invitation.requester_email,
    requesterName: invitation.requester_name,
    status: invitation.status,
    expiresAt: invitation.expires_at,
    accessReleaseAt: invitation.access_release_at,
    title: `Dossier von ${ownerName}`,
    ownerEmail: invitation.owner_email,
    ownerName,
    lastContentUpdatedAt: metadata.lastContentUpdatedAt || null,
    revokedAt: invitation.status === "revoked" ? invitation.invitation_updated_at : null
  };
}

async function dossierStatusMetadata(dossierID, ownerUserID) {
  const [latestResult, profileResult] = await Promise.all([
    databasePool().query(
      "SELECT MAX(updated_at) AS last_content_updated_at FROM dossier_sections WHERE dossier_id = $1",
      [dossierID]
    ),
    databasePool().query(
      "SELECT payload FROM dossier_sections WHERE dossier_id = $1 AND section_type = $2 AND deleted_at IS NULL",
      [dossierID, "profil"]
    )
  ]);
  return {
    ownerName: ownerNameFromProfilePayload(profileResult.rows[0]?.payload, ownerUserID),
    lastContentUpdatedAt: latestResult.rows[0]?.last_content_updated_at || null
  };
}

function ownerNameFromSections(sections, ownerUserID, fallback) {
  const profile = sections.find((section) => section.sectionType === "profil" && !section.deleted);
  return ownerNameFromProfilePayload(profile?.payload, ownerUserID) || fallback;
}

function ownerNameFromProfilePayload(rawPayload, ownerUserID) {
  let payload = rawPayload;
  if (typeof payload === "string") {
    try { payload = JSON.parse(payload); } catch { return null; }
  }
  const profiles = Array.isArray(payload?.items) ? payload.items : [];
  const owner = profiles.find((entry) => String(entry?.userID || "") === String(ownerUserID)) || profiles[0];
  const name = [owner?.vorname, owner?.name].map((part) => String(part || "").trim()).filter(Boolean).join(" ");
  return name || null;
}

function hash(token) { return crypto.createHash("sha256").update(token).digest("hex"); }

function validSharedKeyPackage(value) {
  const packageValue = String(value || "").trim();
  return /^[A-Za-z0-9+/=]{40,512}$/.test(packageValue) ? packageValue : null;
}

async function upsertKeyEnvelope(client, engine, dossierID, recipientUserID, sharedKeyPackage) {
  await client.query(
    engine === "mysql"
      ? `INSERT INTO dossier_key_envelopes
           (dossier_id, recipient_user_id, key_version, algorithm, encrypted_key)
         VALUES ($1, $2, 1, 'AES-256-GCM/invitation-token-v1', FROM_BASE64($3))
         ON DUPLICATE KEY UPDATE encrypted_key = VALUES(encrypted_key), algorithm = VALUES(algorithm),
           revoked_at = NULL, created_at = CURRENT_TIMESTAMP(6)`
      : `INSERT INTO dossier_key_envelopes
           (dossier_id, recipient_user_id, key_version, algorithm, encrypted_key)
         VALUES ($1, $2, 1, 'AES-256-GCM/invitation-token-v1', decode($3, 'base64'))
         ON CONFLICT (dossier_id, recipient_user_id, key_version) DO UPDATE SET
           encrypted_key = EXCLUDED.encrypted_key, algorithm = EXCLUDED.algorithm,
           revoked_at = NULL, created_at = now()`,
    [dossierID, recipientUserID, sharedKeyPackage]
  );
}

export function invitationRequestPushPayload({ token, requesterName, requesterEmail, requesterUserID }) {
  return {
    aps: {
      alert: {
        title: "Weitere Bereiche angefragt",
        body: `${requesterName} möchte auch die bisher verborgenen Bereiche deines Vorsorge-Dossiers sehen.`
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
        title: decision === "accepted" ? "Weitere Bereiche freigegeben" : "Erweiterungsanfrage abgelehnt",
        body: decision === "accepted"
          ? `${ownerName} hat deine Anfrage angenommen. Du kannst jetzt alle Bereiche des Vorsorge-Dossiers sehen.`
          : `${ownerName} hat deine Anfrage abgelehnt. Deine bisher sichtbaren Bereiche bleiben verfügbar.`
      },
      sound: "default"
    },
    type: "trust_invitation_decision",
    invitationToken: token,
    decision
  };
}

export function automaticReleasePushPayload({ ownerName, dossierID }) {
  return {
    aps: {
      alert: {
        title: "Dein Zugriff wurde freigegeben",
        body: `Du kannst das Tschlüssli-Dossier von ${ownerName} jetzt vollständig einsehen.`
      },
      sound: "default"
    },
    type: "trust_invitation_auto_released",
    dossierID
  };
}

export function trustAccessGraceSeconds(environment = process.env) {
  const configured = Number.parseInt(environment.TRUST_ACCESS_GRACE_SECONDS || "", 10);
  if (Number.isInteger(configured) && configured >= 60 && configured <= 2_592_000) {
    return configured;
  }
  if (environment.NODE_ENV === "test") return 60;
  throw new Error("TRUST_ACCESS_GRACE_SECONDS fehlt oder ist ungueltig");
}

export async function releaseDueInvitations({
  pool = databasePool(),
  push = pushToUser,
  limit = 100
} = {}) {
  const client = await pool.connect();
  let released = [];
  try {
    await client.query("BEGIN");
    if (client.engine === "mysql") {
      const due = await client.query(
        `SELECT id, dossier_id, requester_user_id, owner_name FROM dossier_invitations
          WHERE status = 'pending' AND access_release_at IS NOT NULL
            AND access_release_at <= CURRENT_TIMESTAMP(6) AND requester_user_id IS NOT NULL
          ORDER BY access_release_at LIMIT ${Math.max(1, Math.min(Number(limit) || 100, 1000))}
          FOR UPDATE SKIP LOCKED`
      );
      released = due.rows;
      for (const invitation of released) {
        await client.query(
          `UPDATE dossier_invitations SET status = 'accepted', decided_at = CURRENT_TIMESTAMP(6),
             auto_released_at = CURRENT_TIMESTAMP(6), updated_at = CURRENT_TIMESTAMP(6) WHERE id = $1`,
          [invitation.id]
        );
        await client.query(
          `INSERT INTO dossier_access_grants (dossier_id, user_id, invitation_id) VALUES ($1, $2, $3)
           ON DUPLICATE KEY UPDATE revoked_at = NULL, granted_at = CURRENT_TIMESTAMP(6), invitation_id = VALUES(invitation_id)`,
          [invitation.dossier_id, invitation.requester_user_id, invitation.id]
        );
      }
    } else {
    const result = await client.query(
      `WITH due AS (
         SELECT id
           FROM dossier_invitations
          WHERE status = 'pending'
            AND access_release_at IS NOT NULL
            AND access_release_at <= now()
            AND requester_user_id IS NOT NULL
          ORDER BY access_release_at
          LIMIT $1
          FOR UPDATE SKIP LOCKED
       ), released AS (
         UPDATE dossier_invitations i
            SET status = 'accepted', decided_at = now(), auto_released_at = now(), updated_at = now()
           FROM due
          WHERE i.id = due.id
          RETURNING i.id, i.dossier_id, i.requester_user_id, i.owner_name
       )
       INSERT INTO dossier_access_grants (dossier_id, user_id, invitation_id)
       SELECT dossier_id, requester_user_id, id FROM released
       ON CONFLICT (dossier_id, user_id) DO UPDATE
         SET revoked_at = NULL, granted_at = now(), invitation_id = EXCLUDED.invitation_id
       RETURNING invitation_id`,
      [limit]
    );
    const releasedIDs = result.rows.map((row) => row.invitation_id);
    if (releasedIDs.length > 0) {
      const details = await client.query(
        `SELECT id, dossier_id, requester_user_id, owner_name
           FROM dossier_invitations
          WHERE id = ANY($1::uuid[])`,
        [releasedIDs]
      );
      released = details.rows;
    }
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  await Promise.all(released.map((invitation) =>
    push(
      invitation.requester_user_id,
      automaticReleasePushPayload({
        ownerName: invitation.owner_name,
        dossierID: invitation.dossier_id
      })
    )
  ));
  return released.length;
}

function personName(value, fallback) {
  const name = String(value || "").trim().replace(/\s+/g, " ").slice(0, 120);
  return name || fallback;
}

async function registerMySQLInvitation({ token, dossierID, email, ownerName, sharedKeyPackage, userID }) {
  const client = await databasePool().connect();
  try {
    await client.query("BEGIN");
    const target = await client.query(
      `SELECT id, owner_user_id FROM dossiers WHERE owner_user_id = $1 AND is_active
        ORDER BY (id = $2) DESC, is_primary DESC, created_at ASC LIMIT 1 FOR UPDATE`,
      [userID, dossierID]
    );
    const dossier = target.rows[0];
    if (!dossier) { await client.query("ROLLBACK"); return false; }
    const tokenHash = hash(token);
    const existing = await client.query(
      `SELECT status FROM dossier_invitations WHERE token_hash = $1 FOR UPDATE`,
      [tokenHash]
    );
    if (existing.rows[0] && existing.rows[0].status !== "open") {
      await client.query("ROLLBACK");
      return false;
    }
    await client.query(
      `UPDATE dossier_invitations SET status = 'revoked', updated_at = CURRENT_TIMESTAMP(6)
        WHERE owner_user_id = $1 AND dossier_id = $2 AND invited_email = $3
          AND token_hash <> $4 AND status IN ('open', 'pending')`,
      [userID, dossier.id, email, tokenHash]
    );
    await client.query(
      `INSERT INTO dossier_invitations
         (token_hash, dossier_id, owner_user_id, invited_email, owner_name, shared_key_package, expires_at)
       VALUES ($1, $2, $3, $4, $5, FROM_BASE64($6), DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY))
       ON DUPLICATE KEY UPDATE dossier_id = VALUES(dossier_id), owner_user_id = VALUES(owner_user_id),
         invited_email = VALUES(invited_email), owner_name = VALUES(owner_name), shared_key_package = VALUES(shared_key_package),
         expires_at = VALUES(expires_at),
         updated_at = CURRENT_TIMESTAMP(6)`,
      [tokenHash, dossier.id, userID, email, ownerName, sharedKeyPackage]
    );
    await client.query("COMMIT");
    return true;
  } catch (error) { await client.query("ROLLBACK"); throw error; }
  finally { client.release(); }
}

async function requestMySQLInvitation({ token, userID, accountEmail, requesterName, graceSeconds }) {
  const client = await databasePool().connect();
  try {
    await client.query("BEGIN");
    const selected = await client.query(
      `SELECT id FROM dossier_invitations WHERE token_hash = $1 AND expires_at > CURRENT_TIMESTAMP(6)
        AND invited_email = $2 AND owner_user_id <> $3
        AND (status = 'open' OR (status IN ('pending', 'declined') AND requester_user_id = $3 AND requester_email = $2))
        FOR UPDATE`,
      [hash(token), accountEmail, userID]
    );
    if (!selected.rows[0]) { await client.query("ROLLBACK"); return null; }
    await client.query(
      `UPDATE dossier_invitations SET requester_user_id = $1, requester_email = $2, requester_name = $3,
        status = 'pending', requested_at = CURRENT_TIMESTAMP(6), decided_at = NULL,
        access_release_at = DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL $4 SECOND), auto_released_at = NULL,
        updated_at = CURRENT_TIMESTAMP(6) WHERE id = $5`,
      [userID, accountEmail, requesterName, graceSeconds, selected.rows[0].id]
    );
    const result = await client.query(
      `SELECT dossier_id, owner_user_id, invited_email, owner_name, expires_at, access_release_at
        FROM dossier_invitations WHERE id = $1`, [selected.rows[0].id]
    );
    await client.query("COMMIT");
    return result.rows[0];
  } catch (error) { await client.query("ROLLBACK"); throw error; }
  finally { client.release(); }
}

async function decideMySQLInvitation({ token, decision, sharedKeyPackage, user, res }) {
  const client = await databasePool().connect();
  try {
    await client.query("BEGIN");
    const selected = await client.query(
      `SELECT id, dossier_id, requester_user_id, owner_name, status FROM dossier_invitations
        WHERE token_hash = $1 AND owner_user_id = $2 AND (status = 'pending' OR status = $3) FOR UPDATE`,
      [hash(token), user.id, decision]
    );
    const invitation = selected.rows[0];
    if (!invitation) { await client.query("ROLLBACK"); return res.status(404).json({ error: "Offene Anfrage nicht gefunden" }); }
    await client.query(
      `UPDATE dossier_invitations SET status = $1, decided_at = CURRENT_TIMESTAMP(6), updated_at = CURRENT_TIMESTAMP(6)
        WHERE id = $2`, [decision, invitation.id]
    );
    if (decision === "accepted") {
      await client.query(
        `INSERT INTO dossier_access_grants (dossier_id, user_id, invitation_id) VALUES ($1, $2, $3)
         ON DUPLICATE KEY UPDATE revoked_at = NULL, granted_at = CURRENT_TIMESTAMP(6), invitation_id = VALUES(invitation_id)`,
        [invitation.dossier_id, invitation.requester_user_id, invitation.id]
      );
      await client.query(
        `INSERT INTO dossier_key_envelopes
           (dossier_id, recipient_user_id, key_version, algorithm, encrypted_key)
         VALUES ($1, $2, 1, 'AES-256-GCM/invitation-token-v1', FROM_BASE64($3))
         ON DUPLICATE KEY UPDATE encrypted_key = VALUES(encrypted_key), algorithm = VALUES(algorithm),
           revoked_at = NULL, created_at = CURRENT_TIMESTAMP(6)`,
        [invitation.dossier_id, invitation.requester_user_id, sharedKeyPackage]
      );
    }
    await client.query("COMMIT");
    await pushToUser(invitation.requester_user_id,
      invitationDecisionPushPayload({ token, decision, ownerName: invitation.owner_name }));
    return res.status(204).end();
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Einladungsentscheidung:", error);
    return res.status(500).json({ error: "Entscheidung konnte nicht gespeichert werden" });
  } finally { client.release(); }
}
