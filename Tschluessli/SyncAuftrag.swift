import Foundation
import SwiftData

nonisolated enum SyncVorgang: String, Codable, Sendable {
    case upsert
    case delete
}

nonisolated enum SyncAuftragStatus: String, Codable, Sendable {
    case pending
    case uploading
    case blocked
}

@Model
final class SyncAuftrag {
    @Attribute(.unique) var schluessel: String
    var id: UUID
    var dossierID: UUID
    var bereich: String
    var vorgangRaw: String
    var statusRaw: String
    var schemaVersion: Int
    var erwarteteRevision: Int64
    var generation: Int64
    var versuche: Int
    var erstelltAm: Date
    var geaendertAm: Date
    var naechsterVersuchAm: Date
    var gesperrtSeit: Date?
    var letzterFehler: String?

    var vorgang: SyncVorgang {
        get { SyncVorgang(rawValue: vorgangRaw) ?? .upsert }
        set { vorgangRaw = newValue.rawValue }
    }

    var status: SyncAuftragStatus {
        get { SyncAuftragStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        dossierID: UUID,
        bereich: String,
        vorgang: SyncVorgang,
        schemaVersion: Int,
        erwarteteRevision: Int64 = 0,
        jetzt: Date = Date()
    ) {
        self.schluessel = Self.schluessel(dossierID: dossierID, bereich: bereich)
        self.id = UUID()
        self.dossierID = dossierID
        self.bereich = bereich
        self.vorgangRaw = vorgang.rawValue
        self.statusRaw = SyncAuftragStatus.pending.rawValue
        self.schemaVersion = schemaVersion
        self.erwarteteRevision = erwarteteRevision
        self.generation = 1
        self.versuche = 0
        self.erstelltAm = jetzt
        self.geaendertAm = jetzt
        self.naechsterVersuchAm = jetzt
        self.gesperrtSeit = nil
        self.letzterFehler = nil
    }

    static func schluessel(dossierID: UUID, bereich: String) -> String {
        "\(dossierID.uuidString.lowercased()):\(bereich)"
    }
}

nonisolated struct SyncAuftragSnapshot: Sendable, Equatable {
    let id: UUID
    let dossierID: UUID
    let bereich: String
    let vorgang: SyncVorgang
    let schemaVersion: Int
    let erwarteteRevision: Int64
    let generation: Int64
    let idempotencyKey: String

    init(_ auftrag: SyncAuftrag) {
        id = auftrag.id
        dossierID = auftrag.dossierID
        bereich = auftrag.bereich
        vorgang = auftrag.vorgang
        schemaVersion = auftrag.schemaVersion
        erwarteteRevision = auftrag.erwarteteRevision
        generation = auftrag.generation
        idempotencyKey = "\(auftrag.id.uuidString.lowercased()):\(auftrag.generation)"
    }
}
