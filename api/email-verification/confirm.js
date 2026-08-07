import { verifyChallenge } from "./_challenge.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Methode nicht erlaubt" });

  const code = String(req.body?.code || "").trim();
  const challengeToken = req.body?.challengeToken;
  if (!/^\d{6}$/.test(code) || !verifyChallenge(challengeToken, code)) {
    return res.status(400).json({ error: "Code ungültig oder abgelaufen" });
  }

  res.setHeader("Cache-Control", "no-store");
  return res.status(200).json({ verified: true });
}
