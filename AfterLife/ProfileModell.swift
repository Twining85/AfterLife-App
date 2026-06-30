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
    var userID: UUID
    /// Referenz auf das eigene Vorsorgedossier.
    var dossierID: UUID?
    var istVertrauensperson: Bool
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
    /// Zeitpunkt der Profilerstellung.
    var erstelltAm: Date

    /// Zeitpunkt der letzten Profiländerung.
    var aktualisiertAm: Date

    /// Kennzeichnet das aktuell bevorzugte Profil für diesen Benutzer.
    var istAktiv: Bool

    init(
        userID: UUID = UUID(),
        dossierID: UUID? = nil,
        istVertrauensperson: Bool = false,
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
        profilbildDaten: Data? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date(),
        istAktiv: Bool = true
    ) {
        self.userID = userID
        self.dossierID = dossierID
        self.istVertrauensperson = istVertrauensperson
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
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
        self.istAktiv = istAktiv
    }
}
