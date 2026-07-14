import Foundation
import CoreGraphics

struct DossierPDFExportOptions: Equatable {
    var sensibleDatenEinschliessen: Bool
    var dokumenteAlsAnhangBeruecksichtigen: Bool
    var leereFelderAnzeigen: Bool

    static let standard = DossierPDFExportOptions(
        sensibleDatenEinschliessen: false,
        dokumenteAlsAnhangBeruecksichtigen: true,
        leereFelderAnzeigen: false
    )
}

struct DossierPDFDocument {
    var titel: String
    var untertitel: String
    var erstelltAm: Date
    var aktualisiertAm: Date?
    var vertraulichkeitshinweis: String
    var kapitel: [DossierPDFChapter]
    var anhaenge: [DossierPDFAttachment]
}

struct DossierPDFChapter: Identifiable {
    let id: UUID
    var typ: DossierPDFChapterType
    var titel: String
    var beschreibung: String
    var farbe: PDFThemeColor
    var profilbildDaten: Data?
    var sections: [DossierPDFSection]

    init(
        id: UUID = UUID(),
        typ: DossierPDFChapterType,
        titel: String,
        beschreibung: String,
        farbe: PDFThemeColor,
        profilbildDaten: Data? = nil,
        sections: [DossierPDFSection]
    ) {
        self.id = id
        self.typ = typ
        self.titel = titel
        self.beschreibung = beschreibung
        self.farbe = farbe
        self.profilbildDaten = profilbildDaten
        self.sections = sections
    }
}

enum DossierPDFChapterType: String {
    case profil
    case wuensche
    case gesundheit
    case finanzen
    case dokumente
    case abos
}

struct DossierPDFSection: Identifiable {
    let id: UUID
    var titel: String
    var untertitel: String?
    var items: [DossierPDFItem]
    var darstellung: DossierPDFSectionStyle

    init(
        id: UUID = UUID(),
        titel: String,
        untertitel: String? = nil,
        items: [DossierPDFItem],
        darstellung: DossierPDFSectionStyle = .karte
    ) {
        self.id = id
        self.titel = titel
        self.untertitel = untertitel
        self.items = items
        self.darstellung = darstellung
    }
}

enum DossierPDFSectionStyle {
    case karte
    case zweispaltigeTabelle
    case persoenlicherText
    case kontaktkarte
    case statusListe
}

struct DossierPDFItem: Identifiable {
    let id: UUID
    var label: String
    var wert: String
    var status: DossierPDFItemStatus?

    init(id: UUID = UUID(), label: String, wert: String, status: DossierPDFItemStatus? = nil) {
        self.id = id
        self.label = label
        self.wert = wert
        self.status = status
    }
}

enum DossierPDFItemStatus {
    case vorhanden
    case nichtVorhanden
    case nichtErfasst
}

struct DossierPDFAttachment: Identifiable {
    let id: UUID
    var titel: String
    var kategorie: String
    var dateiname: String
    var erstelltAm: Date?
    var daten: Data

    init(
        id: UUID = UUID(),
        titel: String,
        kategorie: String,
        dateiname: String,
        erstelltAm: Date? = nil,
        daten: Data
    ) {
        self.id = id
        self.titel = titel
        self.kategorie = kategorie
        self.dateiname = dateiname
        self.erstelltAm = erstelltAm
        self.daten = daten
    }
}

struct PDFThemeColor: Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
