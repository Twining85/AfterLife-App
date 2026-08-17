import assert from "node:assert/strict";
import test from "node:test";
import {
  createChallenge,
  createCode,
  createRegistrationGrant,
  verifyChallenge,
  verifyRegistrationGrant
} from "../api/email-verification/_challenge.js";

test("erstellt sechsstellige Codes", () => {
  assert.match(createCode(), /^\d{6}$/);
});

test("bindet Registrierungserlaubnis an die bestätigte E-Mail", () => {
  const previous = process.env.EMAIL_VERIFICATION_SECRET;
  process.env.EMAIL_VERIFICATION_SECRET = "test-secret-with-sufficient-entropy";
  try {
    const grant = createRegistrationGrant("person@example.ch");
    assert.equal(verifyRegistrationGrant(grant, "person@example.ch"), true);
    assert.equal(verifyRegistrationGrant(grant, "andere@example.ch"), false);
  } finally {
    if (previous === undefined) delete process.env.EMAIL_VERIFICATION_SECRET;
    else process.env.EMAIL_VERIFICATION_SECRET = previous;
  }
});

test("akzeptiert nur korrekt signierten Code", () => {
  const previous = process.env.EMAIL_VERIFICATION_SECRET;
  process.env.EMAIL_VERIFICATION_SECRET = "test-secret-with-sufficient-entropy";
  try {
    const token = createChallenge("person@example.ch", "123456");
    assert.equal(verifyChallenge(token, "123456"), true);
    assert.equal(verifyChallenge(token, "654321"), false);
    assert.equal(verifyChallenge(`${token}.extra`, "123456"), false);
    assert.equal(verifyChallenge(`${token.slice(0, -1)}x`, "123456"), false);
    const resetToken = createChallenge("person@example.ch", "123456", "password-reset");
    assert.equal(verifyChallenge(resetToken, "123456"), false);
    assert.equal(verifyChallenge(resetToken, "123456", "password-reset"), true);
  } finally {
    if (previous === undefined) delete process.env.EMAIL_VERIFICATION_SECRET;
    else process.env.EMAIL_VERIFICATION_SECRET = previous;
  }
});
