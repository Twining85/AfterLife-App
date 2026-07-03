import Foundation
import SwiftData

@Model
final class WuenscheModell {

    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?

    // Allgemein
    var hatWuensche: Bool
    @Attribute(.externalStorage) var ausgewaehlteThemenData: Data? = nil

    // Beisetzung
    var beisetzungsArt: String
    var beisetzungHinweis: String
    var sonstigeBemerkungen: String
    var keineBlumengeschenkeBitte: Bool

    // Musik
    var besondereMusik: Bool
    var musikWunsch: String

    // Zeremonie
    var zeremonieGewuenscht: Bool
    var zeremonieDetails: String
    var zeremonieOrganisiert: Bool
    var zeremonieFinanziellAbgesichert: Bool

    // Letzte Worte
    var moechteNochEtwasSagen: Bool
    var letzteBotschaft: String
    var letzteBotschaftVideoName: String = ""
    @Attribute(.externalStorage) var letzteBotschaftVideoData: Data? = nil

    // Nachruf
    var nachrufGewuenscht: Bool
    var nachrufText: String
    var nachrufBildDateiName: String
    @Attribute(.externalStorage) var nachrufBildData: Data?

    // Testament
    var testamentVorhanden: Bool
    var testamentAblageort: String
    var testamentDateiName: String
    @Attribute(.externalStorage) var testamentDateiData: Data?
    var testamentHochgeladenAm: Date?
    var testamentErinnerungAktiv: Bool
    var testamentErinnerungAm: Date?

    // Patientenverfügung
    var patientenverfuegungVorhanden: Bool
    var patientenverfuegungDateiName: String
    @Attribute(.externalStorage) var patientenverfuegungDateiData: Data?
    var patientenverfuegungHochgeladenAm: Date?
    var patientenverfuegungErinnerungAktiv: Bool
    var patientenverfuegungErinnerungAm: Date?

    // Vorsorgeauftrag
    var vorsorgeauftragVorhanden: Bool
    var vorsorgeauftragDateiName: String
    @Attribute(.externalStorage) var vorsorgeauftragDateiData: Data?
    var vorsorgeauftragHochgeladenAm: Date?
    var vorsorgeauftragErinnerungAktiv: Bool
    var vorsorgeauftragErinnerungAm: Date?

    // Sterbebegleitung
    var sterbebegleitungGewuenscht: Bool
    var sterbebegleitungDateiName: String
    @Attribute(.externalStorage) var sterbebegleitungDateiData: Data?
    var sterbebegleitungHochgeladenAm: Date?
    var sterbebegleitungErinnerungAktiv: Bool
    var sterbebegleitungErinnerungAm: Date?

    // Schwere Erkrankung / Lebensqualität
    var schwereErkrankungVorhanden: Bool
    var schwereErkrankungArt: String
    var mirIstWichtig: String
    var regelmaessigBeurteilen: Bool

    // Haustiere
    var hatHaustiere: Bool = false
    @Attribute(.externalStorage) var haustiereData: Data? = nil

