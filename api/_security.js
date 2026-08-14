import crypto from "node:crypto";

const buckets = new Map();

export function secureResponse(res) {
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("X-Request-ID", crypto.randomUUID());
}

export function requireMethod(req, res, method) {
  if (req.method === method) return true;
  res.setHeader("Allow", method);
  res.status(405).json({ error: "Methode nicht erlaubt" });
  return false;
}

export function requireJSON(req, res, maximumBytes = 8_192) {
  const contentType = String(req.headers?.["content-type"] || "")
    .split(";", 1)[0]
    .trim()
    .toLowerCase();
  if (contentType !== "application/json") {
    res.status(415).json({ error: "Content-Type application/json erforderlich" });
    return false;
  }

  const contentLength = Number(req.headers?.["content-length"] || 0);
  if (Number.isFinite(contentLength) && contentLength > maximumBytes) {
    res.status(413).json({ error: "Anfrage zu gross" });
    return false;
  }
  return true;
}

export function rateLimit(req, res, { namespace, limit, windowMilliseconds }) {
  const now = Date.now();
  const key = `${namespace}:${clientAddress(req)}`;
  const current = buckets.get(key);
  const bucket = !current || current.resetAt <= now
    ? { count: 0, resetAt: now + windowMilliseconds }
    : current;

  bucket.count += 1;
  buckets.set(key, bucket);
  res.setHeader("RateLimit-Limit", String(limit));
  res.setHeader("RateLimit-Remaining", String(Math.max(0, limit - bucket.count)));
  res.setHeader("RateLimit-Reset", String(Math.ceil(bucket.resetAt / 1000)));

  if (bucket.count <= limit) return true;
  res.setHeader("Retry-After", String(Math.max(1, Math.ceil((bucket.resetAt - now) / 1000))));
  res.status(429).json({ error: "Zu viele Anfragen. Bitte später erneut versuchen." });
  return false;
}

export function normalizeEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
}

export function clearRateLimitsForTests() {
  buckets.clear();
}

function clientAddress(req) {
  const forwarded = String(req.headers?.["x-forwarded-for"] || "").split(",", 1)[0].trim();
  return forwarded || req.socket?.remoteAddress || "unknown";
}
