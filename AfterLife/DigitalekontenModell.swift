//
//  DigitalekontenModell.swift
//  AfterLife
//
//  Created by René Engeler on 19.06.2026.
//

import Foundation
import SwiftData

@Model
final class DigitalekontenModell {

    var id: UUID

    /// Referenz auf das zugehörige Vorsorgedossier.
    var dossierID: UUID?

    var erstelltAm: Date
    var aktualisiertAm: Date

    @Relationship(deleteRule: .cascade)
    var konten: [AboEintrag]

    init(
        id: UUID = UUID(),
        dossierID: UUID? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date(),
        konten: [AboEintrag] = []
    ) {
        self.id = id
        self.dossierID = dossierID
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
        self.konten = konten
    }
}
