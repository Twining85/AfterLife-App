import { authenticatedUser } from "../_auth.js";
import { databasePool } from "../_database.js";
import { rateLimit, requireMethod, secureResponse } from "../_security.js";

export async function deleteAccountForUser({ userID, pool = databasePool() }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.user_id', $1, true)", [userID]);

    // Dossiers zuerst explizit löschen, weil created_by_user_id im bestehenden
    // Schema kein ON DELETE CASCADE besitzt. Alle Sections und Sync-Daten folgen
    // über ihre Foreign Keys automatisch.
    await client.query("DELETE FROM dossiers WHERE owner_user_id = $1", [userID]);
    const result = await client.query(
      "DELETE FROM app_users WHERE id = $1 RETURNING id",
      [userID]
    );
    if (result.rowCount !== 1) throw new Error("Konto nicht gefunden");

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "DELETE")) return;
  if (!rateLimit(req, res, {
    namespace: "account-delete",
    limit: 3,
    windowMilliseconds: 60 * 60 * 1000
  })) return;

  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Anmeldung erforderlich" });

  try {
    await deleteAccountForUser({ userID: user.id });
    return res.status(204).end();
  } catch (error) {
    console.error("Kontolöschung:", error);
    return res.status(500).json({ error: "Das Konto konnte nicht vollständig gelöscht werden" });
  }
}
