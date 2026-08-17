import SwiftUI

struct DossierRecoveryView: View {
    @State private var code = ""
    @State private var bestaetigungDrei = ""
    @State private var bestaetigungSieben = ""
    @State private var bestaetigungElf = ""
    @State private var recoveryWoerter = Array(repeating: "", count: 12)
    @State private var verteiltRecoveryCode = false
    @FocusState private var fokussiertesRecoveryWort: Int?
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
    private var recoveryCodeVollstaendig: Bool {
        recoveryWoerter.count == 12 && recoveryWoerter.allSatisfy {
            DossierRecoveryCode.woerter.contains($0.lowercased())
        }
    }

    var body: some View {
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
                    Text("Gib die Wörter in derselben Reihenfolge wie im PDF ein. Du kannst den gesamten Code auch in das erste Feld einfügen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(0..<12, id: \.self) { index in
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            TextField("Wort \(index + 1)", text: $recoveryWoerter[index])
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($fokussiertesRecoveryWort, equals: index)
                                .foregroundStyle(istRecoveryWortUngueltig(index) ? Color.red : Color.primary)
                                .onChange(of: recoveryWoerter[index]) { _, neuerWert in
                                    verarbeiteRecoveryEingabe(neuerWert, bei: index)
                                }
                            if !recoveryWoerter[index].isEmpty {
                                Image(systemName: istRecoveryWortUngueltig(index) ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(istRecoveryWortUngueltig(index) ? Color.red : Color.green)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    Button("Schlüssel wiederherstellen") { stelleWiederHer() }
                        .disabled(arbeitet || !recoveryCodeVollstaendig)
                }

                if !meldung.isEmpty {
                    Section { Text(meldung).foregroundStyle(meldung.hasPrefix("Erfolgreich") ? .green : .red) }
                }
        }
        .navigationTitle("Dossier-Schlüssel")
        .navigationBarTitleDisplayMode(.inline)
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
                try await CloudFeldVerschluesselung.shared.wiederherstellen(
                    mit: recoveryWoerter.joined(separator: " ")
                )
                recoveryWoerter = Array(repeating: "", count: 12)
                fokussiertesRecoveryWort = nil
                meldung = "Erfolgreich wiederhergestellt. Die verschlüsselten Daten werden erneut geladen."
                NotificationCenter.default.post(name: .dossierRecoveryGeaendert, object: nil)
            } catch { meldung = error.localizedDescription }
            arbeitet = false
        }
    }

    private func istRecoveryWortUngueltig(_ index: Int) -> Bool {
        let wort = recoveryWoerter[index].lowercased()
        return !wort.isEmpty && !DossierRecoveryCode.woerter.contains(wort)
    }

    private func verarbeiteRecoveryEingabe(_ eingabe: String, bei index: Int) {
        guard !verteiltRecoveryCode else { return }
        let teile = eingabe
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)

        if teile.count > 1 {
            verteiltRecoveryCode = true
            for ziel in 0..<12 {
                recoveryWoerter[ziel] = ziel < teile.count ? teile[ziel] : ""
            }
            verteiltRecoveryCode = false
            fokussiertesRecoveryWort = teile.count >= 12 ? nil : min(teile.count, 11)
            return
        }

        let normalisiert = eingabe
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalisiert != eingabe {
            verteiltRecoveryCode = true
            recoveryWoerter[index] = normalisiert
            verteiltRecoveryCode = false
        }
        if DossierRecoveryCode.woerter.contains(normalisiert), index < 11 {
            fokussiertesRecoveryWort = index + 1
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
