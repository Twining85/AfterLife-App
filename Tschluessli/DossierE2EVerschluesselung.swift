import CryptoKit
import Foundation

/// V2 primitives. The legacy sync must not switch until sharing and migration are ready.
nonisolated struct DossierE2EKontext: Codable, Sendable, Equatable {
    let dossierID: UUID
    let sectionType: String
    let schemaVersion: Int
    let keyVersion: Int
    /// "section" for a complete section; a UUID for an independently shareable document.
    let resourceID: String

    static let bereiche: Set<String> = [
        "dossier_einstellungen", "profil", "gesundheit", "wuensche", "finanzen",
        "dokumente", "kontakte", "herzensstuecke", "zugaenge"
    ]

    func validieren() throws {
        guard Self.bereiche.contains(sectionType), schemaVersion > 0, schemaVersion <= 1_000_000,
              keyVersion > 0, keyVersion <= 1_000_000,
              resourceID == "section" || UUID(uuidString: resourceID)?.uuidString.lowercased() == resourceID else {
            throw DossierE2EFehler.ungueltigerKontext
        }
    }

    var authentifizierteDaten: Data {
        Data("Tschluessli-E2E-v2\n\(dossierID.uuidString.lowercased())\n\(sectionType)\n\(schemaVersion)\n\(keyVersion)\n\(resourceID)".utf8)
    }
}

nonisolated struct DossierE2EPayload: Codable, Sendable {
    let formatVersion: Int
    let algorithm: String
    let context: DossierE2EKontext
    /// CryptoKit combined representation: 12-byte nonce, ciphertext, 16-byte tag.
    let ciphertext: String
}

nonisolated struct DossierE2EFreigabeKontext: Codable, Sendable, Equatable {
    enum Umfang: String, Codable, Sendable { case partial, full }
    let dossierID: UUID
    let invitationID: UUID
    let recipientEmail: String
    let grantVersion: Int
    let scope: Umfang

    func validieren() throws {
        guard recipientEmail == recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              recipientEmail.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil,
              recipientEmail.count <= 254, grantVersion > 0, grantVersion <= 1_000_000 else {
            throw DossierE2EFehler.ungueltigerKontext
        }
    }

    var authentifizierteDaten: Data {
        Data("Tschluessli-E2E-grant-v2\n\(dossierID.uuidString.lowercased())\n\(invitationID.uuidString.lowercased())\n\(recipientEmail)\n\(grantVersion)\n\(scope.rawValue)".utf8)
    }
}

nonisolated struct DossierE2ERessourcenSchluessel: Codable, Sendable {
    let context: DossierE2EKontext
    let key: String
}

nonisolated struct DossierE2EFreigabePaket: Codable, Sendable {
    let formatVersion: Int
    let algorithm: String
    let context: DossierE2EFreigabeKontext
    let ciphertext: String
}

nonisolated enum DossierE2EFehler: Error {
    case ungueltigerKontext
    case ungueltigerSchluessel
    case ungueltigesPaket
    case kontextPasstNicht
}

