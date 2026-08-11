//
//  DossierModell.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import Foundation
import SwiftData

@Model
final class DossierModell {

    var dossierID: UUID
    var besitzerUserID: UUID
    /// Benutzer, der das Dossier ursprünglich erstellt hat.
    var erstelltVonUserID: UUID
    /// Kennzeichnet das Standarddossier eines Benutzers.
    var istHauptdossier: Bool

    /// Anzeigename des Dossiers (z. B. "Dossier von René Engeler")
    var titel: String
    /// Optionale Beschreibung des Dossiers.
    var beschreibung: String?

    var erstelltAm: Date
    var aktualisiertAm: Date
    /// Zeitpunkt der letzten inhaltlichen Änderung am Dossier.
    var zuletztGeoeffnetAm: Date?
    /// Wird später verwendet, um freigegebene Dossiers oder archivierte Dossiers zu unterscheiden.
    var istAktiv: Bool
    /// Kennzeichnet, ob das Dossier nach Eintritt des Ereignisses freigegeben wurde.
    var istFreigegeben: Bool

    /// Zeitpunkt der Freigabe des Dossiers.
    var freigegebenAm: Date?

    /// Ein Dossier kann nur genutzt werden, solange es aktiv ist.
    var istBearbeitbar: Bool {
        istAktiv
    }

    /// Nach der Freigabe ist das Dossier schreibgeschützt.
    var istSchreibgeschuetzt: Bool {
        istFreigegeben
    }

    init(
        dossierID: UUID = UUID(),
        besitzerUserID: UUID,
        erstelltVonUserID: UUID? = nil,
        istHauptdossier: Bool = true,
        vorsorgendePersonName: String
    ) {
        self.dossierID = dossierID
        self.besitzerUserID = besitzerUserID
        self.erstelltVonUserID = erstelltVonUserID ?? besitzerUserID
        self.istHauptdossier = istHauptdossier
        self.titel = "Dossier von \(vorsorgendePersonName)"
        self.beschreibung = nil
        self.erstelltAm = Date()
        self.aktualisiertAm = Date()
        self.istAktiv = true
        self.istFreigegeben = false
        self.freigegebenAm = nil
        self.zuletztGeoeffnetAm = nil
    }

    func titelAktualisieren(vorname: String, nachname: String) {
        let name = "\(vorname) \(nachname)"
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty {
            titel = "Mein Dossier"
        } else {
            titel = "Dossier von \(name)"
        }

        aktualisiertAm = Date()
        zuletztGeoeffnetAm = Date()
    }

    func inhaltAktualisiert() {
        guard !istSchreibgeschuetzt else { return }
        aktualisiertAm = Date()
    }

    func geoeffnet() {
        zuletztGeoeffnetAm = Date()
    }

    func freigeben() {
        guard istAktiv, !istFreigegeben else { return }
        istFreigegeben = true
        freigegebenAm = Date()
        aktualisiertAm = Date()
    }

    func archivieren() {
        guard istAktiv else { return }
        istAktiv = false
        aktualisiertAm = Date()
    }
}
