import Foundation
import SwiftData
import Testing
@testable import Tschluessli

@MainActor
struct DossierE2EMetadatenTests {
    @Test func metadatenEnthaltenNurRechteUndExpliziteZustimmung() throws {
        for choice in [nil, false, true] as [Bool?] {
            let person = VertrauenspersonModell(vorname: "PrivateName", name: "PrivateSurname", email: "TESTER@example.ch",
                                               telefon: "SecretPhone", beziehung: "SecretRelationship", automatischeVollfreigabeErlaubt: choice)
            let metadata = try DossierE2EKontaktMetadaten.aus(CloudKontaktDaten(hinterbliebene: [], vertrauenspersonen: [.init(person)]))
            #expect(metadata.recipients[0].recipientEmail == "tester@example.ch")
            #expect(metadata.recipients[0].automaticReleaseAllowed == (choice == true))
            #expect(!metadata.recipients[0].visibleSectionTypes.contains("zugaenge"))
            let text = String(decoding: try JSONEncoder().encode(metadata), as: UTF8.self)
            #expect(!text.contains("Private"))
            #expect(!text.contains("Secret"))
        }
    }

    @Test func doppelteEmpfaengerSindUngueltigUndEntwuerfeOhneEmailWerdenAusgelassen() throws {
        let person = VertrauenspersonModell(email: "tester@example.ch")
        let duplicate = VertrauenspersonModell(email: "TESTER@example.ch")
        #expect(throws: (any Error).self) {
            try DossierE2EKontaktMetadaten.aus(CloudKontaktDaten(hinterbliebene: [], vertrauenspersonen: [.init(person), .init(duplicate)]))
        }
        let draft = VertrauenspersonModell()
        #expect(try DossierE2EKontaktMetadaten.aus(CloudKontaktDaten(hinterbliebene: [], vertrauenspersonen: [.init(draft)])).recipients.isEmpty)
    }

    @Test func kontaktExportUndImportSindVerschluesseltMitSeparatenMetadaten() async throws {
        let source = try ModelContainer(for: DossierModell.self, HinterbliebeneModell.self, VertrauenspersonModell.self,
                                        VertrauenspersonEinladungsHistorieModell.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let target = try ModelContainer(for: DossierModell.self, HinterbliebeneModell.self, VertrauenspersonModell.self,
                                        VertrauenspersonEinladungsHistorieModell.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let dossier = UUID()
        let owner = UUID()
        let person = VertrauenspersonModell(vorname: "OnlyLocalName", email: "tester@example.ch", dossierID: dossier, automatischeVollfreigabeErlaubt: true)
        source.mainContext.insert(person)
        try source.mainContext.save()
        let store = DossierE2ESchluesselStore(service: "E2E-Export-Test-\(UUID())")
        defer { try? store.lokaleOwnerSchluesselLoeschen(ownerUserID: owner, dossierID: dossier) }
        try store.neuesDossier(ownerUserID: owner, dossierID: dossier)
        let payload = try await DossierBereichAdapterRegistry().exportiereE2E(dossierID: dossier, ownerUserID: owner, bereich: "kontakte",
                                                                              aus: source.mainContext, schluesselStore: store)
        #expect(!String(decoding: payload.daten, as: UTF8.self).contains("OnlyLocalName"))
        let metadata = try #require(payload.zugriffsMetadaten)
        #expect(!String(decoding: metadata, as: UTF8.self).contains("OnlyLocalName"))
        #expect(String(decoding: metadata, as: UTF8.self).contains("tester@example.ch"))
        try await DossierBereichImport.importiereE2E(payload.daten, bereich: "kontakte", dossierID: dossier, ownerUserID: owner,
                                                     schemaVersion: 1, keyVersion: 1, in: target.mainContext, schluesselStore: store)
        let imported = try #require(target.mainContext.fetch(FetchDescriptor<VertrauenspersonModell>()).first)
        #expect(imported.vorname == "OnlyLocalName")
        #expect(imported.automatischeVollfreigabeErlaubt == true)
    }
}
