import assert from "node:assert/strict";
import test from "node:test";
import {
  canonicalJSON,
  mutationHash,
  parseCursor,
  parseMutation,
  supportedSectionVersions
} from "../api/_sync-contract.js";

const dossierID = "9ca650a8-a78c-4ef0-b62f-cb640531b667";

test("akzeptiert den gemeinsamen Vertrag aller sieben Bereiche", () => {
  assert.deepEqual(Object.keys(supportedSectionVersions).sort(), [
    "finanzen", "gesundheit", "herzensstuecke", "kontakte", "profil", "wuensche", "zugaenge"
  ]);
  for (const sectionType of Object.keys(supportedSectionVersions)) {
    const mutation = parseMutation({
      dossierID,
      sectionType,
      operation: "upsert",
      schemaVersion: 1,
      expectedRevision: 0,
      payload: { test: true }
    }, `auftrag:${sectionType}:1`);
    assert.equal(mutation.sectionType, sectionType);
  }
});

test("lehnt unbekannte Versionen und unpassende Lösch-Payloads ab", () => {
  assert.throws(() => parseMutation({
    dossierID,
    sectionType: "profil",
    operation: "upsert",
    schemaVersion: 2,
    expectedRevision: 0,
    payload: {}
  }, "auftrag:1"), (error) => error.statusCode === 422);

  assert.throws(() => parseMutation({
    dossierID,
    sectionType: "profil",
    operation: "delete",
    schemaVersion: 1,
    expectedRevision: 1,
    payload: { unerlaubt: true }
  }, "auftrag:2"), /keinen Payload/);
});

test("bildet für semantisch gleiche JSON-Daten dieselbe Prüfsumme", () => {
  const first = parseMutation({
    dossierID,
    sectionType: "wuensche",
    operation: "upsert",
    schemaVersion: 1,
    expectedRevision: 3,
    payload: { b: 2, a: { y: true, x: "wert" } }
  }, "auftrag:3");
  const second = { ...first, payload: { a: { x: "wert", y: true }, b: 2 } };
  assert.equal(mutationHash(first), mutationHash(second));
  assert.equal(canonicalJSON({ b: 2, a: 1 }), "{\"a\":1,\"b\":2}");
});

test("validiert einen undurchsichtigen Cursor ohne Zahlenverlust", () => {
  assert.equal(parseCursor(undefined), "0");
  assert.equal(parseCursor("9223372036854775807"), "9223372036854775807");
  assert.throws(() => parseCursor("-1"), /Cursor/);
  assert.throws(() => parseCursor("1.5"), /Cursor/);
});
