import Foundation

enum VorsorgeBereichID: String, CaseIterable, Codable, Sendable {
    case profil
    case gesundheit
    case wuensche
    case finanzen
    case hinterbliebene
    case dokumente
    case abos
    case herzensstuecke
}

struct VorsorgeBereichAktivitaet: Codable, Equatable, Sendable {
    var erstmalsBearbeitetAm: Date?
    var zuletztGeaendertAm: Date?
    var zuletztGeprueftAm: Date?

    var wurdeBegonnen: Bool {
        erstmalsBearbeitetAm != nil
    }

    var istAktuellGeprueft: Bool {
        guard let zuletztGeprueftAm else { return false }
        guard let zuletztGeaendertAm else { return true }
        return zuletztGeprueftAm >= zuletztGeaendertAm
    }

    var wurdeSeitPruefungGeaendert: Bool {
        guard let zuletztGeaendertAm, let zuletztGeprueftAm else { return false }
        return zuletztGeaendertAm > zuletztGeprueftAm
    }
}

enum VorsorgeBereichStatusStore {
    static let storageKey = "vorsorgeBereichStatusJSON"

    typealias DossierStatus = [String: VorsorgeBereichAktivitaet]
    private typealias AlleDossiers = [String: DossierStatus]

    static func status(
        fuer bereich: VorsorgeBereichID,
        dossierID: String? = nil
    ) -> VorsorgeBereichAktivitaet {
        let id = aufgeloesteDossierID(dossierID)
        return ladeAlle()[id]?[bereich.rawValue] ?? VorsorgeBereichAktivitaet()
    }

    static func statusFuerAktivesDossier() -> DossierStatus {
        ladeAlle()[aufgeloesteDossierID(nil)] ?? [:]
    }

    static func status(fuerDossierID dossierID: String) -> DossierStatus {
        ladeAlle()[aufgeloesteDossierID(dossierID)] ?? [:]
    }

    static func setzeStatus(_ status: DossierStatus, fuerDossierID dossierID: String) {
        let id = aufgeloesteDossierID(dossierID)
        var alle = ladeAlle()
        if status.isEmpty {
            alle.removeValue(forKey: id)
        } else {
            alle[id] = status
        }
        speichere(alle)
    }

    static func markiereBearbeitet(
        _ bereich: VorsorgeBereichID,
        dossierID: String? = nil,
        am datum: Date = Date()
    ) {
        let id = aufgeloesteDossierID(dossierID)
        var alle = ladeAlle()
        var dossier = alle[id] ?? [:]
        var aktivitaet = dossier[bereich.rawValue] ?? VorsorgeBereichAktivitaet()

        if aktivitaet.erstmalsBearbeitetAm == nil {
            aktivitaet.erstmalsBearbeitetAm = datum
        }
        aktivitaet.zuletztGeaendertAm = datum
        dossier[bereich.rawValue] = aktivitaet
        alle[id] = dossier
        speichere(alle)
        DossierEinstellungenStore.markiereGeaendert()

        if let cloudBereich = bereich.cloudBereich {
            NotificationCenter.default.post(
                name: .dossierBereichGespeichert,
                object: cloudBereich
            )
            // Jeder fachliche Dossierbereich nutzt diesen zentralen Änderungs-
            // punkt. Der Sync wird deshalb nicht nur für das Profil, sondern
            // für sämtliche Bereiche unmittelbar angestossen.
            Task { @MainActor in
                DossierSyncDienst.shared?.synchronisieren()
            }
        }
    }

    static func markiereGeprueft(
        _ bereiche: some Sequence<VorsorgeBereichID>,
        dossierID: String? = nil,
        am datum: Date = Date()
    ) {
        let id = aufgeloesteDossierID(dossierID)
        var alle = ladeAlle()
        var dossier = alle[id] ?? [:]

        for bereich in bereiche {
            var aktivitaet = dossier[bereich.rawValue] ?? VorsorgeBereichAktivitaet()
            aktivitaet.zuletztGeprueftAm = datum
            dossier[bereich.rawValue] = aktivitaet
        }

        alle[id] = dossier
        speichere(alle)
        DossierEinstellungenStore.markiereGeaendert()
    }

    static func pruefungZuruecksetzen(
        dossierID: String? = nil
    ) {
        let id = aufgeloesteDossierID(dossierID)
        var alle = ladeAlle()
        guard var dossier = alle[id] else { return }

        for key in Array(dossier.keys) {
            dossier[key]?.zuletztGeprueftAm = nil
        }

        alle[id] = dossier
        speichere(alle)
        DossierEinstellungenStore.markiereGeaendert()
    }

