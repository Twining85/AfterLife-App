import { verifyEmailTransport, sendEmail } from "../api/_email-service.js";

try {
  await verifyEmailTransport();
  console.log("SMTP: TLS-Verbindung und Anmeldung erfolgreich.");
  if (process.argv[2]) {
    await sendEmail({
      to: process.argv[2],
      subject: "Tschlüssli SMTP-Test",
      text: "Der SMTP-Versand von Tschlüssli funktioniert. Bitte im Mailheader SPF, DKIM und DMARC prüfen."
    });
    console.log("SMTP: Testmail vom Versandserver angenommen; Zustellung im Postfach prüfen.");
  }
} catch (error) {
  // SMTP errors can include addresses and server details; do not print credentials or raw responses.
  console.error("SMTP-Prüfung fehlgeschlagen:", error.code || "Konfiguration oder Versand prüfen");
  process.exitCode = 1;
}
