import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import accountLogin from "./api/accounts/login.js";
import accountRegister from "./api/accounts/register.js";
import changePassword from "./api/accounts/change-password.js";
import resetPasswordRequest from "./api/accounts/password-reset/request.js";
import resetPasswordConfirm from "./api/accounts/password-reset/confirm.js";
import emailVerificationRequest from "./api/email-verification/request.js";
import emailVerificationConfirm from "./api/email-verification/confirm.js";
import syncPush from "./api/sync/push.js";
import syncPull from "./api/sync/pull.js";
import syncSnapshot from "./api/sync/snapshot.js";
import dossierSections from "./api/dossiers/sections.js";
import autoRelease from "./api/cron/auto-release-invitations.js";
import { databaseHealth, databasePool } from "./api/_database.js";
import { secureResponse } from "./api/_security.js";
import { storageService } from "./api/_storage.js";
import { adminLoginHandler, supportDeleteAccountHandler, supportLookupHandler, supportMonitoringHandler, supportSiteEnabled, supportSummaryHandler } from "./api/admin/support.js";

const applicationDirectory = path.dirname(fileURLToPath(import.meta.url));
const supportAssets = new Map([
  ["/support", ["support/index.html", "text/html; charset=utf-8"]],
  ["/support/", ["support/index.html", "text/html; charset=utf-8"]],
  ["/support/app.js", ["support/app.js", "text/javascript; charset=utf-8"]],
  ["/support/styles.css", ["support/styles.css", "text/css; charset=utf-8"]],
  ["/support/logo.png", ["api/assets/tschluessli-email-logo.png", "image/png"]]
]);

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
  ["/api/sync/snapshot", syncSnapshot],
  ["/api/dossiers/sections", dossierSections],
  ["/api/cron/auto-release-invitations", autoRelease],
  ["/api/admin/login", adminLoginHandler],
  ["/api/admin/summary", supportSummaryHandler],
  ["/api/admin/monitoring", supportMonitoringHandler],
  ["/api/admin/users/lookup", supportLookupHandler],
  ["/api/admin/users/delete", supportDeleteAccountHandler]
]);

export function createServer() {
  return http.createServer(async (request, response) => {
    const url = new URL(request.url || "/", "http://localhost");
    const res = responseAdapter(response);
    if (url.pathname === "/health/live") return liveHealth(request, res);
    if (url.pathname === "/health/ready") return readyHealth(request, res);
    if (supportAssets.has(url.pathname) && supportSiteEnabled()) return serveSupportAsset(request, response, url.pathname);
    const handler = routes.get(url.pathname);
    if (!handler) { secureResponse(res); return res.status(404).json({ error: "Nicht gefunden" }); }
    try {
      request.query = Object.fromEntries(url.searchParams.entries());
      if (!["GET", "HEAD"].includes(request.method)) {
        const maximumBytes = url.pathname === "/api/sync/push" ? 50_000_000 : 256_000;
        request.body = await readJSONBody(request, maximumBytes);
      }
      return await handler(request, res);
    } catch (error) {
      if (error?.statusCode) { secureResponse(res); return res.status(error.statusCode).json({ error: error.message }); }
      console.error("HTTP-Anfrage fehlgeschlagen", { method: request.method, path: url.pathname, code: error?.code || "INTERNAL_ERROR" });
      if (!response.headersSent) secureResponse(res);
      return res.status(500).json({ error: "Interner Fehler" });
    }
  });
}

async function serveSupportAsset(request, response, pathname) {
  if (!["GET", "HEAD"].includes(request.method)) {
    response.statusCode = 405;
    response.setHeader("Allow", "GET, HEAD");
    return response.end();
  }
  const [relativePath, contentType] = supportAssets.get(pathname);
  const content = await fs.readFile(path.join(applicationDirectory, relativePath));
  response.statusCode = 200;
  response.setHeader("Content-Type", contentType);
  response.setHeader("Cache-Control", "no-store, max-age=0");
  response.setHeader("Content-Security-Policy", "default-src 'self'; img-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
  response.setHeader("Referrer-Policy", "no-referrer");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("X-Frame-Options", "DENY");
  return request.method === "HEAD" ? response.end() : response.end(content);
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
    const storage = await storageService().health();
    const expected = process.env.MYSQL_EXPECTED_DATABASE;
    const correctDatabase = !expected || health.database === expected;
    const storageReady = !storage.configured || storage.connected;
    const ready = health.healthy && correctDatabase && health.schemaReady && storageReady;
    return res.status(ready ? 200 : 503).json({
      status: ready ? "ok" : "unavailable",
      database: {
        engine: health.engine,
        connected: health.healthy,
        expectedDatabase: correctDatabase,
        schemaReady: health.schemaReady
      },
      objectStorage: storage
    });
  } catch (error) {
    console.error("Readiness-Healthcheck fehlgeschlagen", { code: error?.code || "READINESS_ERROR" });
    return res.status(503).json({
      status: "unavailable",
      database: { connected: false, expectedDatabase: false, schemaReady: false },
      objectStorage: { configured: process.env.STORAGE_DRIVER === "infomaniak", connected: false }
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
