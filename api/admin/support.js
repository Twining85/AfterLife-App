import crypto from "node:crypto";
import { authenticatedUser, saveSession, verifyPassword } from "../_auth.js";
import { databasePool } from "../_database.js";
import { normalizeEmail, rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";
import { storageService } from "../_storage.js";
import { supportedSectionVersions } from "../_sync-contract.js";
import { deleteAccountForUser } from "../accounts/login.js";

const sectionLabels = Object.freeze({
  dossier_einstellungen: "Dossier-Einstellungen",
  dokumente: "Dokumente",
  profil: "Profil",
  gesundheit: "Gesundheit",
  wuensche: "Wünsche",
  finanzen: "Finanzen",
  kontakte: "Menschen des Vertrauens",
  herzensstuecke: "Herzensstücke",
  zugaenge: "Abos und digitale Zugänge"
});

export async function adminLoginHandler(req, res) {
  secureResponse(res);
  if (!supportSiteEnabled()) return res.status(404).json({ error: "Nicht gefunden" });
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "admin-login", limit: 5, windowMilliseconds: 15 * 60 * 1000 })) return;

  const email = normalizeEmail(req.body?.email);
  const password = String(req.body?.password || "");
  try {
    const admin = await authenticateAdmin({ email, password });
    if (!admin) return res.status(401).json({ error: "Anmeldung nicht möglich" });
    const session = await saveSession(admin.id, { lifetimeMilliseconds: 8 * 60 * 60 * 1000, refresh: false });
    await writeAudit({ actorUserID: admin.id, action: "support.admin.login", requestID: requestID(res) });
    return res.status(200).json({
      sessionToken: session.token,
      expiresAt: session.expiresAt.toISOString(),
      environment: supportEnvironment()
    });
  } catch (error) {
    console.error("Support-Anmeldung:", { code: error?.code || "ADMIN_LOGIN_ERROR" });
    return res.status(500).json({ error: "Interner Fehler" });
  }
}

export async function supportLookupHandler(req, res) {
  secureResponse(res);
  if (!supportSiteEnabled()) return res.status(404).json({ error: "Nicht gefunden" });
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "admin-user-lookup", limit: 60, windowMilliseconds: 60 * 60 * 1000 })) return;

  const admin = await authenticatedAdmin(req);
  if (!admin) return res.status(401).json({ error: "Admin-Anmeldung erforderlich" });
  const email = normalizeEmail(req.body?.email);
  if (!email) return res.status(400).json({ error: "Gültige E-Mail-Adresse erforderlich" });

  const includeDetails = devDetailsAllowed() && req.body?.includeDetails === true;
  try {
    const result = await lookupSupportUser({ email, includeDetails });
    await writeAudit({
      actorUserID: admin.id,
      action: result.found ? "support.user.lookup" : "support.user.lookup_not_found",
      targetUserID: result.account?.id,
      requestID: requestID(res),
      metadata: { environment: supportEnvironment(), detailsIncluded: includeDetails }
    });
    return res.status(200).json({
      ...result,
      environment: supportEnvironment(),
      capabilities: { devDetails: devDetailsAllowed(), accountDeletion: true }
    });
  } catch (error) {
    console.error("Support-Abfrage:", { code: error?.code || "SUPPORT_LOOKUP_ERROR" });
    return res.status(500).json({ error: "Support-Abfrage fehlgeschlagen" });
  }
}

