import { contactsFromAccessMetadata } from "./_e2e-contract.js";
import { syncAutomaticReleasePolicies } from "./_trust-policy.js";

export async function saveAccessMetadata(client, ownerUserID, mutation, revision) {
  const { dossierID, sectionType, accessMetadata } = mutation;
  if (!["kontakte", "dossier_einstellungen"].includes(sectionType)) return;
  if (mutation.operation === "delete") {
    await client.query(
      "DELETE FROM dossier_access_metadata WHERE owner_user_id = $1 AND dossier_id = $2 AND section_type = $3",
      [ownerUserID, dossierID, sectionType]
    );
    if (sectionType === "kontakte") await syncAutomaticReleasePolicies(client, ownerUserID, dossierID, null);
    return;
  }
  const params = [dossierID, ownerUserID, sectionType, revision, JSON.stringify(accessMetadata)];
  const sql = client.engine === "mysql"
    ? `INSERT INTO dossier_access_metadata (dossier_id, owner_user_id, section_type, revision, metadata)
       VALUES ($1, $2, $3, $4, $5)
       ON DUPLICATE KEY UPDATE revision = VALUES(revision), metadata = VALUES(metadata), updated_at = CURRENT_TIMESTAMP(6)`
    : `INSERT INTO dossier_access_metadata (dossier_id, owner_user_id, section_type, revision, metadata)
       VALUES ($1, $2, $3, $4, $5::jsonb)
       ON CONFLICT (dossier_id, section_type) DO UPDATE SET revision = EXCLUDED.revision,
         metadata = EXCLUDED.metadata, updated_at = now()`;
  await client.query(sql, params);
  if (sectionType === "kontakte") {
    await syncAutomaticReleasePolicies(client, ownerUserID, dossierID, contactsFromAccessMetadata(accessMetadata));
  }
}

export async function loadAccessMetadata(client, ownerUserID, dossierID) {
  const result = await client.query(
    `SELECT m.section_type, m.metadata FROM dossier_access_metadata m
       JOIN dossier_sections s ON s.dossier_id = m.dossier_id AND s.section_type = m.section_type
        AND s.revision = m.revision AND s.encryption_version = 2 AND s.deleted_at IS NULL
      WHERE m.owner_user_id = $1 AND m.dossier_id = $2`, [ownerUserID, dossierID]
  );
  return Object.fromEntries(result.rows.map(row => [row.section_type,
    typeof row.metadata === "string" ? JSON.parse(row.metadata) : row.metadata]));
}
