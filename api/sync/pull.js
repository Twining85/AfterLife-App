import { authenticatedUser } from "../_auth.js";
import { withUserTransaction } from "../_database.js";
import { requireMethod, secureResponse } from "../_security.js";
import { parseCursor } from "../_sync-contract.js";
import { changesSince } from "../_sync-repository.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "GET")) return;

  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });

  try {
    const cursor = parseCursor(req.query?.cursor);
    const result = await withUserTransaction(user.id, (client) =>
      changesSince(client, user.id, cursor)
    );
    return res.status(200).json(result);
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ error: error.message });
    console.error("Sync-Download:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
