//
//  HerzensstueckeModell.swift
//  Tschluessli
//
//  Created by René Engeler on 06.08.2026.
//

import Foundation
import SwiftData

enum HerzensstueckBestimmung: String, CaseIterable, Identifiable, Codable {
    case familieEntscheiden = "Familie entscheiden lassen"
    case verschenken = "An bestimmte Person verschenken"
    case behalten = "Behalten"
    case verkaufen = "Verkaufen"
    case spenden = "Spenden"
    case museumOderVerein = "Museum / Verein"
    case entsorgen = "Entsorgen"
    case andere = "Andere"

    var id: String { rawValue }
}

@Model
final class HerzensstueckModell {
    var id: UUID
    var dossierID: UUID?
    var titel: String
    var beschreibung: String
    var geschichte: String
    var erinnerung: String
    /// Persistierter Raw-Value von ``HerzensstueckBestimmung``.
    var bestimmungRawValue: String
    /// Kontakt wird bewusst als Momentaufnahme gespeichert, damit die Verfügung
    /// auch nach einer späteren Kontaktänderung verständlich bleibt.
    var empfaengerName: String
    var empfaengerEmail: String
    var persoenlicheNachricht: String
    var hatGeschaetztenWert: Bool
    var geschaetzterWert: Double
    var wertUnbekannt: Bool
    var andereBestimmung: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    @Relationship(deleteRule: .cascade)
    var bilder: [HerzensstueckBildModell]

    @Relationship(deleteRule: .cascade)
    var dokumente: [HerzensstueckDokumentModell]

    @Relationship(deleteRule: .cascade)
    var audio: HerzensstueckAudioModell?

    var bestimmung: HerzensstueckBestimmung {
        get { HerzensstueckBestimmung(rawValue: bestimmungRawValue) ?? .familieEntscheiden }
        set { bestimmungRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        titel: String = "",
        beschreibung: String = "",
        geschichte: String = "",
        erinnerung: String = "",
        bestimmung: HerzensstueckBestimmung = .familieEntscheiden,
        empfaengerName: String = "",
        empfaengerEmail: String = "",
        persoenlicheNachricht: String = "",
        hatGeschaetztenWert: Bool = false,
        geschaetzterWert: Double = 0,
        wertUnbekannt: Bool = false,
        andereBestimmung: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date(),
        bilder: [HerzensstueckBildModell] = [],
        dokumente: [HerzensstueckDokumentModell] = [],
        audio: HerzensstueckAudioModell? = nil
    ) {
        self.id = id
        self.dossierID = dossierID
        self.titel = titel
        self.beschreibung = beschreibung
        self.geschichte = geschichte
        self.erinnerung = erinnerung
        self.bestimmungRawValue = bestimmung.rawValue
        self.empfaengerName = empfaengerName
        self.empfaengerEmail = empfaengerEmail
        self.persoenlicheNachricht = persoenlicheNachricht
        self.hatGeschaetztenWert = hatGeschaetztenWert
        self.geschaetzterWert = geschaetzterWert
        self.wertUnbekannt = wertUnbekannt
        self.andereBestimmung = andereBestimmung
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
        self.bilder = bilder
        self.dokumente = dokumente
        self.audio = audio
    }
}

@Model
final class HerzensstueckBildModell {
    var id: UUID
    var dateiName: String
    @Attribute(.externalStorage) var bildDaten: Data
    var reihenfolge: Int
    var hinzugefuegtAm: Date

    init(id: UUID = UUID(), dateiName: String = "", bildDaten: Data = Data(), reihenfolge: Int = 0, hinzugefuegtAm: Date = Date()) {
        self.id = id
        self.dateiName = dateiName
        self.bildDaten = bildDaten
        self.reihenfolge = reihenfolge
        self.hinzugefuegtAm = hinzugefuegtAm
    }
}

@Model
final class HerzensstueckDokumentModell {
    var id: UUID
    var dateiName: String
    var dateiTyp: String
    @Attribute(.externalStorage) var dateiDaten: Data
    var hinzugefuegtAm: Date

    init(id: UUID = UUID(), dateiName: String = "", dateiTyp: String = "", dateiDaten: Data = Data(), hinzugefuegtAm: Date = Date()) {
        self.id = id
        self.dateiName = dateiName
        self.dateiTyp = dateiTyp
        self.dateiDaten = dateiDaten
        self.hinzugefuegtAm = hinzugefuegtAm
    }
}

@Model
final class HerzensstueckAudioModell {
    var id: UUID
    var dateiName: String
    var dateiTyp: String
    @Attribute(.externalStorage) var audioDaten: Data
    var hinzugefuegtAm: Date

    init(id: UUID = UUID(), dateiName: String = "", dateiTyp: String = "", audioDaten: Data = Data(), hinzugefuegtAm: Date = Date()) {
        self.id = id
        self.dateiName = dateiName
        self.dateiTyp = dateiTyp
        self.audioDaten = audioDaten
        self.hinzugefuegtAm = hinzugefuegtAm
    }
}
