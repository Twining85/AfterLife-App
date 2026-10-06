import Foundation
import SwiftData

nonisolated struct DossierE2EKontaktMetadaten: Codable, Sendable {
    let version: Int
    let recipients: [Empfaenger]

    nonisolated struct Empfaenger: Codable, Sendable, Equatable {
        let recipientEmail: String
        let visibleSectionTypes: [String]
        let automaticReleaseAllowed: Bool
    }

    /// Routing/permission data only. No names, addresses, phone numbers or notes.
    static func aus(_ kontakte: CloudKontaktDaten) throws -> Self {
        var seen = Set<String>()
        let recipients = try kontakte.vertrauenspersonen.compactMap { person -> Empfaenger? in
            let email = (person.einladungsEmail?.isEmpty == false ? person.einladungsEmail! : person.email)
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if email.isEmpty { return nil }
            guard email.count <= 254, email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil,
                  seen.insert(email).inserted else { throw DossierE2EFehler.ungueltigerKontext }
            var visible = ["profil"]
            if person.wuenscheSichtbarBeiDossierfreigabe ?? true { visible.append("wuensche") }
            if person.menschenDesVertrauensSichtbarBeiDossierfreigabe ?? true { visible.append("kontakte") }
            if person.finanzenSichtbarBeiDossierfreigabe ?? false { visible.append("finanzen") }
            if person.dokumenteSichtbarBeiDossierfreigabe ?? false { visible.append("dokumente") }
            if person.abosUndProfileSichtbarBeiDossierfreigabe ?? false { visible.append("zugaenge") }
            if person.herzensstueckeSichtbarBeiDossierfreigabe ?? true { visible.append("herzensstuecke") }
            if person.gesundheitSichtbarBeiDossierfreigabe ?? true { visible.append("gesundheit") }
            return Empfaenger(recipientEmail: email, visibleSectionTypes: visible.sorted(),
                             automaticReleaseAllowed: person.automatischeVollfreigabeErlaubt == true)
        }.sorted { $0.recipientEmail < $1.recipientEmail }
        guard recipients.count <= 100 else { throw DossierE2EFehler.ungueltigerKontext }
        return Self(version: 2, recipients: recipients)
    }
}

nonisolated struct DossierE2EEinstellungenMetadaten: Codable, Sendable {
    let version: Int
    let activeSectionTypes: [String]

    static func aus(_ einstellungen: CloudDossierEinstellungenDaten) throws -> Self {
        let mapping = ["hinterbliebene": "kontakte", "abos": "zugaenge"]
        let types = Set(einstellungen.homeAktiveBereiche.map { mapping[$0] ?? $0 })
        guard types.isSubset(of: DossierE2EKontext.bereiche.subtracting(["dossier_einstellungen"])) else {
            throw DossierE2EFehler.ungueltigerKontext
        }
        return Self(version: 2, activeSectionTypes: types.sorted())
    }
}

@MainActor
extension DossierBereichAdapterRegistry {
    /// Explicit V2 export for the migration flow; normal legacy export is unchanged.
    func exportiereE2E(dossierID: UUID, ownerUserID: UUID, bereich: String, keyVersion: Int = 1,
                       aus context: ModelContext, schluesselStore: DossierE2ESchluesselStore = .shared) async throws -> DossierBereichPayload {
        let adapter = try adapter(fuer: bereich)
        let legacy = try await adapter.exportiere(dossierID: dossierID, aus: context)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        var plaintext = legacy.daten
        var metadata: Data?
        switch bereich {
        case "kontakte":
            metadata = try encoder.encode(DossierE2EKontaktMetadaten.aus(decoder.decode(CloudKontaktDaten.self, from: plaintext)))
        case "dossier_einstellungen":
            metadata = try encoder.encode(DossierE2EEinstellungenMetadaten.aus(decoder.decode(CloudDossierEinstellungenDaten.self, from: plaintext)))
        case "zugaenge":
            let old = try decoder.decode(VerschluesselterCloudBereich.self, from: plaintext)
            let clear = try await CloudFeldVerschluesselung.shared.entschluesseln(old, als: CloudZugangsDaten.self)
            plaintext = try encoder.encode(clear)
        default: break
        }
        let cryptoContext = DossierE2EKontext(dossierID: dossierID, sectionType: bereich,
                                            schemaVersion: legacy.schemaVersion, keyVersion: keyVersion, resourceID: "section")
        let key = try schluesselStore.ressourcenSchluessel(ownerUserID: ownerUserID, kontext: cryptoContext)
        let encrypted = try DossierE2EVerschluesselung.verschluesseln(plaintext, schluessel: key, kontext: cryptoContext)
        return DossierBereichPayload(bereich: bereich, schemaVersion: legacy.schemaVersion,
                                    daten: try encoder.encode(encrypted), zugriffsMetadaten: metadata)
    }
}

@MainActor
extension DossierBereichImport {
    static func importiereE2E(_ daten: Data, bereich: String, dossierID: UUID, ownerUserID: UUID,
                             schemaVersion: Int, keyVersion: Int, in context: ModelContext,
                             schluesselStore: DossierE2ESchluesselStore = .shared) async throws {
        let cryptoContext = DossierE2EKontext(dossierID: dossierID, sectionType: bereich,
                                            schemaVersion: schemaVersion, keyVersion: keyVersion, resourceID: "section")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(DossierE2EPayload.self, from: daten)
        let key = try schluesselStore.ressourcenSchluessel(ownerUserID: ownerUserID, kontext: cryptoContext)
        let plaintext = try DossierE2EVerschluesselung.entschluesseln(envelope, schluessel: key, erwarteterKontext: cryptoContext)
        if bereich == "zugaenge" {
            try importiereZugangsDaten(decoder.decode(CloudZugangsDaten.self, from: plaintext), dossierID: dossierID, in: context)
        } else {
            try await importiere(plaintext, bereich: bereich, dossierID: dossierID, in: context)
        }
    }
}
