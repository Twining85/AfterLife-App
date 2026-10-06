import nodemailer from "nodemailer";

let transporter;

export function emailTransportConfiguration(environment = process.env) {
  const host = environment.SMTP_HOST
    || environment.EMAIL_SMTP_HOST
    || environment.MAILOMAT_SMTP_HOST;
  if (!host || !String(host).trim()) throw new Error("SMTP-Host muss ausdrücklich konfiguriert werden");
  const port = Number(
    environment.SMTP_PORT
      || environment.EMAIL_SMTP_PORT
      || environment.MAILOMAT_SMTP_PORT
      || 587
  );
  if (![465, 587].includes(port)) throw new Error("SMTP-Port muss 465 oder 587 sein");
  const user = environment.SMTP_USER || environment.EMAIL_SMTP_USER || environment.MAILOMAT_SMTP_USER;
  const pass = environment.SMTP_PASSWORD || environment.EMAIL_SMTP_PASSWORD || environment.MAILOMAT_SMTP_PASSWORD;

  if (!user || !pass) {
    throw new Error("SMTP-Benutzername oder SMTP-Passwort fehlt");
  }

  return {
    host: String(host).trim(),
    port,
    secure: port === 465,
    requireTLS: port === 587,
    tls: { rejectUnauthorized: true, minVersion: "TLSv1.2" },
    auth: { user, pass }
  };
}

function mailTransporter() {
  if (transporter) return transporter;
  transporter = nodemailer.createTransport(emailTransportConfiguration());
  return transporter;
}

export async function sendEmail({ to, subject, text, html, attachments = [] }) {
  const from = process.env.SMTP_FROM || process.env.EMAIL_SMTP_FROM || process.env.EMAIL_FROM;
  const replyTo = process.env.SMTP_REPLY_TO || process.env.EMAIL_SMTP_REPLY_TO || process.env.EMAIL_REPLY_TO;
  if (!from) throw new Error("SMTP-Absender fehlt");

  return mailTransporter().sendMail({
    from,
    replyTo,
    to,
    subject,
    text,
    html,
    attachments
  });
}
