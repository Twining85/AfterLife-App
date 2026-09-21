export class StorageUnavailableError extends Error {
  constructor(message = "Object Storage ist noch nicht konfiguriert") {
    super(message);
    this.code = "STORAGE_UNAVAILABLE";
  }
}

export function storageConfiguration(environment = process.env) {
  const driver = String(environment.STORAGE_DRIVER || "disabled");
  const container = String(environment.OBJECT_STORAGE_CONTAINER || "");
  if (driver === "disabled") return { driver, configured: false };
  if (driver !== "infomaniak") throw new Error("Unbekannter STORAGE_DRIVER");
  if (!container) throw new Error("OBJECT_STORAGE_CONTAINER fehlt");
  const expected = String(environment.OBJECT_STORAGE_EXPECTED_CONTAINER || "");
  if (!expected) throw new Error("OBJECT_STORAGE_EXPECTED_CONTAINER fehlt");
  if (container !== expected) throw new Error("Falscher Object-Storage-Container");
  return { driver, container, configured: true };
}

export function storageService() {
  const configuration = storageConfiguration();
  if (!configuration.configured) return new DisabledStorageService();
  throw new StorageUnavailableError("Infomaniak-Storage-Adapter ist noch nicht aktiviert");
}

class DisabledStorageService {
  async initiateUpload() { throw new StorageUnavailableError(); }
  async completeUpload() { throw new StorageUnavailableError(); }
  async createDownloadGrant() { throw new StorageUnavailableError(); }
  async deleteObject() { throw new StorageUnavailableError(); }
}
