//
//  AfterLifeTests.swift
//  AfterLifeTests
//
//  Created by René Engeler on 17.06.2026.
//

import Foundation
import Testing
@testable import AfterLife

struct AfterLifeTests {

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

}
