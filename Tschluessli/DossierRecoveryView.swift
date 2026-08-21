import SwiftUI

struct DossierRecoveryView: View {
    var nurWiederherstellen = false
    var nurErstellen = false
    var kontoEmail = ""
    var onDossierZurueckgesetzt: ((UUID) -> Void)? = nil
    var onDatenLaden: (() async -> Bool)? = nil
    var onWiederhergestellt: (() -> Void)? = nil
    var onNeuerCodeBestaetigt: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var bewegungReduzieren
    @AppStorage("systemdialogImProfilLaeuft") private var systemdialogImProfilLaeuft = false
    @State private var code = ""
    @State private var bestaetigungDrei = ""
    @State private var bestaetigungSieben = ""
    @State private var bestaetigungElf = ""
    @State private var recoveryWoerter = Array(repeating: "", count: 12)
    @State private var verteiltRecoveryCode = false
    @FocusState private var fokussiertesRecoveryWort: Int?
    @State private var shareDatei: RecoveryPDFDatei?
    @State private var meldung = ""
    @State private var arbeitet = false
    @State private var recoveryBereitsEingerichtet = false
    @State private var wiederherstellungsFortschrittAnzeigen = false
    @State private var abgeschlosseneWiederherstellungsSchritte = 0
    @State private var notfallResetAnzeigen = false

    private let wiederherstellungsSchritte = [
        "Profildaten prüfen und laden",
        "Gesundheit prüfen und laden",
        "Meine Wünsche prüfen und laden",
        "Finanzen prüfen und laden",
        "Kontakte prüfen und laden",
        "Herzensstücke prüfen und laden",
        "Abos & Zugänge prüfen und laden"
    ]

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
                if !nurWiederherstellen {
                    Section("Wiederherstellungscode") {
                    Text("Die 12 Wörter schützen den Schlüssel deiner verschlüsselten Zugangsdaten. Bewahre sie offline und an einem sicheren Ort auf auf.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if code.isEmpty {
                        if recoveryBereitsEingerichtet {
                            Text("Ein Wiederherstellungscode wurde bereits eingerichtet. Ein neuer Code macht den bisherigen Schlüssel und PDF ungültig.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        Button(recoveryBereitsEingerichtet ? "Neuen 12-Wörter-Code erstellen" : "12 Wörter erstellen") { erstelleCode() }
                            .disabled(arbeitet)
                    } else {
                        Grid(horizontalSpacing: 18, verticalSpacing: 10) {
                            ForEach(0..<6, id: \.self) { zeile in
                                GridRow {
                                    codeWortAnzeige(index: zeile)
                                    codeWortAnzeige(index: zeile + 6)
                                }
                            }
                        }
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
                        if nurErstellen && istBestaetigt {
                            Button("Mit neuem Dossier fortfahren") {
                                onNeuerCodeBestaetigt?()
                            }
                            .fontWeight(.semibold)
                        }
                        Text("Das PDF enthält den vollständigen Schlüssel. Speichere es nicht in einem ungeschützten Cloud-Ordner und versende es nicht per E-Mail oder Chat.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                if !nurErstellen {
                Section("Dein Dossier auf diesem Gerät wiederherstellen") {
                    Text("Gib die zwölf Wörter einzeln und in derselben Reihenfolge wie im PDF ein.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                        ForEach(0..<6, id: \.self) { zeile in
                            GridRow {
                                recoveryWortEingabe(index: zeile)
                                recoveryWortEingabe(index: zeile + 6)
                            }
                        }
                    }
                    Button("Dossier wiederherstellen") { stelleWiederHer() }
                        .disabled(arbeitet || !recoveryCodeVollstaendig)
                    if nurWiederherstellen, onDossierZurueckgesetzt != nil {
                        Button("Wiederherstellungscode nicht mehr vorhanden?") {
                            notfallResetAnzeigen = true
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                }

                if !meldung.isEmpty {
                    Section { Text(meldung).foregroundStyle(meldung.hasPrefix("Erfolgreich") ? .green : .red) }
                }
        }
        .navigationTitle("Dossierwiederherstellungs-Schlüssel")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareDatei, onDismiss: {
            shareDatei = nil
            systemdialogImProfilLaeuft = false
        }) { datei in
            ShareSheet(activityItems: [datei.url]) {
                try? FileManager.default.removeItem(at: datei.url)
            }
        }
        .task {
            recoveryBereitsEingerichtet = await CloudFeldVerschluesselung.shared.hatRecoveryPaket()
        }
        .overlay {
            if wiederherstellungsFortschrittAnzeigen {
                wiederherstellungsFortschritt
                    .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(wiederherstellungsFortschrittAnzeigen)
        .sheet(isPresented: $notfallResetAnzeigen) {
            if let onDossierZurueckgesetzt {
                DossierNotfallResetView(email: kontoEmail) { dossierID in
                    notfallResetAnzeigen = false
                    onDossierZurueckgesetzt(dossierID)
                }
            }
        }
    }

    private func erstelleCode() {
        arbeitet = true
        meldung = ""
        Task {
            do {
                let neuerCode = try await CloudFeldVerschluesselung.shared.recoveryEinrichten()
                guard let syncDienst = DossierSyncDienst.shared,
                      await syncDienst.recoveryPaketSynchronisieren() else {
                    throw DossierRecoveryFehler.recoveryNichtSynchronisiert
                }
                code = neuerCode
                recoveryBereitsEingerichtet = true
            } catch { meldung = error.localizedDescription }
            arbeitet = false
        }
    }

    private func exportierePDF() {
        systemdialogImProfilLaeuft = true
        do {
            shareDatei = RecoveryPDFDatei(try DossierRecoveryPDF.erstellen(code: code))
        } catch {
            systemdialogImProfilLaeuft = false
            meldung = error.localizedDescription
        }
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    wiederherstellungsFortschrittAnzeigen = true
                }
                abgeschlosseneWiederherstellungsSchritte = 0
                async let datenGeladen = ladeDatenNachRecovery()
                await animiereWiederherstellungsFortschritt()
                guard await datenGeladen else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        wiederherstellungsFortschrittAnzeigen = false
                    }
                    throw DossierRecoveryFehler.cloudWiederherstellungFehlgeschlagen
                }
                withAnimation(.easeInOut(duration: bewegungReduzieren ? 0 : 0.22)) {
                    wiederherstellungsFortschrittAnzeigen = false
                }
                meldung = "Erfolgreich wiederhergestellt. Das Dossier wurde aus der Cloud geladen."
                onWiederhergestellt?()
            } catch { meldung = error.localizedDescription }
            arbeitet = false
        }
    }

    private var wiederherstellungsFortschritt: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Dossier wird wiederhergestellt")
                    .font(.title3.weight(.bold))
                    .padding(.bottom, 6)
                Text("Bereiche werden geprüft und etwaige Daten geladen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 22)

                ForEach(Array(wiederherstellungsSchritte.enumerated()), id: \.offset) { index, titel in
                    HStack(alignment: .top, spacing: 13) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(index < abgeschlosseneWiederherstellungsSchritte ? Color.green : Color.secondary.opacity(0.14))
                                    .frame(width: 27, height: 27)
                                if index < abgeschlosseneWiederherstellungsSchritte {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                } else if index == abgeschlosseneWiederherstellungsSchritte {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }

                            if index < wiederherstellungsSchritte.count - 1 {
                                Rectangle()
                                    .fill(index < abgeschlosseneWiederherstellungsSchritte ? Color.green.opacity(0.65) : Color.secondary.opacity(0.16))
                                    .frame(width: 2, height: 25)
                            }
                        }

                        Text(titel)
                            .font(.body.weight(index == abgeschlosseneWiederherstellungsSchritte ? .semibold : .regular))
                            .foregroundStyle(index <= abgeschlosseneWiederherstellungsSchritte ? Color.primary : Color.secondary)
                            .padding(.top, 3)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 360, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
            .padding(24)
        }
    }

