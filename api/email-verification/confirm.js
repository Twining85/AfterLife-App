import { verifyChallenge } from "./_challenge.js";
import { rateLimit, requireJSON, requireMethod, secureResponse } from "../_security.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST")) return;
  if (!requireJSON(req, res)) return;
  if (!rateLimit(req, res, {
    namespace: "email-verification-confirm",
    limit: 10,
    windowMilliseconds: 15 * 60 * 1000
  })) return;

  const code = String(req.body?.code || "").trim();
  const challengeToken = req.body?.challengeToken;
  if (!/^\d{6}$/.test(code) || !verifyChallenge(challengeToken, code)) {
    return res.status(400).json({ error: "Code ungültig oder abgelaufen" });
  }

  return res.status(200).json({ verified: true });
}
