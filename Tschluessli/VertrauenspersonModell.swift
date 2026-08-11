//
//  VertrauenspersonModell.swift
//  AfterLife
//
//  Created by René Engeler on 25.06.2026.
//

import Foundation
import SwiftData

@Model
final class VertrauenspersonModell {
    // MARK: - Personendaten

    var personenID: UUID?
    var vorname: String
    var name: String
    var email: String
    var telefon: String
    var beziehung: String

    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?

    // MARK: - Legacy-Felder
    // Diese Felder bleiben vorerst bestehen, damit bestehende Views und gespeicherte Daten nicht brechen.
    // Die fachliche Zugriffslogik soll schrittweise ins DossierZugriffModell wandern.
    var einladungsStatus: String
    var vorsorgeprozessStatus: String
    var einladungsToken: String?
    var einladungsEmail: String?
    var einladungsLinkErstelltAm: Date?
    var vorsorgendeUserID: UUID?
    var vertrauenspersonUserID: UUID?
    var einladungAngenommenAm: Date?
    var einladungAbgelehntAm: Date?
    var istPrimaereVertrauensperson: Bool
    var reihenfolge: Int

    @Relationship(deleteRule: .cascade)
    var einladungsHistorie: [VertrauenspersonEinladungsHistorieModell]

    var erstelltAm: Date
    var geaendertAm: Date

    init(
        personenID: UUID? = UUID(),
        vorname: String = "",
        name: String = "",
        email: String = "",
        telefon: String = "",
        beziehung: String = "",
        einladungsStatus: String = "Offen",
        vorsorgeprozessStatus: String = "Noch nicht gestartet",
        einladungsToken: String? = nil,
        einladungsEmail: String? = nil,
        einladungsLinkErstelltAm: Date? = nil,
        dossierID: UUID? = nil,
        vorsorgendeUserID: UUID? = nil,
        vertrauenspersonUserID: UUID? = nil,
        einladungAngenommenAm: Date? = nil,
        einladungAbgelehntAm: Date? = nil,
        istPrimaereVertrauensperson: Bool = true,
        reihenfolge: Int = 0,
        einladungsHistorie: [VertrauenspersonEinladungsHistorieModell] = [],
        erstelltAm: Date = Date(),
        geaendertAm: Date = Date()
    ) {
        self.personenID = personenID
        self.vorname = vorname
        self.name = name
        self.email = email
        self.telefon = telefon
        self.beziehung = beziehung
        self.einladungsStatus = einladungsStatus
        self.vorsorgeprozessStatus = vorsorgeprozessStatus
        self.einladungsToken = einladungsToken
        self.einladungsEmail = einladungsEmail
        self.einladungsLinkErstelltAm = einladungsLinkErstelltAm
        self.dossierID = dossierID
        self.vorsorgendeUserID = vorsorgendeUserID
        self.vertrauenspersonUserID = vertrauenspersonUserID
        self.einladungAngenommenAm = einladungAngenommenAm
        self.einladungAbgelehntAm = einladungAbgelehntAm
        self.istPrimaereVertrauensperson = istPrimaereVertrauensperson
        self.reihenfolge = reihenfolge
        self.einladungsHistorie = einladungsHistorie
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
    }

    var vollerName: String {
        let nameTeile = [vorname, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !nameTeile.isEmpty {
            return nameTeile.joined(separator: " ")
        }

        if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return email
        }

        return "Unbekannte Vertrauensperson"
    }

    var hatKontaktangaben: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !telefon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Im MVP gilt eine Person bereits als hinterlegt, sobald mindestens eine
    /// lokale Personen- oder Kontaktangabe vorhanden ist. Eine Einladung oder
    /// ein Dossierzugriff ist dafür ausdrücklich nicht erforderlich.
    var istLokalHinterlegt: Bool {
        !vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        hatKontaktangaben
    }

    var normalisierteEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var normalisierteTelefonnummer: String {
        telefon.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var kontaktUntertitel: String {
        if !normalisierteEmail.isEmpty && !normalisierteTelefonnummer.isEmpty {
            return "\(normalisierteEmail) · \(normalisierteTelefonnummer)"
        }

        if !normalisierteEmail.isEmpty {
            return normalisierteEmail
        }

        if !normalisierteTelefonnummer.isEmpty {
            return normalisierteTelefonnummer
        }

        return "Keine Kontaktangaben erfasst"
    }

    var beziehungsAnzeige: String {
        let bereinigteBeziehung = beziehung.trimmingCharacters(in: .whitespacesAndNewlines)
        return bereinigteBeziehung.isEmpty ? "Beziehung nicht erfasst" : bereinigteBeziehung
    }

    func hatGleicheEmail(wie andereEmail: String) -> Bool {
        normalisierteEmail == andereEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var hatGueltigeEmailStruktur: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return normalisierteEmail.range(of: emailRegex, options: .regularExpression) != nil
    }

    var istVollstaendigErfasst: Bool {
        !vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        hatKontaktangaben
    }

    func istDieselbePerson(wie anderePerson: VertrauenspersonModell) -> Bool {
        guard let personenID, let anderePersonenID = anderePerson.personenID else {
            return false
        }

        return personenID == anderePersonenID
    }


    func stellePersonenIDSicher() {
        if personenID == nil {
            personenID = UUID()
            markiereAlsGeaendert()
        }
    }

    func kontaktangabenAktualisieren(
        vorname: String,
        name: String,
        email: String,
        telefon: String,
        beziehung: String
    ) {
        self.vorname = vorname.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.telefon = telefon.trimmingCharacters(in: .whitespacesAndNewlines)
        self.beziehung = beziehung.trimmingCharacters(in: .whitespacesAndNewlines)
        markiereAlsGeaendert()
    }

    func markiereAlsGeaendert() {
        geaendertAm = Date()
    }
}

@Model
final class VertrauenspersonEinladungsHistorieModell {
    var datum: Date
    var beschreibung: String

    init(
        datum: Date = Date(),
        beschreibung: String = ""
    ) {
        self.datum = datum
        self.beschreibung = beschreibung
    }
}