    init(
        dossierID: UUID? = nil,
        hatWuensche: Bool = true,
        ausgewaehlteThemenData: Data? = nil,
        beisetzungsArt: String = "",
        beisetzungHinweis: String = "",
        sonstigeBemerkungen: String = "",
        keineBlumengeschenkeBitte: Bool = false,
        besondereMusik: Bool = false,
        musikWunsch: String = "",
        zeremonieGewuenscht: Bool = false,
        zeremonieDetails: String = "",
        zeremonieOrganisiert: Bool = false,
        zeremonieFinanziellAbgesichert: Bool = false,
        moechteNochEtwasSagen: Bool = false,
        letzteBotschaft: String = "",
        letzteBotschaftVideoName: String = "",
        letzteBotschaftVideoData: Data? = nil,
        nachrufGewuenscht: Bool = false,
        nachrufText: String = "",
        nachrufBildDateiName: String = "",
        nachrufBildData: Data? = nil,
        testamentVorhanden: Bool = false,
        testamentAblageort: String = "",
        testamentDateiName: String = "",
        testamentDateiData: Data? = nil,
        testamentHochgeladenAm: Date? = nil,
        testamentErinnerungAktiv: Bool = true,
        testamentErinnerungAm: Date? = nil,
        patientenverfuegungVorhanden: Bool = false,
        patientenverfuegungDateiName: String = "",
        patientenverfuegungDateiData: Data? = nil,
        patientenverfuegungHochgeladenAm: Date? = nil,
        patientenverfuegungErinnerungAktiv: Bool = true,
        patientenverfuegungErinnerungAm: Date? = nil,
        vorsorgeauftragVorhanden: Bool = false,
        vorsorgeauftragDateiName: String = "",
        vorsorgeauftragDateiData: Data? = nil,
        vorsorgeauftragHochgeladenAm: Date? = nil,
        vorsorgeauftragErinnerungAktiv: Bool = true,
        vorsorgeauftragErinnerungAm: Date? = nil,
        sterbebegleitungGewuenscht: Bool = false,
        sterbebegleitungDateiName: String = "",
        sterbebegleitungDateiData: Data? = nil,
        sterbebegleitungHochgeladenAm: Date? = nil,
        sterbebegleitungErinnerungAktiv: Bool = true,
        sterbebegleitungErinnerungAm: Date? = nil,
        schwereErkrankungVorhanden: Bool = false,
        schwereErkrankungArt: String = "",
        mirIstWichtig: String = "",
        regelmaessigBeurteilen: Bool = true,
        hatHaustiere: Bool = false,
        haustiereData: Data? = nil
    ) {
        self.dossierID = dossierID
        self.hatWuensche = hatWuensche
        self.ausgewaehlteThemenData = ausgewaehlteThemenData
        self.beisetzungsArt = beisetzungsArt
        self.beisetzungHinweis = beisetzungHinweis
        self.sonstigeBemerkungen = sonstigeBemerkungen
        self.keineBlumengeschenkeBitte = keineBlumengeschenkeBitte
        self.besondereMusik = besondereMusik
        self.musikWunsch = musikWunsch
        self.zeremonieGewuenscht = zeremonieGewuenscht
        self.zeremonieDetails = zeremonieDetails
        self.zeremonieOrganisiert = zeremonieOrganisiert
        self.zeremonieFinanziellAbgesichert = zeremonieFinanziellAbgesichert
        self.moechteNochEtwasSagen = moechteNochEtwasSagen
        self.letzteBotschaft = letzteBotschaft
        self.letzteBotschaftVideoName = letzteBotschaftVideoName
        self.letzteBotschaftVideoData = letzteBotschaftVideoData
        self.nachrufGewuenscht = nachrufGewuenscht
        self.nachrufText = nachrufText
        self.nachrufBildDateiName = nachrufBildDateiName
        self.nachrufBildData = nachrufBildData
        self.testamentVorhanden = testamentVorhanden
        self.testamentAblageort = testamentAblageort
        self.testamentDateiName = testamentDateiName
        self.testamentDateiData = testamentDateiData
        self.testamentHochgeladenAm = testamentHochgeladenAm
        self.testamentErinnerungAktiv = testamentErinnerungAktiv
        self.testamentErinnerungAm = testamentErinnerungAm
        self.patientenverfuegungVorhanden = patientenverfuegungVorhanden
        self.patientenverfuegungDateiName = patientenverfuegungDateiName
        self.patientenverfuegungDateiData = patientenverfuegungDateiData
        self.patientenverfuegungHochgeladenAm = patientenverfuegungHochgeladenAm
        self.patientenverfuegungErinnerungAktiv = patientenverfuegungErinnerungAktiv
        self.patientenverfuegungErinnerungAm = patientenverfuegungErinnerungAm
        self.vorsorgeauftragVorhanden = vorsorgeauftragVorhanden
        self.vorsorgeauftragDateiName = vorsorgeauftragDateiName
        self.vorsorgeauftragDateiData = vorsorgeauftragDateiData
        self.vorsorgeauftragHochgeladenAm = vorsorgeauftragHochgeladenAm
        self.vorsorgeauftragErinnerungAktiv = vorsorgeauftragErinnerungAktiv
        self.vorsorgeauftragErinnerungAm = vorsorgeauftragErinnerungAm
        self.sterbebegleitungGewuenscht = sterbebegleitungGewuenscht
        self.sterbebegleitungDateiName = sterbebegleitungDateiName
        self.sterbebegleitungDateiData = sterbebegleitungDateiData
        self.sterbebegleitungHochgeladenAm = sterbebegleitungHochgeladenAm
        self.sterbebegleitungErinnerungAktiv = sterbebegleitungErinnerungAktiv
        self.sterbebegleitungErinnerungAm = sterbebegleitungErinnerungAm
        self.schwereErkrankungVorhanden = schwereErkrankungVorhanden
        self.schwereErkrankungArt = schwereErkrankungArt
        self.mirIstWichtig = mirIstWichtig
        self.regelmaessigBeurteilen = regelmaessigBeurteilen
        self.hatHaustiere = hatHaustiere
        self.haustiereData = haustiereData
    }
}