nonisolated enum DossierE2EVerschluesselung {
    static func zufaelligerSchluessel() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    /// The root is only for the owner/recovery. Share only the derived resource keys.
    static func ressourcenSchluessel(stammSchluessel: Data, kontext: DossierE2EKontext) throws -> Data {
        try kontext.validieren()
        try schluesselPruefen(stammSchluessel)
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: stammSchluessel),
            salt: Data("Tschluessli-E2E-resource-key-v2".utf8),
            info: kontext.authentifizierteDaten,
            outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }

    static func verschluesseln(_ klartext: Data, schluessel: Data, kontext: DossierE2EKontext) throws -> DossierE2EPayload {
        try kontext.validieren()
        return DossierE2EPayload(formatVersion: 2, algorithm: "AES-256-GCM", context: kontext,
                                ciphertext: try versiegeln(klartext, schluessel, kontext.authentifizierteDaten))
    }

    /// Expected context comes from the authenticated sync/grant, not from the received payload.
    static func entschluesseln(_ paket: DossierE2EPayload, schluessel: Data, erwarteterKontext: DossierE2EKontext) throws -> Data {
        try erwarteterKontext.validieren()
        guard paket.formatVersion == 2, paket.algorithm == "AES-256-GCM" else { throw DossierE2EFehler.ungueltigesPaket }
        guard paket.context == erwarteterKontext else { throw DossierE2EFehler.kontextPasstNicht }
        return try oeffnen(paket.ciphertext, schluessel, erwarteterKontext.authentifizierteDaten)
    }

    /// Secret is random and delivered out of band (QR/link fragment), never an API token.
    static func freigabeVerpacken(
        _ schluessel: [DossierE2ERessourcenSchluessel],
        geheimnis: Data,
        kontext: DossierE2EFreigabeKontext
    ) throws -> DossierE2EFreigabePaket {
        try kontext.validieren()
        try freigabeSchluesselPruefen(schluessel, dossierID: kontext.dossierID)
        let wrappingKey = try freigabeSchluessel(geheimnis, kontext)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return DossierE2EFreigabePaket(formatVersion: 2, algorithm: "AES-256-GCM", context: kontext,
                                     ciphertext: try versiegeln(encoder.encode(schluessel), wrappingKey, kontext.authentifizierteDaten))
    }

    static func freigabeOeffnen(
        _ paket: DossierE2EFreigabePaket,
        geheimnis: Data,
        erwarteterKontext: DossierE2EFreigabeKontext
    ) throws -> [DossierE2ERessourcenSchluessel] {
        try erwarteterKontext.validieren()
        guard paket.formatVersion == 2, paket.algorithm == "AES-256-GCM" else { throw DossierE2EFehler.ungueltigesPaket }
        guard paket.context == erwarteterKontext else { throw DossierE2EFehler.kontextPasstNicht }
        let wrappingKey = try freigabeSchluessel(geheimnis, erwarteterKontext)
        let daten = try oeffnen(paket.ciphertext, wrappingKey, erwarteterKontext.authentifizierteDaten)
        let keys = try JSONDecoder().decode([DossierE2ERessourcenSchluessel].self, from: daten)
        try freigabeSchluesselPruefen(keys, dossierID: erwarteterKontext.dossierID)
        return keys
    }

    private static func freigabeSchluessel(_ geheimnis: Data, _ kontext: DossierE2EFreigabeKontext) throws -> Data {
        try schluesselPruefen(geheimnis)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: geheimnis),
            salt: Data("Tschluessli-E2E-grant-key-v2".utf8),
            info: kontext.authentifizierteDaten,
            outputByteCount: 32
        ).withUnsafeBytes { Data($0) }
    }

    private static func freigabeSchluesselPruefen(_ keys: [DossierE2ERessourcenSchluessel], dossierID: UUID) throws {
        guard !keys.isEmpty, keys.count <= 1024 else { throw DossierE2EFehler.ungueltigesPaket }
        var gesehen = Set<DossierE2EKontextID>()
        for entry in keys {
            try entry.context.validieren()
            guard entry.context.dossierID == dossierID,
                  let key = Data(base64Encoded: entry.key), key.count == 32,
                  gesehen.insert(DossierE2EKontextID(entry.context)).inserted else {
                throw DossierE2EFehler.ungueltigesPaket
            }
        }
    }

    private static func schluesselPruefen(_ key: Data) throws {
        guard key.count == 32 else { throw DossierE2EFehler.ungueltigerSchluessel }
    }

    private static func versiegeln(_ data: Data, _ key: Data, _ aad: Data) throws -> String {
        try schluesselPruefen(key)
        let box = try AES.GCM.seal(data, using: SymmetricKey(data: key), authenticating: aad)
        guard let combined = box.combined else { throw DossierE2EFehler.ungueltigesPaket }
        return combined.base64EncodedString()
    }

    private static func oeffnen(_ encoded: String, _ key: Data, _ aad: Data) throws -> Data {
        try schluesselPruefen(key)
        guard let data = Data(base64Encoded: encoded), data.count >= 28,
              data.base64EncodedString() == encoded else { throw DossierE2EFehler.ungueltigesPaket }
        return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: SymmetricKey(data: key), authenticating: aad)
    }
}

private nonisolated struct DossierE2EKontextID: Hashable {
    let daten: Data
    init(_ context: DossierE2EKontext) { daten = context.authentifizierteDaten }
}
