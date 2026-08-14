import CryptoKit
import Foundation

nonisolated struct CloudFinanzenDaten: Codable, Sendable {
    let bankkonten: [Bankkonto]
    let schulden: [Schuld]
    let versicherungen: [Versicherung]
    let liegenschaften: [Liegenschaft]
    let wertsachen: [Wertsache]
    let steuerdokumente: [Steuerdokument]

    nonisolated struct Bankkonto: Codable, Sendable {
        let id: String; let bankname: String; let bankAdresse: String; let iban: String; let kontoArt: String
        let berater: String; let vermoegenswert: Double; let waehrung: String; let dokumentDateiName: String
        let erstelltAm: Date; let aktualisiertAm: Date
        init(_ m: BankkontoModell) { id=m.eintragsID; bankname=m.bankname; bankAdresse=m.bankAdresse; iban=m.iban; kontoArt=m.kontoArt; berater=m.berater; vermoegenswert=m.vermoegenswert; waehrung=m.waehrung; dokumentDateiName=m.dokumentDateiName; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    }
    nonisolated struct Schuld: Codable, Sendable {
        let id: String; let art: String; let betrag: Double; let waehrung: String; let glaeubiger: String
        let bemerkungen: String; let dokumentDateiName: String; let erstelltAm: Date; let aktualisiertAm: Date
        init(_ m: SchuldenModell) { id=m.eintragsID; art=m.art; betrag=m.betrag; waehrung=m.waehrung; glaeubiger=m.glaeubiger; bemerkungen=m.bemerkungen; dokumentDateiName=m.dokumentDateiName; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    }
    nonisolated struct Versicherung: Codable, Sendable {
        let id: String; let art: String; let anbieter: String; let policenNummer: String; let praemie: Double
        let waehrung: String; let bemerkungen: String; let dokumentDateiName: String; let erstelltAm: Date; let aktualisiertAm: Date
        init(_ m: VersicherungModell) { id=m.eintragsID; art=m.art; anbieter=m.anbieter; policenNummer=m.policenNummer; praemie=m.praemie; waehrung=m.waehrung; bemerkungen=m.bemerkungen; dokumentDateiName=m.dokumentDateiName; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    }
    nonisolated struct Liegenschaft: Codable, Sendable {
        let id: String; let art: String; let adresse: String; let plz: String; let stadt: String; let land: String
        let verkehrswert: Double; let eigenmietwert: Double; let eigenmietwertWaehrung: String; let waehrung: String
        let bemerkungen: String; let dokumentDateiName: String; let erstelltAm: Date; let aktualisiertAm: Date
        init(_ m: LiegenschaftModell) { id=m.eintragsID; art=m.art; adresse=m.adresse; plz=m.plz; stadt=m.stadt; land=m.land; verkehrswert=m.verkehrswert; eigenmietwert=m.eigenmietwert; eigenmietwertWaehrung=m.eigenmietwertWaehrung; waehrung=m.waehrung; bemerkungen=m.bemerkungen; dokumentDateiName=m.dokumentDateiName; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    }
    nonisolated struct Wertsache: Codable, Sendable {
        let id: String; let art: String; let beschreibung: String; let betrag: Double; let waehrung: String
        let aufbewahrungsort: String; let bemerkungen: String; let dokumentDateiName: String; let erstelltAm: Date; let aktualisiertAm: Date
        init(_ m: WertsacheModell) { id=m.eintragsID; art=m.art; beschreibung=m.beschreibung; betrag=m.betrag; waehrung=m.waehrung; aufbewahrungsort=m.aufbewahrungsort; bemerkungen=m.bemerkungen; dokumentDateiName=m.dokumentDateiName; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    }
    nonisolated struct Steuerdokument: Codable, Sendable {
        let id: String; let titel: String; let jahr: Int; let dateiName: String; let hochgeladenAm: Date; let bemerkungen: String
        init(_ m: SteuerdokumentModell) { id=m.eintragsID; titel=m.titel; jahr=m.jahr; dateiName=m.dateiName; hochgeladenAm=m.hochgeladenAm; bemerkungen=m.bemerkungen }
    }
}

nonisolated struct CloudKontaktDaten: Codable, Sendable {
    let hinterbliebene: [Hinterbliebene]
    let vertrauenspersonen: [Vertrauensperson]

    nonisolated struct Hinterbliebene: Codable, Sendable {
        let vorname: String; let name: String; let rolle: String; let beziehung: String; let telefon: String; let email: String
        let adresse: String; let plz: String; let stadt: String; let land: String; let bemerkungen: String; let quelle: String
        let istVertrauensperson: Bool; let sollInformiertWerden: Bool; let darfDokumenteErhalten: Bool
        let wirdInWuenschenBeruecksichtigt: Bool?; let erstelltAm: Date; let aktualisiertAm: Date
        init(_ m: HinterbliebeneModell) { vorname=m.vorname; name=m.name; rolle=m.rolle; beziehung=m.beziehung; telefon=m.telefon; email=m.email; adresse=m.adresse; plz=m.plz; stadt=m.stadt; land=m.land; bemerkungen=m.bemerkungen; quelle=m.quelle; istVertrauensperson=m.istVertrauensperson; sollInformiertWerden=m.sollInformiertWerden; darfDokumenteErhalten=m.darfDokumenteErhalten; wirdInWuenschenBeruecksichtigt=m.wirdInWuenschenBeruecksichtigt; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    }
    nonisolated struct Vertrauensperson: Codable, Sendable {
        let personenID: UUID?; let vorname: String; let name: String; let email: String; let telefon: String; let beziehung: String
        let einladungsStatus: String; let vorsorgeprozessStatus: String; let einladungsEmail: String?; let einladungsLinkErstelltAm: Date?
        let vorsorgendeUserID: UUID?; let vertrauenspersonUserID: UUID?; let einladungAngenommenAm: Date?; let einladungAbgelehntAm: Date?
        let istPrimaereVertrauensperson: Bool; let reihenfolge: Int; let historie: [Historie]; let erstelltAm: Date; let geaendertAm: Date
        init(_ m: VertrauenspersonModell) { personenID=m.personenID; vorname=m.vorname; name=m.name; email=m.email; telefon=m.telefon; beziehung=m.beziehung; einladungsStatus=m.einladungsStatus; vorsorgeprozessStatus=m.vorsorgeprozessStatus; einladungsEmail=m.einladungsEmail; einladungsLinkErstelltAm=m.einladungsLinkErstelltAm; vorsorgendeUserID=m.vorsorgendeUserID; vertrauenspersonUserID=m.vertrauenspersonUserID; einladungAngenommenAm=m.einladungAngenommenAm; einladungAbgelehntAm=m.einladungAbgelehntAm; istPrimaereVertrauensperson=m.istPrimaereVertrauensperson; reihenfolge=m.reihenfolge; historie=m.einladungsHistorie.map(Historie.init); erstelltAm=m.erstelltAm; geaendertAm=m.geaendertAm }
    }
    nonisolated struct Historie: Codable, Sendable { let datum: Date; let beschreibung: String; init(_ m: VertrauenspersonEinladungsHistorieModell) { datum=m.datum; beschreibung=m.beschreibung } }
}

nonisolated struct CloudHerzensstueckDaten: Codable, Sendable {
    let id: UUID; let titel: String; let beschreibung: String; let geschichte: String; let erinnerung: String
    let bestimmung: String; let empfaengerName: String; let empfaengerEmail: String; let persoenlicheNachricht: String
    let hatGeschaetztenWert: Bool; let geschaetzterWert: Double; let wertUnbekannt: Bool; let andereBestimmung: String
    let bilder: [Datei]; let dokumente: [Datei]; let audio: Datei?; let erstelltAm: Date; let aktualisiertAm: Date
    init(_ m: HerzensstueckModell) { id=m.id; titel=m.titel; beschreibung=m.beschreibung; geschichte=m.geschichte; erinnerung=m.erinnerung; bestimmung=m.bestimmungRawValue; empfaengerName=m.empfaengerName; empfaengerEmail=m.empfaengerEmail; persoenlicheNachricht=m.persoenlicheNachricht; hatGeschaetztenWert=m.hatGeschaetztenWert; geschaetzterWert=m.geschaetzterWert; wertUnbekannt=m.wertUnbekannt; andereBestimmung=m.andereBestimmung; bilder=m.bilder.map { Datei(id:$0.id,dateiName:$0.dateiName,dateiTyp:"image",datum:$0.hinzugefuegtAm) }; dokumente=m.dokumente.map { Datei(id:$0.id,dateiName:$0.dateiName,dateiTyp:$0.dateiTyp,datum:$0.hinzugefuegtAm) }; audio=m.audio.map { Datei(id:$0.id,dateiName:$0.dateiName,dateiTyp:$0.dateiTyp,datum:$0.hinzugefuegtAm) }; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm }
    nonisolated struct Datei: Codable, Sendable { let id: UUID; let dateiName: String; let dateiTyp: String; let datum: Date }
}

nonisolated struct CloudAboDaten: Codable, Sendable {
    let id: UUID; let erstelltAm: Date; let aktualisiertAm: Date; let eintraege: [Eintrag]
    init(_ m: AboModell) { id=m.id; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm; eintraege=m.abos.map(Eintrag.init) }
    nonisolated struct Eintrag: Codable, Sendable {
        let id: UUID; let erstelltAm: Date; let aktualisiertAm: Date; let aboTyp: String; let anbieter: String; let unternehmen: String
        let bezeichnung: String; let aboArt: String; let aboNummer: String; let benutzername: String; let passwort: String
        let streamingAnbieter: String; let socialMediaPlattform: String; let digitaleIdentitaetAnbieter: String; let emailAnbieter: String
        let geraeteArt: String; let geraeteBezeichnung: String; let geraetePIN: String; let oevUnternehmen: String; let oevAboTyp: String
        let andereBezeichnung: String; let bankkontoName: String; let bankkontoArt: String; let mobileInternetAnbieter: String
        let mobileInternetVertragsdetails: String; let notizen: String; let istAktiv: Bool; let istSystemEintrag: Bool
        init(_ m: AboEintrag) { id=m.id; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm; aboTyp=m.aboTyp; anbieter=m.anbieter; unternehmen=m.unternehmen; bezeichnung=m.bezeichnung; aboArt=m.aboArt; aboNummer=m.aboNummer; benutzername=m.benutzername; passwort=m.passwort; streamingAnbieter=m.streamingAnbieter; socialMediaPlattform=m.socialMediaPlattform; digitaleIdentitaetAnbieter=m.digitaleIdentitaetAnbieter; emailAnbieter=m.emailAnbieter; geraeteArt=m.geraeteArt; geraeteBezeichnung=m.geraeteBezeichnung; geraetePIN=m.geraetePIN; oevUnternehmen=m.oevUnternehmen; oevAboTyp=m.oevAboTyp; andereBezeichnung=m.andereBezeichnung; bankkontoName=m.bankkontoName; bankkontoArt=m.bankkontoArt; mobileInternetAnbieter=m.mobileInternetAnbieter; mobileInternetVertragsdetails=m.mobileInternetVertragsdetails; notizen=m.notizen; istAktiv=m.istAktiv; istSystemEintrag=m.istSystemEintrag }
    }
}

nonisolated struct CloudZugangsDaten: Codable, Sendable {
    let abos: [CloudAboDaten]
    let digitaleKonten: [DigitalesKonto]
    nonisolated struct DigitalesKonto: Codable, Sendable {
        let id: UUID; let erstelltAm: Date; let aktualisiertAm: Date; let eintraege: [CloudAboDaten.Eintrag]
        init(_ m: DigitalekontenModell) { id=m.id; erstelltAm=m.erstelltAm; aktualisiertAm=m.aktualisiertAm; eintraege=m.konten.map(CloudAboDaten.Eintrag.init) }
    }
}

nonisolated struct VerschluesselterCloudBereich: Codable, Sendable { let algorithmus: String; let schluesselVersion: Int; let daten: String }

actor CloudFeldVerschluesselung {
    static let shared = CloudFeldVerschluesselung()
    private let service = "Tschluessli.CloudEncryption"
    private let account = "dossier-key-v1"

    func verschluesseln<T: Encodable & Sendable>(_ wert: T) async throws -> VerschluesselterCloudBereich {
        let keyData = try await schluesselDaten()
        let data = try JSONEncoder().encode(wert)
        let sealed = try AES.GCM.seal(data, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else { throw CloudDossierSyncFehler.ungueltigeDaten }
        return VerschluesselterCloudBereich(algorithmus: "AES-256-GCM", schluesselVersion: 1, daten: combined.base64EncodedString())
    }

    private func schluesselDaten() async throws -> Data {
        try await MainActor.run {
            if let encoded = try? KeychainHelper.shared.read(service: service, account: account), let data = Data(base64Encoded: encoded) { return data }
            let data = Data(SymmetricKey(size: .bits256).withUnsafeBytes { Array($0) })
            try KeychainHelper.shared.save(data.base64EncodedString(), service: service, account: account)
            return data
        }
    }
}
