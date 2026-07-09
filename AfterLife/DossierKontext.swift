//
//  DossierKontext.swift
//  AfterLife
//
//  Created by René Engeler on 09.07.2026.
//

import Foundation

/// Zentraler Kontext, mit dem Views wissen, welches Dossier angezeigt wird
/// und ob die aktuelle Person dieses Dossier bearbeiten oder nur lesen darf.
struct DossierKontext: Hashable, Identifiable {
    enum Modus: String, Hashable {
        case eigenesDossier
        case freigegebenesDossier
    }

    let id: UUID
    let dossierID: UUID
    let modus: Modus
    let zugriffID: UUID?
    let besitzerName: String?
    let besitzerEmail: String?

    init(
        dossierID: UUID,
        modus: Modus,
        zugriffID: UUID? = nil,
        besitzerName: String? = nil,
        besitzerEmail: String? = nil
    ) {
        self.id = dossierID
        self.dossierID = dossierID
        self.modus = modus
        self.zugriffID = zugriffID
        self.besitzerName = besitzerName
        self.besitzerEmail = besitzerEmail
    }

    var istEigenesDossier: Bool {
        modus == .eigenesDossier
    }

    var istFreigegebenesDossier: Bool {
        modus == .freigegebenesDossier
    }

    var istReadOnly: Bool {
        istFreigegebenesDossier
    }

    var kannBearbeiten: Bool {
        istEigenesDossier
    }

    var kannLoeschen: Bool {
        kannBearbeiten
    }

    var kannDokumenteHochladen: Bool {
        kannBearbeiten
    }

    var kannDokumenteScannen: Bool {
        kannBearbeiten
    }

    var kannPDFExportieren: Bool {
        true
    }

    var kannFotoalbumHerunterladen: Bool {
        true
    }

    var kannVideoHerunterladen: Bool {
        true
    }

    var darfSensibleDatenAnzeigen: Bool {
        true
    }

    var lesemodusHinweis: String? {
        guard istReadOnly else { return nil }
        return "Du kannst dieses Dossier ansehen, aber nicht bearbeiten."
    }

    static func eigenesDossier(
        dossierID: UUID,
        besitzerName: String? = nil,
        besitzerEmail: String? = nil
    ) -> DossierKontext {
        DossierKontext(
            dossierID: dossierID,
            modus: .eigenesDossier,
            besitzerName: besitzerName,
            besitzerEmail: besitzerEmail
        )
    }

    static func freigegebenesDossier(
        dossierID: UUID,
        zugriffID: UUID,
        besitzerName: String? = nil,
        besitzerEmail: String? = nil
    ) -> DossierKontext {
        DossierKontext(
            dossierID: dossierID,
            modus: .freigegebenesDossier,
            zugriffID: zugriffID,
            besitzerName: besitzerName,
            besitzerEmail: besitzerEmail
        )
    }
}
