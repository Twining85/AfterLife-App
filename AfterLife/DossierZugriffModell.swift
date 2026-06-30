//
//  DossierZugriffModell.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import Foundation
import SwiftData

enum DossierZugriffStatus {
    static let erstellt = "erstellt"
    static let angenommen = "angenommen"
    static let abgelehnt = "abgelehnt"
    static let freigegeben = "freigegeben"
    static let widerrufen = "widerrufen"
}

@Model
final class DossierZugriffModell {

    var zugriffID: UUID

    /// Token, über den der Zugriff ursprünglich entstanden ist.
    var einladungsToken: String?

    /// E-Mail-Adresse, an welche die Einladung verschickt wurde.
    var eingeladeneEmail: String

    /// E-Mail-Adresse, mit der sich die Vertrauensperson tatsächlich registriert hat.
    var registrierungsEmail: String?

    /// Name der eingeladenen Vertrauensperson, falls bereits bekannt.
    var eingeladenePersonName: String?

    /// Zeitpunkt, bis zu dem der Einladungslink gültig ist.
    var einladungGueltigBis: Date?

    /// Kennzeichnet, ob der Einladungslink bereits verwendet wurde.
    var einladungsLinkVerwendet: Bool

    /// Zeitpunkt, an dem der Einladungslink verwendet wurde.
    var einladungsLinkVerwendetAm: Date?

    /// Referenz auf das freigegebene Vorsorgedossier.
    var dossierID: UUID

    /// Besitzer des Dossiers.
    var vorsorgendeUserID: UUID

    /// Nutzer, der als Vertrauensperson Zugriff erhält. Bei einer offenen Einladung ist dieser Wert noch nicht bekannt.
    var vertrauenspersonUserID: UUID?

    /// Status der Einladung (z. B. erstellt, angenommen, abgelehnt).
    var status: String

    /// Zeitpunkt der Annahme der Einladung.
    var angenommenAm: Date?

    /// Zeitpunkt der Ablehnung der Einladung.
    var abgelehntAm: Date?

    /// Zeitpunkt, an dem der Zugriff nach Eintritt des Ereignisses freigegeben wurde.
    var freigegebenAm: Date?

    /// Zeitpunkt, an dem der Zugriff widerrufen wurde.
    var widerrufenAm: Date?

    /// Kann später für unterschiedliche Berechtigungen verwendet werden.
    var rolle: String

    /// Kennzeichnet die primäre Vertrauensperson, falls mehrere Personen Zugriff besitzen.
    var istPrimaer: Bool

    /// Reihenfolge für die spätere Anzeige mehrerer Vertrauenspersonen.
    var reihenfolge: Int

    /// Ermöglicht das spätere Deaktivieren eines Zugriffs, ohne ihn zu löschen.
    var istAktiv: Bool

    /// Interne Notiz zur Vertrauensperson oder zum Zugriff.
    var notiz: String?

    /// Zeitpunkt, an dem der Zugriff erstellt wurde.
    var erstelltAm: Date

    /// Zeitpunkt, an dem der Zugriff zuletzt geändert wurde.
    var aktualisiertAm: Date

    init(
        zugriffID: UUID = UUID(),
        einladungsToken: String? = nil,
        eingeladeneEmail: String,
        registrierungsEmail: String? = nil,
        eingeladenePersonName: String? = nil,
        einladungGueltigBis: Date? = nil,
        einladungsLinkVerwendet: Bool = false,
        einladungsLinkVerwendetAm: Date? = nil,
        dossierID: UUID,
        vorsorgendeUserID: UUID,
        vertrauenspersonUserID: UUID? = nil,
        status: String = DossierZugriffStatus.erstellt,
        angenommenAm: Date? = nil,
        abgelehntAm: Date? = nil,
        freigegebenAm: Date? = nil,
        widerrufenAm: Date? = nil,
        rolle: String = "Vertrauensperson",
        istPrimaer: Bool = false,
        reihenfolge: Int = 0,
        istAktiv: Bool = true,
        notiz: String? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.zugriffID = zugriffID
        self.einladungsToken = einladungsToken
        self.eingeladeneEmail = eingeladeneEmail
        self.registrierungsEmail = registrierungsEmail
        self.eingeladenePersonName = eingeladenePersonName
        self.einladungGueltigBis = einladungGueltigBis
        self.einladungsLinkVerwendet = einladungsLinkVerwendet
        self.einladungsLinkVerwendetAm = einladungsLinkVerwendetAm
        self.dossierID = dossierID
        self.vorsorgendeUserID = vorsorgendeUserID
        self.vertrauenspersonUserID = vertrauenspersonUserID
        self.status = status
        self.angenommenAm = angenommenAm
        self.abgelehntAm = abgelehntAm
        self.freigegebenAm = freigegebenAm
        self.widerrufenAm = widerrufenAm
        self.rolle = rolle
        self.istPrimaer = istPrimaer
        self.reihenfolge = reihenfolge
        self.istAktiv = istAktiv
        self.notiz = notiz
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
    
    func einladungAlsVerwendetMarkieren() {
        einladungsLinkVerwendet = true
        einladungsLinkVerwendetAm = Date()
        aktualisiertAm = Date()
    }

    func einladungAnnehmen(vertrauenspersonUserID: UUID, registrierungsEmail: String? = nil) {
        self.vertrauenspersonUserID = vertrauenspersonUserID
        self.registrierungsEmail = registrierungsEmail
        status = DossierZugriffStatus.angenommen
        angenommenAm = Date()
        abgelehntAm = nil
        aktualisiertAm = Date()
        einladungAlsVerwendetMarkieren()
    }

    func einladungAblehnen() {
        status = DossierZugriffStatus.abgelehnt
        abgelehntAm = Date()
        angenommenAm = nil
        vertrauenspersonUserID = nil
        registrierungsEmail = nil
        istAktiv = false
        aktualisiertAm = Date()
    }

    func zugriffFreigeben() {
        status = DossierZugriffStatus.freigegeben
        freigegebenAm = Date()
        aktualisiertAm = Date()
    }

    func zugriffWiderrufen() {
        status = DossierZugriffStatus.widerrufen
        widerrufenAm = Date()
        istAktiv = false
        aktualisiertAm = Date()
    }

    func archivieren() {
        istAktiv = false
        aktualisiertAm = Date()
    }

    var istEinladungAbgelaufen: Bool {
        guard let einladungGueltigBis else { return false }
        return Date() > einladungGueltigBis
    }

    var kannRegistrierungFortsetzen: Bool {
        status == DossierZugriffStatus.erstellt && istAktiv && !einladungsLinkVerwendet && !istEinladungAbgelaufen
    }
}
