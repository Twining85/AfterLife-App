import Foundation
import SwiftData

@MainActor
enum EinladungsStatusSynchronisation {
    private static var laeuft = false
    static func aktualisieren(
        zugriffe: [DossierZugriffModell],
        dossiers: [DossierModell],
        aktiveUserID: UUID?,
        modelContext: ModelContext
    ) async -> String? {
        guard let aktiveUserID else { return nil }
        guard !laeuft else { return nil }
        laeuft = true
        defer { laeuft = false }
        var letzterFehler: String?

        for zugriff in zugriffe where
            (zugriff.vorsorgendeUserID == aktiveUserID || zugriff.vertrauenspersonUserID == aktiveUserID) &&
            (zugriff.istAktiv || zugriff.status == DossierZugriffStatus.abgelehnt) {
            guard let token = zugriff.einladungsToken, !token.isEmpty else { continue }
            do {
                let status = try await PushEinladungsService.shared.status(token: token)
                if status.status == "revoked" {
                    entferneLokaleFreigabe(zugriff: zugriff, modelContext: modelContext)
                    continue
                }
                uebernehme(status, in: zugriff, aktiveUserID: aktiveUserID)

            } catch PushFehler.nichtGefunden where zugriff.status == DossierZugriffStatus.erstellt {
                // Direkt nach dem QR-Scan ist die eingeladene Person auf
                // älteren Serverständen noch nicht als Requester verknüpft.
                // Die bewusst noch nicht angefragte Home-Kachel muss in diesem
                // Zustand erhalten bleiben.
                continue
            } catch PushFehler.nichtGefunden {
                entferneLokaleFreigabe(zugriff: zugriff, modelContext: modelContext)
                continue
            } catch PushFehler.zugriffVerweigert {
                entferneLokaleFreigabe(zugriff: zugriff, modelContext: modelContext)
                continue
            } catch {
                letzterFehler = error.localizedDescription
                continue
            }
        }

        try? modelContext.save()
        return letzterFehler
    }

    private static func entferneLokaleFreigabe(
        zugriff: DossierZugriffModell,
        modelContext: ModelContext
    ) {
        // Beim Eigentümer wird nur die Freigabe entfernt, niemals sein Dossier.
        if zugriff.vorsorgendeUserID.uuidString.lowercased() ==
            UserDefaults.standard.string(forKey: "aktiveUserID")?.lowercased() {
            modelContext.delete(zugriff)
            return
        }
        let hatWeiterenAktivenZugriff: Bool
        if let alleZugriffe = try? modelContext.fetch(FetchDescriptor<DossierZugriffModell>()) {
            hatWeiterenAktivenZugriff = alleZugriffe.contains {
                $0.zugriffID != zugriff.zugriffID &&
                $0.dossierID == zugriff.dossierID &&
                $0.istAktiv
            }
        } else {
            hatWeiterenAktivenZugriff = false
        }

        if hatWeiterenAktivenZugriff {
            modelContext.delete(zugriff)
            return
        }

        for bereich in ["profil", "gesundheit", "wuensche", "finanzen", "kontakte", "herzensstuecke", "zugaenge"] {
            try? DossierBereichImport.loesche(
                bereich: bereich,
                dossierID: zugriff.dossierID,
                in: modelContext
            )
        }
        if let dokumente = try? modelContext.fetch(FetchDescriptor<DokumenteModell>()) {
            dokumente.filter { $0.dossierID == zugriff.dossierID }.forEach { modelContext.delete($0) }
        }
        if let fotos = try? modelContext.fetch(FetchDescriptor<FotoalbumBildModell>()) {
            fotos.filter { $0.dossierID == zugriff.dossierID }.forEach { modelContext.delete($0) }
        }
        if let dossiers = try? modelContext.fetch(FetchDescriptor<DossierModell>()),
           let dossier = dossiers.first(where: { $0.dossierID == zugriff.dossierID }) {
            modelContext.delete(dossier)
        }
        modelContext.delete(zugriff)
    }

