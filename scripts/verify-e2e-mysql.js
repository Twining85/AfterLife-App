// Run only against a disposable local database, never the application database.
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import mysql from "mysql2/promise";
import { discoverMySQLMigrations, runMySQLMigrations } from "../database/mysql/migrate.js";

const uri = process.env.E2E_TEST_MYSQL_URL;
if (!uri) throw new Error("E2E_TEST_MYSQL_URL fehlt");
const target = new URL(uri);
if (!["localhost", "127.0.0.1"].includes(target.hostname) || target.pathname !== "/e2e_check") {
  throw new Error("Nur die isolierte lokale Datenbank e2e_check ist erlaubt");
}
const db = await mysql.createConnection({ uri, multipleStatements: true });
try {
  const migrations = await discoverMySQLMigrations(fileURLToPath(new URL("../database/mysql/migrations/", import.meta.url)));
  await runMySQLMigrations(db, migrations);
  await runMySQLMigrations(db, migrations);
  const user = crypto.randomUUID(), dossier = crypto.randomUUID();
  await db.execute("INSERT INTO app_users (id,email,password_hash,password_salt,email_verified_at) VALUES (?,?,?,?,NOW())", [user, `${user}@example.test`, "test", "test"]);
  await db.execute("INSERT INTO dossiers (id,owner_user_id,created_by_user_id,title) VALUES (?,?,?,?)", [dossier, user, user, "Synthetic migration check"]);
  const cipher = JSON.stringify({ formatVersion: 2, ciphertext: "synthetic" });
  await db.execute("INSERT INTO dossier_sections (dossier_id,owner_user_id,section_type,payload,encryption_version) VALUES (?,?,?, ?,2)", [dossier, user, "profil", cipher]);
  await assert.rejects(db.execute("UPDATE dossier_sections SET payload=? WHERE dossier_id=?", [JSON.stringify({ name: "plaintext" }), dossier]), error => error.code === "ER_CHECK_CONSTRAINT_VIOLATED");
  await db.execute("UPDATE dossier_sections SET payload=NULL,deleted_at=NOW() WHERE dossier_id=?", [dossier]);
  const [rows] = await db.execute("SELECT encryption_version FROM dossier_sections WHERE dossier_id=?", [dossier]);
  assert.equal(rows[0].encryption_version, 2);
  await assert.rejects(db.execute("UPDATE dossier_sections SET payload=?,deleted_at=NULL WHERE dossier_id=?", ["{}", dossier]), error => error.code === "ER_CHECK_CONSTRAINT_VIOLATED");
  await db.execute("UPDATE dossier_sections SET payload=?,deleted_at=NULL WHERE dossier_id=?", [cipher, dossier]);
  await assert.rejects(db.execute("INSERT INTO dossier_access_metadata (dossier_id,owner_user_id,section_type,revision,metadata) VALUES (?,?,?,1,?)", [dossier, user, "profil", "{}"]), error => error.code === "ER_CHECK_CONSTRAINT_VIOLATED");
  console.log("MySQL: alle Migrationen, Wiederholung, Klartextschutz und Tombstone-Schutz erfolgreich.");
} finally {
  await db.end();
}
