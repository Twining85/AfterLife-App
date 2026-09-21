import assert from "node:assert/strict";
import test from "node:test";
import {
  clearRateLimitsForTests,
  isEmailRecipientAllowed,
  normalizeEmail,
  rateLimit,
  requireJSON,
  requireMethod,
  secureResponse
} from "../api/_security.js";

function response() {
  return {
    headers: {},
    statusCode: 200,
    body: undefined,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
}

test("normalisiert gültige E-Mail-Adressen", () => {
  assert.equal(normalizeEmail(" Test@Example.CH "), "test@example.ch");
  assert.equal(normalizeEmail("keine-adresse"), null);
});

test("erlaubt eine konfigurierbare Liste von DEV-E-Mail-Empfängern", () => {
  const environment = {
    EMAIL_VERIFICATION_ALLOWED_RECIPIENTS: "first@example.ch, Second@Example.ch",
    EMAIL_VERIFICATION_ALLOWED_RECIPIENT: "legacy@example.ch"
  };
  assert.equal(isEmailRecipientAllowed("first@example.ch", environment), true);
  assert.equal(isEmailRecipientAllowed("second@example.ch", environment), true);
  assert.equal(isEmailRecipientAllowed("legacy@example.ch", environment), true);
  assert.equal(isEmailRecipientAllowed("blocked@example.ch", environment), false);
  assert.equal(isEmailRecipientAllowed("any@example.ch", {}), true);
});

test("erlaubt in DEV unbekannte Temp-Mail-Domains, aber keine gesperrten Standardanbieter", () => {
  const environment = {
    EMAIL_VERIFICATION_ALLOWED_RECIPIENTS: "allowed@gmail.com",
    EMAIL_VERIFICATION_ALLOW_UNLISTED: "true",
    EMAIL_VERIFICATION_BLOCKED_DOMAINS: "gmail.com, gmx.net, outlook.com"
  };
  assert.equal(isEmailRecipientAllowed("allowed@gmail.com", environment), true);
  assert.equal(isEmailRecipientAllowed("random@gmail.com", environment), false);
  assert.equal(isEmailRecipientAllowed("random@gmx.net", environment), false);
  assert.equal(isEmailRecipientAllowed("random@temporary-random.example", environment), true);
});

test("setzt Sicherheits-Header und eine Request-ID", () => {
  const res = response();
  secureResponse(res);
  assert.equal(res.headers["Cache-Control"], "no-store, max-age=0");
  assert.equal(res.headers["X-Content-Type-Options"], "nosniff");
  assert.match(res.headers["X-Request-ID"], /^[0-9a-f-]{36}$/);
});

test("lehnt falsche Methode und falschen Inhaltstyp ab", () => {
  const methodResponse = response();
  assert.equal(requireMethod({ method: "GET" }, methodResponse, "POST"), false);
  assert.equal(methodResponse.statusCode, 405);
  assert.equal(methodResponse.headers.Allow, "POST");

  const jsonResponse = response();
  assert.equal(requireJSON({ headers: { "content-type": "text/plain" } }, jsonResponse), false);
  assert.equal(jsonResponse.statusCode, 415);
});

test("begrenzt Anfragen pro Client", () => {
  clearRateLimitsForTests();
  const req = { headers: { "x-forwarded-for": "192.0.2.1" } };
  assert.equal(rateLimit(req, response(), { namespace: "test", limit: 1, windowMilliseconds: 60_000 }), true);
  const blocked = response();
  assert.equal(rateLimit(req, blocked, { namespace: "test", limit: 1, windowMilliseconds: 60_000 }), false);
  assert.equal(blocked.statusCode, 429);
});
