import { authenticatedUser } from "../_auth.js";
import { withUserTransaction } from "../_database.js";
import { requireJSON, requireMethod, secureResponse } from "../_security.js";
import { parseMutation } from "../_sync-contract.js";
import { applySectionMutation } from "../_sync-repository.js";
import { handleInvitationOperation } from "../_invitation-handler.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res, 256_000)) return;

  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });

  const operation = String(req.query?.operation || "");
  if (operation) return handleInvitationOperation(operation, req, res, user);

  try {
    const mutation = parseMutation(req.body, req.headers?.["idempotency-key"]);
    const result = await withUserTransaction(user.id, (client) =>
      applySectionMutation(client, user.id, mutation)
    );
    if (result.replayed) res.setHeader("Idempotency-Replayed", "true");
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ error: error.message });
    console.error("Sync-Upload:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
