import assert from "node:assert/strict";
import test from "node:test";
import { isStorageReference, storageConfiguration, storageService } from "../api/_storage.js";

const dossierID = "9ca650a8-a78c-4ef0-b62f-cb640531b667";

function environment(overrides = {}) {
  return {
    STORAGE_DRIVER: "infomaniak",
    OBJECT_STORAGE_CONTAINER: "tschluessli-dev-files",
    OBJECT_STORAGE_EXPECTED_CONTAINER: "tschluessli-dev-files",
    OBJECT_STORAGE_ENDPOINT: "https://s3.example.test",
    OBJECT_STORAGE_REGION: "dc4",
    OBJECT_STORAGE_ACCESS_KEY: "access-key",
    OBJECT_STORAGE_SECRET_KEY: "secret-key",
    OBJECT_STORAGE_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString("base64"),
    OBJECT_STORAGE_THRESHOLD_BYTES: "1024",
    ...overrides
  };
}

test("validiert getrennten Container, HTTPS-Endpunkt und Verschlüsselungsschlüssel", () => {
  const configuration = storageConfiguration(environment());
  assert.equal(configuration.configured, true);
  assert.equal(configuration.container, "tschluessli-dev-files");
  assert.equal(configuration.encryptionKey.length, 32);
  assert.throws(
    () => storageConfiguration(environment({ OBJECT_STORAGE_ENDPOINT: "http://storage.invalid" })),
    /HTTPS-URL/
  );
  assert.throws(
    () => storageConfiguration(environment({ OBJECT_STORAGE_EXPECTED_CONTAINER: "prod-files" })),
    /Falscher Object-Storage-Container/
  );
});

test("verschlüsselt grosse Bereichspayloads und entschlüsselt sie beim Lesen", async () => {
  let encryptedObject;
  const calls = [];
  const client = {
    async send(command) {
      calls.push(command);
      if (command.constructor.name === "PutObjectCommand") {
        encryptedObject = Buffer.from(command.input.Body);
        return {};
      }
      if (command.constructor.name === "GetObjectCommand") {
        return { Body: { async transformToByteArray() { return encryptedObject; } } };
      }
      throw new Error(`Unerwarteter Storage-Befehl: ${command.constructor.name}`);
    }
  };
  const service = storageService({ environment: environment(), client });
  const payload = { dokument: Buffer.alloc(2_000, 9).toString("base64") };
  const reference = await service.storeSectionPayload({
    dossierID,
    sectionType: "dokumente",
    revision: 4,
    payload
  });

  assert.equal(isStorageReference(reference), true);
  assert.equal(encryptedObject.includes(Buffer.from(payload.dokument)), false);
  assert.match(calls[0].input.Key, new RegExp(`^dossiers/${dossierID}/sections/dokumente/4-`));
  assert.equal(calls[0].input.ContentType, "application/octet-stream");

  const loaded = await service.loadSectionPayload(reference, { dossierID, sectionType: "dokumente" });
  assert.deepEqual(loaded, payload);
});

test("lässt kleine Payloads in der Datenbank und löscht Dossierobjekte präfixbasiert", async () => {
  const calls = [];
  const client = {
    async send(command) {
      calls.push(command);
      if (command.constructor.name === "ListObjectsV2Command") {
        return { Contents: [{ Key: `dossiers/${dossierID}/sections/dokumente/1-a.json.enc` }] };
      }
      if (command.constructor.name === "DeleteObjectsCommand") return {};
      throw new Error(`Unerwarteter Storage-Befehl: ${command.constructor.name}`);
    }
  };
  const service = storageService({ environment: environment(), client });
  const payload = { name: "klein" };
  assert.deepEqual(await service.storeSectionPayload({
    dossierID,
    sectionType: "profil",
    revision: 1,
    payload
  }), payload);

  await service.deleteDossier(dossierID);
  assert.equal(calls[0].input.Prefix, `dossiers/${dossierID}/`);
  assert.equal(calls[1].input.Delete.Objects.length, 1);
});