    private static func aufgeloesteDossierID(_ dossierID: String?) -> String {
        let expliziteID = dossierID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !expliziteID.isEmpty { return expliziteID }

        let aktiveID = UserDefaults.standard.string(forKey: "aktivesDossierID")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return aktiveID.isEmpty ? "hauptdossier" : aktiveID
    }

    private static func ladeAlle() -> AlleDossiers {
        guard
            let json = UserDefaults.standard.string(forKey: storageKey),
            let data = json.data(using: .utf8),
            let status = try? JSONDecoder().decode(AlleDossiers.self, from: data)
        else {
            return [:]
        }
        return status
    }

    private static func speichere(_ status: AlleDossiers) {
        guard
            let data = try? JSONEncoder().encode(status),
            let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: storageKey)
    }
}

@MainActor
enum DynamischerDossierFortschrittService {
    static func berechne(
        profil: ProfilModell?,
        gesundheit: GesundheitModell?,
        wuensche: [WuenscheModell],
        hinterbliebene: [HinterbliebeneModell],
        bankkonten: [BankkontoModell],
        schulden: [SchuldenModell],
        versicherungen: [VersicherungModell],
        liegenschaften: [LiegenschaftModell],
        wertsachen: [WertsacheModell],
        steuerdokumente: [SteuerdokumentModell],
        dokumente: [DokumenteModell],
        fotos: [FotoalbumBildModell],
        abos: [AboModell],
        herzensstuecke: [HerzensstueckModell],
        aktiveBereiche: Set<VorsorgeBereichID>
    ) -> Double {
        let profilAnteil = profilFortschritt(profil)
        let fachbereiche = aktiveBereiche.subtracting([.profil])
        guard !fachbereiche.isEmpty else { return profilAnteil * 0.2 }

        let dossierID = profil?.dossierID
        let dossierIDText = dossierID?.uuidString
        func gehoertZumDossier(_ id: UUID?) -> Bool { id == dossierID }
        func geprueft(_ bereich: VorsorgeBereichID) -> Bool {
            VorsorgeBereichStatusStore.status(fuer: bereich, dossierID: dossierIDText).istAktuellGeprueft
        }
        func begonnen(_ bereich: VorsorgeBereichID) -> Bool {
            VorsorgeBereichStatusStore.status(fuer: bereich, dossierID: dossierIDText).wurdeBegonnen
        }

        let gesundheitAnteil = bereichsAnteil(
            geprueft: geprueft(.gesundheit),
            begonnen: begonnen(.gesundheit),
            inhalt: gesundheit.map(gesundheitsFortschritt) ?? 0
        )
        let passendeWuensche = wuensche.filter { gehoertZumDossier($0.dossierID) }
        let wuenscheAnteil = bereichsAnteil(
            geprueft: geprueft(.wuensche),
            begonnen: begonnen(.wuensche),
            inhalt: passendeWuensche.map(wuenscheFortschritt).max() ?? 0
        )
        let passendeHinterbliebene = hinterbliebene.filter { gehoertZumDossier($0.dossierID) }
        let hinterbliebeneAnteil = bereichsAnteil(
            geprueft: geprueft(.hinterbliebene),
            begonnen: begonnen(.hinterbliebene),
            inhalt: passendeHinterbliebene.map(hinterbliebenenFortschritt).max() ?? 0
        )
        let hatFinanzen = bankkonten.contains { gehoertZumDossier($0.dossierID) }
            || schulden.contains { gehoertZumDossier($0.dossierID) }
            || versicherungen.contains { gehoertZumDossier($0.dossierID) }
            || liegenschaften.contains { gehoertZumDossier($0.dossierID) }
            || wertsachen.contains { gehoertZumDossier($0.dossierID) }
            || steuerdokumente.contains { gehoertZumDossier($0.dossierID) }
        let finanzenAnteil = bereichsAnteil(
            geprueft: geprueft(.finanzen),
            begonnen: begonnen(.finanzen),
            inhalt: hatFinanzen ? 0.9 : 0
        )
        let hatDokumente = dokumente.contains { gehoertZumDossier($0.dossierID) }
            || fotos.contains { gehoertZumDossier($0.dossierID) }
        let dokumenteAnteil = bereichsAnteil(
            geprueft: geprueft(.dokumente),
            begonnen: begonnen(.dokumente),
            inhalt: hatDokumente ? 0.9 : 0
        )
        let hatAbos = abos
            .filter { gehoertZumDossier($0.dossierID) }
            .contains { $0.abos.contains { !$0.istSystemEintrag } }
        let abosAnteil = bereichsAnteil(
            geprueft: geprueft(.abos),
            begonnen: begonnen(.abos),
            inhalt: hatAbos ? 0.9 : 0
        )
        let passendeHerzensstuecke = herzensstuecke.filter { gehoertZumDossier($0.dossierID) }
        let herzensstueckeAnteil = bereichsAnteil(
            geprueft: geprueft(.herzensstuecke),
            begonnen: begonnen(.herzensstuecke),
            inhalt: passendeHerzensstuecke.map(herzensstueckFortschritt).max() ?? 0
        )

        let anteile: [VorsorgeBereichID: Double] = [
            .gesundheit: gesundheitAnteil,
            .wuensche: wuenscheAnteil,
            .hinterbliebene: hinterbliebeneAnteil,
            .finanzen: finanzenAnteil,
            .dokumente: dokumenteAnteil,
            .abos: abosAnteil,
            .herzensstuecke: herzensstueckeAnteil
        ]
        let durchschnitt = fachbereiche.reduce(0.0) { $0 + (anteile[$1] ?? 0) }
            / Double(fachbereiche.count)
        return min(max(profilAnteil * 0.2 + durchschnitt * 0.8, 0), 1)
    }