    private func animiereWiederherstellungsFortschritt() async {
        let pause: Duration = .seconds(1)
        for schritt in 1...wiederherstellungsSchritte.count {
            try? await Task.sleep(for: pause)
            withAnimation(bewegungReduzieren ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                abgeschlosseneWiederherstellungsSchritte = schritt
            }
        }
    }

    private func ladeDatenNachRecovery() async -> Bool {
        if let onDatenLaden {
            return await onDatenLaden()
        }
        NotificationCenter.default.post(name: .dossierRecoveryWiederhergestellt, object: nil)
        return true
    }

    private func istRecoveryWortUngueltig(_ index: Int) -> Bool {
        let wort = recoveryWoerter[index].lowercased()
        return !wort.isEmpty && !DossierRecoveryCode.woerter.contains(wort)
    }

    @ViewBuilder
    private func codeWortAnzeige(index: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(index + 1).")
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(woerter[index])
                .fontDesign(.monospaced)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func recoveryWortEingabe(index: Int) -> some View {
        HStack(spacing: 5) {
            Text("\(index + 1).")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
            TextField("Wort", text: $recoveryWoerter[index])
                .font(.caption)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($fokussiertesRecoveryWort, equals: index)
                .foregroundStyle(istRecoveryWortUngueltig(index) ? Color.red : Color.primary)
                .onChange(of: recoveryWoerter[index]) { _, neuerWert in
                    verarbeiteRecoveryEingabe(neuerWert, bei: index)
                }
            if istRecoveryWortUngueltig(index) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
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
    let url: URL
    var id: URL { url }
    init(_ url: URL) { self.url = url }
}

extension Notification.Name {
    static let dossierRecoveryEingerichtet = Notification.Name("Tschluessli.DossierRecoveryEingerichtet")
    static let dossierRecoveryWiederhergestellt = Notification.Name("Tschluessli.DossierRecoveryWiederhergestellt")
    static let dossierSyncAngefordert = Notification.Name("Tschluessli.DossierSyncAngefordert")
}
