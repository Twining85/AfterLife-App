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
  const secret = process.env.EMAIL_VERIFICATION_SECRET;
  if (!secret || typeof token !== "string") return false;

  const [payload, signature] = token.split(".");
  if (!payload || !signature) return false;
  const expectedSignature = sign(payload, secret);
  if (!safeEqual(signature, expectedSignature)) return false;

  try {
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    if (Date.now() > data.expiresAt) return false;
    return safeEqual(data.codeHash, hashCode(data.email, String(code), secret));
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
