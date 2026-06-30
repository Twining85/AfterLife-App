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
    var vorname: String
    var name: String
    var email: String
    var telefon: String
    var beziehung: String

    var einladungsStatus: String
    var vorsorgeprozessStatus: String
    var einladungsToken: String?
    var einladungsEmail: String?
    var einladungsLinkErstelltAm: Date?
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    // Beziehung zwischen vorsorgender Person und Vertrauensperson
    var vorsorgendeUserID: UUID?
    var vertrauenspersonUserID: UUID?
    var einladungAngenommenAm: Date?
    var einladungAbgelehntAm: Date?

    // Vorbereitung für mehrere Vertrauenspersonen pro Dossier
    var istPrimaereVertrauensperson: Bool
    var reihenfolge: Int

    @Relationship(deleteRule: .cascade)
    var einladungsHistorie: [VertrauenspersonEinladungsHistorieModell]

    var erstelltAm: Date
    var geaendertAm: Date

    init(
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
