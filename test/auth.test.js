import assert from "node:assert/strict";
import test from "node:test";
import { createSessionToken, hashPassword, hashSessionToken, verifyPassword } from "../api/_auth.js";

test("hasht und prüft Passwörter", async () => {
  const stored = await hashPassword("ein langes Testpasswort");
  assert.equal(await verifyPassword("ein langes Testpasswort", stored.salt, stored.hash), true);
  assert.equal(await verifyPassword("falsches Passwort", stored.salt, stored.hash), false);
  assert.notEqual(stored.hash, "ein langes Testpasswort");
});

test("erzeugt und hasht zufällige Session-Tokens", () => {
  const first = createSessionToken();
  const second = createSessionToken();
  assert.match(first, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(first, second);
  assert.match(hashSessionToken(first), /^[0-9a-f]{64}$/);
});

test("lehnt zu kurze Passwörter ab", async () => {
  await assert.rejects(() => hashPassword("zu-kurz"), /12 bis 128/);
});
