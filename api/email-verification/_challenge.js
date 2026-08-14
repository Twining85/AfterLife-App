import crypto from "node:crypto";

const validityMilliseconds = 10 * 60 * 1000;

export function createCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

export function createChallenge(email, code) {
  const secret = process.env.EMAIL_VERIFICATION_SECRET;
  if (!secret) throw new Error("EMAIL_VERIFICATION_SECRET fehlt");

  const payload = Buffer.from(JSON.stringify({
    email,
    codeHash: hashCode(email, code, secret),
    expiresAt: Date.now() + validityMilliseconds
  })).toString("base64url");
  const signature = sign(payload, secret);
  return `${payload}.${signature}`;
}

export function verifyChallenge(token, code) {
  return readVerifiedChallenge(token, code) !== null;
}

export function readVerifiedChallenge(token, code) {
  const secret = process.env.EMAIL_VERIFICATION_SECRET;
  if (!secret || typeof token !== "string") return null;

  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [payload, signature] = parts;
  if (!payload || !signature) return null;
  const expectedSignature = sign(payload, secret);
  if (!safeEqual(signature, expectedSignature)) return null;

  try {
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    if (typeof data.email !== "string" || typeof data.codeHash !== "string") return null;
    if (!Number.isFinite(data.expiresAt) || Date.now() > data.expiresAt) return null;
    return safeEqual(data.codeHash, hashCode(data.email, String(code), secret)) ? data : null;
  } catch {
    return null;
  }
}

export function createRegistrationGrant(email) {
  const secret = process.env.EMAIL_VERIFICATION_SECRET;
  if (!secret) throw new Error("EMAIL_VERIFICATION_SECRET fehlt");
  const payload = Buffer.from(JSON.stringify({
    purpose: "account-registration",
    email,
    expiresAt: Date.now() + 15 * 60 * 1000
  })).toString("base64url");
  return `${payload}.${sign(payload, secret)}`;
}

export function verifyRegistrationGrant(token, email) {
  const secret = process.env.EMAIL_VERIFICATION_SECRET;
  if (!secret || typeof token !== "string") return false;
  const parts = token.split(".");
  if (parts.length !== 2 || !safeEqual(parts[1], sign(parts[0], secret))) return false;
  try {
    const data = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
    return data.purpose === "account-registration"
      && data.email === email
      && Number.isFinite(data.expiresAt)
      && Date.now() <= data.expiresAt;
  } catch {
    return false;
  }
}

export function expiresAt() {
  return new Date(Date.now() + validityMilliseconds).toISOString();
}

function hashCode(email, code, secret) {
  return crypto.createHmac("sha256", secret).update(`${email}:${code}`).digest("hex");
}

function sign(payload, secret) {
  return crypto.createHmac("sha256", secret).update(payload).digest("base64url");
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left));
  const b = Buffer.from(String(right));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
