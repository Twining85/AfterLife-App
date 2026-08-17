import SwiftData
import SwiftUI

struct SyncKonfliktView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SyncKonflikt.empfangenAm, order: .reverse) private var konflikte: [SyncKonflikt]
    @State private var fehlermeldung = ""

    var body: some View {
        NavigationStack {
            List {
                if konflikte.isEmpty {
                    ContentUnavailableView(
                        "Keine Konflikte",
                        systemImage: "checkmark.shield",
                        description: Text("Lokale Daten und Cloud-Stand stimmen überein.")
                    )
                }
                ForEach(konflikte) { konflikt in
                    Section {
                        LabeledContent("Bereich", value: anzeigename(konflikt.bereich))
                        LabeledContent("Cloud-Stand", value: "Revision \(konflikt.serverRevision)")
                        LabeledContent("Empfangen", value: konflikt.empfangenAm.formatted(date: .abbreviated, time: .shortened))
                        Button("Cloud-Version übernehmen") { uebernehmeCloud(konflikt) }
                        Button("Lokale Version behalten") { behalteLokal(konflikt) }
                    } header: {
                        Label("Änderung auf einem anderen Gerät", systemImage: "arrow.triangle.2.circlepath")
                    } footer: {
                        Text("Es wird nichts automatisch überschrieben. Wähle bewusst, welcher Stand weiterverwendet wird.")
                    }
                }
                if !fehlermeldung.isEmpty {
                    Section { Text(fehlermeldung).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Sync-Konflikte")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func uebernehmeCloud(_ konflikt: SyncKonflikt) {
        fehlermeldung = ""
        Task { @MainActor in
            do {
                if konflikt.vorgangRaw == SyncVorgang.delete.rawValue {
                    try DossierBereichImport.loesche(
                        bereich: konflikt.bereich,
                        dossierID: konflikt.dossierID,
                        in: modelContext
                    )
                } else {
                    guard let payload = konflikt.serverPayload else {
                        throw DossierBereichAdapterFehler.ungueltigerPayload
                    }
                    let adapter = try DossierBereichAdapterRegistry().adapter(fuer: konflikt.bereich)
                    let validiert = try adapter.validiere(payload, schemaVersion: konflikt.schemaVersion)
                    try await DossierBereichImport.importiere(
                        validiert,
                        bereich: konflikt.bereich,
                        dossierID: konflikt.dossierID,
                        in: modelContext
                    )
                }
                try entferneLokalenAuftrag(fuer: konflikt)
                UserDefaults.standard.set(
                    konflikt.serverRevision,
                    forKey: DossierSyncDienst.revisionKey(dossierID: konflikt.dossierID, bereich: konflikt.bereich)
                )
                modelContext.delete(konflikt)
                try modelContext.save()
                NotificationCenter.default.post(name: .dossierSyncAngefordert, object: nil)
            } catch { fehlermeldung = error.localizedDescription }
        }
    }

    private func behalteLokal(_ konflikt: SyncKonflikt) {
        fehlermeldung = ""
        do {
            let schluessel = konflikt.schluessel
            let descriptor = FetchDescriptor<SyncAuftrag>(predicate: #Predicate { $0.schluessel == schluessel })
            let adapter = try DossierBereichAdapterRegistry().adapter(fuer: konflikt.bereich)
            let auftrag: SyncAuftrag
            if let vorhanden = try modelContext.fetch(descriptor).first {
                auftrag = vorhanden
                auftrag.status = .pending
                auftrag.gesperrtSeit = nil
                auftrag.letzterFehler = nil
                auftrag.generation += 1
            } else {
                auftrag = SyncAuftrag(
                    dossierID: konflikt.dossierID,
                    bereich: konflikt.bereich,
                    vorgang: .upsert,
                    schemaVersion: adapter.schemaVersion,
                    erwarteteRevision: konflikt.serverRevision
                )
                modelContext.insert(auftrag)
            }
            auftrag.erwarteteRevision = konflikt.serverRevision
            auftrag.naechsterVersuchAm = Date()
            modelContext.delete(konflikt)
            try modelContext.save()
            NotificationCenter.default.post(name: .dossierSyncAngefordert, object: nil)
        } catch { fehlermeldung = error.localizedDescription }
    }

    private func entferneLokalenAuftrag(fuer konflikt: SyncKonflikt) throws {
        let schluessel = konflikt.schluessel
        let descriptor = FetchDescriptor<SyncAuftrag>(predicate: #Predicate { $0.schluessel == schluessel })
        try modelContext.fetch(descriptor).forEach(modelContext.delete)
    }

    private func anzeigename(_ bereich: String) -> String {
        [
            "profil": "Profil", "gesundheit": "Gesundheit", "wuensche": "Wünsche",
            "finanzen": "Finanzen", "kontakte": "Kontakte",
            "herzensstuecke": "Herzensmenschen", "zugaenge": "Zugänge und Abonnemente"
        ][bereich] ?? bereich
    }
}
