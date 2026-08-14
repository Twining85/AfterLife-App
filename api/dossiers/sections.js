import { authenticatedUser } from "../_auth.js";
import { withUserTransaction } from "../_database.js";
import { requireJSON, secureResponse } from "../_security.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (req.method !== "GET" && req.method !== "PUT") {
    res.setHeader("Allow", "GET, PUT");
    return res.status(405).json({ error: "Methode nicht erlaubt" });
  }
  if (req.method === "PUT" && !requireJSON(req, res, 256_000)) return;

  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });
  const dossierID = String(req.query?.dossierID || "");
  const sectionType = String(req.query?.sectionType || "");
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(dossierID) || !/^[a-z][a-z0-9_-]{0,63}$/.test(sectionType)) {
    return res.status(400).json({ error: "Ungültiger Dossierbereich" });
  }

  try {
    const result = await withUserTransaction(user.id, async (client) => {
      if (req.method === "GET") {
        return client.query(
          `SELECT schema_version, revision, payload, updated_at
             FROM dossier_sections WHERE dossier_id = $1 AND section_type = $2`,
          [dossierID, sectionType]
        );
      }
      const schemaVersion = Number(req.body?.schemaVersion || 1);
      const expectedRevision = Number(req.body?.expectedRevision || 0);
      const payload = req.body?.payload;
      if (!Number.isInteger(schemaVersion) || schemaVersion < 1 || !Number.isInteger(expectedRevision) || expectedRevision < 0 || !payload || Array.isArray(payload) || typeof payload !== "object") {
        const error = new Error("Ungültige Bereichsdaten");
        error.statusCode = 400;
        throw error;
      }
      return client.query(
        `INSERT INTO dossier_sections (dossier_id, owner_user_id, section_type, schema_version, payload)
         SELECT id, owner_user_id, $2, $3, $4::jsonb FROM dossiers WHERE id = $1 AND $5 = 0
         ON CONFLICT (dossier_id, section_type) DO UPDATE
           SET schema_version = EXCLUDED.schema_version,
               payload = EXCLUDED.payload,
               revision = dossier_sections.revision + 1,
               updated_at = now()
         WHERE dossier_sections.revision = $5
         RETURNING schema_version, revision, payload, updated_at`,
        [dossierID, sectionType, schemaVersion, JSON.stringify(payload), expectedRevision]
      );
    });
    if (!result.rows[0]) return res.status(req.method === "PUT" ? 409 : 404).json({ error: req.method === "PUT" ? "Daten wurden zwischenzeitlich geändert" : "Bereich nicht gefunden" });
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ error: error.message });
    console.error("Dossierbereich:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
