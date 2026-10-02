import SwiftUI
import SwiftData

struct DossierRecoveryView: View {
    private enum Bestaetigungsfeld: Hashable {
        case wortDrei
        case wortSieben
        case wortElf
    }

    private enum WiederherstellungsPhase {
        case bereichePruefen
        case letzteDatenLaden
        case erfolgreich
    }

    @Environment(\.appLayout) private var appLayout
    @Environment(\.modelContext) private var modelContext
    var nurWiederherstellen = false
    var nurErstellen = false
    var kontoEmail = ""
    var abbruchToken: UUID? = nil
    var onDossierZurueckgesetzt: ((UUID) -> Void)? = nil
    var onDatenLaden: (() async -> Bool)? = nil
    var onDatenLadeFehler: (() -> String)? = nil
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
    @FocusState private var fokussiertesBestaetigungsfeld: Bestaetigungsfeld?
    @State private var shareDatei: RecoveryPDFDatei?
    @State private var meldung = ""
    @State private var arbeitet = false
    @State private var recoveryBereitsEingerichtet = false
    @State private var wiederherstellungsFortschrittAnzeigen = false
    @State private var abgeschlosseneWiederherstellungsSchritte = 0
    @State private var wiederherstellungsPhase: WiederherstellungsPhase = .bereichePruefen
    @State private var datenladenAbgeschlossen = false
    @State private var erfolgsSymbolSichtbar = false
    @State private var erfolgsTextSichtbar = false
    @State private var finalisierungsMeldungsIndex = 0
    @State private var notfallResetAnzeigen = false
    @State private var recoveryScannerAnzeigen = false
    @State private var wiederherstellungsTask: Task<Void, Never>?
    @State private var recoverySyncDienst: DossierSyncDienst?

    private let wiederherstellungsSchritte = [
        "Profildaten",
        "Gesundheit",
        "Meine Wünsche",
        "Finanzen",
        "Kontakte",
        "Vertrauenspersonen",
        "Herzensstücke",
        "Abos & Zugänge"
    ]

