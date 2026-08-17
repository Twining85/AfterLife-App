import Foundation

nonisolated struct CloudDatenListe<Element: Codable & Sendable>: Codable, Sendable {
    let items: [Element]
}

nonisolated struct CloudProfilDaten: Codable, Sendable {
    let userID: UUID
    let dossierID: UUID?
    let istVertrauensperson: Bool
    let vorname: String
    let name: String
    let geburtsdatum: Date
    let strasse: String
    let hausnummer: String
    let plz: String
    let stadt: String
    let land: String
    let telefon: String
    let ahvNummer: String
    let email: String
    let notfallHinweis: String
    let registrierungsart: String
    let registrierungsEmail: String
    let biometrieAktiviert: Bool
    let profilbild: String?
    let erstelltAm: Date
    let aktualisiertAm: Date
    let istAktiv: Bool
    let homeBereicheReihenfolge: String?
    let homeAktiveBereiche: String?

    init(_ modell: ProfilModell, homeBereicheReihenfolge: String, homeAktiveBereiche: String) {
        userID = modell.userID
        dossierID = modell.dossierID
        istVertrauensperson = modell.istVertrauensperson
        vorname = modell.vorname
        name = modell.name
        geburtsdatum = modell.geburtsdatum
        strasse = modell.strasse
        hausnummer = modell.hausnummer
        plz = modell.plz
        stadt = modell.stadt
        land = modell.land
        telefon = modell.telefon
        ahvNummer = modell.ahvNummer
        email = modell.email
        notfallHinweis = modell.notfallHinweis
        registrierungsart = modell.registrierungsart
        registrierungsEmail = modell.registrierungsEmail
        biometrieAktiviert = modell.biometrieAktiviert
        profilbild = modell.profilbildDaten?.base64EncodedString()
        erstelltAm = modell.erstelltAm
        aktualisiertAm = modell.aktualisiertAm
        istAktiv = modell.istAktiv
        self.homeBereicheReihenfolge = homeBereicheReihenfolge
        self.homeAktiveBereiche = homeAktiveBereiche
    }
}

nonisolated struct CloudGesundheitDaten: Codable, Sendable {
    let gesundheitID: UUID?
    let userID: UUID?
    let dossierID: UUID?
    let hatHausarzt: Bool
    let hausarztKontaktID: UUID?
    let hausarztName: String
    let hausarztTelefon: String
    let hausarztEmail: String
    let hausarztAdresse: String
    let hausarztPLZ: String
    let hausarztOrt: String
    let blutgruppe: String
    let organspende: String
    let hatAllergien: Bool
    let allergien: String
    let nimmtMedikamente: Bool
    let medikamente: String
    let gesundheitlicheHinweise: String
    let erstelltAm: Date
    let geaendertAm: Date

    init(_ modell: GesundheitModell) {
        gesundheitID = modell.gesundheitID
        userID = modell.userID
        dossierID = modell.dossierID
        hatHausarzt = modell.hatHausarzt
        hausarztKontaktID = modell.hausarztKontaktID
        hausarztName = modell.hausarztName
        hausarztTelefon = modell.hausarztTelefon
        hausarztEmail = modell.hausarztEmail
        hausarztAdresse = modell.hausarztAdresse
        hausarztPLZ = modell.hausarztPLZ
        hausarztOrt = modell.hausarztOrt
        blutgruppe = modell.blutgruppe
        organspende = modell.organspende
        hatAllergien = modell.hatAllergien
        allergien = modell.allergien
        nimmtMedikamente = modell.nimmtMedikamente
        medikamente = modell.medikamente
        gesundheitlicheHinweise = modell.gesundheitlicheHinweise
        erstelltAm = modell.erstelltAm
        geaendertAm = modell.geaendertAm
    }
}

