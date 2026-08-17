//
//  TschluessliTests.swift
//  TschluessliTests
//
//  Created by René Engeler on 17.06.2026.
//

import Foundation
import SwiftData
import Testing
@testable import Tschluessli

@MainActor
struct TschluessliTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test func vorsorgeStatusFolgtDerMVPrioritaet() {
        let export = Date(timeIntervalSince1970: 1_000)

        #expect(VorsorgeStatusService.berechne(
            vollstaendigkeit: 0.8, wurdeGeprueft: false, letzterExportAm: nil,
            letzteInhaltlicheAenderungAm: nil, hatOffeneEinladung: false,
            hatAktiveVertrauensperson: false
        ) == .bereitZurPruefung)

        #expect(VorsorgeStatusService.berechne(
            vollstaendigkeit: 1, wurdeGeprueft: true, letzterExportAm: export,
            letzteInhaltlicheAenderungAm: export.addingTimeInterval(1), hatOffeneEinladung: true,
            hatAktiveVertrauensperson: true
        ) == .aktualisierungNoetig)

        #expect(VorsorgeStatusService.berechne(
            vollstaendigkeit: 1, wurdeGeprueft: true, letzterExportAm: export,
            letzteInhaltlicheAenderungAm: export, hatOffeneEinladung: true,
            hatAktiveVertrauensperson: true
        ) == .vertrauenspersonAktiv)
    }

    @Test func vertrauenspersonKapitelWirdNurBeiVorhandenerPersonErzeugt() {
        let mapper = DossierExportMapper()
        let ohnePerson = mapper.makeDossierDocument(profil: nil, wuensche: [])
        #expect(!ohnePerson.kapitel.contains(where: { $0.typ == .vertrauensperson }))

        let person = VertrauenspersonModell(vorname: "Anna", name: "Muster", telefon: "+41 79 000 00 00")
        let mitPerson = mapper.makeDossierDocument(
            profil: nil,
            wuensche: [],
            vertrauenspersonen: [person]
        )

        let kapitel = mitPerson.kapitel.first(where: { $0.typ == .vertrauensperson })
        #expect(kapitel != nil)
        #expect(Array(mitPerson.kapitel.map(\.typ).prefix(3)) == [.profil, .vertrauensperson, .wuensche])
        #expect(kapitel?.sections.first?.items.contains(where: {
            $0.label == "Name" && $0.wert == "Anna Muster"
        }) == true)
    }

    @Test func personenInformierenBietetGenauDieZweiVorgesehenenBehandlungen() {
        #expect(KontaktBehandlung.allCases == [
            .nurInformieren,
            .informierenUndEinladen
        ])
        #expect(KontaktBehandlung.nurInformieren.sollInformiertWerden)
        #expect(!KontaktBehandlung.nurInformieren.sollEingeladenWerden)
        #expect(KontaktBehandlung.informierenUndEinladen.sollInformiertWerden)
        #expect(KontaktBehandlung.informierenUndEinladen.sollEingeladenWerden)
    }

    @Test func kontaktKategorienHabenDieGewuenschteSortierreihenfolge() {
        #expect(KontaktArt.allCases.sorted(by: {
            $0.sortierreihenfolge < $1.sortierreihenfolge
        }) == [.partner, .familie, .freunde, .anderes])
    }

    @Test func lokaleSicherheitsMigrationEntferntAltesKontopasswortGenauEinmal() throws {
        let suiteName = "TschluessliTests.Sicherheitsmigration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("nicht-speichern", forKey: "gespeichertesPasswort")
        var keychainBereinigungen = 0

        let ausfuehren = {
            LokaleSicherheitsMigration.ausfuehren(
                userDefaults: defaults,
                legacyLoginLoeschen: { keychainBereinigungen += 1 },
                dateischutzAnwenden: false
            )
        }

        ausfuehren()
        #expect(defaults.string(forKey: "gespeichertesPasswort") == nil)
        #expect(keychainBereinigungen == 1)

        defaults.set("darf-nicht-erneut-verarbeitet-werden", forKey: "gespeichertesPasswort")
        ausfuehren()
        #expect(keychainBereinigungen == 1)
    }

    @Test func syncOutboxFasstMehrereAenderungenEinesBereichsZusammen() throws {
        let container = try ModelContainer(
            for: SyncAuftrag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let outbox = SyncOutbox(modelContext: container.mainContext)
        let dossierID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)

        let erster = try outbox.markiereAenderung(
            dossierID: dossierID,
            bereich: "profil",
            schemaVersion: 1,
            jetzt: start
        )
        let id = erster.id

        let zweiter = try outbox.markiereAenderung(
            dossierID: dossierID,
            bereich: "profil",
            schemaVersion: 2,
            jetzt: start.addingTimeInterval(1)
        )

        #expect(try outbox.anzahlOffen() == 1)
        #expect(zweiter.id == id)
        #expect(zweiter.generation == 2)
        #expect(zweiter.schemaVersion == 2)
    }

    @Test func syncOutboxVerliertKeineAenderungWaehrendUpload() throws {
        let container = try ModelContainer(
            for: SyncAuftrag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let outbox = SyncOutbox(modelContext: container.mainContext)
        let dossierID = UUID()
        let start = Date(timeIntervalSince1970: 2_000)

        _ = try outbox.markiereAenderung(
            dossierID: dossierID,
            bereich: "wuensche",
            schemaVersion: 1,
            jetzt: start
        )
        let reservierterUpload = try outbox.reserviereNaechstenAuftrag(jetzt: start)
        let upload = try #require(reservierterUpload)

        _ = try outbox.markiereAenderung(
            dossierID: dossierID,
            bereich: "wuensche",
            schemaVersion: 1,
            jetzt: start.addingTimeInterval(1)
        )
        try outbox.bestaetige(upload, serverRevision: 7, jetzt: start.addingTimeInterval(2))

        #expect(try outbox.anzahlOffen() == 1)
        let reservierterNachfolger = try outbox.reserviereNaechstenAuftrag(
            jetzt: start.addingTimeInterval(2)
        )
        let naechster = try #require(reservierterNachfolger)
        #expect(naechster.generation == 2)
        #expect(naechster.erwarteteRevision == 7)
    }

    @Test func syncRetryPolicyIstBegrenzt() {
        #expect(SyncRetryPolicy.verzoegerung(nachVersuch: 1) == 5)
        #expect(SyncRetryPolicy.verzoegerung(nachVersuch: 2) == 10)
        #expect(SyncRetryPolicy.verzoegerung(nachVersuch: 20) == 3_600)
    }

    @Test func syncCoordinatorBestaetigtErfolgreichenAuftrag() async throws {
        let container = try ModelContainer(
            for: SyncAuftrag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let outbox = SyncOutbox(modelContext: container.mainContext)
        let verarbeiter = ErfolgreicherSyncVerarbeiter(serverRevision: 4)
        let coordinator = SyncCoordinator(outbox: outbox, verarbeiter: verarbeiter)

        _ = try outbox.markiereAenderung(
            dossierID: UUID(),
            bereich: "profil",
            schemaVersion: 1
        )
        await coordinator.synchronisieren()

        #expect(try outbox.anzahlOffen() == 0)
        #expect(await verarbeiter.anzahlVerarbeitungen() == 1)
        #expect(coordinator.letzterErfolgreicherLauf != nil)
        #expect(coordinator.letzterFehler == nil)
    }

}

private actor ErfolgreicherSyncVerarbeiter: SyncAuftragVerarbeiter {
    private let serverRevision: Int64
    private var anzahl = 0

    init(serverRevision: Int64) {
        self.serverRevision = serverRevision
    }

    func verarbeite(_ auftrag: SyncAuftragSnapshot) async throws -> Int64 {
        anzahl += 1
        return serverRevision
    }

    func anzahlVerarbeitungen() -> Int {
        anzahl
    }
}
