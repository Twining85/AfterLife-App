//
//  WeiteresModell.swift
//  AfterLife
//
//  Created by René Engeler on 19.06.2026.
//

import Foundation
import SwiftData

@Model
final class WeiteresModell {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var erstelltAm: Date
    var aktualisiertAm: Date

    // MARK: - Allgemeine Notizen
    var allgemeineNotizen: String

    // MARK: - Haustiere
    var hatHaustiere: Bool
    @Relationship(deleteRule: .cascade)
    var haustiere: [HaustierEintrag]

    // MARK: - Fahrzeuge
    var hatFahrzeuge: Bool
    @Relationship(deleteRule: .cascade)
    var fahrzeuge: [FahrzeugEintrag]

    // MARK: - Schlüssel / Zugang
    var hatSchluesselOderZugaenge: Bool
    @Relationship(deleteRule: .cascade)
    var schluesselUndZugaenge: [SchluesselZugangEintrag]

    // MARK: - Verträge / Sonstiges
    var hatWeitereWichtigeInformationen: Bool
    @Relationship(deleteRule: .cascade)
    var weitereInformationen: [WeitereInformationEintrag]

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date(),
        allgemeineNotizen: String = "",
        hatHaustiere: Bool = false,
        haustiere: [HaustierEintrag] = [],
        hatFahrzeuge: Bool = false,
        fahrzeuge: [FahrzeugEintrag] = [],
        hatSchluesselOderZugaenge: Bool = false,
        schluesselUndZugaenge: [SchluesselZugangEintrag] = [],
        hatWeitereWichtigeInformationen: Bool = false,
        weitereInformationen: [WeitereInformationEintrag] = []
    ) {
        self.id = id
        self.dossierID = dossierID
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
        self.allgemeineNotizen = allgemeineNotizen
        self.hatHaustiere = hatHaustiere
        self.haustiere = haustiere
        self.hatFahrzeuge = hatFahrzeuge
        self.fahrzeuge = fahrzeuge
        self.hatSchluesselOderZugaenge = hatSchluesselOderZugaenge
        self.schluesselUndZugaenge = schluesselUndZugaenge
        self.hatWeitereWichtigeInformationen = hatWeitereWichtigeInformationen
        self.weitereInformationen = weitereInformationen
    }
}

@Model
final class HaustierEintrag {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var name: String
    var tierart: String
    var wichtigeInformationen: String
    var betreuungspersonName: String
    var betreuungspersonTelefon: String
    var betreuungspersonEmail: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        name: String = "",
        tierart: String = "Bitte wählen",
        wichtigeInformationen: String = "",
        betreuungspersonName: String = "",
        betreuungspersonTelefon: String = "",
        betreuungspersonEmail: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.dossierID = dossierID
        self.name = name
        self.tierart = tierart
        self.wichtigeInformationen = wichtigeInformationen
        self.betreuungspersonName = betreuungspersonName
        self.betreuungspersonTelefon = betreuungspersonTelefon
        self.betreuungspersonEmail = betreuungspersonEmail
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}

@Model
final class FahrzeugEintrag {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var fahrzeugart: String
    var markeModell: String
    var kennzeichen: String
    var standort: String
    var wichtigeInformationen: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        fahrzeugart: String = "Bitte wählen",
        markeModell: String = "",
        kennzeichen: String = "",
        standort: String = "",
        wichtigeInformationen: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.dossierID = dossierID
        self.fahrzeugart = fahrzeugart
        self.markeModell = markeModell
        self.kennzeichen = kennzeichen
        self.standort = standort
        self.wichtigeInformationen = wichtigeInformationen
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}

@Model
final class SchluesselZugangEintrag {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var bezeichnung: String
    var ort: String
    var zugangscodeOderHinweis: String
    var wichtigeInformationen: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        bezeichnung: String = "",
        ort: String = "",
        zugangscodeOderHinweis: String = "",
        wichtigeInformationen: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.dossierID = dossierID
        self.bezeichnung = bezeichnung
        self.ort = ort
        self.zugangscodeOderHinweis = zugangscodeOderHinweis
        self.wichtigeInformationen = wichtigeInformationen
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}

@Model
final class WeitereInformationEintrag {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var kategorie: String
    var titel: String
    var beschreibung: String
    var kontaktperson: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        kategorie: String = "Bitte wählen",
        titel: String = "",
        beschreibung: String = "",
        kontaktperson: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.dossierID = dossierID
        self.kategorie = kategorie
        self.titel = titel
        self.beschreibung = beschreibung
        self.kontaktperson = kontaktperson
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}