nonisolated struct CloudWuenscheDaten: Codable, Sendable {
    let dossierID: UUID?
    let hatWuensche: Bool
    let ausgewaehlteThemen: String?
    let beisetzungsRahmen: String
    let beisetzungsArt: String
    let beisetzungHinweis: String
    let bestattungswuensche: String?
    let kremationHinweise: String?
    let erdbestattungHinweise: String?
    let sonstigeBemerkungen: String
    let keineBlumengeschenkeBitte: Bool
    let besondereMusik: Bool
    let musikWunsch: String
    let zeremonieGewuenscht: Bool
    let zeremonieDetails: String
    let zeremonieOrganisiert: Bool
    let zeremonieOrganisiertDetails: String?
    let zeremonieFinanziellAbgesichert: Bool
    let moechteNochEtwasSagen: Bool
    let letzteBotschaft: String
    let letzteBotschaftVideoName: String
    let nachrufGewuenscht: Bool
    let nachrufText: String
    let nachrufBildDateiName: String
    let testamentVorhanden: Bool
    let testamentAblageort: String
    let testamentDateiName: String
    let testamentHochgeladenAm: Date?
    let testamentErinnerungAktiv: Bool
    let testamentErinnerungAm: Date?
    let patientenverfuegungVorhanden: Bool
    let patientenverfuegungDateiName: String
    let patientenverfuegungHochgeladenAm: Date?
    let patientenverfuegungErinnerungAktiv: Bool
    let patientenverfuegungErinnerungAm: Date?
    let vorsorgeauftragVorhanden: Bool
    let vorsorgeauftragDateiName: String
    let vorsorgeauftragHochgeladenAm: Date?
    let vorsorgeauftragErinnerungAktiv: Bool
    let vorsorgeauftragErinnerungAm: Date?
    let sterbebegleitungGewuenscht: Bool
    let sterbebegleitungDateiName: String
    let sterbebegleitungHochgeladenAm: Date?
    let sterbebegleitungErinnerungAktiv: Bool
    let sterbebegleitungErinnerungAm: Date?
    let schwereErkrankungVorhanden: Bool
    let schwereErkrankungArt: String
    let mirIstWichtig: String
    let regelmaessigBeurteilen: Bool
    let hatHaustiere: Bool
    let haustiere: String?

    init(_ modell: WuenscheModell) {
        dossierID = modell.dossierID
        hatWuensche = modell.hatWuensche
        ausgewaehlteThemen = modell.ausgewaehlteThemenData?.base64EncodedString()
        beisetzungsRahmen = modell.beisetzungsRahmen
        beisetzungsArt = modell.beisetzungsArt
        beisetzungHinweis = modell.beisetzungHinweis
        bestattungswuensche = modell.bestattungswuensche
        kremationHinweise = modell.kremationHinweise
        erdbestattungHinweise = modell.erdbestattungHinweise
        sonstigeBemerkungen = modell.sonstigeBemerkungen
        keineBlumengeschenkeBitte = modell.keineBlumengeschenkeBitte
        besondereMusik = modell.besondereMusik
        musikWunsch = modell.musikWunsch
        zeremonieGewuenscht = modell.zeremonieGewuenscht
        zeremonieDetails = modell.zeremonieDetails
        zeremonieOrganisiert = modell.zeremonieOrganisiert
        zeremonieOrganisiertDetails = modell.zeremonieOrganisiertDetails
        zeremonieFinanziellAbgesichert = modell.zeremonieFinanziellAbgesichert
        moechteNochEtwasSagen = modell.moechteNochEtwasSagen
        letzteBotschaft = modell.letzteBotschaft
        letzteBotschaftVideoName = modell.letzteBotschaftVideoName
        nachrufGewuenscht = modell.nachrufGewuenscht
        nachrufText = modell.nachrufText
        nachrufBildDateiName = modell.nachrufBildDateiName
        testamentVorhanden = modell.testamentVorhanden
        testamentAblageort = modell.testamentAblageort
        testamentDateiName = modell.testamentDateiName
        testamentHochgeladenAm = modell.testamentHochgeladenAm
        testamentErinnerungAktiv = modell.testamentErinnerungAktiv
        testamentErinnerungAm = modell.testamentErinnerungAm
        patientenverfuegungVorhanden = modell.patientenverfuegungVorhanden
        patientenverfuegungDateiName = modell.patientenverfuegungDateiName
        patientenverfuegungHochgeladenAm = modell.patientenverfuegungHochgeladenAm
        patientenverfuegungErinnerungAktiv = modell.patientenverfuegungErinnerungAktiv
        patientenverfuegungErinnerungAm = modell.patientenverfuegungErinnerungAm
        vorsorgeauftragVorhanden = modell.vorsorgeauftragVorhanden
        vorsorgeauftragDateiName = modell.vorsorgeauftragDateiName
        vorsorgeauftragHochgeladenAm = modell.vorsorgeauftragHochgeladenAm
        vorsorgeauftragErinnerungAktiv = modell.vorsorgeauftragErinnerungAktiv
        vorsorgeauftragErinnerungAm = modell.vorsorgeauftragErinnerungAm
        sterbebegleitungGewuenscht = modell.sterbebegleitungGewuenscht
        sterbebegleitungDateiName = modell.sterbebegleitungDateiName
        sterbebegleitungHochgeladenAm = modell.sterbebegleitungHochgeladenAm
        sterbebegleitungErinnerungAktiv = modell.sterbebegleitungErinnerungAktiv
        sterbebegleitungErinnerungAm = modell.sterbebegleitungErinnerungAm
        schwereErkrankungVorhanden = modell.schwereErkrankungVorhanden
        schwereErkrankungArt = modell.schwereErkrankungArt
        mirIstWichtig = modell.mirIstWichtig
        regelmaessigBeurteilen = modell.regelmaessigBeurteilen
        hatHaustiere = modell.hatHaustiere
        haustiere = modell.haustiereData?.base64EncodedString()
    }
}
