//
//  ProfileModell.swift
//  AfterLife
//
//  Created by René Engeler on 19.06.2026.
//

import Foundation
import SwiftData

@Model
final class ProfilModell {
    var vorname: String
    var name: String
    var geburtsdatum: Date
    var strasse: String
    var hausnummer: String
    var plz: String
    var stadt: String
    var land: String
    var telefon: String
    var email: String
    var notfallHinweis: String

    // Registrierung / Login
    var registrierungsart: String
    var registrierungsEmail: String
    var registrierungsPasswort: String
    var biometrieAktiviert: Bool

    var profilbildDaten: Data?

    init(
        vorname: String = "",
        name: String = "",
        geburtsdatum: Date = Calendar.current.date(from: DateComponents(year: 1978, month: 6, day: 1)) ?? Date(),
        strasse: String = "",
        hausnummer: String = "",
        plz: String = "",
        stadt: String = "",
        land: String = "Schweiz",
        telefon: String = "",
        email: String = "",
        notfallHinweis: String = "",
        registrierungsart: String = "E-Mail",
        registrierungsEmail: String = "",
        registrierungsPasswort: String = "",
        biometrieAktiviert: Bool = false,
        profilbildDaten: Data? = nil
    ) {
        self.vorname = vorname
        self.name = name
        self.geburtsdatum = geburtsdatum
        self.strasse = strasse
        self.hausnummer = hausnummer
        self.plz = plz
        self.stadt = stadt
        self.land = land
        self.telefon = telefon
        self.email = email
        self.notfallHinweis = notfallHinweis
        self.registrierungsart = registrierungsart
        self.registrierungsEmail = registrierungsEmail
        self.registrierungsPasswort = registrierungsPasswort
        self.biometrieAktiviert = biometrieAktiviert
        self.profilbildDaten = profilbildDaten
    }
}
