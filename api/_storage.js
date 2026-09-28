import crypto from "node:crypto";
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client
} from "@aws-sdk/client-s3";

const referenceField = "_tschluessliStorage";
const defaultThresholdBytes = 64 * 1024;
let sharedService;

export class StorageUnavailableError extends Error {
  constructor(message = "Object Storage ist noch nicht konfiguriert") {
    super(message);
    this.code = "STORAGE_UNAVAILABLE";
  }
}

export function storageConfiguration(environment = process.env) {
  const driver = String(environment.STORAGE_DRIVER || "disabled");
  const container = String(environment.OBJECT_STORAGE_CONTAINER || "").trim();
  if (driver === "disabled") return { driver, configured: false };
  if (driver !== "infomaniak") throw new Error("Unbekannter STORAGE_DRIVER");
  if (!container) throw new Error("OBJECT_STORAGE_CONTAINER fehlt");
  const expected = String(environment.OBJECT_STORAGE_EXPECTED_CONTAINER || "").trim();
  if (!expected) throw new Error("OBJECT_STORAGE_EXPECTED_CONTAINER fehlt");
  if (container !== expected) throw new Error("Falscher Object-Storage-Container");

  const endpoint = validHTTPSURL(environment.OBJECT_STORAGE_ENDPOINT, "OBJECT_STORAGE_ENDPOINT");
  const region = String(environment.OBJECT_STORAGE_REGION || "").trim();
  const accessKeyId = String(environment.OBJECT_STORAGE_ACCESS_KEY || "").trim();
  const secretAccessKey = String(environment.OBJECT_STORAGE_SECRET_KEY || "").trim();
  if (!region) throw new Error("OBJECT_STORAGE_REGION fehlt");
  if (!accessKeyId) throw new Error("OBJECT_STORAGE_ACCESS_KEY fehlt");
  if (!secretAccessKey) throw new Error("OBJECT_STORAGE_SECRET_KEY fehlt");

  const encryptionKey = decodeEncryptionKey(environment.OBJECT_STORAGE_ENCRYPTION_KEY);
  const thresholdBytes = Number.parseInt(
    String(environment.OBJECT_STORAGE_THRESHOLD_BYTES || defaultThresholdBytes),
    10
  );
  if (!Number.isInteger(thresholdBytes) || thresholdBytes < 1024 || thresholdBytes > 50_000_000) {
    throw new Error("OBJECT_STORAGE_THRESHOLD_BYTES ist ungültig");
  }
  return {
    driver,
    container,
    configured: true,
    endpoint,
    region,
    accessKeyId,
    secretAccessKey,
    encryptionKey,
    thresholdBytes
  };
}

export function storageService({ environment = process.env, client } = {}) {
  const configuration = storageConfiguration(environment);
  if (!configuration.configured) return new DisabledStorageService();
  if (client) return new InfomaniakStorageService(configuration, client);
  if (!sharedService) {
    sharedService = new InfomaniakStorageService(configuration, new S3Client({
      region: configuration.region,
      endpoint: configuration.endpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId: configuration.accessKeyId,
        secretAccessKey: configuration.secretAccessKey
      }
    }));
  }
  return sharedService;
}

export class InfomaniakStorageService {
  constructor(configuration, client) {
    this.configuration = configuration;
    this.client = client;
  }

  async storeSectionPayload({ dossierID, sectionType, revision, payload }) {
    const plaintext = Buffer.from(JSON.stringify(payload));
    if (plaintext.length < this.configuration.thresholdBytes) return payload;
    const encrypted = encryptPayload(plaintext, this.configuration.encryptionKey);
    const digest = crypto.createHash("sha256").update(encrypted).digest("hex");
    const objectKey = sectionObjectKey(dossierID, sectionType, revision, digest);
    await this.client.send(new PutObjectCommand({
      Bucket: this.configuration.container,
      Key: objectKey,
      Body: encrypted,
      ContentType: "application/octet-stream",
      Metadata: { format: "tschluessli-section-v1", sha256: digest }
    }));
    return {
      [referenceField]: {
        version: 1,
        objectKey,
        sha256: digest,
        encryptedBytes: encrypted.length
      }
    };
  }

  async health() {
    await this.client.send(new HeadBucketCommand({ Bucket: this.configuration.container }));
    return { configured: true, connected: true };
  }

  async loadSectionPayload(storedPayload, { dossierID, sectionType }) {
    const reference = storageReference(storedPayload);
    if (!reference) return parseJSON(storedPayload);
    const expectedPrefix = sectionObjectPrefix(dossierID, sectionType);
    if (!reference.objectKey.startsWith(expectedPrefix)) {
      throw new Error("Object-Storage-Referenz gehört nicht zum Dossierbereich");
    }
    const response = await this.client.send(new GetObjectCommand({
      Bucket: this.configuration.container,
      Key: reference.objectKey
    }));
    const encrypted = Buffer.from(await response.Body.transformToByteArray());
    const digest = crypto.createHash("sha256").update(encrypted).digest("hex");
    if (!crypto.timingSafeEqual(Buffer.from(digest), Buffer.from(reference.sha256))) {
      throw new Error("Object-Storage-Prüfsumme stimmt nicht");
    }
    const plaintext = decryptPayload(encrypted, this.configuration.encryptionKey);
    return JSON.parse(plaintext.toString("utf8"));
  }

