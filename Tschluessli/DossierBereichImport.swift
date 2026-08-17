import Foundation
import SwiftData

@MainActor
enum DossierBereichImport {
    static func importiere(
        _ daten: Data,
        bereich: String,
        dossierID: UUID,
        in context: ModelContext
    ) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        switch bereich {
        case "profil":
            try importiereProfil(decoder.decode(CloudDatenListe<CloudProfilDaten>.self, from: daten), dossierID, context)
        case "gesundheit":
            try importiereGesundheit(decoder.decode(CloudDatenListe<CloudGesundheitDaten>.self, from: daten), dossierID, context)
        case "wuensche":
            try importiereWuensche(decoder.decode(CloudDatenListe<CloudWuenscheDaten>.self, from: daten), dossierID, context)
        case "finanzen":
            try importiereFinanzen(decoder.decode(CloudFinanzenDaten.self, from: daten), dossierID, context)
        case "kontakte":
            try importiereKontakte(decoder.decode(CloudKontaktDaten.self, from: daten), dossierID, context)
        case "herzensstuecke":
            try importiereHerzensstuecke(decoder.decode(CloudDatenListe<CloudHerzensstueckDaten>.self, from: daten), dossierID, context)
        case "zugaenge":
            let verschluesselt = try decoder.decode(VerschluesselterCloudBereich.self, from: daten)
            let klartext = try await CloudFeldVerschluesselung.shared.entschluesseln(
                verschluesselt,
                als: CloudZugangsDaten.self
            )
            try importiereZugaenge(klartext, dossierID, context)
        default:
            throw DossierBereichAdapterFehler.unbekannterBereich(bereich)
        }
    }

    static func loesche(
        bereich: String,
        dossierID: UUID,
        in context: ModelContext
    ) throws {
        switch bereich {
        case "profil": try loesche(ProfilModell.self, dossierID, context) { $0.dossierID }
        case "gesundheit": try loesche(GesundheitModell.self, dossierID, context) { $0.dossierID }
        case "wuensche": try loesche(WuenscheModell.self, dossierID, context) { $0.dossierID }
        case "finanzen":
            try loescheFinanzen(dossierID, context)
        case "kontakte":
            try loesche(HinterbliebeneModell.self, dossierID, context) { $0.dossierID }
            try loesche(VertrauenspersonModell.self, dossierID, context) { $0.dossierID }
        case "herzensstuecke": try loesche(HerzensstueckModell.self, dossierID, context) { $0.dossierID }
        case "zugaenge":
            try loesche(AboModell.self, dossierID, context) { $0.dossierID }
            try loesche(DigitalekontenModell.self, dossierID, context) { $0.dossierID }
        default: throw DossierBereichAdapterFehler.unbekannterBereich(bereich)
        }
    }

    private static func importiereProfil(
        _ cloud: CloudDatenListe<CloudProfilDaten>, _ dossierID: UUID, _ context: ModelContext
    ) throws {
        let bestehend = try context.fetch(FetchDescriptor<ProfilModell>()).filter { $0.dossierID == dossierID }
        let ids = Set(cloud.items.map(\.userID))
        for modell in bestehend where !ids.contains(modell.userID) { context.delete(modell) }
        for wert in cloud.items {
            let modell = bestehend.first { $0.userID == wert.userID } ?? ProfilModell(userID: wert.userID, dossierID: dossierID)
            if modell.modelContext == nil { context.insert(modell) }
            modell.dossierID = dossierID; modell.istVertrauensperson = wert.istVertrauensperson
            modell.vorname = wert.vorname; modell.name = wert.name; modell.geburtsdatum = wert.geburtsdatum
            modell.strasse = wert.strasse; modell.hausnummer = wert.hausnummer; modell.plz = wert.plz
            modell.stadt = wert.stadt; modell.land = wert.land; modell.telefon = wert.telefon
            modell.ahvNummer = wert.ahvNummer; modell.email = wert.email; modell.notfallHinweis = wert.notfallHinweis
            modell.registrierungsart = wert.registrierungsart; modell.registrierungsEmail = wert.registrierungsEmail
            modell.biometrieAktiviert = wert.biometrieAktiviert; modell.erstelltAm = wert.erstelltAm
            modell.aktualisiertAm = wert.aktualisiertAm; modell.istAktiv = wert.istAktiv
        }
    }

    private static func importiereGesundheit(
        _ cloud: CloudDatenListe<CloudGesundheitDaten>, _ dossierID: UUID, _ context: ModelContext
    ) throws {
        try loesche(GesundheitModell.self, dossierID, context) { $0.dossierID }
        for w in cloud.items {
            context.insert(GesundheitModell(
                gesundheitID: w.gesundheitID, userID: w.userID, dossierID: dossierID,
                hatHausarzt: w.hatHausarzt, hausarztKontaktID: w.hausarztKontaktID,
                hausarztName: w.hausarztName, hausarztTelefon: w.hausarztTelefon,
                hausarztEmail: w.hausarztEmail, hausarztAdresse: w.hausarztAdresse,
                hausarztPLZ: w.hausarztPLZ, hausarztOrt: w.hausarztOrt,
                blutgruppe: w.blutgruppe, organspende: w.organspende,
                hatAllergien: w.hatAllergien, allergien: w.allergien,
                nimmtMedikamente: w.nimmtMedikamente, medikamente: w.medikamente,
                gesundheitlicheHinweise: w.gesundheitlicheHinweise,
                erstelltAm: w.erstelltAm, geaendertAm: w.geaendertAm
            ))
        }
    }

    private static func importiereWuensche(
        _ cloud: CloudDatenListe<CloudWuenscheDaten>, _ dossierID: UUID, _ context: ModelContext
    ) throws {
        let bestehend = try context.fetch(FetchDescriptor<WuenscheModell>()).first { $0.dossierID == dossierID }
        let alle = try context.fetch(FetchDescriptor<WuenscheModell>()).filter { $0.dossierID == dossierID }
        for modell in alle.dropFirst() { context.delete(modell) }
        guard let w = cloud.items.first else {
            if let bestehend { context.delete(bestehend) }
            return
        }
        let m = bestehend ?? WuenscheModell(dossierID: dossierID)
        if m.modelContext == nil { context.insert(m) }
        m.dossierID = dossierID; m.hatWuensche = w.hatWuensche
        m.ausgewaehlteThemenData = w.ausgewaehlteThemen.flatMap { Data(base64Encoded: $0) }
        m.beisetzungsRahmen = w.beisetzungsRahmen; m.beisetzungsArt = w.beisetzungsArt
        m.beisetzungHinweis = w.beisetzungHinweis; m.sonstigeBemerkungen = w.sonstigeBemerkungen
        m.keineBlumengeschenkeBitte = w.keineBlumengeschenkeBitte; m.besondereMusik = w.besondereMusik
        m.musikWunsch = w.musikWunsch; m.zeremonieGewuenscht = w.zeremonieGewuenscht
        m.zeremonieDetails = w.zeremonieDetails; m.zeremonieOrganisiert = w.zeremonieOrganisiert
        m.zeremonieFinanziellAbgesichert = w.zeremonieFinanziellAbgesichert
        m.moechteNochEtwasSagen = w.moechteNochEtwasSagen; m.letzteBotschaft = w.letzteBotschaft
        m.letzteBotschaftVideoName = w.letzteBotschaftVideoName; m.nachrufGewuenscht = w.nachrufGewuenscht
        m.nachrufText = w.nachrufText; m.nachrufBildDateiName = w.nachrufBildDateiName
        m.testamentVorhanden = w.testamentVorhanden; m.testamentAblageort = w.testamentAblageort
        m.testamentDateiName = w.testamentDateiName; m.testamentHochgeladenAm = w.testamentHochgeladenAm
        m.testamentErinnerungAktiv = w.testamentErinnerungAktiv; m.testamentErinnerungAm = w.testamentErinnerungAm
        m.patientenverfuegungVorhanden = w.patientenverfuegungVorhanden
        m.patientenverfuegungDateiName = w.patientenverfuegungDateiName
        m.patientenverfuegungHochgeladenAm = w.patientenverfuegungHochgeladenAm
        m.patientenverfuegungErinnerungAktiv = w.patientenverfuegungErinnerungAktiv
        m.patientenverfuegungErinnerungAm = w.patientenverfuegungErinnerungAm
        m.vorsorgeauftragVorhanden = w.vorsorgeauftragVorhanden; m.vorsorgeauftragDateiName = w.vorsorgeauftragDateiName
        m.vorsorgeauftragHochgeladenAm = w.vorsorgeauftragHochgeladenAm
        m.vorsorgeauftragErinnerungAktiv = w.vorsorgeauftragErinnerungAktiv; m.vorsorgeauftragErinnerungAm = w.vorsorgeauftragErinnerungAm
        m.sterbebegleitungGewuenscht = w.sterbebegleitungGewuenscht; m.sterbebegleitungDateiName = w.sterbebegleitungDateiName
        m.sterbebegleitungHochgeladenAm = w.sterbebegleitungHochgeladenAm
        m.sterbebegleitungErinnerungAktiv = w.sterbebegleitungErinnerungAktiv; m.sterbebegleitungErinnerungAm = w.sterbebegleitungErinnerungAm
        m.schwereErkrankungVorhanden = w.schwereErkrankungVorhanden; m.schwereErkrankungArt = w.schwereErkrankungArt
        m.mirIstWichtig = w.mirIstWichtig; m.regelmaessigBeurteilen = w.regelmaessigBeurteilen
        m.hatHaustiere = w.hatHaustiere; m.haustiereData = w.haustiere.flatMap { Data(base64Encoded: $0) }
    }

    private static func importiereFinanzen(_ c: CloudFinanzenDaten, _ id: UUID, _ context: ModelContext) throws {
        let alteBankkonten = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<BankkontoModell>()).filter { $0.dossierID == id }.map { ($0.eintragsID, $0.dokumentPfad) })
        let alteSchulden = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SchuldenModell>()).filter { $0.dossierID == id }.map { ($0.eintragsID, $0.dokumentPfad) })
        let alteVersicherungen = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<VersicherungModell>()).filter { $0.dossierID == id }.map { ($0.eintragsID, $0.dokumentPfad) })
        let alteLiegenschaften = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<LiegenschaftModell>()).filter { $0.dossierID == id }.map { ($0.eintragsID, $0.dokumentPfad) })
        let alteWertsachen = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WertsacheModell>()).filter { $0.dossierID == id }.map { ($0.eintragsID, $0.dokumentPfad) })
        let alteSteuern = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SteuerdokumentModell>()).filter { $0.dossierID == id }.map { ($0.eintragsID, ($0.dateiDaten, $0.dokumentPfad)) })
        try loescheFinanzen(id, context)
        for w in c.bankkonten { context.insert(BankkontoModell(eintragsID:w.id,dossierID:id,bankname:w.bankname,bankAdresse:w.bankAdresse,iban:w.iban,kontoArt:w.kontoArt,berater:w.berater,vermoegenswert:w.vermoegenswert,waehrung:w.waehrung,dokumentDateiName:w.dokumentDateiName,dokumentPfad:alteBankkonten[w.id] ?? "",erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm)) }
        for w in c.schulden { context.insert(SchuldenModell(eintragsID:w.id,dossierID:id,art:w.art,betrag:w.betrag,waehrung:w.waehrung,glaeubiger:w.glaeubiger,bemerkungen:w.bemerkungen,dokumentDateiName:w.dokumentDateiName,dokumentPfad:alteSchulden[w.id] ?? "",erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm)) }
        for w in c.versicherungen { context.insert(VersicherungModell(eintragsID:w.id,dossierID:id,art:w.art,anbieter:w.anbieter,policenNummer:w.policenNummer,praemie:w.praemie,waehrung:w.waehrung,bemerkungen:w.bemerkungen,dokumentDateiName:w.dokumentDateiName,dokumentPfad:alteVersicherungen[w.id] ?? "",erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm)) }
        for w in c.liegenschaften { context.insert(LiegenschaftModell(eintragsID:w.id,dossierID:id,art:w.art,adresse:w.adresse,plz:w.plz,stadt:w.stadt,land:w.land,verkehrswert:w.verkehrswert,eigenmietwert:w.eigenmietwert,eigenmietwertWaehrung:w.eigenmietwertWaehrung,waehrung:w.waehrung,bemerkungen:w.bemerkungen,dokumentDateiName:w.dokumentDateiName,dokumentPfad:alteLiegenschaften[w.id] ?? "",erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm)) }
        for w in c.wertsachen { context.insert(WertsacheModell(eintragsID:w.id,dossierID:id,art:w.art,beschreibung:w.beschreibung,betrag:w.betrag,waehrung:w.waehrung,aufbewahrungsort:w.aufbewahrungsort,bemerkungen:w.bemerkungen,dokumentDateiName:w.dokumentDateiName,dokumentPfad:alteWertsachen[w.id] ?? "",erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm)) }
        for w in c.steuerdokumente { context.insert(SteuerdokumentModell(eintragsID:w.id,dossierID:id,titel:w.titel,jahr:w.jahr,dateiName:w.dateiName,dateiDaten:alteSteuern[w.id]?.0,dokumentPfad:alteSteuern[w.id]?.1 ?? "",hochgeladenAm:w.hochgeladenAm,bemerkungen:w.bemerkungen)) }
    }

    private static func importiereKontakte(_ c: CloudKontaktDaten, _ id: UUID, _ context: ModelContext) throws {
        let alteVertrauenspersonen = try context.fetch(FetchDescriptor<VertrauenspersonModell>()).filter { $0.dossierID == id }
        try loesche(HinterbliebeneModell.self, id, context) { $0.dossierID }
        try loesche(VertrauenspersonModell.self, id, context) { $0.dossierID }
        for w in c.hinterbliebene { context.insert(HinterbliebeneModell(dossierID:id,vorname:w.vorname,name:w.name,rolle:w.rolle,beziehung:w.beziehung,telefon:w.telefon,email:w.email,adresse:w.adresse,plz:w.plz,stadt:w.stadt,land:w.land,bemerkungen:w.bemerkungen,quelle:w.quelle,istVertrauensperson:w.istVertrauensperson,sollInformiertWerden:w.sollInformiertWerden,darfDokumenteErhalten:w.darfDokumenteErhalten,wirdInWuenschenBeruecksichtigt:w.wirdInWuenschenBeruecksichtigt ?? false,erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm)) }
        for w in c.vertrauenspersonen {
            let historie = w.historie.map { VertrauenspersonEinladungsHistorieModell(datum:$0.datum,beschreibung:$0.beschreibung) }
            let alt = alteVertrauenspersonen.first { $0.personenID == w.personenID || (!$0.email.isEmpty && $0.email.caseInsensitiveCompare(w.email) == .orderedSame) }
            context.insert(VertrauenspersonModell(personenID:w.personenID,vorname:w.vorname,name:w.name,email:w.email,telefon:w.telefon,beziehung:w.beziehung,einladungsStatus:w.einladungsStatus,vorsorgeprozessStatus:w.vorsorgeprozessStatus,einladungsToken:alt?.einladungsToken,einladungsEmail:w.einladungsEmail,einladungsLinkErstelltAm:w.einladungsLinkErstelltAm,dossierID:id,vorsorgendeUserID:w.vorsorgendeUserID,vertrauenspersonUserID:w.vertrauenspersonUserID,einladungAngenommenAm:w.einladungAngenommenAm,einladungAbgelehntAm:w.einladungAbgelehntAm,istPrimaereVertrauensperson:w.istPrimaereVertrauensperson,reihenfolge:w.reihenfolge,einladungsHistorie:historie,erstelltAm:w.erstelltAm,geaendertAm:w.geaendertAm))
        }
    }

    private static func importiereHerzensstuecke(_ c: CloudDatenListe<CloudHerzensstueckDaten>, _ id: UUID, _ context: ModelContext) throws {
        let bestehend = try context.fetch(FetchDescriptor<HerzensstueckModell>()).filter { $0.dossierID == id }
        let cloudIDs = Set(c.items.map(\.id))
        for m in bestehend where !cloudIDs.contains(m.id) { context.delete(m) }
        for w in c.items {
            let m = bestehend.first { $0.id == w.id } ?? HerzensstueckModell(id:w.id,dossierID:id)
            if m.modelContext == nil { context.insert(m) }
            m.titel=w.titel; m.beschreibung=w.beschreibung; m.geschichte=w.geschichte; m.erinnerung=w.erinnerung
            m.bestimmungRawValue=w.bestimmung; m.empfaengerName=w.empfaengerName; m.empfaengerEmail=w.empfaengerEmail
            m.persoenlicheNachricht=w.persoenlicheNachricht; m.hatGeschaetztenWert=w.hatGeschaetztenWert
            m.geschaetzterWert=w.geschaetzterWert; m.wertUnbekannt=w.wertUnbekannt; m.andereBestimmung=w.andereBestimmung
            m.erstelltAm=w.erstelltAm; m.aktualisiertAm=w.aktualisiertAm
        }
    }

    private static func importiereZugaenge(_ c: CloudZugangsDaten, _ id: UUID, _ context: ModelContext) throws {
        try loesche(AboModell.self, id, context) { $0.dossierID }
        try loesche(DigitalekontenModell.self, id, context) { $0.dossierID }
        for w in c.abos { context.insert(AboModell(id:w.id,dossierID:id,erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm,abos:w.eintraege.map { aboEintrag($0, id) })) }
        for w in c.digitaleKonten { context.insert(DigitalekontenModell(id:w.id,dossierID:id,erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm,konten:w.eintraege.map { aboEintrag($0, id) })) }
    }

    private static func aboEintrag(_ w: CloudAboDaten.Eintrag, _ id: UUID) -> AboEintrag {
        AboEintrag(id:w.id,dossierID:id,erstelltAm:w.erstelltAm,aktualisiertAm:w.aktualisiertAm,aboTyp:w.aboTyp,anbieter:w.anbieter,unternehmen:w.unternehmen,bezeichnung:w.bezeichnung,aboArt:w.aboArt,aboNummer:w.aboNummer,benutzername:w.benutzername,passwort:w.passwort,streamingAnbieter:w.streamingAnbieter,socialMediaPlattform:w.socialMediaPlattform,digitaleIdentitaetAnbieter:w.digitaleIdentitaetAnbieter,emailAnbieter:w.emailAnbieter,geraeteArt:w.geraeteArt,geraeteBezeichnung:w.geraeteBezeichnung,geraetePIN:w.geraetePIN,oevUnternehmen:w.oevUnternehmen,oevAboTyp:w.oevAboTyp,andereBezeichnung:w.andereBezeichnung,bankkontoName:w.bankkontoName,bankkontoArt:w.bankkontoArt,mobileInternetAnbieter:w.mobileInternetAnbieter,mobileInternetVertragsdetails:w.mobileInternetVertragsdetails,notizen:w.notizen,istAktiv:w.istAktiv,istSystemEintrag:w.istSystemEintrag)
    }

    private static func loescheFinanzen(_ id: UUID, _ context: ModelContext) throws {
        try loesche(BankkontoModell.self,id,context){$0.dossierID}; try loesche(SchuldenModell.self,id,context){$0.dossierID}
        try loesche(VersicherungModell.self,id,context){$0.dossierID}; try loesche(LiegenschaftModell.self,id,context){$0.dossierID}
        try loesche(WertsacheModell.self,id,context){$0.dossierID}; try loesche(SteuerdokumentModell.self,id,context){$0.dossierID}
    }

    private static func loesche<T: PersistentModel>(
        _ typ: T.Type, _ dossierID: UUID, _ context: ModelContext, dossier: (T) -> UUID?
    ) throws {
        for modell in try context.fetch(FetchDescriptor<T>()) where dossier(modell) == dossierID {
            context.delete(modell)
        }
    }
}
