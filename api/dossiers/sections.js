import crypto from "node:crypto";
import { authenticatedUser } from "../_auth.js";
import { withUserTransaction } from "../_database.js";
import { requireJSON, secureResponse } from "../_security.js";
import { storageService } from "../_storage.js";
import { parseMutation } from "../_sync-contract.js";
import { applySectionMutation } from "../_sync-repository.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (req.method !== "GET" && req.method !== "PUT") {
    res.setHeader("Allow", "GET, PUT");
    return res.status(405).json({ error: "Methode nicht erlaubt" });
  }
  if (req.method === "PUT" && !requireJSON(req, res, 256_000)) return;
  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });
  const dossierID = String(req.query?.dossierID || "").toLowerCase();
  const sectionType = String(req.query?.sectionType || "");
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(dossierID) || !/^[a-z][a-z0-9_-]{0,63}$/.test(sectionType)) {
    return res.status(400).json({ error: "Ungültiger Dossierbereich" });
  }
  try {
    const result = await withUserTransaction(user.id, async client => {
      if (req.method === "PUT") {
        // Both write routes use the same revision, consent and downgrade guards.
        const mutation = parseMutation({ ...req.body, dossierID, sectionType, operation: "upsert",
          schemaVersion: req.body?.schemaVersion ?? 1, expectedRevision: req.body?.expectedRevision ?? 0
        }, req.headers?.["idempotency-key"] || `legacy:${crypto.randomUUID()}`);
        const saved = await applySectionMutation(client, user.id, mutation);
        if (saved.statusCode !== 200) return saved;
      }
      const rows = await client.query(
        `SELECT schema_version, revision, payload, updated_at FROM dossier_sections
          WHERE dossier_id = $1 AND section_type = $2 AND owner_user_id = $3 AND deleted_at IS NULL`,
        [dossierID, sectionType, user.id]
      );
      return { statusCode: rows.rows[0] ? 200 : 404, body: rows.rows[0] || { error: "Bereich nicht gefunden" } };
    });
    if (result.statusCode === 200) {
      result.body.payload = await storageService().loadSectionPayload(result.body.payload, { dossierID, sectionType });
    }
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ error: error.message });
    console.error("Dossierbereich:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
