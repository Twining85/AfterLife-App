import http from "node:http";
import { pathToFileURL } from "node:url";
import accountLogin from "./api/accounts/login.js";
import accountRegister from "./api/accounts/register.js";
import changePassword from "./api/accounts/change-password.js";
import resetPasswordRequest from "./api/accounts/password-reset/request.js";
import resetPasswordConfirm from "./api/accounts/password-reset/confirm.js";
import emailVerificationRequest from "./api/email-verification/request.js";
import emailVerificationConfirm from "./api/email-verification/confirm.js";
import syncPush from "./api/sync/push.js";
import syncPull from "./api/sync/pull.js";
import dossierSections from "./api/dossiers/sections.js";
import autoRelease from "./api/cron/auto-release-invitations.js";
import autocomplete from "./api/autocomplete.js";
import buildingVerification from "./api/building-verification.js";
import { databaseHealth, databasePool } from "./api/_database.js";
import { secureResponse } from "./api/_security.js";

const routes = new Map([
  ["/api/accounts/login", accountLogin],
  ["/api/accounts/delete", accountLogin],
  ["/api/accounts/register", accountRegister],
  ["/api/accounts/change-password", changePassword],
  ["/api/accounts/password-reset/request", resetPasswordRequest],
  ["/api/accounts/password-reset/confirm", resetPasswordConfirm],
  ["/api/email-verification/request", emailVerificationRequest],
  ["/api/email-verification/confirm", emailVerificationConfirm],
  ["/api/sync/push", syncPush],
  ["/api/sync/pull", syncPull],
  ["/api/dossiers/sections", dossierSections],
  ["/api/cron/auto-release-invitations", autoRelease],
  ["/api/autocomplete", autocomplete],
  ["/api/building-verification", buildingVerification]
]);

export function createServer() {
  return http.createServer(async (request, response) => {
    const url = new URL(request.url || "/", "http://localhost");
    const res = responseAdapter(response);
    if (url.pathname === "/health/live") return liveHealth(request, res);
    if (url.pathname === "/health/ready") return readyHealth(request, res);
    const handler = routes.get(url.pathname);
    if (!handler) { secureResponse(res); return res.status(404).json({ error: "Nicht gefunden" }); }
    try {
      request.query = Object.fromEntries(url.searchParams.entries());
      if (!["GET", "HEAD"].includes(request.method)) request.body = await readJSONBody(request);
      return await handler(request, res);
    } catch (error) {
      if (error?.statusCode) { secureResponse(res); return res.status(error.statusCode).json({ error: error.message }); }
      console.error("HTTP-Anfrage fehlgeschlagen", { method: request.method, path: url.pathname, code: error?.code || "INTERNAL_ERROR" });
      if (!response.headersSent) secureResponse(res);
      return res.status(500).json({ error: "Interner Fehler" });
    }
  });
}

export function liveHealth(req, res) {
  secureResponse(res);
  if (req.method !== "GET") return res.status(405).json({ error: "Methode nicht erlaubt" });
  return res.status(200).json({ status: "ok" });
}

export async function readyHealth(req, res) {
  secureResponse(res);
  if (req.method !== "GET") return res.status(405).json({ error: "Methode nicht erlaubt" });
  try {
    const health = await databaseHealth();
    const expected = process.env.MYSQL_EXPECTED_DATABASE;
    const correctDatabase = !expected || health.database === expected;
    const ready = health.healthy && correctDatabase && health.schemaReady;
    return res.status(ready ? 200 : 503).json({
      status: ready ? "ok" : "unavailable",
      database: {
        engine: health.engine,
        connected: health.healthy,
        expectedDatabase: correctDatabase,
        schemaReady: health.schemaReady
      }
    });
  } catch (error) {
    console.error("Datenbank-Healthcheck fehlgeschlagen", { code: error?.code || "DATABASE_ERROR" });
    return res.status(503).json({
      status: "unavailable",
      database: { connected: false, expectedDatabase: false, schemaReady: false }
    });
  }
}

async function readJSONBody(request, maximumBytes = 256_000) {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > maximumBytes) {
      const error = new Error("Anfrage zu gross"); error.statusCode = 413; throw error;
    }
    chunks.push(chunk);
  }
  if (bytes === 0) return {};
  try { return JSON.parse(Buffer.concat(chunks).toString("utf8")); }
  catch { const error = new Error("Ungültiges JSON"); error.statusCode = 400; throw error; }
}

function responseAdapter(response) {
  response.status = (code) => { response.statusCode = code; return response; };
  response.json = (body) => {
    if (!response.hasHeader("Content-Type")) response.setHeader("Content-Type", "application/json; charset=utf-8");
    response.end(JSON.stringify(body)); return response;
  };
  response.send = (body) => { response.end(body); return response; };
  return response;
}

async function main() {
  const host = process.env.HOST || "127.0.0.1";
  const port = Number(process.env.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("PORT ist ungueltig");
  await databaseHealth();
  const server = createServer();
  server.listen(port, host, () => console.log(JSON.stringify({ event: "server_started", host, port })));
  const shutdown = async (signal) => {
    console.log(JSON.stringify({ event: "server_stopping", signal }));
    server.close(async () => { await databasePool().end(); process.exit(0); });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

const isCommandLine = process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url;
if (isCommandLine) main().catch((error) => { console.error("Serverstart fehlgeschlagen", { code: error?.code || "STARTUP_ERROR" }); process.exitCode = 1; });
