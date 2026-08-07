import { createChallenge, createCode, expiresAt } from "./_challenge.js";
import { sendEmail } from "../_email-service.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Methode nicht erlaubt" });

  const email = String(req.body?.email || "").trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) {
    return res.status(400).json({ error: "Ungültige E-Mail-Adresse" });
  }

  const allowedRecipient = String(
    process.env.EMAIL_VERIFICATION_ALLOWED_RECIPIENT || ""
  ).trim().toLowerCase();
  if (allowedRecipient && email !== allowedRecipient) {
    return res.status(403).json({ error: "Empfänger im Testbetrieb nicht freigegeben" });
  }

  try {
    const code = createCode();
    const challengeToken = createChallenge(email, code);
    await sendEmail({
      to: email,
      subject: `${code} ist dein Tschlüssli-Bestätigungscode`,
      text: `Dein Tschlüssli-Bestätigungscode lautet:\n\n${code}\n\nDieser Code ist 10 Minuten gültig.`,
      html: `<p>Dein Tschlüssli-Bestätigungscode lautet:</p><p style="font-size:32px;font-weight:700;letter-spacing:6px">${code}</p><p>Dieser Code ist 10 Minuten gültig.</p>`
    });

    res.setHeader("Cache-Control", "no-store");
    return res.status(200).json({ challengeToken, expiresAt: expiresAt() });
  } catch (error) {
    console.error("E-Mail-Verifizierung:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
