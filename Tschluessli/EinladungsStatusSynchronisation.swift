import Foundation
import SwiftData

@MainActor
enum EinladungsStatusSynchronisation {
    static func aktualisieren(
        zugriffe: [DossierZugriffModell],
        dossiers: [DossierModell],
        aktiveUserID: UUID?,
        modelContext: ModelContext
    ) async {
        guard let aktiveUserID else { return }

        for zugriff in zugriffe where zugriff.istAktiv || zugriff.status == DossierZugriffStatus.abgelehnt {
            guard let token = zugriff.einladungsToken, !token.isEmpty else { continue }
            do {
                let status = try await PushEinladungsService.shared.status(token: token)
                if status.status == "revoked", status.requesterUserID == aktiveUserID {
                    entferneLokaleFreigabe(zugriff: zugriff, modelContext: modelContext)
                    continue
                }
                uebernehme(status, in: zugriff, aktiveUserID: aktiveUserID)

                if status.status == "accepted", status.requesterUserID == aktiveUserID {
                    try await ladeFreigegebenesDossier(
                        token: token,
                        zugriff: zugriff,
                        vorhandeneDossiers: dossiers,
                        modelContext: modelContext
                    )
                }
            } catch {
                // Ein einzelner abgelaufener oder widerrufener Token darf die
                // Synchronisierung der übrigen Einladungen nicht verhindern.
                continue
            }
        }

        try? modelContext.save()
    }

    private static func entferneLokaleFreigabe(
        zugriff: DossierZugriffModell,
        modelContext: ModelContext
    ) {
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
        zugriff.eingeladeneEmail = cloud.invitedEmail
        zugriff.vorsorgendePersonName = cloud.ownerName
        zugriff.einladungGueltigBis = cloud.expiresAt
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

    private static func ladeFreigegebenesDossier(
        token: String,
        zugriff: DossierZugriffModell,
        vorhandeneDossiers: [DossierModell],
        modelContext: ModelContext
    ) async throws {
        let cloud = try await PushEinladungsService.shared.freigegebenesDossier(token: token)
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

        for bereich in cloud.sections {
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
                // Verschlüsselte Bereiche ohne freigegebenen Dossierschlüssel
                // werden nicht unsicher umgangen; die übrigen Bereiche bleiben verfügbar.
                continue
            }
        }
        zugriff.dossierID = cloud.dossierID
    }
}