  async deleteDossier(dossierID) {
    const prefix = dossierObjectPrefix(dossierID);
    for (let pass = 0; pass < 1_000; pass += 1) {
      const listed = await this.client.send(new ListObjectsV2Command({
        Bucket: this.configuration.container,
        Prefix: prefix
      }));
      const objects = (listed.Contents || []).map(({ Key }) => ({ Key })).filter(({ Key }) => Key);
      if (objects.length === 0) return;
      for (let index = 0; index < objects.length; index += 20) {
        await Promise.all(objects.slice(index, index + 20).map(({ Key }) =>
          this.client.send(new DeleteObjectCommand({
            Bucket: this.configuration.container,
            Key
          }))
        ));
      }
    }
    throw new Error("Object-Storage-Bereinigung konnte nicht verifiziert werden");
  }
}

class DisabledStorageService {
  async health() { return { configured: false, connected: false }; }
  async storeSectionPayload({ payload }) { return payload; }
  async loadSectionPayload(payload) { return parseJSON(payload); }
  async deleteDossier() {}
  async initiateUpload() { throw new StorageUnavailableError(); }
  async completeUpload() { throw new StorageUnavailableError(); }
  async createDownloadGrant() { throw new StorageUnavailableError(); }
  async deleteObject() { throw new StorageUnavailableError(); }
}

export function isStorageReference(value) {
  return storageReference(value) !== null;
}

function storageReference(value) {
  const parsed = parseJSON(value);
  const reference = parsed?.[referenceField];
  if (!reference || reference.version !== 1) return null;
  if (!/^[a-zA-Z0-9/_-]+\.json\.enc$/.test(String(reference.objectKey || ""))) return null;
  if (!/^[0-9a-f]{64}$/.test(String(reference.sha256 || ""))) return null;
  return reference;
}

function sectionObjectKey(dossierID, sectionType, revision, digest) {
  if (!Number.isSafeInteger(Number(revision)) || Number(revision) < 1) {
    throw new Error("Ungültige Storage-Revision");
  }
  return `${sectionObjectPrefix(dossierID, sectionType)}${revision}-${digest}.json.enc`;
}

function sectionObjectPrefix(dossierID, sectionType) {
  if (!/^[0-9a-f-]{36}$/i.test(String(dossierID)) ||
      !/^[a-z][a-z0-9_-]{0,63}$/.test(String(sectionType))) {
    throw new Error("Ungültiger Storage-Pfad");
  }
  return `${dossierObjectPrefix(dossierID)}sections/${sectionType}/`;
}

function dossierObjectPrefix(dossierID) {
  if (!/^[0-9a-f-]{36}$/i.test(String(dossierID))) throw new Error("Ungültige Dossier-ID");
  return `dossiers/${String(dossierID).toLowerCase()}/`;
}

function encryptPayload(plaintext, key) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.from(JSON.stringify({
    version: 1,
    algorithm: "AES-256-GCM",
    iv: iv.toString("base64"),
    tag: tag.toString("base64"),
    ciphertext: ciphertext.toString("base64")
  }));
}

function decryptPayload(encrypted, key) {
  const envelope = JSON.parse(encrypted.toString("utf8"));
  if (envelope.version !== 1 || envelope.algorithm !== "AES-256-GCM") {
    throw new Error("Unbekanntes Storage-Verschlüsselungsformat");
  }
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(envelope.iv, "base64"));
  decipher.setAuthTag(Buffer.from(envelope.tag, "base64"));
  return Buffer.concat([
    decipher.update(Buffer.from(envelope.ciphertext, "base64")),
    decipher.final()
  ]);
}

function decodeEncryptionKey(value) {
  const encoded = String(value || "").trim();
  if (!encoded) throw new Error("OBJECT_STORAGE_ENCRYPTION_KEY fehlt");
  const key = Buffer.from(encoded, "base64");
  if (key.length !== 32 || key.toString("base64").replace(/=+$/, "") !== encoded.replace(/=+$/, "")) {
    throw new Error("OBJECT_STORAGE_ENCRYPTION_KEY muss 32 Byte Base64 sein");
  }
  return key;
}

function validHTTPSURL(value, name) {
  try {
    const url = new URL(String(value || ""));
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) throw new Error();
    return url.toString().replace(/\/$/, "");
  } catch {
    throw new Error(`${name} muss eine HTTPS-URL sein`);
  }
}

function parseJSON(value) {
  if (typeof value !== "string") return value;
  try { return JSON.parse(value); } catch { return value; }
}
