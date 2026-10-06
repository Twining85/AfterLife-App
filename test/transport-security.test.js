import assert from "node:assert/strict";
import test from "node:test";
import { emailTransportConfiguration } from "../api/_email-service.js";
import { postgreSQLConnectionOptions, postgreSQLTLSOptions } from "../api/_database.js";
import pg from "pg";

const smtp = { SMTP_HOST: "mail.example.ch", SMTP_USER: "test-user", SMTP_PASSWORD: "test-only" };

test("Mailversand benötigt einen ausdrücklich gewählten Anbieter", () => {
  assert.throws(() => emailTransportConfiguration({ SMTP_USER: "user", SMTP_PASSWORD: "test" }), /SMTP-Host/);
  assert.throws(() => emailTransportConfiguration({ ...smtp, SMTP_HOST: "  " }), /SMTP-Host/);
});

test("SMTP erzwingt TLS und Zertifikatsprüfung auf beiden erlaubten Ports", () => {
  for (const port of [465, 587]) {
    const configuration = emailTransportConfiguration({ ...smtp, SMTP_PORT: String(port) });
    assert.equal(configuration.secure, port === 465);
    assert.equal(configuration.requireTLS, port === 587);
    assert.equal(configuration.tls.rejectUnauthorized, true);
    assert.equal(configuration.tls.minVersion, "TLSv1.2");
  }
  for (const port of [25, 2525, "invalid"]) {
    assert.throws(() => emailTransportConfiguration({ ...smtp, SMTP_PORT: String(port) }), /SMTP-Port/);
  }
});

test("Bestehende ausdrücklich gesetzte Mailomat-Konfiguration bleibt gültig", () => {
  const configuration = emailTransportConfiguration({
    MAILOMAT_SMTP_HOST: "smtp.mailomat.cloud", MAILOMAT_SMTP_USER: "user", MAILOMAT_SMTP_PASSWORD: "test"
  });
  assert.equal(configuration.host, "smtp.mailomat.cloud");
  assert.equal(configuration.requireTLS, true);
});

test("PostgreSQL-TLS kann ausserhalb von Tests nicht abgeschaltet werden", () => {
  for (const variable of ["DATABASE_SSL", "DATABASE_SSL_MODE"]) {
    for (const mode of ["production", "development", undefined]) {
      assert.throws(() => postgreSQLTLSOptions({ NODE_ENV: mode, [variable]: "disable" }), /nicht deaktiviert/);
    }
    assert.equal(postgreSQLTLSOptions({ NODE_ENV: "test", [variable]: "disable" }), false);
  }
  assert.deepEqual(postgreSQLTLSOptions({}), { rejectUnauthorized: true });
  assert.deepEqual(postgreSQLTLSOptions({ DATABASE_SSL_CA: "line1\\nline2" }), {
    rejectUnauthorized: true, ca: "line1\nline2"
  });
});

test("Verbindungsparameter können PostgreSQL-Zertifikatsprüfung nicht überschreiben", () => {
  for (const query of ["sslmode=disable", "ssl=no-verify", "ssl=0", "sslmode=require&uselibpqcompat=true", "sslrootcert=/missing/ca.pem"]) {
    const options = postgreSQLConnectionOptions(`postgresql://user:test@db.example.ch/db?application_name=afterlife&${query}`, {
      DATABASE_SSL_CA: "test-ca", NODE_ENV: "production"
    });
    // Exercise pg's real connection-string parsing without opening a connection.
    const client = new pg.Client(options);
    assert.deepEqual(client.connectionParameters.ssl, { rejectUnauthorized: true, ca: "test-ca" });
    assert.equal(client.connectionParameters.application_name, "afterlife");
  }
  assert.throws(() => postgreSQLConnectionOptions("invalid"), /Ungültige PostgreSQL/);
});
