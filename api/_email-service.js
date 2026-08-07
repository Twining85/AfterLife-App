import nodemailer from "nodemailer";

let transporter;

function mailTransporter() {
  if (transporter) return transporter;

  const host = process.env.MAILOMAT_SMTP_HOST || "smtp.mailomat.cloud";
  const port = Number(process.env.MAILOMAT_SMTP_PORT || 587);
  const user = process.env.MAILOMAT_SMTP_USER;
  const pass = process.env.MAILOMAT_SMTP_PASSWORD;

  if (!user || !pass) {
    throw new Error("MAILOMAT_SMTP_USER oder MAILOMAT_SMTP_PASSWORD fehlt");
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

export async function sendEmail({ to, subject, text, html }) {
  const from = process.env.EMAIL_FROM;
  const replyTo = process.env.EMAIL_REPLY_TO;
  if (!from) throw new Error("EMAIL_FROM fehlt");

  return mailTransporter().sendMail({ from, replyTo, to, subject, text, html });
}
