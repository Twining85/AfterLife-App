import { releaseDueInvitations } from "../_invitation-handler.js";

export default async function handler(req, res) {
  const secret = String(process.env.CRON_SECRET || "");
  const authorization = String(req.headers?.authorization || "");
  if (!secret || authorization !== `Bearer ${secret}`) {
    return res.status(401).json({ error: "Nicht autorisiert" });
  }
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ error: "Methode nicht erlaubt" });
  }

  try {
    const released = await releaseDueInvitations();
    return res.status(200).json({ released });
  } catch (error) {
    console.error("Automatische Dossierfreigabe:", error);
    return res.status(500).json({ error: "Automatische Freigabe fehlgeschlagen" });
  }
}
