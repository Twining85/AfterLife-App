import assert from "node:assert/strict";
import test from "node:test";
import { createSessionToken, hashPassword, hashSessionToken, verifyPassword } from "../api/_auth.js";
import { changePasswordForUser } from "../api/accounts/change-password.js";
import { resetPassword } from "../api/accounts/password-reset/confirm.js";
import { createChallenge } from "../api/email-verification/_challenge.js";

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

test("ändert ein Passwort erst nach Prüfung des bisherigen Passworts", async () => {
  const bisher = await hashPassword("bisheriges Passwort 123");
  const queries = [];
  const client = {
    async query(sql, params = []) {
      queries.push({ sql, params });
      if (sql.includes("SELECT password_hash")) {
        return { rows: [{ password_hash: bisher.hash, password_salt: bisher.salt }] };
      }
      return { rows: [] };
    },
    release() {}
  };
  await changePasswordForUser({
    userID: "00000000-0000-0000-0000-000000000001",
    currentPassword: "bisheriges Passwort 123",
    newPassword: "vollständig neues Passwort 456",
    pool: { async connect() { return client; } }
  });

  const update = queries.find(({ sql }) => sql.includes("UPDATE app_users"));
  assert.ok(update);
  assert.notEqual(update.params[1], "vollständig neues Passwort 456");
  assert.equal(await verifyPassword("vollständig neues Passwort 456", update.params[2], update.params[1]), true);
  assert.equal(queries.at(-1).sql, "COMMIT");
});

test("ändert das Passwort bei falschem bisherigen Passwort nicht", async () => {
  const bisher = await hashPassword("bisheriges Passwort 123");
  const queries = [];
  const client = {
    async query(sql) {
      queries.push(sql);
      if (sql.includes("SELECT password_hash")) {
        return { rows: [{ password_hash: bisher.hash, password_salt: bisher.salt }] };
      }
      return { rows: [] };
    },
    release() {}
  };
  await assert.rejects(
    () => changePasswordForUser({
      userID: "00000000-0000-0000-0000-000000000001",
      currentPassword: "falsches bisheriges Passwort",
      newPassword: "vollständig neues Passwort 456",
      pool: { async connect() { return client; } }
    }),
    /nicht korrekt/
  );
  assert.equal(queries.some((sql) => sql.includes("UPDATE app_users")), false);
  assert.equal(queries.at(-1), "ROLLBACK");
});

test("setzt ein Passwort mit einmaligem Reset-Code zurück und widerruft Sitzungen", async () => {
  const previous = process.env.EMAIL_VERIFICATION_SECRET;
  process.env.EMAIL_VERIFICATION_SECRET = "test-secret-with-sufficient-entropy";
  try {
    const token = createChallenge("person@example.ch", "123456", "password-reset");
    const queries = [];
    const client = {
      async query(sql, params = []) {
        queries.push({ sql, params });
        if (sql.includes("FROM password_reset_challenges")) {
          return { rows: [{
            id: "challenge-id",
            user_id: "user-id",
            attempts: 0,
            email: "person@example.ch"
          }] };
        }
        return { rows: [] };
      },
      release() {}
    };
    await resetPassword({
      challengeToken: token,
      code: "123456",
      newPassword: "vollständig neues Passwort 789",
      pool: { async connect() { return client; } }
    });
    const passwordUpdate = queries.find(({ sql }) => sql.includes("UPDATE app_users"));
    assert.ok(passwordUpdate);
    assert.equal(
      await verifyPassword("vollständig neues Passwort 789", passwordUpdate.params[2], passwordUpdate.params[1]),
      true
    );
    assert.equal(queries.some(({ sql }) => sql.includes("consumed_at = now()")), true);
    assert.equal(queries.some(({ sql }) => sql.includes("UPDATE user_sessions")), true);
    assert.equal(queries.at(-1).sql, "COMMIT");
  } finally {
    if (previous === undefined) delete process.env.EMAIL_VERIFICATION_SECRET;
    else process.env.EMAIL_VERIFICATION_SECRET = previous;
  }
});
