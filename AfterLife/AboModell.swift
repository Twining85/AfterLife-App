//
//  AboModell.swift
//  AfterLife
//
//  Created by René Engeler on 20.06.2026.
//

import Foundation
import SwiftData

@Model
final class AboModell {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var erstelltAm: Date
    var aktualisiertAm: Date

    @Relationship(deleteRule: .cascade)
    var abos: [AboEintrag]

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date(),
        abos: [AboEintrag] = []
    ) {
        self.id = id
        self.dossierID = dossierID
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
        self.abos = abos
    }
}

@Model
final class AboEintrag {
    var id: UUID
    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?
    var erstelltAm: Date
    var aktualisiertAm: Date

    // MARK: - Grunddaten
    var aboTyp: String
    var anbieter: String
    var unternehmen: String
    var bezeichnung: String
    var aboArt: String
    var aboNummer: String

    // MARK: - Zugangsdaten
    var benutzername: String
    var passwort: String

    // MARK: - Streaming / Social Media / Digitale Identitäten / E-Mail
    var streamingAnbieter: String
    var socialMediaPlattform: String
    var digitaleIdentitaetAnbieter: String
    var emailAnbieter: String

    // MARK: - Geräte
    var geraeteArt: String
    var geraeteBezeichnung: String
    var geraetePIN: String

    // MARK: - ÖV / Mitgliedschaften / Spezialfälle
    var oevUnternehmen: String
    var oevAboTyp: String
    var andereBezeichnung: String
    var bankkontoName: String
    var bankkontoArt: String

    // MARK: - Zusatzinformationen
    var notizen: String
    var istAktiv: Bool
    var istSystemEintrag: Bool

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date(),
        aboTyp: String = "Bitte wählen",
        anbieter: String = "Bitte wählen",
        unternehmen: String = "",
        bezeichnung: String = "",
        aboArt: String = "",
        aboNummer: String = "",
        benutzername: String = "",
        passwort: String = "",
        streamingAnbieter: String = "Bitte wählen",
        socialMediaPlattform: String = "Bitte wählen",
        digitaleIdentitaetAnbieter: String = "Bitte wählen",
        emailAnbieter: String = "Bitte wählen",
        geraeteArt: String = "Bitte wählen",
        geraeteBezeichnung: String = "",
        geraetePIN: String = "",
        oevUnternehmen: String = "Bitte wählen",
        oevAboTyp: String = "Bitte wählen",
        andereBezeichnung: String = "",
        bankkontoName: String = "",
        bankkontoArt: String = "",
        notizen: String = "",
        istAktiv: Bool = true,
        istSystemEintrag: Bool = false
    ) {
        self.id = id
        self.dossierID = dossierID
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
        self.aboTyp = aboTyp
        self.anbieter = anbieter
        self.unternehmen = unternehmen
        self.bezeichnung = bezeichnung
        self.aboArt = aboArt
        self.aboNummer = aboNummer
        self.benutzername = benutzername
        self.passwort = passwort
        self.streamingAnbieter = streamingAnbieter
        self.socialMediaPlattform = socialMediaPlattform
        self.digitaleIdentitaetAnbieter = digitaleIdentitaetAnbieter
        self.emailAnbieter = emailAnbieter
        self.geraeteArt = geraeteArt
        self.geraeteBezeichnung = geraeteBezeichnung
        self.geraetePIN = geraetePIN
        self.oevUnternehmen = oevUnternehmen
        self.oevAboTyp = oevAboTyp
        self.andereBezeichnung = andereBezeichnung
        self.bankkontoName = bankkontoName
        self.bankkontoArt = bankkontoArt
        self.notizen = notizen
        self.istAktiv = istAktiv
        self.istSystemEintrag = istSystemEintrag
    }
}
