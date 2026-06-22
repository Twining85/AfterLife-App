//
//  DokumenteModell.swift
//  AfterLife
//
//  Created by René Engeler on 19.06.2026.
//

import Foundation
import SwiftData

@Model
final class DokumenteModell {
    var id: UUID
    var dateiName: String
    var kategorie: String
    var hochgeladenAm: Date
    var dateiDaten: Data

    init(
        id: UUID = UUID(),
        dateiName: String = "",
        kategorie: String = "Weitere Dokumente",
        hochgeladenAm: Date = Date(),
        dateiDaten: Data = Data()
    ) {
        self.id = id
        self.dateiName = dateiName
        self.kategorie = kategorie
        self.hochgeladenAm = hochgeladenAm
        self.dateiDaten = dateiDaten
    }
}

@Model
final class FotoalbumBildModell {
    var id: UUID
    var dateiName: String
    var hinzugefuegtAm: Date
    var bildDaten: Data
    var reihenfolge: Int

    init(
        id: UUID = UUID(),
        dateiName: String = "",
        hinzugefuegtAm: Date = Date(),
        bildDaten: Data = Data(),
        reihenfolge: Int = 0
    ) {
        self.id = id
        self.dateiName = dateiName
        self.hinzugefuegtAm = hinzugefuegtAm
        self.bildDaten = bildDaten
        self.reihenfolge = reihenfolge
    }
}
