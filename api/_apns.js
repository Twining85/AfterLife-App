import crypto from "node:crypto";
import http2 from "node:http2";
import { databasePool } from "./_database.js";

const bundleID = process.env.APNS_BUNDLE_ID || "ch.tschluessli.app";
const teamID = process.env.APNS_TEAM_ID;

export async function pushToUser(userID, payload) {
  const result = await databasePool().query(
    `SELECT device_token, environment FROM push_device_tokens WHERE user_id = $1`,
    [userID]
  );
  await Promise.allSettled(result.rows.map((row) => sendPush(row.device_token, row.environment, payload)));
}

async function sendPush(deviceToken, environment, payload) {
  const production = environment === "production";
  const keyID = production ? process.env.APNS_PRODUCTION_KEY_ID : process.env.APNS_SANDBOX_KEY_ID;
  const privateKey = (production ? process.env.APNS_PRODUCTION_PRIVATE_KEY : process.env.APNS_SANDBOX_PRIVATE_KEY)?.replace(/\\n/g, "\n");
  if (!teamID || !keyID || !privateKey) throw new Error(`APNs-Konfiguration für ${environment} fehlt`);

  const jwt = providerToken(keyID, privateKey);
  const host = production ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
  await new Promise((resolve, reject) => {
    const client = http2.connect(host);
    client.on("error", reject);
    const request = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleID,
      "apns-push-type": "alert",
      "apns-priority": "10"
    });
    let status = 0;
    let response = "";
    request.setEncoding("utf8");
    request.on("response", (headers) => { status = Number(headers[":status"] || 0); });
    request.on("data", (chunk) => { response += chunk; });
    request.on("end", () => {
      client.close();
      if (status === 200) resolve();
      else reject(new Error(`APNs ${status}: ${response}`));
    });
    request.on("error", (error) => { client.close(); reject(error); });
    request.end(JSON.stringify(payload));
  });
}

function providerToken(keyID, privateKey) {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const claims = base64url(JSON.stringify({ iss: teamID, iat: Math.floor(Date.now() / 1000) }));
  const input = `${header}.${claims}`;
  const signature = crypto.sign("sha256", Buffer.from(input), {
    key: privateKey,
    dsaEncoding: "ieee-p1363"
  }).toString("base64url");
  return `${input}.${signature}`;
}

function base64url(value) {
  return Buffer.from(value).toString("base64url");
}