export async function supportDeleteAccountHandler(req, res) {
  secureResponse(res);
  if (!supportSiteEnabled()) return res.status(404).json({ error: "Nicht gefunden" });
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "admin-account-delete", limit: 5, windowMilliseconds: 60 * 60 * 1000 })) return;

  const admin = await authenticatedAdmin(req);
  if (!admin) return res.status(401).json({ error: "Admin-Anmeldung erforderlich" });
  const userID = String(req.body?.userID || "").toLowerCase();
  const email = normalizeEmail(req.body?.email);
  const confirmation = normalizeEmail(req.body?.confirmation);
  if (!uuidPattern.test(userID) || !email || confirmation !== email) {
    return res.status(400).json({ error: "Löschbestätigung stimmt nicht überein" });
  }

  try {
    const target = await databasePool().query(
      `SELECT u.id, a.user_id IS NOT NULL AS is_admin
         FROM app_users u
         LEFT JOIN admin_users a ON a.user_id = u.id
        WHERE u.id = $1 AND u.email = $2`,
      [userID, email]
    );
    if (!target.rows[0]) return res.status(404).json({ error: "Konto nicht gefunden" });
    if (databaseFlag(target.rows[0].is_admin)) {
      return res.status(403).json({ error: "Administratorkonten können hier nicht gelöscht werden" });
    }

    await deleteAccountForUser({ userID, forbidAdmin: true });
    await writeAudit({
      actorUserID: admin.id,
      action: "support.account.deleted",
      requestID: requestID(res),
      metadata: { environment: supportEnvironment() }
    });
    return res.status(200).json({ deleted: true });
  } catch (error) {
    if (error?.code === "ADMIN_ACCOUNT_PROTECTED") {
      return res.status(403).json({ error: error.message });
    }
    console.error("Support-Kontolöschung:", { code: error?.code || "SUPPORT_DELETE_ERROR" });
    return res.status(500).json({ error: "Das Konto konnte nicht vollständig gelöscht werden" });
  }
}

export async function authenticateAdmin({ email, password, pool = databasePool() }) {
  if (!email || !password) return null;
  const result = await pool.query(
    `SELECT u.id, u.password_hash, u.password_salt
       FROM app_users u
       JOIN admin_users a ON a.user_id = u.id
      WHERE u.email = $1 AND u.disabled_at IS NULL`,
    [email]
  );
  const admin = result.rows[0];
  if (!admin || !await verifyPassword(password, admin.password_salt, admin.password_hash)) return null;
  return { id: admin.id };
}

export async function authenticatedAdmin(req, pool = databasePool()) {
  const user = await authenticatedUser(req);
  if (!user) return null;
  const result = await pool.query("SELECT user_id FROM admin_users WHERE user_id = $1", [user.id]);
  return result.rowCount === 1 ? user : null;
}

export async function lookupSupportUser({
  email,
  includeDetails = false,
  pool = databasePool(),
  loadPayload = (payload, context) => storageService().loadSectionPayload(payload, context)
}) {
  const userResult = await pool.query(
    `SELECT u.id, u.email, u.email_verified_at, u.created_at, u.updated_at, u.disabled_at,
            a.user_id IS NOT NULL AS is_admin
       FROM app_users u
       LEFT JOIN admin_users a ON a.user_id = u.id
      WHERE u.email = $1`,
    [email]
  );
  const user = userResult.rows[0];
  if (!user) return { found: false };

  const dossierResult = await pool.query(
    `SELECT id, is_primary, is_active, is_released, released_at, last_opened_at, created_at, updated_at
       FROM dossiers WHERE owner_user_id = $1 ORDER BY is_primary DESC, created_at ASC`,
    [user.id]
  );
  const dossiers = [];
  for (const dossier of dossierResult.rows) {
    const [sectionsResult, invitationsResult, filesResult] = await Promise.all([
      pool.query(
        `SELECT section_type, schema_version, revision, payload, deleted_at, created_at, updated_at
           FROM dossier_sections WHERE dossier_id = $1 ORDER BY section_type`,
        [dossier.id]
      ),
      pool.query(
        `SELECT i.status, i.invited_email, i.requester_email, i.requester_name,
                i.expires_at, i.requested_at,
                i.decided_at, i.access_release_at, i.auto_released_at,
                CASE WHEN g.dossier_id IS NULL OR g.revoked_at IS NOT NULL THEN 0 ELSE 1 END AS access_active
           FROM dossier_invitations i
           LEFT JOIN dossier_access_grants g ON g.invitation_id = i.id
          WHERE i.dossier_id = $1 ORDER BY i.created_at DESC`,
        [dossier.id]
      ),
      pool.query(
        `SELECT status, COUNT(*) AS count, COALESCE(SUM(byte_size), 0) AS bytes
           FROM stored_files WHERE dossier_id = $1 AND deleted_at IS NULL GROUP BY status`,
        [dossier.id]
      )
    ]);

    const rawSections = new Map();
    for (const row of sectionsResult.rows) {
      const payload = row.deleted_at ? null : await loadPayload(parseJSON(row.payload), {
        dossierID: dossier.id,
        sectionType: row.section_type
      });
      rawSections.set(row.section_type, { row, payload: parseJSON(payload) });
    }
    const settings = rawSections.get("dossier_einstellungen")?.payload;
    const contacts = rawSections.get("kontakte")?.payload;
    const selected = Array.isArray(settings?.homeAktiveBereiche) ? settings.homeAktiveBereiche : [];
    const sections = Object.keys(supportedSectionVersions).map((sectionType) => {
      const stored = rawSections.get(sectionType);
      const encrypted = sectionType === "zugaenge" && Boolean(stored?.payload?.daten);
      return {
        type: sectionType,
        label: sectionLabels[sectionType] || sectionType,
        selected: selected.includes(sectionType),
        stored: Boolean(stored && !stored.row.deleted_at),
        hasData: encrypted ? null : payloadHasData(sectionType, stored?.payload),
        encrypted,
        revision: stored ? Number(stored.row.revision) : null,
        updatedAt: stored?.row.updated_at || null,
        ...(includeDetails && stored?.payload ? { details: redactDeveloperPayload(stored.payload) } : {})
      };
    });

    dossiers.push({
      id: dossier.id,
      primary: databaseFlag(dossier.is_primary),
      active: databaseFlag(dossier.is_active),
      released: databaseFlag(dossier.is_released),
      releasedAt: dossier.released_at,
      lastOpenedAt: dossier.last_opened_at,
      createdAt: dossier.created_at,
      updatedAt: dossier.updated_at,
      sections,
      subscription: pendingSubscriptionStatus(),
      trustedPeople: buildTrustedPeople(contacts, invitationsResult.rows, includeDetails),
      files: filesResult.rows.map((row) => ({
        status: row.status,
        count: Number(row.count),
        bytes: Number(row.bytes)
      }))
    });
  }

  return {
    found: true,
    account: {
      id: user.id,
      email: user.email,
      admin: databaseFlag(user.is_admin),
      verified: Boolean(user.email_verified_at),
      active: !user.disabled_at,
      createdAt: user.created_at,
      updatedAt: user.updated_at
    },
    dossiers
  };
}

