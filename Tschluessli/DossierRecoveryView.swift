import SwiftUI

struct DossierRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var bestaetigungDrei = ""
    @State private var bestaetigungSieben = ""
    @State private var bestaetigungElf = ""
    @State private var recoveryEingabe = ""
    @State private var shareURL: URL?
    @State private var meldung = ""
    @State private var arbeitet = false
    @State private var recoveryBereitsEingerichtet = false

    private var woerter: [String] { code.split(separator: " ").map(String.init) }
    private var istBestaetigt: Bool {
        woerter.count == 12
            && bestaetigungDrei.lowercased() == woerter[2]
            && bestaetigungSieben.lowercased() == woerter[6]
            && bestaetigungElf.lowercased() == woerter[10]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wiederherstellungscode") {
                    Text("Die 12 Wörter schützen den Schlüssel deiner verschlüsselten Zugangsdaten. Bewahre sie offline auf.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if code.isEmpty {
                        if recoveryBereitsEingerichtet {
                            Text("Ein Wiederherstellungscode wurde bereits eingerichtet. Ein neuer Code macht das bisherige PDF ungültig.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        Button(recoveryBereitsEingerichtet ? "Neuen 12-Wörter-Code erstellen" : "12 Wörter erstellen") { erstelleCode() }
                            .disabled(arbeitet)
                    } else {
                        ForEach(Array(woerter.enumerated()), id: \.offset) { index, wort in
                            LabeledContent("\(index + 1)", value: wort)
                                .fontDesign(.monospaced)
                        }
                    }
                }

                if !code.isEmpty {
                    Section("Code bestätigen") {
                        TextField("Wort 3", text: $bestaetigungDrei)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Wort 7", text: $bestaetigungSieben)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Wort 11", text: $bestaetigungElf)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Als PDF sichern") { exportierePDF() }
                            .disabled(!istBestaetigt)
                        Text("Das PDF enthält den vollständigen Schlüssel. Speichere es nicht in einem ungeschützten Cloud-Ordner und versende es nicht per E-Mail oder Chat.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Auf diesem Gerät wiederherstellen") {
                    TextField("12 Wörter eingeben", text: $recoveryEingabe, axis: .vertical)
                        .lineLimit(4...7)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Schlüssel wiederherstellen") { stelleWiederHer() }
                        .disabled(arbeitet || recoveryEingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !meldung.isEmpty {
                    Section { Text(meldung).foregroundStyle(meldung.hasPrefix("Erfolgreich") ? .green : .red) }
                }
            }
            .navigationTitle("Dossier-Schlüssel")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(item: Binding(
                get: { shareURL.map(RecoveryPDFDatei.init) },
                set: { if $0 == nil { shareURL = nil } }
            ), onDismiss: {
                if let shareURL { try? FileManager.default.removeItem(at: shareURL) }
                shareURL = nil
            }) { datei in
                ShareSheet(activityItems: [datei.url])
            }
            .task {
                recoveryBereitsEingerichtet = await CloudFeldVerschluesselung.shared.hatRecoveryPaket()
            }
        }
    }

    private func erstelleCode() {
        arbeitet = true
        meldung = ""
        Task {
            do {
                code = try await CloudFeldVerschluesselung.shared.recoveryEinrichten()
                recoveryBereitsEingerichtet = true
                NotificationCenter.default.post(name: .dossierRecoveryGeaendert, object: nil)
            } catch { meldung = error.localizedDescription }
            arbeitet = false
        }
    }

    private func exportierePDF() {
        do { shareURL = try DossierRecoveryPDF.erstellen(code: code) }
        catch { meldung = error.localizedDescription }
    }

    private func stelleWiederHer() {
        arbeitet = true
        meldung = ""
        Task {
            do {
                try await CloudFeldVerschluesselung.shared.wiederherstellen(mit: recoveryEingabe)
                recoveryEingabe = ""
                meldung = "Erfolgreich wiederhergestellt. Die verschlüsselten Daten werden erneut geladen."
                NotificationCenter.default.post(name: .dossierRecoveryGeaendert, object: nil)
            } catch { meldung = error.localizedDescription }
            arbeitet = false
        }
    }
}

private nonisolated struct RecoveryPDFDatei: Identifiable {
    let id = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}

extension Notification.Name {
    static let dossierRecoveryGeaendert = Notification.Name("Tschluessli.DossierRecoveryGeaendert")
}
