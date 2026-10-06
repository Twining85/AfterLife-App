import CryptoKit
import Foundation

nonisolated struct DossierE2ERecoveryPaket: Codable, Sendable {
    let formatVersion: Int
    let algorithm: String
    let ownerUserID: UUID
    let dossierID: UUID
    let recoveryID: UUID
    let ciphertext: String

    var authentifizierteDaten: Data {
        Data("Tschluessli-E2E-recovery-v2\n\(ownerUserID.uuidString.lowercased())\n\(dossierID.uuidString.lowercased())\n\(recoveryID.uuidString.lowercased())".utf8)
    }
}

/// Account-scoped owner keys. Never used for a recipient's shared dossier.
/// Dormant until the V2 migration flow can explicitly initialize each dossier.
@MainActor
final class DossierE2ESchluesselStore {
    static let shared = DossierE2ESchluesselStore()
    private let service: String

    init(service: String = "Tschluessli.E2E.Owner.v2") {
        self.service = service
    }

    func neuesDossier(ownerUserID: UUID, dossierID: UUID) throws {
        do {
            _ = try vorhandenerStammSchluessel(ownerUserID: ownerUserID, dossierID: dossierID)
            return
        } catch KeychainHelper.KeychainError.itemNotFound {
            // Only an explicit initialization creates a key. Other errors must propagate.
            try speichern(DossierE2EVerschluesselung.zufaelligerSchluessel(), ownerUserID, dossierID)
        }
    }

    func ressourcenSchluessel(ownerUserID: UUID, kontext: DossierE2EKontext) throws -> Data {
        try DossierE2EVerschluesselung.ressourcenSchluessel(
            stammSchluessel: vorhandenerStammSchluessel(ownerUserID: ownerUserID, dossierID: kontext.dossierID), kontext: kontext
        )
    }

    func recoveryPaket(ownerUserID: UUID, dossierID: UUID, code: String) throws -> DossierE2ERecoveryPaket {
        let root = try vorhandenerStammSchluessel(ownerUserID: ownerUserID, dossierID: dossierID)
        let empty = DossierE2ERecoveryPaket(formatVersion: 2, algorithm: "AES-256-GCM/HKDF-SHA256",
                                          ownerUserID: ownerUserID, dossierID: dossierID, recoveryID: UUID(), ciphertext: "")
        let box = try AES.GCM.seal(root, using: recoverySchluessel(code, empty), authenticating: empty.authentifizierteDaten)
        guard let combined = box.combined else { throw DossierE2EFehler.ungueltigesPaket }
        return DossierE2ERecoveryPaket(formatVersion: empty.formatVersion, algorithm: empty.algorithm,
                                      ownerUserID: ownerUserID, dossierID: dossierID, recoveryID: empty.recoveryID,
                                      ciphertext: combined.base64EncodedString())
    }

    /// Validate the expected owner/dossier before writing anything into Keychain.
    /// Never overwrite an existing, different root: that needs a migration flow.
    func wiederherstellen(_ paket: DossierE2ERecoveryPaket, code: String, ownerUserID: UUID, dossierID: UUID) throws {
        guard paket.formatVersion == 2, paket.algorithm == "AES-256-GCM/HKDF-SHA256",
              paket.ownerUserID == ownerUserID, paket.dossierID == dossierID,
              let combined = Data(base64Encoded: paket.ciphertext), combined.count == 60,
              combined.base64EncodedString() == paket.ciphertext else { throw DossierE2EFehler.ungueltigesPaket }
        let root = try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: recoverySchluessel(code, paket),
                                    authenticating: paket.authentifizierteDaten)
        guard root.count == 32 else { throw DossierE2EFehler.ungueltigerSchluessel }
        do {
            let existing = try vorhandenerStammSchluessel(ownerUserID: ownerUserID, dossierID: dossierID)
            guard existing == root else { throw DossierE2EFehler.ungueltigerSchluessel }
        } catch KeychainHelper.KeychainError.itemNotFound {
            try speichern(root, ownerUserID, dossierID)
        }
    }

    func lokaleOwnerSchluesselLoeschen(ownerUserID: UUID, dossierID: UUID) throws {
        try KeychainHelper.shared.delete(service: service, account: account(ownerUserID, dossierID))
    }

    private func vorhandenerStammSchluessel(ownerUserID: UUID, dossierID: UUID) throws -> Data {
        let encoded = try KeychainHelper.shared.read(service: service, account: account(ownerUserID, dossierID))
        guard let key = Data(base64Encoded: encoded), key.count == 32, key.base64EncodedString() == encoded else {
            throw DossierE2EFehler.ungueltigerSchluessel
        }
        return key
    }

    private func speichern(_ key: Data, _ owner: UUID, _ dossier: UUID) throws {
        try KeychainHelper.shared.save(key.base64EncodedString(), service: service, account: account(owner, dossier))
    }

    private func account(_ owner: UUID, _ dossier: UUID) -> String {
        "\(owner.uuidString.lowercased()):\(dossier.uuidString.lowercased())"
    }

    private func recoverySchluessel(_ code: String, _ paket: DossierE2ERecoveryPaket) throws -> SymmetricKey {
        // Codes are generated with 132 bits of entropy; this is not a user password.
        let normalized = try DossierRecoveryCode.normalisieren(code)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(normalized.utf8)),
            salt: Data("Tschluessli-E2E-recovery-key-v2".utf8),
            info: paket.authentifizierteDaten,
            outputByteCount: 32
        )
    }
}
