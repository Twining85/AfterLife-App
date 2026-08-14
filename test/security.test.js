import assert from "node:assert/strict";
import test from "node:test";
import {
  clearRateLimitsForTests,
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
