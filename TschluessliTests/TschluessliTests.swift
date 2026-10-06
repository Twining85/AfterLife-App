//
//  TschluessliTests.swift
//  TschluessliTests
//
//  Created by René Engeler on 17.06.2026.
//

import Foundation
import CryptoKit
import SwiftData
import SwiftUI
import Testing
@testable import Tschluessli

@MainActor
struct TschluessliTests {
    @Test func prozessstartVerlangtReloginUndBehaeltKontodaten() throws {
        let suite = "ReloginStartTest-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "istEingeloggt")
        defaults.set(true, forKey: "direktNachRegistrierungEingeloggt")
        defaults.set(true, forKey: "profilIstVorhanden")
        defaults.set("test@example.ch", forKey: "gespeicherteEmail")

        TschluessliApp.sperreBeimProzessstart(defaults: defaults)

        #expect(!defaults.bool(forKey: "istEingeloggt"))
        #expect(!defaults.bool(forKey: "direktNachRegistrierungEingeloggt"))
        #expect(defaults.bool(forKey: "profilIstVorhanden"))
        #expect(defaults.string(forKey: "gespeicherteEmail") == "test@example.ch")
    }

    @Test func syncFehlerZeigtDieKonkreteMeldung() {
        let fehler = SyncVerarbeitungsFehler.temporaer("Der Sync-Server ist nicht erreichbar.")
        #expect(fehler.localizedDescription == "Der Sync-Server ist nicht erreichbar.")
    }


    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test func appLayoutReagiertAufVerfuegbareBreiteStattAufGeraetemodelle() {
        let kompakt = AppLayout(containerWidth: 393, dynamicTypeSize: .large)
        let regulaer = AppLayout(containerWidth: 430, dynamicTypeSize: .large)
        let erweitert = AppLayout(containerWidth: 820, dynamicTypeSize: .large)

        #expect(kompakt.widthClass == .compact)
        #expect(kompakt.pageInset == 18)
        #expect(kompakt.profileImageSize == 70)
        #expect(regulaer.widthClass == .regular)
        #expect(regulaer.pageInset == 24)
        #expect(erweitert.widthClass == .expanded)
        #expect(erweitert.pageInset == 32)
    }

    @Test func appLayoutUebernimmtAccessibilityTextgroessen() {
        let layout = AppLayout(containerWidth: 393, dynamicTypeSize: .accessibility3)
        #expect(layout.isAccessibilitySize)
        #expect(layout.prefersLinearNavigation)
    }

    @Test func orbitWechseltVorEinerTextkollisionInDieLineareNavigation() {
        let standard = AppLayout(containerWidth: 393, dynamicTypeSize: .large)
        let vergroessert = AppLayout(containerWidth: 393, dynamicTypeSize: .xLarge)
        let grosseSchrift = AppLayout(containerWidth: 393, dynamicTypeSize: .xxLarge)

        #expect(!standard.prefersCompactNavigationIcons)
        #expect(!standard.prefersLinearNavigation)
        #expect(vergroessert.prefersCompactNavigationIcons)
        #expect(!vergroessert.prefersLinearNavigation)
        #expect(grosseSchrift.prefersLinearNavigation)
    }

    @Test func bereicheBleibenAufNormalenIPhonesBisXlargeZweispaltig() {
        let standard = AppLayout(containerWidth: 393, dynamicTypeSize: .large)
        let vergroessert = AppLayout(containerWidth: 393, dynamicTypeSize: .xLarge)
        let sehrGross = AppLayout(containerWidth: 393, dynamicTypeSize: .xxLarge)
        let sehrSchmal = AppLayout(containerWidth: 350, dynamicTypeSize: .large)

        #expect(!standard.prefersSingleColumnAreaGrid)
        #expect(!vergroessert.prefersSingleColumnAreaGrid)
        #expect(sehrGross.prefersSingleColumnAreaGrid)
        #expect(sehrSchmal.prefersSingleColumnAreaGrid)
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

    @Test func fremddossierPDFEnthaeltNurFreigegebeneWunschdokumente() throws {
        let wuensche = WuenscheModell()
        wuensche.testamentDateiName = "Testament.pdf"
        wuensche.testamentDateiData = Data("testament".utf8)
        wuensche.testamentFreigegebenBeiDossierfreigabe = false
        wuensche.patientenverfuegungDateiName = "Patientenverfuegung.pdf"
        wuensche.patientenverfuegungDateiData = Data("patientenverfuegung".utf8)
        wuensche.patientenverfuegungFreigegebenBeiDossierfreigabe = true

        let mapper = DossierExportMapper()
        let eigenesDossier = mapper.makeDossierDocument(profil: nil, wuensche: [wuensche])
        let fremddossier = mapper.makeDossierDocument(
            profil: nil,
            wuensche: [wuensche],
            wunschDokumenteNachFreigabeFiltern: true
        )

        let eigeneLabels = try #require(
            eigenesDossier.kapitel.first(where: { $0.typ == .wuensche })
        ).sections.flatMap(\.items).map(\.label)
        let fremdeLabels = try #require(
            fremddossier.kapitel.first(where: { $0.typ == .wuensche })
        ).sections.flatMap(\.items).map(\.label)