export function buildTrustedPeople(contactsPayload, invitations, includeDetails = false) {
  const configured = Array.isArray(contactsPayload?.vertrauenspersonen)
    ? contactsPayload.vertrauenspersonen
    : [];
  const invitationRows = Array.isArray(invitations) ? invitations : [];
  const usedInvitations = new Set();
  const people = configured.map((contact) => {
    const contactEmail = normalizedOptionalEmail(contact.einladungsEmail || contact.email);
    const invitationIndex = invitationRows.findIndex((invitation, index) => {
      if (usedInvitations.has(index) || !contactEmail) return false;
      return [invitation.requester_email, invitation.invited_email]
        .map(normalizedOptionalEmail)
        .includes(contactEmail);
    });
    const invitation = invitationIndex >= 0 ? invitationRows[invitationIndex] : null;
    if (invitationIndex >= 0) usedInvitations.add(invitationIndex);
    const displayEmail = contactEmail || normalizedOptionalEmail(invitation?.requester_email || invitation?.invited_email);
    const configuredName = [contact.vorname, contact.name].map((value) => String(value || "").trim()).filter(Boolean).join(" ");
    const displayName = normalizedOptionalText(invitation?.requester_name) || configuredName || null;
    return trustedPersonResponse({
      invitation,
      configured: true,
      primary: Boolean(contact.istPrimaereVertrauensperson),
      hasName: Boolean(displayName),
      name: includeDetails ? displayName : null,
      hasEmail: Boolean(displayEmail),
      email: includeDetails ? displayEmail : null,
      relationship: includeDetails ? String(contact.beziehung || "").trim() || null : null,
      localInvitationStatus: contact.einladungsStatus || null
    });
  });

  invitationRows.forEach((invitation, index) => {
    if (usedInvitations.has(index)) return;
    const email = normalizedOptionalEmail(invitation.requester_email || invitation.invited_email);
    const name = normalizedOptionalText(invitation.requester_name);
    people.push(trustedPersonResponse({
      invitation,
      configured: false,
      primary: false,
      hasName: Boolean(name),
      name: includeDetails ? name : null,
      hasEmail: Boolean(email),
      email: includeDetails ? email : null,
      relationship: null,
      localInvitationStatus: null
    }));
  });
  return people;
}

