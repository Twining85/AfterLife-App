import { authenticatedUser } from "../_auth.js";
import { withUserTransaction } from "../_database.js";
import { requireMethod, secureResponse } from "../_security.js";
import { currentSnapshot } from "../_sync-repository.js";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "GET")) return;

  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });
  const dossierID = String(req.query?.dossierID || "").toLowerCase();
  if (!uuidPattern.test(dossierID)) {
    return res.status(400).json({ error: "Ungültiges Dossier" });
  }

  try {
    const result = await withUserTransaction(user.id, (client) =>
      currentSnapshot(client, user.id, dossierID)
    );
    return res.status(200).json(result);
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ error: error.message });
    console.error("Sync-Snapshot:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
