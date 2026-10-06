import SwiftData
import SwiftUI

struct SyncKonfliktHinweis: View {
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""
    @Query private var konflikte: [SyncKonflikt]
    @State private var konfliktAufloesungAnzeigen = false

    private var dossierID: UUID? { UUID(uuidString: aktivesDossierID) }

    private var anzahlKonflikte: Int {
        guard let dossierID else { return 0 }
        return konflikte.filter { $0.dossierID == dossierID }.count
    }

    var body: some View {
        if anzahlKonflikte > 0 {
            Button {
                konfliktAufloesungAnzeigen = true
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Synchronisation benötigt deine Entscheidung")
                            .font(.subheadline.weight(.semibold))
                        Text("Cloud und dieses Gerät enthalten unterschiedliche Daten. Konflikte prüfen")
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.appPrimaryText)
                .padding(14)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.appCanvas)
            .accessibilityIdentifier("syncKonfliktHinweis")
            .sheet(isPresented: $konfliktAufloesungAnzeigen) {
                SyncKonfliktView(dossierID: dossierID)
            }
        }
    }
}

struct SyncKonfliktView: View {
    var dossierID: UUID? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SyncKonflikt.empfangenAm, order: .reverse) private var gespeicherteKonflikte: [SyncKonflikt]
    @State private var fehlermeldung = ""

    private var konflikte: [SyncKonflikt] {
        gespeicherteKonflikte.filter { dossierID == nil || $0.dossierID == dossierID }
    }

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
                        Label("Unterschiedliche Datenstände", systemImage: "arrow.triangle.2.circlepath")
                    } footer: {
                        Text("Die Cloud-Version ersetzt deine lokalen Änderungen in diesem Bereich. Die lokale Version ersetzt den Cloud-Stand dieses Bereichs und wird auf deine anderen Geräte synchronisiert.")
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
