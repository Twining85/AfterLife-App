import assert from "node:assert/strict";
import test from "node:test";
import { liveHealth, readyHealth } from "../server.js";
import { resetDatabasePoolForTests, setDatabasePoolForTests } from "../api/_database.js";

test("Healthchecks geben keine Datenbanknamen oder Secrets aus", async () => {
  const previousNodeEnvironment = process.env.NODE_ENV;
  const previousEngine = process.env.DATABASE_ENGINE;
  const previousExpected = process.env.MYSQL_EXPECTED_DATABASE;
  process.env.NODE_ENV = "test";
  process.env.DATABASE_ENGINE = "mysql";
  process.env.MYSQL_EXPECTED_DATABASE = "tschluessli_dev";
  setDatabasePoolForTests({
    engine: "mysql",
    async query() { return { rows: [{ database_name: "tschluessli_dev", healthy: 1, schema_version: 1 }] }; }
  });
  try {
    const live = mockResponse();
    liveHealth({ method: "GET" }, live);
    assert.deepEqual(live.body, { status: "ok" });
    const ready = mockResponse();
    await readyHealth({ method: "GET" }, ready);
    assert.equal(ready.statusCode, 200);
    const body = ready.body;
    assert.deepEqual(body, {
      status: "ok",
      database: { engine: "mysql", connected: true, expectedDatabase: true, schemaReady: true }
    });
    const serialized = JSON.stringify(body);
    assert.doesNotMatch(serialized, /tschluessli_dev|password|token|secret/i);
  } finally {
    resetDatabasePoolForTests();
    restore("NODE_ENV", previousNodeEnvironment);
    restore("DATABASE_ENGINE", previousEngine);
    restore("MYSQL_EXPECTED_DATABASE", previousExpected);
  }
});

function mockResponse() {
  return {
    headers: {},
    statusCode: 0,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
}

function restore(name, value) {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
