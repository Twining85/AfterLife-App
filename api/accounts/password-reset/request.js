import { fileURLToPath } from "node:url";
import { hashSessionToken } from "../../_auth.js";
import { databasePool } from "../../_database.js";
import { sendEmail } from "../../_email-service.js";
import { normalizeEmail, rateLimit, requireJSON, requireMethod, secureResponse } from "../../_security.js";
import { createChallenge, createCode, expiresAt } from "../../email-verification/_challenge.js";

export default async function handler(req, res) {
  secureResponse(res);
  if (!requireMethod(req, res, "POST") || !requireJSON(req, res)) return;
  if (!rateLimit(req, res, { namespace: "password-reset-request", limit: 5, windowMilliseconds: 30 * 60 * 1000 })) return;

  const email = normalizeEmail(req.body?.email);
  if (!email) return res.status(400).json({ error: "Ungültige E-Mail-Adresse" });
  const allowedRecipient = String(process.env.EMAIL_VERIFICATION_ALLOWED_RECIPIENT || "")
    .trim()
    .toLowerCase();
  if (allowedRecipient && email !== allowedRecipient) {
    return res.status(403).json({ error: "Empfänger im Testbetrieb nicht freigegeben" });
  }

  try {
    const code = createCode();
    const challengeToken = createChallenge(email, code, "password-reset");
    const gueltigBis = expiresAt();
    const result = await databasePool().query(
      `SELECT id FROM app_users WHERE email = $1 AND disabled_at IS NULL`,
      [email]
    );
    const user = result.rows[0];
    if (user) {
      await databasePool().query(
        `INSERT INTO password_reset_challenges (user_id, token_hash, expires_at)
         VALUES ($1, $2, $3)`,
        [user.id, hashSessionToken(challengeToken), gueltigBis]
      );
      await sendEmail({
        to: email,
        subject: `${code} ist dein Tschlüssli-Code zum Zurücksetzen des Passworts`,
        text: `Mit diesem Code kannst du dein Tschlüssli-Passwort zurücksetzen:\n\n${code}\n\nDer Code ist 10 Minuten gültig. Falls du dies nicht angefordert hast, ignoriere diese Nachricht.`,
        html: `<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#1f1f1d;text-align:center;line-height:1.5"><p>Mit diesem Code kannst du dein Tschlüssli-Passwort zurücksetzen:</p><p style="font-size:32px;font-weight:700;letter-spacing:6px;color:#295c6b;margin:20px 0">${code}</p><p>Der Code ist 10 Minuten gültig. Falls du dies nicht angefordert hast, ignoriere diese Nachricht.</p><img src="cid:tschluessli-logo" alt="Tschlüssli" width="160" style="display:block;width:160px;max-width:55%;height:auto;margin:24px auto 0;border:0" /></div>`,
        attachments: [{
          filename: "tschluessli.png",
          path: fileURLToPath(new URL("../../assets/tschluessli-email-logo.png", import.meta.url)),
          cid: "tschluessli-logo"
        }]
      });
    }
    // Dieselbe Antwort auch fuer unbekannte Adressen verhindert Kontoauskunft.
    return res.status(200).json({ challengeToken, expiresAt: gueltigBis });
  } catch (error) {
    console.error("Passwort-Reset anfordern:", error);
    return res.status(500).json({ error: "Interner Fehler" });
  }
}