    private static func uebernehme(
        _ cloud: CloudEinladungsStatus,
        in zugriff: DossierZugriffModell,
        aktiveUserID: UUID
    ) {
        // Die Serverantwort ist die autoritative Zuordnung. Insbesondere nach
        // einer erneuten Einladung darf ein lokal veraltetes dossierID nie
        // weiterverwendet werden.
        zugriff.dossierID = cloud.dossierID
        zugriff.vorsorgendeUserID = cloud.ownerUserID
        zugriff.eingeladeneEmail = cloud.invitedEmail
        zugriff.vorsorgendePersonName = cloud.ownerName
        zugriff.einladungGueltigBis = cloud.expiresAt
        zugriff.automatischeFreigabeAm = cloud.accessReleaseAt
        if let requester = cloud.requesterUserID {
            zugriff.vertrauenspersonUserID = requester
        }
        zugriff.registrierungsEmail = cloud.requesterEmail

        switch cloud.status {
        case "pending":
            if let requester = cloud.requesterUserID {
                zugriff.bestaetigungAnfragen(
                    vertrauenspersonUserID: requester,
                    registrierungsEmail: cloud.requesterEmail ?? cloud.invitedEmail
                )
            }
        case "accepted":
            if let requester = cloud.requesterUserID {
                zugriff.einladungAnnehmen(
                    vertrauenspersonUserID: requester,
                    registrierungsEmail: cloud.requesterEmail
                )
            }
        case "declined":
            zugriff.einladungAblehnen(registrierungsEmail: cloud.requesterEmail)
        case "revoked":
            zugriff.zugriffWiderrufen(notizText: "Zugriff wurde serverseitig widerrufen.")
        default:
            break
        }
    }

}

/// Ausschliesslich durch das Öffnen eines freigegebenen Dossiers ausgelöst.
@MainActor
enum FreigegebenesDossierSync {
    static func laden(
        token: String,
        zugriff: DossierZugriffModell,
        vorhandeneDossiers: [DossierModell],
        modelContext: ModelContext
    ) async throws -> String? {
        let userID = UUID(uuidString: UserDefaults.standard.string(forKey: "aktiveUserID") ?? "")
        guard zugriff.vertrauenspersonUserID == userID,
              zugriff.vorsorgendeUserID != userID, zugriff.istAktiv else {
            throw PushFehler.zugriffVerweigert
        }
        let status = try await PushEinladungsService.shared.status(token: token)
        guard status.status == "accepted", status.requesterUserID == userID,
              status.dossierID == zugriff.dossierID else {
            throw PushFehler.zugriffVerweigert
        }
        let cloud = try await PushEinladungsService.shared.freigegebenesDossier(token: token)
        guard cloud.dossierID == zugriff.dossierID,
              cloud.ownerUserID == zugriff.vorsorgendeUserID else {
            throw PushFehler.ungueltigeAntwort
        }
        if let dossier = vorhandeneDossiers.first(where: { $0.dossierID == cloud.dossierID }) {
            dossier.titel = cloud.title
            dossier.aktualisiertAm = Date()
        } else {
            let dossier = DossierModell(
                dossierID: cloud.dossierID,
                besitzerUserID: cloud.ownerUserID,
                erstelltVonUserID: cloud.ownerUserID,
                istHauptdossier: false,
                vorsorgendePersonName: cloud.ownerName
            )
            dossier.titel = cloud.title
            modelContext.insert(dossier)
        }

        var fehlerhafteBereiche: [String] = []
        for bereich in cloud.sections {
            // Die bestehende Schlüsselverwaltung gehört ausschliesslich zum
            // eigenen Konto und speichert auch dessen Recovery-Paket.
            // Fremde verschlüsselte Daten dürfen diesen Pfad nicht verwenden.
            if bereich.sectionType == "zugaenge", !bereich.deleted {
                fehlerhafteBereiche.append("verschlüsselte Zugänge (Schlüsselfreigabe fehlt)")
                continue
            }
            do {
                if bereich.deleted {
                    try DossierBereichImport.loesche(
                        bereich: bereich.sectionType,
                        dossierID: cloud.dossierID,
                        in: modelContext
                    )
                } else if let payload = bereich.payload {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let daten = try encoder.encode(payload)
                    try await DossierBereichImport.importiere(
                        daten,
                        bereich: bereich.sectionType,
                        dossierID: cloud.dossierID,
                        in: modelContext
                    )
                }
            } catch {
                fehlerhafteBereiche.append(bereich.sectionType)
                continue
            }
        }
        zugriff.dossierID = cloud.dossierID
        try modelContext.save()
        if !fehlerhafteBereiche.isEmpty {
            return "Nicht alle Inhalte sind verfügbar: \(fehlerhafteBereiche.joined(separator: ", ")). Verschlüsselte Inhalte benötigen den freigegebenen Dossierschlüssel."
        }
        return nil
    }
}
