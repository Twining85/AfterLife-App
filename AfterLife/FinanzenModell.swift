import Foundation
import SwiftData

@Model
final class BankkontoModell {
    @Attribute(.unique) var eintragsID: String
    var bankname: String
    var bankAdresse: String
    var iban: String
    var kontoArt: String
    var berater: String
    var vermoegenswert: Double
    var waehrung: String
    var dokumentDateiName: String
    var dokumentPfad: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        eintragsID: String = UUID().uuidString,
        bankname: String = "",
        bankAdresse: String = "",
        iban: String = "",
        kontoArt: String = "Bitte wählen",
        berater: String = "",
        vermoegenswert: Double = 0,
        waehrung: String = "CHF",
        dokumentDateiName: String = "",
        dokumentPfad: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.eintragsID = eintragsID
        self.bankname = bankname
        self.bankAdresse = bankAdresse
        self.iban = iban
        self.kontoArt = kontoArt
        self.berater = berater
        self.vermoegenswert = vermoegenswert
        self.waehrung = waehrung
        self.dokumentDateiName = dokumentDateiName
        self.dokumentPfad = dokumentPfad
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }

    var istSpeicherwuerdig: Bool {
        !kontoArt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        kontoArt != "Bitte wählen"
    }
}

@Model
final class SchuldenModell {
    @Attribute(.unique) var eintragsID: String
    var art: String
    var betrag: Double
    var waehrung: String
    var glaeubiger: String
    var bemerkungen: String
    var dokumentDateiName: String
    var dokumentPfad: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        eintragsID: String = UUID().uuidString,
        art: String = "Bitte wählen",
        betrag: Double = 0,
        waehrung: String = "CHF",
        glaeubiger: String = "",
        bemerkungen: String = "",
        dokumentDateiName: String = "",
        dokumentPfad: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.eintragsID = eintragsID
        self.art = art
        self.betrag = betrag
        self.waehrung = waehrung
        self.glaeubiger = glaeubiger
        self.bemerkungen = bemerkungen
        self.dokumentDateiName = dokumentDateiName
        self.dokumentPfad = dokumentPfad
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }

    var istSpeicherwuerdig: Bool {
        !art.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        art != "Bitte wählen"
    }
}

@Model
final class VersicherungModell {
    @Attribute(.unique) var eintragsID: String
    var art: String
    var anbieter: String
    var policenNummer: String
    var praemie: Double
    var waehrung: String
    var bemerkungen: String
    var dokumentDateiName: String
    var dokumentPfad: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        eintragsID: String = UUID().uuidString,
        art: String = "Bitte wählen",
        anbieter: String = "",
        policenNummer: String = "",
        praemie: Double = 0,
        waehrung: String = "CHF",
        bemerkungen: String = "",
        dokumentDateiName: String = "",
        dokumentPfad: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.eintragsID = eintragsID
        self.art = art
        self.anbieter = anbieter
        self.policenNummer = policenNummer
        self.praemie = praemie
        self.waehrung = waehrung
        self.bemerkungen = bemerkungen
        self.dokumentDateiName = dokumentDateiName
        self.dokumentPfad = dokumentPfad
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }

    var istSpeicherwuerdig: Bool {
        !art.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        art != "Bitte wählen"
    }
}

@Model
final class LiegenschaftModell {
    @Attribute(.unique) var eintragsID: String
    var art: String
    var adresse: String
    var plz: String
    var stadt: String
    var land: String
    var verkehrswert: Double
    var eigenmietwert: Double
    var eigenmietwertWaehrung: String
    var waehrung: String
    var bemerkungen: String
    var dokumentDateiName: String
    var dokumentPfad: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        eintragsID: String = UUID().uuidString,
        art: String = "Bitte wählen",
        adresse: String = "",
        plz: String = "",
        stadt: String = "",
        land: String = "Schweiz",
        verkehrswert: Double = 0,
        eigenmietwert: Double = 0,
        eigenmietwertWaehrung: String = "CHF",
        waehrung: String = "CHF",
        bemerkungen: String = "",
        dokumentDateiName: String = "",
        dokumentPfad: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.eintragsID = eintragsID
        self.art = art
        self.adresse = adresse
        self.plz = plz
        self.stadt = stadt
        self.land = land
        self.verkehrswert = verkehrswert
        self.eigenmietwert = eigenmietwert
        self.eigenmietwertWaehrung = eigenmietwertWaehrung
        self.waehrung = waehrung
        self.bemerkungen = bemerkungen
        self.dokumentDateiName = dokumentDateiName
        self.dokumentPfad = dokumentPfad
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }

    var istSpeicherwuerdig: Bool {
        !art.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        art != "Bitte wählen"
    }
}

@Model
final class WertsacheModell {
    @Attribute(.unique) var eintragsID: String
    var art: String
    var beschreibung: String
    var betrag: Double
    var waehrung: String
    var aufbewahrungsort: String
    var bemerkungen: String
    var dokumentDateiName: String
    var dokumentPfad: String
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        eintragsID: String = UUID().uuidString,
        art: String = "Bitte wählen",
        beschreibung: String = "",
        betrag: Double = 0,
        waehrung: String = "CHF",
        aufbewahrungsort: String = "",
        bemerkungen: String = "",
        dokumentDateiName: String = "",
        dokumentPfad: String = "",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.eintragsID = eintragsID
        self.art = art
        self.beschreibung = beschreibung
        self.betrag = betrag
        self.waehrung = waehrung
        self.aufbewahrungsort = aufbewahrungsort
        self.bemerkungen = bemerkungen
        self.dokumentDateiName = dokumentDateiName
        self.dokumentPfad = dokumentPfad
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }

    var istSpeicherwuerdig: Bool {
        !art.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        art != "Bitte wählen"
    }
}

@Model
final class SteuerdokumentModell {
    @Attribute(.unique) var eintragsID: String
    var titel: String
    var jahr: Int
    var dateiName: String
    var dateiDaten: Data?
    var dokumentPfad: String
    var hochgeladenAm: Date
    var bemerkungen: String

    init(
        eintragsID: String = UUID().uuidString,
        titel: String = "Alte Steuerunterlagen",
        jahr: Int = Calendar.current.component(.year, from: Date()),
        dateiName: String = "",
        dateiDaten: Data? = nil,
        dokumentPfad: String = "",
        hochgeladenAm: Date = Date(),
        bemerkungen: String = ""
    ) {
        self.eintragsID = eintragsID
        self.titel = titel
        self.jahr = jahr
        self.dateiName = dateiName
        self.dateiDaten = dateiDaten
        self.dokumentPfad = dokumentPfad
        self.hochgeladenAm = hochgeladenAm
        self.bemerkungen = bemerkungen
    }
}