        #expect(eigeneLabels.contains("Testament"))
        #expect(fremdeLabels.contains("Patientenverfügung"))
        #expect(!fremdeLabels.contains("Testament"))
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
        #expect(verarbeiter.anzahlVerarbeitungen() == 1)
        #expect(coordinator.letzterErfolgreicherLauf != nil)
        #expect(coordinator.letzterFehler == nil)
    }

    @Test func standardBereichsadapterSindEindeutigUndVollstaendig() throws {
        let registry = try DossierBereichAdapterRegistry()
        #expect(registry.bereiche == [
            "dokumente", "dossier_einstellungen", "finanzen", "gesundheit", "herzensstuecke", "kontakte",
            "profil", "wuensche", "zugaenge"
        ])
    }

    @Test func profilAdapterExportiertKeinKontopasswort() async throws {
        let container = try ModelContainer(
            for: ProfilModell.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dossierID = UUID()
        container.mainContext.insert(ProfilModell(dossierID: dossierID))
        try container.mainContext.save()

        let payload = try await ProfilBereichAdapter().exportiere(
            dossierID: dossierID,
            aus: container.mainContext
        )
        let json = try #require(String(data: payload.daten, encoding: .utf8))
        #expect(!json.lowercased().contains("passwort"))
        #expect(try ProfilBereichAdapter().validiere(payload.daten, schemaVersion: 1) == payload.daten)
    }

    @Test func profilDownloadAktualisiertDasVerwendeteSwiftDataModell() async throws {
        let container = try ModelContainer(
            for: ProfilModell.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dossierID = UUID()
        let profil = ProfilModell(dossierID: dossierID, vorname: "Cloud", name: "Stand")
        container.mainContext.insert(profil)
        try container.mainContext.save()
        let payload = try await ProfilBereichAdapter().exportiere(
            dossierID: dossierID,
            aus: container.mainContext
        )

        profil.vorname = "Lokaler Zwischenstand"
        try await DossierBereichImport.importiere(
            payload.daten,
            bereich: "profil",
            dossierID: dossierID,
            in: container.mainContext
        )

        let geladen = try #require(container.mainContext.fetch(FetchDescriptor<ProfilModell>()).first)
        #expect(geladen.vorname == "Cloud")
        #expect(geladen.name == "Stand")
    }

    @Test func profilSyncIgnoriertLeerenRecoveryDoppelgaenger() async throws {
        let container = try ModelContainer(
            for: ProfilModell.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dossierID = UUID()
        let userID = UUID()
        let cloudProfil = ProfilModell(
            userID: userID,
            dossierID: dossierID,
            vorname: "Cloud",
            name: "Profil",
            email: "profil@example.com",
            erstelltAm: Date(timeIntervalSince1970: 100)
        )
        let leererDoppelgaenger = ProfilModell(
            userID: userID,
            dossierID: dossierID,
            email: "profil@example.com",
            erstelltAm: Date(timeIntervalSince1970: 200)
        )
        container.mainContext.insert(cloudProfil)
        container.mainContext.insert(leererDoppelgaenger)
        try container.mainContext.save()

        let export = try await ProfilBereichAdapter().exportiere(
            dossierID: dossierID,
            aus: container.mainContext
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportierteProfile = try decoder.decode(
            CloudDatenListe<CloudProfilDaten>.self,
            from: export.daten
        )
        #expect(exportierteProfile.items.count == 1)
        #expect(exportierteProfile.items.first?.vorname == "Cloud")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let verunreinigterCloudStand = try encoder.encode(CloudDatenListe(items: [
            CloudProfilDaten(cloudProfil),
            CloudProfilDaten(leererDoppelgaenger)
        ]))
        try await DossierBereichImport.importiere(
            verunreinigterCloudStand,
            bereich: "profil",
            dossierID: dossierID,
            in: container.mainContext
        )

        let lokaleProfile = try container.mainContext.fetch(FetchDescriptor<ProfilModell>())
            .filter { $0.dossierID == dossierID && $0.userID == userID }
        #expect(lokaleProfile.count == 1)
        #expect(lokaleProfile.first?.vorname == "Cloud")
        #expect(lokaleProfile.first?.name == "Profil")
    }

    @Test func automatischeVollfreigabeWirdMitKontaktenSynchronisiert() async throws {
        for erlaubt in [nil, false, true] as [Bool?] {
            let container = try ModelContainer(
                for: DossierModell.self, HinterbliebeneModell.self,
                VertrauenspersonModell.self, VertrauenspersonEinladungsHistorieModell.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let dossierID = UUID()
            let person = VertrauenspersonModell(
                email: "trust@example.ch", dossierID: dossierID,
                automatischeVollfreigabeErlaubt: erlaubt
            )
            let cloud = CloudKontaktDaten(hinterbliebene: [], vertrauenspersonen: [CloudKontaktDaten.Vertrauensperson(person)])
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try await DossierBereichImport.importiere(
                encoder.encode(cloud), bereich: "kontakte", dossierID: dossierID, in: container.mainContext
            )
            try container.mainContext.save()
            let geladen = try #require(container.mainContext.fetch(FetchDescriptor<VertrauenspersonModell>()).first)
            #expect(geladen.automatischeVollfreigabeErlaubt == erlaubt)
            #expect((geladen.automatischeVollfreigabeErlaubt ?? false) == (erlaubt ?? false))
        }
    }

    @Test func kontakteRecoveryErgaenztFehlendeBesitzerZuordnung() async throws {
        let container = try ModelContainer(
            for: DossierModell.self,
            HinterbliebeneModell.self,
            VertrauenspersonModell.self,
            VertrauenspersonEinladungsHistorieModell.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dossierID = UUID()
        let besitzerID = UUID()
        container.mainContext.insert(DossierModell(
            dossierID: dossierID,
            besitzerUserID: besitzerID,
            vorsorgendePersonName: "Test"
        ))
        let vertrauensperson = VertrauenspersonModell(
            vorname: "Erika",
            name: "Muster",
            email: "erika@example.com",
            dossierID: dossierID,
            vorsorgendeUserID: nil
        )
        let cloud = CloudKontaktDaten(
            hinterbliebene: [],
            vertrauenspersonen: [CloudKontaktDaten.Vertrauensperson(vertrauensperson)]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try await DossierBereichImport.importiere(
            encoder.encode(cloud),
            bereich: "kontakte",
            dossierID: dossierID,
            in: container.mainContext
        )

        let geladen = try #require(
            container.mainContext.fetch(FetchDescriptor<VertrauenspersonModell>()).first
        )
        #expect(geladen.vorname == "Erika")
        #expect(geladen.dossierID == dossierID)
        #expect(geladen.vorsorgendeUserID == besitzerID)
    }

    @Test func recoveryCodeBestehtAusZwoelfGueltigenWoertern() throws {
        let woerter = try DossierRecoveryCode.erstellen()
        #expect(woerter.count == 12)
        #expect(woerter.allSatisfy(DossierRecoveryCode.woerter.contains))
        #expect(try DossierRecoveryCode.normalisieren(woerter.joined(separator: "  ")) == woerter.joined(separator: " "))
    }

    @Test func recoveryCodeLeitetStabilenUndCodeAbhaengigenSchluesselAb() throws {
        let erster = Array(DossierRecoveryCode.woerter.prefix(12)).joined(separator: " ")
        let zweiter = Array(DossierRecoveryCode.woerter.dropFirst().prefix(12)).joined(separator: " ")
        let ersterHash = try DossierRecoveryCode.schluessel(aus: erster).withUnsafeBytes { Data($0) }
        let wiederholt = try DossierRecoveryCode.schluessel(aus: erster.uppercased()).withUnsafeBytes { Data($0) }
        let zweiterHash = try DossierRecoveryCode.schluessel(aus: zweiter).withUnsafeBytes { Data($0) }
        #expect(ersterHash.count == 32)
        #expect(ersterHash == wiederholt)
        #expect(ersterHash != zweiterHash)
    }

    @Test func recoveryPaketHatEindeutigeAktiveIdentitaetUndMigriertAltbestand() throws {
        let paket = DossierRecoveryPaket(
            version: 1,
            algorithmus: "AES-256-GCM/SHA-256",
            verschluesselterSchluessel: "test"
        )
        #expect(paket.status == .aktiv)
        #expect(paket.erstelltAm > .distantPast)

        let altbestand = Data(#"{"version":1,"algorithmus":"AES-256-GCM/SHA-256","verschluesselterSchluessel":"test"}"#.utf8)
        let migriert = try JSONDecoder().decode(DossierRecoveryPaket.self, from: altbestand)
        #expect(migriert.status == .aktiv)
        #expect(migriert.erstelltAm == .distantPast)
    }

    @Test func recoveryPaketLiestLokalesUndCloudDatumsformat() throws {
        let datum = Date(timeIntervalSince1970: 1_800_000_000)
        let paket = DossierRecoveryPaket(
            version: 1,
            algorithmus: "AES-256-GCM/SHA-256",
            verschluesselterSchluessel: "test",
            erstelltAm: datum
        )

        let lokaleDaten = try JSONEncoder().encode(paket)
        let lokalesPaket = try JSONDecoder().decode(
            DossierRecoveryPaket.self,
            from: lokaleDaten
        )
        #expect(lokalesPaket.erstelltAm == datum)

        let cloudEncoder = JSONEncoder()
        cloudEncoder.dateEncodingStrategy = .iso8601
        let cloudPaket = try JSONDecoder().decode(
            DossierRecoveryPaket.self,
            from: cloudEncoder.encode(paket)
        )
        #expect(cloudPaket.erstelltAm == datum)
        #expect(cloudPaket.id == paket.id)
    }

    @Test func recoveryCodeFingerabdruckErkenntAktuellenUndVeraltetenCode() throws {
        let aktuellerCode = Array(DossierRecoveryCode.woerter.prefix(12)).joined(separator: " ")
        let alterCode = Array(DossierRecoveryCode.woerter.dropFirst().prefix(12)).joined(separator: " ")
        let aktuellerFingerabdruck = try DossierRecoveryCode.fingerabdruck(aus: aktuellerCode)
        let alterFingerabdruck = try DossierRecoveryCode.fingerabdruck(aus: alterCode)

        #expect(aktuellerFingerabdruck == (try DossierRecoveryCode.fingerabdruck(aus: aktuellerCode.uppercased())))
        #expect(aktuellerFingerabdruck != alterFingerabdruck)

        let paket = DossierRecoveryPaket(
            version: 1,
            algorithmus: "AES-256-GCM/SHA-256",
            verschluesselterSchluessel: "test",
            codeFingerabdruck: aktuellerFingerabdruck,
            obsoleteCodeFingerabdruecke: [alterFingerabdruck]
        )
        #expect(paket.codeFingerabdruck == aktuellerFingerabdruck)
        #expect(paket.obsoleteCodeFingerabdruecke.contains(alterFingerabdruck))
    }

    @Test func recoveryPDFCodiertNormalisiertenCodeImQRCode() throws {
        let code = Array(DossierRecoveryCode.woerter.prefix(12)).joined(separator: " ")
        let inhalt = try DossierRecoveryPDF.qrCodeInhalt(code: code.uppercased())
        #expect(inhalt == "TSCHLUESSLI-RECOVERY:1:\(code)")
        #expect(try DossierRecoveryCode.ausQRCode(inhalt) == code)
        #expect(throws: DossierRecoveryFehler.self) {
            try DossierRecoveryCode.ausQRCode("https://example.com/\(code)")
        }

        let url = try DossierRecoveryPDF.erstellen(code: code)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect((try Data(contentsOf: url)).count > 0)
    }

    @Test func recoveryAktiviertDossierbezogeneHomeEinstellungen() throws {
        let suite = "TschluessliTests.Recovery.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let dossierID = UUID()
        let suffix = dossierID.uuidString.lowercased()

        defaults.set("profil", forKey: "homeBereicheReihenfolge")
        defaults.set("", forKey: "homeAktiveBereiche")
        defaults.set(
            "profil,wuensche,gesundheit,herzensstuecke",
            forKey: "homeBereicheReihenfolge.\(suffix)"
        )
        defaults.set(
            "wuensche,gesundheit,herzensstuecke",
            forKey: "homeAktiveBereiche.\(suffix)"
        )
        defaults.set("gefuehrt", forKey: "dossierErstellungsart.\(suffix)")

        DossierEinstellungenStore.aktiviereLokaleEinstellungen(
            fuer: dossierID,
            defaults: defaults
        )

        #expect(defaults.string(forKey: "homeBereicheReihenfolge") == "profil,wuensche,gesundheit,herzensstuecke")
        #expect(defaults.string(forKey: "homeAktiveBereiche") == "wuensche,gesundheit,herzensstuecke")
        #expect(defaults.string(forKey: "dossierErstellungsart") == "gefuehrt")
    }

    @Test func erscheinungsbildOrdnetSystemHellUndDunkelKorrektZu() {
        #expect(AppErscheinungsbild.system.colorScheme == nil)
        #expect(AppErscheinungsbild.hell.colorScheme == .light)
        #expect(AppErscheinungsbild.dunkel.colorScheme == .dark)
        #expect(AppErscheinungsbild.allCases.map(\.rawValue) == ["system", "hell", "dunkel"])
    }

}

@MainActor
private final class ErfolgreicherSyncVerarbeiter: SyncAuftragVerarbeiter {
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
