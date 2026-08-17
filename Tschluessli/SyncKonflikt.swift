import Foundation
import SwiftData

@Model
final class SyncKonflikt {
    @Attribute(.unique) var schluessel: String
    var dossierID: UUID
    var bereich: String
    var vorgangRaw: String
    var schemaVersion: Int
    var serverRevision: Int64
    @Attribute(.externalStorage) var serverPayload: Data?
    var empfangenAm: Date

    init(
        dossierID: UUID,
        bereich: String,
        vorgang: SyncVorgang,
        schemaVersion: Int,
        serverRevision: Int64,
        serverPayload: Data?,
        empfangenAm: Date
    ) {
        self.schluessel = SyncAuftrag.schluessel(dossierID: dossierID, bereich: bereich)
        self.dossierID = dossierID
        self.bereich = bereich
        self.vorgangRaw = vorgang.rawValue
        self.schemaVersion = schemaVersion
        self.serverRevision = serverRevision
        self.serverPayload = serverPayload
        self.empfangenAm = empfangenAm
    }
}
