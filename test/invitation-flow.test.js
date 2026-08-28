import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import {
  handleInvitationOperation,
  invitationDecisionPushPayload,
  invitationRequestPushPayload,
  revokeInvitationForOwner
} from "../api/_invitation-handler.js";
import { resetDatabasePoolForTests, setDatabasePoolForTests } from "../api/_database.js";

process.env.NODE_ENV = "test";

afterEach(() => resetDatabasePoolForTests());

test("prüft den QR-Code gegen die verifizierte Konto-E-Mail", async () => {
  const pool = scriptedPool([{ rows: [{
    dossier_id: "9ca650a8-a78c-4ef0-b62f-cb640531b667",
    owner_user_id: "cbcb4c1c-289f-4719-b237-02c9c7534642",
    owner_name: "Anna Beispiel",
    invited_email: "trust@example.ch",
    expires_at: new Date("2026-09-20T10:00:00Z")
  }] }]);
  setDatabasePoolForTests(pool);
  const res = responseRecorder();
  await handleInvitationOperation(
    "validate-invitation",
    { body: { token: "invite-token", profileEmail: "manipulated@example.ch" } },
    res,
    { id: "a1a14c1c-289f-4719-b237-02c9c7534642", email: "TRUST@example.ch" }
  );
  assert.equal(res.statusCode, 200);
  assert.equal(pool.calls[0].parameters[1], "trust@example.ch");
  assert.equal(pool.calls[0].parameters.includes("manipulated@example.ch"), false);
});

test("Scan allein erzeugt keine Anfrage und der bewusste Request meldet fehlende Push-Zustellung", async () => {
  const pool = scriptedPool([
    { rows: [{
      dossier_id: "9ca650a8-a78c-4ef0-b62f-cb640531b667",
      owner_user_id: "cbcb4c1c-289f-4719-b237-02c9c7534642",
      owner_name: "Anna Beispiel",
      invited_email: "trust@example.ch",
      expires_at: new Date("2026-09-20T10:00:00Z")
    }] },
    { rows: [] }
  ]);
  setDatabasePoolForTests(pool);
  const res = responseRecorder();
  await handleInvitationOperation(
    "request-invitation",
    { body: { token: "invite-token", requesterName: "Max Muster" } },
    res,
    { id: "a1a14c1c-289f-4719-b237-02c9c7534642", email: "trust@example.ch" }
  );
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.notificationDelivered, false);
  assert.match(pool.calls[0].text, /status = 'pending'/);
  assert.match(pool.calls[0].text, /'declined'/);
  assert.equal(pool.calls[0].parameters[3], "Max Muster");
  assert.equal(pool.calls.length, 2);
});

test("nennt die beteiligten Personen in den Pushnachrichten", () => {
  const request = invitationRequestPushPayload({
    token: "token",
    requesterName: "Max Muster",
    requesterEmail: "max@example.ch",
    requesterUserID: "user-id"
  });
  assert.match(request.aps.alert.body, /Max Muster/);

  const accepted = invitationDecisionPushPayload({
    token: "token",
    decision: "accepted",
    ownerName: "Anna Beispiel"
  });
  const declined = invitationDecisionPushPayload({
    token: "token",
    decision: "declined",
    ownerName: "Anna Beispiel"
  });
  assert.match(accepted.aps.alert.body, /Anna Beispiel/);
  assert.match(declined.aps.alert.body, /Anna Beispiel/);
});

test("widerruft Einladung und Dossierfreigabe gemeinsam", async () => {
  const queries = [];
  const pushes = [];
  const client = {
    async query(text, parameters = []) {
      queries.push({ text: String(text), parameters });
      if (String(text).includes("UPDATE dossier_invitations")) {
        return { rows: [{
          id: "9ca650a8-a78c-4ef0-b62f-cb640531b667",
          requester_user_id: "a1a14c1c-289f-4719-b237-02c9c7534642",
          owner_name: "Anna Beispiel"
        }] };
      }
      return { rows: [] };
    },
    release() {}
  };
  const count = await revokeInvitationForOwner({
    userID: "cbcb4c1c-289f-4719-b237-02c9c7534642",
    dossierID: "7b4a924e-f65a-4b51-9c19-3e4c74dc79de",
    email: "trust@example.ch",
    pool: { async connect() { return client; } },
    async push(userID, payload) { pushes.push({ userID, payload }); }
  });

  assert.equal(count, 1);
  assert.equal(queries.some(({ text }) => text.includes("UPDATE dossier_access_grants")), true);
  assert.equal(queries.at(-1).text, "COMMIT");
  assert.equal(pushes[0].userID, "a1a14c1c-289f-4719-b237-02c9c7534642");
  assert.match(pushes[0].payload.aps.alert.body, /Anna Beispiel/);
  assert.equal(pushes[0].payload.type, "trust_invitation_revoked");
});

function scriptedPool(responses) {
  return {
    calls: [],
    async query(text, parameters) {
      this.calls.push({ text: String(text), parameters });
      const response = responses.shift();
      if (!response) throw new Error(`Unerwartete Query: ${text}`);
      return response;
    }
  };
}

function responseRecorder() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
    end() { return this; }
  };
}