    private let finalisierungsMeldungen = [
        (symbol: "🚀", titel: "Auf der Zielgeraden – 3", detail: "Auf dem Weg durch die Cloud."),
        (symbol: "🚀", titel: "Auf der Zielgeraden – 2", detail: "Auf dem Weg durch die Cloud."),
        (symbol: "🚀", titel: "Auf der Zielgeraden – 1", detail: "Auf dem Weg durch die Cloud."),
        (symbol: "🌤️", titel: "Restliche Daten aus der Cloud laden", detail: "Einen kleinen Moment noch."),
        (symbol: "📥", titel: "Fast geschafft", detail: "Die letzten Daten werden geladen und sicher eingerichtet.")
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
                        LazyVGrid(columns: recoverySpalten, alignment: .leading, spacing: 10) {
                            ForEach(0..<12, id: \.self) { index in
                                codeWortAnzeige(index: index)
                            }
                        }
                    }
                    }
                }

                if !code.isEmpty {
                    Section("Code bestätigen") {
                        bestaetigungsfelder
                        Button("Als PDF sichern") { exportierePDF() }
                            .disabled(!istBestaetigt)
                        if nurErstellen, istBestaetigt, onNeuerCodeBestaetigt != nil {
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
                    LazyVGrid(columns: recoverySpalten, alignment: .leading, spacing: 10) {
                        ForEach(0..<12, id: \.self) { index in
                            recoveryWortEingabe(index: index)
                        }
                    }
                    Button("Dossier wiederherstellen") { stelleWiederHer() }
                        .disabled(arbeitet || !recoveryCodeVollstaendig)
                    Button {
                        recoveryScannerAnzeigen = true
                    } label: {
                        Label("QR-Code scannen", systemImage: "camera.viewfinder")
                    }
                    .disabled(arbeitet)
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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Dossierwiederherstellungs-Code")
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
        .onChange(of: abbruchToken) { _, _ in
            wiederherstellungsTask?.cancel()
            wiederherstellungsTask = nil
        }
        .onDisappear {
            wiederherstellungsTask?.cancel()
            wiederherstellungsTask = nil
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
        .fullScreenCover(
            isPresented: $recoveryScannerAnzeigen,
            onDismiss: recoveryScannerGeschlossen
        ) {
            QRCodeScannerView(
                ergebnis: recoveryQRCodeUebernehmen,
                abbruch: { recoveryScannerAnzeigen = false }
            )
            .ignoresSafeArea()
        }
    }

    private var recoverySpalten: [GridItem] {
        if appLayout.isCompact || appLayout.dynamicTypeSize >= .xLarge {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    }

    private var bestaetigungsfelder: some View {
        VStack(spacing: 10) {
            bestaetigungsfeld("Wort 3", text: $bestaetigungDrei, fokus: .wortDrei)
            bestaetigungsfeld("Wort 7", text: $bestaetigungSieben, fokus: .wortSieben)
            bestaetigungsfeld("Wort 11", text: $bestaetigungElf, fokus: .wortElf)
        }
    }

    private func bestaetigungsfeld(
        _ titel: String,
        text: Binding<String>,
        fokus: Bestaetigungsfeld
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(titel)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(titel, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($fokussiertesBestaetigungsfeld, equals: fokus)
                .submitLabel(fokus == .wortElf ? .done : .next)
                .onSubmit { fokussiereNaechstesBestaetigungsfeld(nach: fokus) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fokussiereNaechstesBestaetigungsfeld(nach feld: Bestaetigungsfeld) {
        switch feld {
        case .wortDrei: fokussiertesBestaetigungsfeld = .wortSieben
        case .wortSieben: fokussiertesBestaetigungsfeld = .wortElf
        case .wortElf: fokussiertesBestaetigungsfeld = nil
        }
    }

    private func erstelleCode() {
        arbeitet = true
        meldung = ""
        Task {
            do {
                let neuerCode = try await CloudFeldVerschluesselung.shared.recoveryEinrichten()
                let syncDienst: DossierSyncDienst
                if let vorhandenerDienst = DossierSyncDienst.shared {
                    syncDienst = vorhandenerDienst
                } else if let vorbereiteterDienst = recoverySyncDienst {
                    syncDienst = vorbereiteterDienst
                } else {
                    let neuerDienst = try DossierSyncDienst(modelContext: modelContext)
                    neuerDienst.starten()
                    recoverySyncDienst = neuerDienst
                    syncDienst = neuerDienst
                }
                try await syncDienst.recoveryPaketSynchronisieren()
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
        wiederherstellungsTask?.cancel()
        wiederherstellungsTask = Task {
            do {
                try await CloudFeldVerschluesselung.shared.wiederherstellen(
                    mit: recoveryWoerter.joined(separator: " ")
                )
                try Task.checkCancellation()
                recoveryWoerter = Array(repeating: "", count: 12)
                fokussiertesRecoveryWort = nil
                withAnimation(.easeInOut(duration: 0.2)) {
                    wiederherstellungsFortschrittAnzeigen = true
                }
                abgeschlosseneWiederherstellungsSchritte = 0
                wiederherstellungsPhase = .bereichePruefen
                datenladenAbgeschlossen = false
                erfolgsSymbolSichtbar = false
                erfolgsTextSichtbar = false
                let datenLadeTask = Task { @MainActor in
                    let erfolgreich = await ladeDatenNachRecovery()
                    datenladenAbgeschlossen = true
                    return erfolgreich
                }
                defer { datenLadeTask.cancel() }
                await animiereWiederherstellungsFortschritt()
                try Task.checkCancellation()
                if !datenladenAbgeschlossen {
                    finalisierungsMeldungsIndex = 0
                    withAnimation(.easeInOut(duration: bewegungReduzieren ? 0 : 0.3)) {
                        wiederherstellungsPhase = .letzteDatenLaden
                    }
                }
                let finalisierungsTask = Task { @MainActor in
                    guard wiederherstellungsPhase == .letzteDatenLaden else { return }
                    await animiereFinalisierungsMeldungen()
                }
                guard await datenLadeTask.value else {
                    finalisierungsTask.cancel()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        wiederherstellungsFortschrittAnzeigen = false
                    }
                    let genauerFehler = onDatenLadeFehler?() ?? ""
                    if genauerFehler.isEmpty {
                        throw DossierRecoveryFehler.cloudWiederherstellungFehlgeschlagen
                    }
                    throw DossierRecoveryFehler.cloudWiederherstellungMitUrsache(genauerFehler)
                }
                try Task.checkCancellation()
                finalisierungsTask.cancel()

                withAnimation(.easeInOut(duration: bewegungReduzieren ? 0 : 0.28)) {
                    wiederherstellungsPhase = .erfolgreich
                }
                zeigeErfolgreichenAbschluss()
                try await Task.sleep(for: .milliseconds(bewegungReduzieren ? 900 : 1_500))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: bewegungReduzieren ? 0 : 0.22)) {
                    wiederherstellungsFortschrittAnzeigen = false
                }
                meldung = "Erfolgreich wiederhergestellt. Das Dossier wurde aus der Cloud geladen."
                onWiederhergestellt?()
            } catch is CancellationError {
                wiederherstellungsFortschrittAnzeigen = false
            } catch { meldung = error.localizedDescription }
            arbeitet = false
            wiederherstellungsTask = nil
        }
    }

    private var wiederherstellungsFortschritt: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            ScrollView {
                Group {
                    switch wiederherstellungsPhase {
                    case .bereichePruefen:
                        bereichsFortschrittAnsicht
                    case .letzteDatenLaden:
                        letzteDatenAnsicht
                    case .erfolgreich:
                        erfolgreicheWiederherstellungAnsicht
                    }
                }
              .padding(appLayout.cardPadding)
              .frame(maxWidth: 360, alignment: .leading)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
              .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
              .appPagePadding()
              .padding(.vertical, appLayout.pageInset)
            }
        }
    }

    private var bereichsFortschrittAnsicht: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dossier wird geprüft und wiederhergestellt")
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            Text("Alle Bereiche werden geprüft. Vorhandene Daten werden sicher auf dieses Gerät geladen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

                    Text(wiederherstellungsText(titel, index: index))
                        .font(.body.weight(index == abgeschlosseneWiederherstellungsSchritte ? .semibold : .regular))
                        .foregroundStyle(index <= abgeschlosseneWiederherstellungsSchritte ? Color.primary : Color.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .padding(.top, 3)
                }
            }
        }
    }

    private var letzteDatenAnsicht: some View {
        let meldung = finalisierungsMeldungen[finalisierungsMeldungsIndex]
        return VStack(spacing: 18) {
            Text(meldung.symbol)
                .font(.system(size: 54))
                .contentTransition(.numericText())
            VStack(spacing: 8) {
                Text(meldung.titel)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(meldung.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProgressView()
                .controlSize(.regular)
                .tint(Color.appAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .id(finalisierungsMeldungsIndex)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private var erfolgreicheWiederherstellungAnsicht: some View {
        VStack(spacing: appLayout.sectionSpacing) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 118, height: 118)
                    .scaleEffect(erfolgsSymbolSichtbar ? 1 : 0.55)
                    .opacity(erfolgsSymbolSichtbar ? 1 : 0)

                Circle()
                    .stroke(Color.green.opacity(0.18), lineWidth: 1)
                    .frame(width: 94, height: 94)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(Color.green)
                    .symbolEffect(.bounce, value: erfolgsSymbolSichtbar)
                    .scaleEffect(erfolgsSymbolSichtbar ? 1 : 0.25)
                    .opacity(erfolgsSymbolSichtbar ? 1 : 0)
            }

            VStack(spacing: 10) {
                Text("Alles bereit")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appPrimaryText)
                Text("Dein Dossier wurde erfolgreich wiederhergestellt.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(erfolgsTextSichtbar ? 1 : 0)
            .offset(y: erfolgsTextSichtbar ? 0 : 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func animiereWiederherstellungsFortschritt() async {
        let pause: Duration = .seconds(bewegungReduzieren ? 1 : 3)
        for schritt in 1...wiederherstellungsSchritte.count {
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            withAnimation(bewegungReduzieren ? nil : .easeInOut(duration: 0.3)) {
                abgeschlosseneWiederherstellungsSchritte = schritt
            }
        }
    }

    private func animiereFinalisierungsMeldungen() async {
        while !Task.isCancelled {
            let pause: Duration = finalisierungsMeldungsIndex < 3 ? .seconds(1) : .seconds(3)
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            let naechsterIndex: Int
            if finalisierungsMeldungsIndex < finalisierungsMeldungen.count - 1 {
                naechsterIndex = finalisierungsMeldungsIndex + 1
            } else {
                naechsterIndex = 3
            }
            withAnimation(.easeInOut(duration: bewegungReduzieren ? 0 : 0.35)) {
                finalisierungsMeldungsIndex = naechsterIndex
            }
        }
    }

    private func wiederherstellungsText(_ titel: String, index: Int) -> String {
        if index < abgeschlosseneWiederherstellungsSchritte {
            return "\(titel) geprüft"
        }
        if index == abgeschlosseneWiederherstellungsSchritte {
            return "\(titel) wird geprüft …"
        }
        return titel
    }

    private func zeigeErfolgreichenAbschluss() {
        withAnimation(bewegungReduzieren ? nil : .spring(response: 0.52, dampingFraction: 0.68)) {
            erfolgsSymbolSichtbar = true
        }
        withAnimation(.easeOut(duration: bewegungReduzieren ? 0 : 0.38).delay(bewegungReduzieren ? 0 : 0.22)) {
            erfolgsTextSichtbar = true
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

    private func recoveryQRCodeUebernehmen(_ inhalt: String) {
        recoveryScannerAnzeigen = false
        do {
            let normalisiert = try DossierRecoveryCode.ausQRCode(inhalt)
            verteiltRecoveryCode = true
            recoveryWoerter = normalisiert.split(separator: " ").map(String.init)
            verteiltRecoveryCode = false
            fokussiertesRecoveryWort = nil
            meldung = "Erfolgreich erkannt. Prüfe die zwölf Wörter und starte anschliessend die Wiederherstellung."
        } catch {
            meldung = "Dieser QR-Code ist kein gültiger Tschlüssli-Wiederherstellungscode."
        }
    }

    private func recoveryScannerGeschlossen() {
        fokussiertesRecoveryWort = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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
