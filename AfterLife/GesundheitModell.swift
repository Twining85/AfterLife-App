//
//  GesundheitModell.swift
//  AfterLife
//
//  Created by René Engeler on 01.07.2026.
//

import Foundation
import SwiftData

@Model
final class GesundheitModell {
    // MARK: - Zuordnung

    /// Eigene stabile ID für den Gesundheitseintrag.
    var gesundheitID: UUID?

    /// Verknüpfung zum aktiven Profil / Benutzer.
    var userID: UUID?

    /// Verknüpfung zum Vorsorgedossier.
    var dossierID: UUID?

    // MARK: - Hausarzt

    var hatHausarzt: Bool

    /// Referenz auf einen bestehenden Kontakt, sobald die Kontakt-Auswahl angebunden ist.
    var hausarztKontaktID: UUID?

    /// Fallback / Anzeige für den Hausarzt, solange noch keine Kontakt-Auswahl angebunden ist.
    var hausarztName: String

    // MARK: - Medizinische Informationen

    /// Werte: Unbekannt, A+, A-, B+, B-, AB+, AB-, 0+, 0-
    var blutgruppe: String

    /// Werte: Nicht angegeben, Ja, Nein
    var organspende: String

    var hatAllergien: Bool
    var allergien: String

    var nimmtMedikamente: Bool
    var medikamente: String

    var gesundheitlicheHinweise: String

    // MARK: - Metadaten

    var erstelltAm: Date
    var geaendertAm: Date

    init(
        gesundheitID: UUID? = UUID(),
        userID: UUID? = nil,
        dossierID: UUID? = nil,
        hatHausarzt: Bool = false,
        hausarztKontaktID: UUID? = nil,
        hausarztName: String = "",
        blutgruppe: String = GesundheitBlutgruppe.unbekannt,
        organspende: String = GesundheitOrganspendeStatus.nichtAngegeben,
        hatAllergien: Bool = false,
        allergien: String = "",
        nimmtMedikamente: Bool = false,
        medikamente: String = "",
        gesundheitlicheHinweise: String = "",
        erstelltAm: Date = Date(),
        geaendertAm: Date = Date()
    ) {
        self.gesundheitID = gesundheitID
        self.userID = userID
        self.dossierID = dossierID
        self.hatHausarzt = hatHausarzt
        self.hausarztKontaktID = hausarztKontaktID
        self.hausarztName = hausarztName
        self.blutgruppe = blutgruppe
        self.organspende = organspende
        self.hatAllergien = hatAllergien
        self.allergien = allergien
        self.nimmtMedikamente = nimmtMedikamente
        self.medikamente = medikamente
        self.gesundheitlicheHinweise = gesundheitlicheHinweise
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
    }

    // MARK: - Abgeleitete Werte

    var hausarztAnzeige: String {
        let bereinigterName = hausarztName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !hatHausarzt {
            return "Kein Hausarzt erfasst"
        }

        if !bereinigterName.isEmpty {
            return bereinigterName
        }

        if hausarztKontaktID != nil {
            return "Hausarzt-Kontakt ausgewählt"
        }

        return "Hausarzt noch nicht ausgewählt"
    }

    var hatMedizinischeAngaben: Bool {
        blutgruppe != GesundheitBlutgruppe.unbekannt ||
        organspende != GesundheitOrganspendeStatus.nichtAngegeben ||
        hatAllergien ||
        nimmtMedikamente ||
        !gesundheitlicheHinweise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hatWichtigeNotfallinformationen: Bool {
        hatHausarzt || hatMedizinischeAngaben
    }

    // MARK: - Pflegefunktionen

    func hausarztAktualisieren(
        hatHausarzt: Bool,
        hausarztKontaktID: UUID? = nil,
        hausarztName: String = ""
    ) {
        self.hatHausarzt = hatHausarzt
        self.hausarztKontaktID = hatHausarzt ? hausarztKontaktID : nil
        self.hausarztName = hatHausarzt ? hausarztName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        markiereAlsGeaendert()
    }

    func medizinischeInformationenAktualisieren(
        blutgruppe: String,
        organspende: String,
        hatAllergien: Bool,
        allergien: String,
        nimmtMedikamente: Bool,
        medikamente: String,
        gesundheitlicheHinweise: String
    ) {
        self.blutgruppe = blutgruppe
        self.organspende = organspende
        self.hatAllergien = hatAllergien
        self.allergien = hatAllergien ? allergien.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        self.nimmtMedikamente = nimmtMedikamente
        self.medikamente = nimmtMedikamente ? medikamente.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        self.gesundheitlicheHinweise = gesundheitlicheHinweise.trimmingCharacters(in: .whitespacesAndNewlines)
        markiereAlsGeaendert()
    }

    func stelleGesundheitIDSicher() {
        if gesundheitID == nil {
            gesundheitID = UUID()
            markiereAlsGeaendert()
        }
    }

    func markiereAlsGeaendert() {
        geaendertAm = Date()
    }
}

// MARK: - Statische Werte

enum GesundheitBlutgruppe {
    static let unbekannt = "Unbekannt"
    static let alle = [
        unbekannt,
        "A+",
        "A-",
        "B+",
        "B-",
        "AB+",
        "AB-",
        "0+",
        "0-"
    ]
}

enum GesundheitOrganspendeStatus {
    static let nichtAngegeben = "Nicht angegeben"
    static let ja = "Ja"
    static let nein = "Nein"

    static let alle = [
        nichtAngegeben,
        ja,
        nein
    ]
}
