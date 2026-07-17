import Foundation

enum VorsorgeBereichID: String, CaseIterable, Codable {
    case profil
    case gesundheit
    case wuensche
    case finanzen
    case hinterbliebene
    case dokumente
    case abos
}

struct VorsorgeBereichAktivitaet: Codable, Equatable {
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
