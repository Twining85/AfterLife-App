import Foundation
import Testing
@testable import Tschluessli

@MainActor
struct DossierE2ERecoveryTests {
    @Test func recoveryAufNeuemGeraetUndTrennungVonDossiers() throws {
        let store = DossierE2ESchluesselStore(service: "E2E-Test-\(UUID())")
        let owner = UUID()
        let dossier = UUID()
        let foreign = UUID()
        defer {
            try? store.lokaleOwnerSchluesselLoeschen(ownerUserID: owner, dossierID: dossier)
            try? store.lokaleOwnerSchluesselLoeschen(ownerUserID: owner, dossierID: foreign)
        }
        let context = DossierE2EKontext(dossierID: dossier, sectionType: "gesundheit", schemaVersion: 1, keyVersion: 1, resourceID: "section")
        #expect(throws: (any Error).self) { try store.ressourcenSchluessel(ownerUserID: owner, kontext: context) }
        try store.neuesDossier(ownerUserID: owner, dossierID: dossier)
        let key = try store.ressourcenSchluessel(ownerUserID: owner, kontext: context)
        let code = try DossierRecoveryCode.erstellen().joined(separator: " ")
        let recovery = try store.recoveryPaket(ownerUserID: owner, dossierID: dossier, code: code)
        try store.lokaleOwnerSchluesselLoeschen(ownerUserID: owner, dossierID: dossier)
        #expect(throws: (any Error).self) { try store.wiederherstellen(recovery, code: code, ownerUserID: owner, dossierID: foreign) }
        #expect(throws: (any Error).self) { try store.wiederherstellen(recovery, code: code, ownerUserID: UUID(), dossierID: dossier) }
        let wrongCode = try DossierRecoveryCode.erstellen().joined(separator: " ")
        #expect(throws: (any Error).self) { try store.wiederherstellen(recovery, code: wrongCode, ownerUserID: owner, dossierID: dossier) }
        try store.wiederherstellen(recovery, code: code, ownerUserID: owner, dossierID: dossier)
        #expect(try store.ressourcenSchluessel(ownerUserID: owner, kontext: context) == key)
        try store.neuesDossier(ownerUserID: owner, dossierID: dossier)
        #expect(try store.ressourcenSchluessel(ownerUserID: owner, kontext: context) == key)
    }

    @Test func recoveryUeberschreibtKeineVorhandenenSchluessel() throws {
        let store = DossierE2ESchluesselStore(service: "E2E-Test-\(UUID())")
        let owner = UUID()
        let dossier = UUID()
        defer { try? store.lokaleOwnerSchluesselLoeschen(ownerUserID: owner, dossierID: dossier) }
        try store.neuesDossier(ownerUserID: owner, dossierID: dossier)
        let code = try DossierRecoveryCode.erstellen().joined(separator: " ")
        let recovery = try store.recoveryPaket(ownerUserID: owner, dossierID: dossier, code: code)
        try store.lokaleOwnerSchluesselLoeschen(ownerUserID: owner, dossierID: dossier)
        try store.neuesDossier(ownerUserID: owner, dossierID: dossier)
        let c = DossierE2EKontext(dossierID: dossier, sectionType: "profil", schemaVersion: 1, keyVersion: 1, resourceID: "section")
        let current = try store.ressourcenSchluessel(ownerUserID: owner, kontext: c)
        #expect(throws: (any Error).self) { try store.wiederherstellen(recovery, code: code, ownerUserID: owner, dossierID: dossier) }
        #expect(try store.ressourcenSchluessel(ownerUserID: owner, kontext: c) == current)
    }
}
