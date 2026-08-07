import nodemailer from "nodemailer";

let transporter;

function mailTransporter() {
  if (transporter) return transporter;

  const host = process.env.EMAIL_SMTP_HOST
    || process.env.MAILOMAT_SMTP_HOST
    || "smtp.mailomat.cloud";
  const port = Number(
    process.env.EMAIL_SMTP_PORT
      || process.env.MAILOMAT_SMTP_PORT
      || 587
  );
  const user = process.env.EMAIL_SMTP_USER || process.env.MAILOMAT_SMTP_USER;
  const pass = process.env.EMAIL_SMTP_PASSWORD || process.env.MAILOMAT_SMTP_PASSWORD;

  if (!user || !pass) {
    throw new Error("SMTP-Benutzername oder SMTP-Passwort fehlt");
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port === 587,
    auth: { user, pass }
  });
  return transporter;
}

export async function sendEmail({ to, subject, text, html, attachments = [] }) {
  const from = process.env.EMAIL_SMTP_FROM || process.env.EMAIL_FROM;
  const replyTo = process.env.EMAIL_SMTP_REPLY_TO || process.env.EMAIL_REPLY_TO;
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
