import Foundation
import SwiftData

@Model
final class HinterbliebeneModell {
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var vorname: String
    var name: String
    var rolle: String
    var beziehung: String
    var telefon: String
    var email: String
    var adresse: String
    var plz: String
    var stadt: String
    var land: String
    var bemerkungen: String
    var quelle: String
    var istVertrauensperson: Bool
    var sollInformiertWerden: Bool
    var darfDokumenteErhalten: Bool
    var erstelltAm: Date
    var aktualisiertAm: Date

    init(
        dossierID: UUID? = nil,
        vorname: String = "",
        name: String = "",
        rolle: String = "",
        beziehung: String = "",
        telefon: String = "",
        email: String = "",
        adresse: String = "",
        plz: String = "",
        stadt: String = "",
        land: String = "Schweiz",
        bemerkungen: String = "",
        quelle: String = "",
        istVertrauensperson: Bool = false,
        sollInformiertWerden: Bool = true,
        darfDokumenteErhalten: Bool = false,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.dossierID = dossierID
        self.vorname = vorname
        self.name = name
        self.rolle = rolle
        self.beziehung = beziehung
        self.telefon = telefon
        self.email = email
        self.adresse = adresse
        self.plz = plz
        self.stadt = stadt
        self.land = land
        self.bemerkungen = bemerkungen
        self.quelle = quelle
        self.istVertrauensperson = istVertrauensperson
        self.sollInformiertWerden = sollInformiertWerden
        self.darfDokumenteErhalten = darfDokumenteErhalten
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}