    private static func bereichsAnteil(
        geprueft: Bool,
        begonnen: Bool,
        inhalt: Double
    ) -> Double {
        if geprueft { return 1 }
        return max(begonnen ? 0.2 : 0, min(inhalt, 0.9))
    }

    private static func profilFortschritt(_ profil: ProfilModell?) -> Double {
        guard let profil else { return 0 }
        let werte = [
            profil.vorname,
            profil.name,
            profil.telefon,
            profil.email,
            [profil.strasse, profil.plz, profil.stadt].joined()
        ]
        return Double(werte.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)
            / Double(werte.count)
    }

    private static func gesundheitsFortschritt(_ gesundheit: GesundheitModell) -> Double {
        var beantwortet = 0
        if gesundheit.hatHausarzt { beantwortet += 1 }
        if gesundheit.blutgruppe.lowercased() != "unbekannt" { beantwortet += 1 }
        if gesundheit.organspende.lowercased() != "nicht angegeben" { beantwortet += 1 }
        if gesundheit.hatAllergien || !gesundheit.allergien.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { beantwortet += 1 }
        if gesundheit.nimmtMedikamente || !gesundheit.medikamente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { beantwortet += 1 }
        if !gesundheit.gesundheitlicheHinweise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { beantwortet += 1 }
        return beantwortet == 0 ? 0 : 0.2 + 0.7 * Double(beantwortet) / 6
    }

    private static func wuenscheFortschritt(_ wuensche: WuenscheModell) -> Double {
        if !wuensche.hatWuensche { return 0.9 }
        let texte = [
            wuensche.beisetzungsArt, wuensche.beisetzungHinweis,
            wuensche.musikWunsch, wuensche.zeremonieDetails,
            wuensche.letzteBotschaft, wuensche.nachrufText,
            wuensche.testamentAblageort, wuensche.mirIstWichtig
        ]
        let hatInhalt = texte.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || wuensche.ausgewaehlteThemenData?.isEmpty == false
            || wuensche.testamentDateiData?.isEmpty == false
            || wuensche.patientenverfuegungDateiData?.isEmpty == false
            || wuensche.vorsorgeauftragDateiData?.isEmpty == false
        return hatInhalt ? 0.9 : 0.2
    }

    private static func hinterbliebenenFortschritt(_ person: HinterbliebeneModell) -> Double {
        let hatName = ![person.vorname, person.name].joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hatKontext = ![person.rolle, person.beziehung].joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let istErreichbar = ![person.telefon, person.email].joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hatName && hatKontext && istErreichbar { return 0.9 }
        if hatName && (hatKontext || istErreichbar) { return 0.6 }
        return hatName ? 0.35 : 0
    }

    private static func herzensstueckFortschritt(_ stueck: HerzensstueckModell) -> Double {
        let hatTitel = !stueck.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hatBeschreibung = ![stueck.beschreibung, stueck.geschichte, stueck.erinnerung]
            .joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hatBestimmung = stueck.bestimmung != .familieEntscheiden
            || !stueck.empfaengerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hatTitel && (hatBeschreibung || hatBestimmung) { return 0.9 }
        return hatTitel ? 0.55 : 0
    }
}

private extension VorsorgeBereichID {
    var cloudBereich: String? {
        switch self {
        case .profil: "profil"
        case .gesundheit: "gesundheit"
        case .wuensche: "wuensche"
        case .finanzen: "finanzen"
        case .hinterbliebene: "kontakte"
        case .abos: "zugaenge"
        case .herzensstuecke: "herzensstuecke"
        case .dokumente: "dokumente"
        }
    }
}
