// No implicit consent for old clients, missing contacts or ambiguous matches.
export function automaticReleaseAllowedForContact(contacts, invitation) {
  const email = String(invitation.invited_email || "").trim().toLowerCase();
  if (!email || !Array.isArray(contacts?.vertrauenspersonen)) return false;
  const matches = contacts.vertrauenspersonen.filter((person) =>
    [person?.email, person?.einladungsEmail].some((value) => String(value || "").trim().toLowerCase() === email)
  );
  return matches.length === 1 && matches[0].automatischeVollfreigabeErlaubt === true;
}

export function trustAccessGraceSeconds(environment = process.env) {
  // Production always uses the seven days shown in the consent text.
  if (environment.APP_ENV === "production" ||
      (environment.NODE_ENV === "production" && !["development", "staging"].includes(environment.APP_ENV))) return 604_800;
  const raw = environment.TRUST_ACCESS_GRACE_SECONDS || "";
  const configured = /^\d+$/.test(raw) ? Number(raw) : NaN;
  if (Number.isInteger(configured) && configured >= 60 && configured <= 2_592_000) return configured;
  if (environment.NODE_ENV === "test") return 60;
  throw new Error("TRUST_ACCESS_GRACE_SECONDS fehlt oder ist ungueltig");
}

export async function syncAutomaticReleasePolicies(client, ownerUserID, dossierID, contacts) {
  const invitations = await client.query(
    `SELECT id, invited_email FROM dossier_invitations
      WHERE dossier_id = $1 AND owner_user_id = $2 AND status <> 'revoked'
      ORDER BY id FOR UPDATE`, [dossierID, ownerUserID]
  );
  const graceSeconds = trustAccessGraceSeconds();
  for (const invitation of invitations.rows) {
    const allowed = automaticReleaseAllowedForContact(contacts, invitation);
    const deadline = client.engine === "mysql"
      ? "DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL $2 SECOND)"
      : "now() + ($2::integer * interval '1 second')";
    // Enabling while pending starts a fresh grace period. Repeated syncs leave
    // an existing deadline untouched; disabling clears it without deciding.
    await client.query(
      `UPDATE dossier_invitations SET access_release_at = CASE
         WHEN NOT $1 THEN NULL
         WHEN status = 'pending' AND (NOT automatic_release_allowed OR access_release_at IS NULL) THEN ${deadline}
         ELSE access_release_at END,
         automatic_release_allowed = $1
       WHERE id = $3 AND owner_user_id = $4`,
      [allowed, graceSeconds, invitation.id, ownerUserID]
    );
  }
}
