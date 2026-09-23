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
            zugriff.zugriffWiderrufen(notizText: "Die Verbindung wurde von der vorsorgenden Person entfernt.")
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
        // Der Zugriff bleibt als inaktiver Verlaufseintrag erhalten, damit die
        // Vertrauensperson den entfernten Eintrag weiterhin in ihrer Übersicht
        // erkennt. Sämtliche zuvor geladenen Dossierinhalte wurden oben gelöscht.
        zugriff.zugriffWiderrufen(notizText: "Die Verbindung wurde von der vorsorgenden Person entfernt.")
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
        var status = try await PushEinladungsService.shared.status(token: token)
        if ["open", "pending", "declined"].contains(status.status),
           status.requesterUserID != userID {
            do {
                _ = try await PushEinladungsService.shared.einladungPruefen(token: token)
                status = try await PushEinladungsService.shared.status(token: token)
            } catch {
                throw PushFehler.server(
                    "Der Zugang konnte noch nicht aktiviert werden. Bitte versuche es erneut oder scanne die Einladung nochmals."
                )
            }
        }
        guard ["open", "pending", "declined", "accepted"].contains(status.status),
              status.requesterUserID == userID,
              status.dossierID == zugriff.dossierID else {
            throw PushFehler.zugriffVerweigert
        }
        let cloud: CloudFreigegebenesDossier
        do {
            cloud = try await PushEinladungsService.shared.freigegebenesDossier(token: token)
        } catch PushFehler.zugriffVerweigert
                    where ["open", "pending", "declined"].contains(status.status) {
            // Ältere App-/Serverstände konnten die Einladung bereits lokal
            // speichern, ohne den dazugehörigen Basis-Grant anzulegen. Ein
            // erneutes Validieren repariert diesen Zustand idempotent.
            do {
                _ = try await PushEinladungsService.shared.einladungPruefen(token: token)
                cloud = try await PushEinladungsService.shared.freigegebenesDossier(token: token)
            } catch {
                throw PushFehler.server(
                    "Der Zugang konnte noch nicht aktiviert werden. Bitte versuche es erneut oder scanne die Einladung nochmals."
                )
            }
        }
        guard cloud.dossierID == zugriff.dossierID,
              cloud.ownerUserID == zugriff.vorsorgendeUserID else {
            throw PushFehler.ungueltigeAntwort
        }
        let sichtbarkeitsKey = "freigegebeneBereiche.\(cloud.dossierID.uuidString.lowercased())"
        let zuvorFreigegeben = Set(
            UserDefaults.standard.string(forKey: sichtbarkeitsKey)?
                .split(separator: ",").map(String.init) ?? []
        )
        let jetztFreigegeben = Set(cloud.visibleSectionTypes)
        for entzogenerBereich in zuvorFreigegeben.subtracting(jetztFreigegeben) {
            try? DossierBereichImport.loesche(
                bereich: entzogenerBereich,
                dossierID: cloud.dossierID,
                in: modelContext
            )
        }
        UserDefaults.standard.set(
            cloud.visibleSectionTypes.joined(separator: ","),
            forKey: sichtbarkeitsKey
        )
        UserDefaults.standard.set(
            cloud.availableSectionTypes.joined(separator: ","),
            forKey: "verfuegbareBereiche.\(cloud.dossierID.uuidString.lowercased())"
        )
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
            do {
                if bereich.deleted {
                    try DossierBereichImport.loesche(
                        bereich: bereich.sectionType,
                        dossierID: cloud.dossierID,
                        in: modelContext
                    )
                } else if bereich.sectionType == "zugaenge",
                          let payload = bereich.payload,
                          let freigabePaket = cloud.sharedKeyPackage {
                    let encoder = JSONEncoder()
                    let verschluesselt = try JSONDecoder().decode(
                        VerschluesselterCloudBereich.self,
                        from: encoder.encode(payload)
                    )
                    let klartext = try await CloudFeldVerschluesselung.shared.entschluesseln(
                        verschluesselt,
                        als: CloudZugangsDaten.self,
                        freigabePaket: freigabePaket,
                        token: token
                    )
                    try DossierBereichImport.importiereZugangsDaten(
                        klartext,
                        dossierID: cloud.dossierID,
                        in: modelContext
                    )
                } else if bereich.sectionType == "zugaenge", !bereich.deleted {
                    fehlerhafteBereiche.append("verschlüsselte Zugänge (Schlüsselfreigabe fehlt)")
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
