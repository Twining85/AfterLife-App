import { databasePool } from "../api/_database.js";
import { isStorageReference, storageConfiguration, storageService } from "../api/_storage.js";

const configuration = storageConfiguration();
if (!configuration.configured) throw new Error("Object Storage ist nicht aktiviert");

const pool = databasePool();
const storage = storageService();
let migratedSections = 0;
let migratedChanges = 0;
const migratedReferences = new Map();

try {
  const sections = await pool.query(
    `SELECT dossier_id, section_type, revision, payload
       FROM dossier_sections
      WHERE deleted_at IS NULL
      ORDER BY dossier_id, section_type`
  );
  for (const row of sections.rows) {
    const payload = parseJSON(row.payload);
    if (!payload || isStorageReference(payload)) continue;
    const stored = await storage.storeSectionPayload({
      dossierID: row.dossier_id,
      sectionType: row.section_type,
      revision: Number(row.revision),
      payload
    });
    if (!isStorageReference(stored)) continue;
    migratedReferences.set(sectionRevisionKey(row), stored);
    await pool.query(
      `UPDATE dossier_sections SET payload = $1
        WHERE dossier_id = $2 AND section_type = $3 AND revision = $4`,
      [JSON.stringify(stored), row.dossier_id, row.section_type, Number(row.revision)]
    );
    migratedSections += 1;
  }

  let cursor = "0";
  while (true) {
    const changes = await pool.query(
      `SELECT change_id, dossier_id, section_type, revision, payload
         FROM sync_changes
        WHERE change_id > $1 AND payload IS NOT NULL
        ORDER BY change_id
        LIMIT 100`,
      [cursor]
    );
    if (!changes.rows.length) break;
    for (const row of changes.rows) {
      cursor = String(row.change_id);
      const payload = parseJSON(row.payload);
      if (!payload || isStorageReference(payload)) continue;
      const key = sectionRevisionKey(row);
      const stored = migratedReferences.get(key) || await storage.storeSectionPayload({
        dossierID: row.dossier_id,
        sectionType: row.section_type,
        revision: Number(row.revision),
        payload
      });
      if (!isStorageReference(stored)) continue;
      migratedReferences.set(key, stored);
      await pool.query(
        "UPDATE sync_changes SET payload = $1 WHERE change_id = $2",
        [JSON.stringify(stored), String(row.change_id)]
      );
      migratedChanges += 1;
    }
  }

  console.log(JSON.stringify({
    event: "object_storage_migration_complete",
    migratedSections,
    migratedChanges
  }));
} finally {
  await pool.end();
}

function parseJSON(value) {
  if (typeof value !== "string") return value;
  try { return JSON.parse(value); } catch { return null; }
}

function sectionRevisionKey(row) {
  return `${row.dossier_id}:${row.section_type}:${row.revision}`;
}