export function pendingSubscriptionStatus() {
  return {
    connected: false,
    plan: null,
    status: "not_connected",
    validUntil: null,
    promoCode: null,
    promoRedemptionAvailable: false
  };
}

export function payloadHasData(sectionType, rawPayload) {
  const payload = parseJSON(rawPayload);
  if (!payload || typeof payload !== "object") return false;
  if (["profil", "gesundheit", "wuensche", "herzensstuecke"].includes(sectionType)) {
    return Array.isArray(payload.items) ? payload.items.length > 0 : meaningfulValue(payload);
  }
  if (sectionType === "kontakte") {
    return [payload.hinterbliebene, payload.vertrauenspersonen].some((items) => Array.isArray(items) && items.length > 0);
  }
  if (sectionType === "dokumente") {
    return [payload.dokumente, payload.fotos].some((items) => Array.isArray(items) && items.length > 0);
  }
  if (sectionType === "finanzen") {
    return ["bankkonten", "schulden", "versicherungen", "liegenschaften", "wertsachen", "steuerdokumente"]
      .some((key) => Array.isArray(payload[key]) && payload[key].length > 0);
  }
  if (sectionType === "dossier_einstellungen") {
    return Array.isArray(payload.homeAktiveBereiche) && payload.homeAktiveBereiche.length > 0;
  }
  return meaningfulValue(payload);
}

export function supportEnvironment(environment = process.env) {
  return ["development", "staging", "production"].includes(environment.APP_ENV)
    ? environment.APP_ENV
    : environment.NODE_ENV === "production" ? "production" : "development";
}

export function supportSiteEnabled(environment = process.env) {
  return environment.SUPPORT_SITE_ENABLED === "true";
}

function devDetailsAllowed(environment = process.env) {
  return supportEnvironment(environment) === "development" && environment.SUPPORT_ALLOW_DEV_PAYLOADS === "true";
}

function meaningfulValue(value) {
  if (Array.isArray(value)) return value.some(meaningfulValue);
  if (value && typeof value === "object") return Object.values(value).some(meaningfulValue);
  if (typeof value === "string") return value.trim().length > 0;
  return typeof value === "number" ? value !== 0 : value === true;
}

function trustedPersonResponse({ invitation, configured, primary, hasName, name, hasEmail, email, relationship, localInvitationStatus }) {
  return {
    configured,
    primary,
    hasName,
    name,
    hasEmail,
    email,
    relationship,
    status: invitation?.status || localInvitationStatus || null,
    accessActive: databaseFlag(invitation?.access_active),
    expiresAt: invitation?.expires_at || null,
    requestedAt: invitation?.requested_at || null,
    decidedAt: invitation?.decided_at || null,
    accessReleaseAt: invitation?.access_release_at || null,
    autoReleasedAt: invitation?.auto_released_at || null
  };
}

function normalizedOptionalEmail(value) {
  return normalizeEmail(value) || null;
}

function normalizedOptionalText(value) {
  return String(value || "").trim() || null;
}

function databaseFlag(value) {
  return value === true || value === 1 || value === "1";
}

function redactDeveloperPayload(value, key = "") {
  const sensitive = /passwort|password|token|secret|schluessel|encrypted_key|dateiDaten|bildDaten|audioDaten|daten$/i;
  if (sensitive.test(key)) return "[ausgeblendet]";
  if (Array.isArray(value)) return value.map((item) => redactDeveloperPayload(item));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([childKey, childValue]) => [childKey, redactDeveloperPayload(childValue, childKey)]));
  }
  return value;
}

function parseJSON(value) {
  if (typeof value !== "string") return value;
  try { return JSON.parse(value); } catch { return null; }
}

async function writeAudit({ actorUserID, action, targetUserID = null, requestID, metadata = {}, pool = databasePool() }) {
  await pool.query(
    `INSERT INTO audit_log (actor_user_id, action, target_user_id, request_id, metadata)
     VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [actorUserID, action, targetUserID, requestID || crypto.randomUUID(), JSON.stringify(metadata)]
  );
}

function requestID(res) {
  return typeof res.getHeader === "function" ? res.getHeader("X-Request-ID") : undefined;
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
