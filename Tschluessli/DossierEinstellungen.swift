import Foundation

nonisolated struct CloudDossierEinstellungenDaten: Codable, Sendable, Equatable {
    let dossierID: UUID
    let homeBereicheReihenfolge: [String]
    let homeAktiveBereiche: [String]
    let dossierErstellungsart: String?
    let uebersprungeneDossierSchritte: [String]
    let jaehrlicheVorsorgeErinnerungAktiv: Bool
    let dossierZuletztGeprueftAm: Date?
    let dossierLetzterExportAm: Date?
    let vorsorgeBereichStatus: [String: VorsorgeBereichAktivitaet]
}

enum DossierEinstellungenStore {
    static let cloudBereich = "dossier_einstellungen"

    private enum Key {
        static let reihenfolge = "homeBereicheReihenfolge"
        static let aktiveBereiche = "homeAktiveBereiche"
        static let erstellungsart = "dossierErstellungsart"
        static let uebersprungeneSchritte = "uebersprungeneDossierSchritte"
        static let erinnerungAktiv = "jaehrlicheVorsorgeErinnerungAktiv"
        static let zuletztGeprueft = "dossierZuletztGeprueftAmISO"
        static let letzterExport = "dossierLetzterExportAmISO"
    }

    static func cloudDaten(fuer dossierID: UUID) -> CloudDossierEinstellungenDaten {
        CloudDossierEinstellungenDaten(
            dossierID: dossierID,
            homeBereicheReihenfolge: liste(fuer: Key.reihenfolge, dossierID: dossierID),
            homeAktiveBereiche: liste(fuer: Key.aktiveBereiche, dossierID: dossierID),
            dossierErstellungsart: optionalerString(fuer: Key.erstellungsart, dossierID: dossierID),
            uebersprungeneDossierSchritte: liste(fuer: Key.uebersprungeneSchritte, dossierID: dossierID),
            jaehrlicheVorsorgeErinnerungAktiv: bool(
                fuer: Key.erinnerungAktiv,
                dossierID: dossierID,
                standardwert: true
            ),
            dossierZuletztGeprueftAm: datum(fuer: Key.zuletztGeprueft, dossierID: dossierID),
            dossierLetzterExportAm: datum(fuer: Key.letzterExport, dossierID: dossierID),
            vorsorgeBereichStatus: VorsorgeBereichStatusStore.status(fuerDossierID: dossierID.uuidString)
        )
    }

    static func importiere(_ daten: CloudDossierEinstellungenDaten, fuer dossierID: UUID) {
        setze(daten.homeBereicheReihenfolge.joined(separator: ","), fuer: Key.reihenfolge, dossierID: dossierID)
        setze(daten.homeAktiveBereiche.joined(separator: ","), fuer: Key.aktiveBereiche, dossierID: dossierID)
        setze(daten.dossierErstellungsart ?? "", fuer: Key.erstellungsart, dossierID: dossierID)
        setze(daten.uebersprungeneDossierSchritte.joined(separator: ","), fuer: Key.uebersprungeneSchritte, dossierID: dossierID)
        setze(daten.jaehrlicheVorsorgeErinnerungAktiv, fuer: Key.erinnerungAktiv, dossierID: dossierID)
        setze(daten.dossierZuletztGeprueftAm.map(ISO8601DateFormatter().string) ?? "", fuer: Key.zuletztGeprueft, dossierID: dossierID)
        setze(daten.dossierLetzterExportAm.map(ISO8601DateFormatter().string) ?? "", fuer: Key.letzterExport, dossierID: dossierID)
        VorsorgeBereichStatusStore.setzeStatus(daten.vorsorgeBereichStatus, fuerDossierID: dossierID.uuidString)
    }

    static func loesche(fuer dossierID: UUID) {
        [Key.reihenfolge, Key.aktiveBereiche, Key.erstellungsart, Key.uebersprungeneSchritte,
         Key.erinnerungAktiv, Key.zuletztGeprueft, Key.letzterExport].forEach {
            UserDefaults.standard.removeObject(forKey: dossierKey($0, dossierID: dossierID))
            if istAktivesDossier(dossierID) {
                UserDefaults.standard.removeObject(forKey: $0)
            }
        }
        VorsorgeBereichStatusStore.setzeStatus([:], fuerDossierID: dossierID.uuidString)
    }

    static func markiereGeaendert() {
        NotificationCenter.default.post(name: .dossierBereichGespeichert, object: cloudBereich)
    }

    private static func liste(fuer key: String, dossierID: UUID) -> [String] {
        string(fuer: key, dossierID: dossierID)
            .split(separator: ",")
            .map(String.init)
    }

    private static func optionalerString(fuer key: String, dossierID: UUID) -> String? {
        let wert = string(fuer: key, dossierID: dossierID)
        return wert.isEmpty ? nil : wert
    }

    private static func datum(fuer key: String, dossierID: UUID) -> Date? {
        ISO8601DateFormatter().date(from: string(fuer: key, dossierID: dossierID))
    }

    private static func bool(fuer key: String, dossierID: UUID, standardwert: Bool) -> Bool {
        let defaults = UserDefaults.standard
        let scopedKey = dossierKey(key, dossierID: dossierID)
        if let wert = defaults.object(forKey: scopedKey) as? Bool { return wert }
        if istAktivesDossier(dossierID), let wert = defaults.object(forKey: key) as? Bool { return wert }
        return standardwert
    }

    private static func string(fuer key: String, dossierID: UUID) -> String {
        let defaults = UserDefaults.standard
        if istAktivesDossier(dossierID), let wert = defaults.string(forKey: key) { return wert }
        return defaults.string(forKey: dossierKey(key, dossierID: dossierID)) ?? ""
    }

    private static func setze(_ wert: Any, fuer key: String, dossierID: UUID) {
        let defaults = UserDefaults.standard
        defaults.set(wert, forKey: dossierKey(key, dossierID: dossierID))
        if istAktivesDossier(dossierID) { defaults.set(wert, forKey: key) }
    }

    private static func dossierKey(_ key: String, dossierID: UUID) -> String {
        "\(key).\(dossierID.uuidString.lowercased())"
    }

    private static func istAktivesDossier(_ dossierID: UUID) -> Bool {
        guard let wert = UserDefaults.standard.string(forKey: "aktivesDossierID"),
              let aktiveID = UUID(uuidString: wert) else { return false }
        return aktiveID == dossierID
    }
}
