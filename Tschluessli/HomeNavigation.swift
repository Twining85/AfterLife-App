import SwiftUI
import SwiftData
import UIKit

struct HomeNavigation: View {
    @Environment(\.appLayout) private var appLayout
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("homeAktiveBereiche") private var homeAktiveBereiche = ""
    @AppStorage("dossierZuletztGeprueftAmISO") private var dossierZuletztGeprueftAmISO = ""
    @AppStorage("dossierLetzterExportAmISO") private var dossierLetzterExportAmISO = ""
    @AppStorage("jaehrlicheVorsorgeErinnerungAktiv") private var erinnerungAktiv = true
    @AppStorage(VorsorgeBereichStatusStore.storageKey) private var vorsorgeBereichStatusJSON = ""
    @AppStorage("dossierErstellungsart") private var dossierErstellungsartRawValue = ""
    @AppStorage("uebersprungeneDossierSchritte") private var uebersprungeneDossierSchritte = ""
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteDossiers: [DossierModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]
    @Query private var gespeicherteGesundheitsdaten: [GesundheitModell]
    @Query private var gespeicherteVertrauenspersonen: [VertrauenspersonModell]
    @Query private var gespeicherteBankkonten: [BankkontoModell]
    @Query private var gespeicherteSchulden: [SchuldenModell]
    @Query private var gespeicherteVersicherungen: [VersicherungModell]
    @Query private var gespeicherteLiegenschaften: [LiegenschaftModell]
    @Query private var gespeicherteWertsachen: [WertsacheModell]
    @Query private var gespeicherteSteuerdokumente: [SteuerdokumentModell]
    @Query private var gespeicherteDokumente: [DokumenteModell]
    @Query private var gespeicherteFotos: [FotoalbumBildModell]
    @Query private var gespeicherteHerzensstuecke: [HerzensstueckModell]
    @Query private var gespeicherteAbos: [AboModell]
    @Query private var gespeicherteWuensche: [WuenscheModell]
    @Query private var gespeicherteHinterbliebene: [HinterbliebeneModell]

    @State private var ziel: HomeNavigationZiel?
    @State private var erinnerungenAnzeigen = false
    @State private var exportAnzeigen = false
    @State private var syncKonflikteAnzeigen = false
    @State private var orbitAnimationsFortschritt: CGFloat = 0
    @State private var animationWurdeAbgespielt = false
    @State private var satellitenVerschiebungen: [HomeNavigationKnoten: CGSize] = [:]
    @State private var gezogenerSatellit: HomeNavigationKnoten?
    @State private var bereicheGlowHervorgehoben = false
    @State private var temporaereErstellungsart: DossierErstellungsart = .gefuehrt
    @State private var recoveryStatusGeladen = false
    @State private var recoveryVorhanden = false
    @State private var zugriffsFehler = ""

    private let akzent = Color.appAccent
    private let hintergrund = Color.appCanvas

    /// Etwas präsenter als das appweite Standard-Profilbild, ohne dem Text
    /// auf kompakten Displays zu viel Breite zu entziehen.
    private var homeProfilbildGroesse: CGFloat {
        appLayout.profileImageSize + (appLayout.dynamicTypeSize >= .xxLarge ? 4 : 8)
    }

    private var aktivesProfil: ProfilModell? {
        guard let userID = UUID(uuidString: aktiveUserID) else { return nil }
        return gespeicherteProfile.first { $0.userID == userID }
    }

    private var anzeigename: String {
        let vorname = aktivesProfil?.vorname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return vorname.isEmpty ? "Willkommen" : vorname
    }

    private var eigeneVertrauenspersonZugriffe: [DossierZugriffModell] {
        guard let userID = UUID(uuidString: aktiveUserID) else { return [] }
        return gespeicherteDossierZugriffe.filter { $0.vertrauenspersonUserID == userID }
    }

    private var freigegebeneDossiers: [DossierZugriffModell] {
        eigeneVertrauenspersonZugriffe.filter {
            ($0.istAktiv || $0.status == DossierZugriffStatus.widerrufen) && [
                DossierZugriffStatus.erstellt,
                DossierZugriffStatus.bestaetigungAusstehend,
                DossierZugriffStatus.angenommen,
                DossierZugriffStatus.abgelehnt,
                DossierZugriffStatus.freigegeben,
                DossierZugriffStatus.widerrufen
            ].contains($0.status)
        }
    }

    private var offeneErweiterungsanfragen: [DossierZugriffModell] {
        guard let userID = UUID(uuidString: aktiveUserID) else { return [] }
        return gespeicherteDossierZugriffe.filter {
            $0.istAktiv &&
                $0.vorsorgendeUserID == userID &&
                $0.status == DossierZugriffStatus.bestaetigungAusstehend
        }
    }

    private var dossierVonAnderenUntertitel: String {
        let anzahl = freigegebeneDossiers.filter {
            $0.istAktiv && $0.status != DossierZugriffStatus.widerrufen
        }.count
        return anzahl > 0 ? "(\(anzahl))" : "QR-Code scannen"
    }

    private var eigeneVertrauenspersonen: [VertrauenspersonModell] {
        guard let profil = aktivesProfil else { return [] }
        return gespeicherteVertrauenspersonen.filter {
            ((profil.dossierID != nil && $0.dossierID == profil.dossierID)
                || $0.vorsorgendeUserID == profil.userID)
                && $0.istLokalHinterlegt
        }
    }

    private var hatVerbundeneVertrauensperson: Bool {
        guard let profil = aktivesProfil else { return false }

        let hatAusgehendeVerbindung = gespeicherteDossierZugriffe.contains {
            profil.dossierID != nil
                && $0.dossierID == profil.dossierID
                && $0.vorsorgendeUserID == profil.userID
                && $0.istAktiv
                && $0.vertrauenspersonUserID != nil
                && $0.status != DossierZugriffStatus.widerrufen
        }
        let hatLegacyVerbindung = eigeneVertrauenspersonen.contains {
            $0.vertrauenspersonUserID != nil && $0.einladungAngenommenAm != nil
        }
        return hatAusgehendeVerbindung || hatLegacyVerbindung
    }

    private var teilenUntertitel: String {
        if hatVerbundeneVertrauensperson {
            return "Vertrauensperson verwalten"
        }
        guard !eigeneVertrauenspersonen.isEmpty else {
            return HomeNavigationKnoten.teilen.untertitel
        }
        return "Vertrauensperson einladen"
    }

    private func untertitel(fuer knoten: HomeNavigationKnoten) -> String {
        switch knoten {
        case .teilen: teilenUntertitel
        case .dossierVon: dossierVonAnderenUntertitel
        default: knoten.untertitel
        }
    }

    private func besitzerProfil(fuer zugriff: DossierZugriffModell) -> ProfilModell? {
        gespeicherteProfile.first { $0.userID == zugriff.vorsorgendeUserID }
    }

    private func besitzerName(fuer zugriff: DossierZugriffModell) -> String {
        if let name = zugriff.vorsorgendePersonName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty { return name }
        if let profil = besitzerProfil(fuer: zugriff) {
            let name = "\(profil.vorname) \(profil.name)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return "einer vertrauten Person"
    }

    private var begruessung: String {
        let stunde = Calendar.current.component(.hour, from: Date())
        if stunde < 13 { return "Guten Morgen," }
        if stunde < 18 { return "Guten Nachmittag," }
        return "Guten Abend,"
    }

    private var anzahlGewaehlteVorsorgeBereiche: Int {
        let gueltigeBereiche: Set<String> = [
            "hinterbliebene", "wuensche", "finanzen", "dokumente",
            "abos", "herzensstuecke", "gesundheit"
        ]
        return Set(
            homeAktiveBereiche
                .split(separator: ",")
                .map(String.init)
                .filter { gueltigeBereiche.contains($0) }
        ).count
    }

    private var dossierErstellungsart: DossierErstellungsart? {
        DossierErstellungsart(rawValue: dossierErstellungsartRawValue)
    }

    private var uebersprungeneSchritte: Set<String> {
        Set(uebersprungeneDossierSchritte.split(separator: ",").map(String.init))
    }

    private var profilGrundlageVollstaendig: Bool {
        guard let profil = aktivesProfil else { return false }
        let adresse = [profil.strasse, profil.hausnummer]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !profil.vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profil.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !adresse.isEmpty
            && !profil.plz.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profil.stadt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var aktiveGefuehrteBereiche: [VorsorgeBereichID] {
        let erlaubteBereiche = Set(VorsorgeBereichID.allCases).subtracting([.profil])
        var gesehen: Set<VorsorgeBereichID> = []
        return homeAktiveBereiche
            .split(separator: ",")
            .compactMap { VorsorgeBereichID(rawValue: String($0)) }
            .filter { erlaubteBereiche.contains($0) && gesehen.insert($0).inserted }
    }

    private var naechsterGefuehrterSchritt: GefuehrterDossierSchritt? {
        let uebersprungen = uebersprungeneSchritte

        if !profilGrundlageVollstaendig, !uebersprungen.contains(GefuehrterDossierSchritt.profil.id) {
            return .profil
        }
        if recoveryStatusGeladen,
           !recoveryVorhanden,
           !uebersprungen.contains(GefuehrterDossierSchritt.recovery.id) {
            return .recovery
        }
        if aktiveGefuehrteBereiche.isEmpty,
           !uebersprungen.contains(GefuehrterDossierSchritt.bereiche.id) {
            return .bereiche
        }
        if let bereich = aktiveGefuehrteBereiche.first(where: {
            !VorsorgeBereichStatusStore.status(fuer: $0, dossierID: aktivesProfil?.dossierID?.uuidString).wurdeBegonnen
                && !uebersprungen.contains(GefuehrterDossierSchritt.bereich($0).id)
        }) {
            return .bereich(bereich)
        }
        let hatVertrauensperson = gespeicherteVertrauenspersonen.contains {
            $0.vorsorgendeUserID == aktivesProfil?.userID && $0.istLokalHinterlegt
        }
        if !hatVertrauensperson,
           !uebersprungen.contains(GefuehrterDossierSchritt.vertrauensperson.id) {
            return .vertrauensperson
        }
        return nil
    }

    private var anzahlBereicheMitDaten: Int {
        guard let dossierID = aktivesProfil?.dossierID else { return 0 }

        let gesundheitBereit = gespeicherteGesundheitsdaten.contains { $0.dossierID == dossierID }
        let wuenscheBereit = gespeicherteWuensche.contains { $0.dossierID == dossierID }
        let vertrauenspersonenBereit = gespeicherteVertrauenspersonen.contains {
            $0.dossierID == dossierID
                && $0.vorsorgendeUserID == aktivesProfil?.userID
                && $0.istLokalHinterlegt
        }
        let finanzenBereit = gespeicherteBankkonten.contains { $0.dossierID == dossierID }
            || gespeicherteSchulden.contains { $0.dossierID == dossierID }
            || gespeicherteVersicherungen.contains { $0.dossierID == dossierID }
            || gespeicherteLiegenschaften.contains { $0.dossierID == dossierID }
            || gespeicherteWertsachen.contains { $0.dossierID == dossierID }
            || gespeicherteSteuerdokumente.contains { $0.dossierID == dossierID }
        let abosBereit = gespeicherteAbos
            .filter { $0.dossierID == dossierID }
            .contains { modell in modell.abos.contains { !$0.istSystemEintrag } }
        let dokumenteBereit = gespeicherteDokumente.contains { $0.dossierID == dossierID }
            || gespeicherteFotos.contains { $0.dossierID == dossierID }
        let herzensstueckeBereit = gespeicherteHerzensstuecke.contains { $0.dossierID == dossierID }

        return [
            gesundheitBereit,
            wuenscheBereit,
            vertrauenspersonenBereit,
            finanzenBereit,
            abosBereit,
            dokumenteBereit,
            herzensstueckeBereit
        ].filter { $0 }.count
    }

    private var aktiveGesundheitsdaten: GesundheitModell? {
        guard let profil = aktivesProfil else { return nil }
        return gespeicherteGesundheitsdaten.first { $0.userID == profil.userID }
            ?? gespeicherteGesundheitsdaten.first { $0.dossierID == profil.dossierID }
    }

    private var fortschritt: Double {
        DynamischerDossierFortschrittService.berechne(
            profil: aktivesProfil,
            gesundheit: aktiveGesundheitsdaten,
            wuensche: gespeicherteWuensche,
            hinterbliebene: gespeicherteHinterbliebene,
            bankkonten: gespeicherteBankkonten,
            schulden: gespeicherteSchulden,
            versicherungen: gespeicherteVersicherungen,
            liegenschaften: gespeicherteLiegenschaften,
            wertsachen: gespeicherteWertsachen,
            steuerdokumente: gespeicherteSteuerdokumente,
            dokumente: gespeicherteDokumente,
            fotos: gespeicherteFotos,
            abos: gespeicherteAbos,
            herzensstuecke: gespeicherteHerzensstuecke,
            aktiveBereiche: Set(
                homeAktiveBereiche
                    .split(separator: ",")
                    .compactMap { VorsorgeBereichID(rawValue: String($0)) }
            )
        )
    }

    private var wurdeGeprueft: Bool {
        guard let datum = ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO) else { return false }
        let jahreSeitPruefung = Calendar.current.dateComponents([.year], from: datum, to: Date()).year ?? 1
        return jahreSeitPruefung < 1
    }

    private var letzterExport: Date? {
        ISO8601DateFormatter().date(from: dossierLetzterExportAmISO)
    }

    private var vorsorgeStatus: VorsorgeStatus {
        VorsorgeStatusService.berechne(
            vollstaendigkeit: fortschritt,
            wurdeGeprueft: wurdeGeprueft,
            letzterExportAm: letzterExport,
            letzteInhaltlicheAenderungAm: nil,
            hatOffeneEinladung: false,
            hatAktiveVertrauensperson: !gespeicherteVertrauenspersonen.isEmpty
        )
    }

    private var istVorsorgeStart: Bool {
        aktiveGefuehrteBereiche.isEmpty && !profilGrundlageVollstaendig
    }

    private var heroStatusTitel: String {
        istVorsorgeStart ? "Deine Vorsorge beginnt jetzt" : vorsorgeStatus.titel
    }

    private var heroStatusBeschreibung: String {
        istVorsorgeStart
            ? "Nimm dir Zeit, dein Vorsorge-Dossier in Ruhe auszufüllen."
            : vorsorgeStatus.beschreibung
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    Group {
                        if appLayout.prefersLinearNavigation {
                            VStack(spacing: 12) {
                                hero
                                footerLogo
                                    .padding(.bottom, 6)
                            }
                        } else {
                            ZStack(alignment: .bottom) {
                                hero
                                footerLogo
                                    .padding(.bottom, 6)
                            }
                        }
                    }
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .refreshable {
                    let anzahlKonflikte = await DossierSyncDienst.shared?.manuellerVollabgleich() ?? 0
                    if anzahlKonflikte > 0 {
                        syncKonflikteAnzeigen = true
                    }
                }
            }
            .background(hintergrund.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(item: $ziel) { ziel in
                switch ziel {
                case .profil: ProfilView()
                case .bereiche: VorsorgeBereicheView()
                case .bereicheVerwalten: VorsorgeBereicheView(startetMitVerwaltung: true)
                case .teilen: VertrauenspersonView()
                case .dossierVon: dossierVonAnderenBereich
                case .recovery: DossierRecoveryView(nurErstellen: true)
                case .gesundheit: GesundheitView()
                case .wuensche: WuenscheView()
                case .finanzen: FinanzenView()
                case .hinterbliebene: HinterbliebeneView()
                case .dokumente: DokumenteView()
                case .abos: AbosView()
                case .herzensstuecke: HerzensstueckeView()
                }
            }
            .sheet(isPresented: $exportAnzeigen) {
                ProfilView(dossierExportDirektAnzeigen: true)
            }
            .sheet(isPresented: $erinnerungenAnzeigen) {
                erinnerungenSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $syncKonflikteAnzeigen) {
                SyncKonfliktView()
            }
            .alert("Zugriff konnte nicht aktualisiert werden", isPresented: Binding(
                get: { !zugriffsFehler.isEmpty },
                set: { if !$0 { zugriffsFehler = "" } }
            )) {
                Button("OK", role: .cancel) { zugriffsFehler = "" }
            } message: {
                Text(zugriffsFehler)
            }
            .task {
                await ladeRecoveryStatus()
                try? await PushEinladungsService.shared.registriereGespeichertesGeraet()
                verarbeiteGespeichertenEntscheidungsPush()
                await aktualisiereEinladungszustaende()
            }
            .task(id: aktiveUserID) {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    guard !Task.isCancelled, scenePhase == .active else { continue }
                    await aktualisiereEinladungszustaende()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .vertrauenspersonPushEmpfangen)) { _ in
                verarbeiteGespeichertenEntscheidungsPush()
                Task { await aktualisiereEinladungszustaende() }
            }
            .onChange(of: scenePhase) { _, neuePhase in
                guard neuePhase == .active else { return }
                Task { await aktualisiereEinladungszustaende() }
            }
            .onChange(of: ziel) { _, neuesZiel in
                guard neuesZiel == nil else { return }
                Task { await ladeRecoveryStatus() }
            }
            .onChange(of: naechsterGefuehrterSchritt?.id) { _, _ in
                starteBereicheGlowFallsNoetig()
            }
        }
    }

    private var vorsorgeStatusKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                ZStack {
                    Circle().stroke(akzent.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fortschritt)
                        .stroke(akzent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((fortschritt * 100).rounded()))%")
                        .font(.caption.weight(.bold))
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(heroStatusTitel)
                        .font(.headline.weight(.bold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(heroStatusBeschreibung)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }

            switch dossierErstellungsart {
            case nil:
                VStack(alignment: .leading, spacing: 9) {
                    Text("Wie möchtest du dein Dossier erstellen?")
                        .font(.subheadline.weight(.semibold))

                    Picker("Art der Dossier-Erstellung", selection: $temporaereErstellungsart) {
                        ForEach(DossierErstellungsart.allCases) { art in
                            Text(art.titel).tag(art)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        dossierErstellungsartRawValue = temporaereErstellungsart.rawValue
                        DossierEinstellungenStore.markiereGeaendert()
                    } label: {
                        Text("Auswahl übernehmen")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(akzent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

            case .selbstaendig:
                Text("Du entscheidest selbst, welche Bereiche du wann bearbeitest.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .gefuehrt:
                if profilGrundlageVollstaendig && !recoveryStatusGeladen {
                    HStack(spacing: 9) {
                        ProgressView()
                        Text("Nächste Empfehlung wird vorbereitet …")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let schritt = naechsterGefuehrterSchritt {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(schritt.titel)
                            .font(.subheadline.weight(.bold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(schritt.beschreibung)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button { ueberspringe(schritt) } label: {
                                Text("Überspringen")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(akzent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(akzent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button { oeffne(schritt) } label: {
                                Text("Weiter")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appOnAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(akzent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Label("Alle wichtigen Grundlagen sind eingerichtet.", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(akzent)
                }
            }
        }
        .padding(appLayout.cardPadding)
        .background(Color.appRaisedCard, in: RoundedRectangle(cornerRadius: appLayout.cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: appLayout.cardCornerRadius, style: .continuous).stroke(Color.appBorder))
        .shadow(color: Color.appShadow, radius: 12, y: 5)
        .appPagePadding()
        .padding(.bottom, 18)
    }

    private var hero: some View {
        heroBild
    }

    private var footerLogo: some View {
        TschluessliLogo()
            .frame(width: 118, height: 44)
            .opacity(0.84)
            .accessibilityLabel("Tschlüssli")
    }

    private var heroBild: some View {
        VStack(spacing: appLayout.sectionSpacing) {
            homeKopfzeile(profilbildGroesse: homeProfilbildGroesse)

            vorsorgeStatusKarte

            orbitNavigation
        }
        .padding(.top, 26)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geometry in
                Image("etienne-bosiger-OWsdJ-MllYA-unsplash")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [hintergrund.opacity(0.08), hintergrund.opacity(0.56), hintergrund],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    }
                    .overlay {
                        LinearGradient(colors: [.clear, hintergrund], startPoint: .top, endPoint: .bottom)
                    }
                    .overlay {
                        LinearGradient(
                            colors: [.clear, hintergrund.opacity(0.46), hintergrund.opacity(0.72)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: hintergrund.opacity(0.52), location: 0),
                                .init(color: .clear, location: 0.14),
                                .init(color: .clear, location: 0.86),
                                .init(color: hintergrund.opacity(0.46), location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: hintergrund, location: 0),
                                .init(color: hintergrund.opacity(0.70), location: 0.045),
                                .init(color: .clear, location: 0.16),
                                .init(color: .clear, location: 0.80),
                                .init(color: hintergrund.opacity(0.76), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
    }

    private var dossierVonAnderenBereich: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dossiers von anderen")
                        .font(.largeTitle.bold())
                    Text("Hier findest du die Vorsorge-Dossiers, auf die du als Vertrauensperson Zugriff hast.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NavigationLink {
                    EinladungQRCodeAnnehmenView()
                } label: {
                    Label("Weiteres Dossier hinzufügen", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .foregroundStyle(Color.appOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(akzent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if freigegebeneDossiers.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Dossiers",
                        systemImage: "folder.badge.person.crop",
                        description: Text("Scanne den QR-Code einer Einladung, um ein Dossier hinzuzufügen.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                } else {
                    Text("Deine Zugriffe")
                        .font(.title3.bold())

                    ForEach(freigegebeneDossiers) { zugriff in
                        if zugriff.status == DossierZugriffStatus.widerrufen {
                            zugriffsZeile(
                                symbol: "folder.badge.minus",
                                farbe: .gray,
                                titel: "Dossier von \(besitzerName(fuer: zugriff))",
                                text: widerrufenerZugriffText(fuer: zugriff)
                            )
                            .opacity(0.68)
                            .accessibilityLabel(
                                "Dossier von \(besitzerName(fuer: zugriff)). Zugriff auf das Dossier wurde von \(besitzerName(fuer: zugriff)) entfernt."
                            )
                        } else {
                            NavigationLink {
                                FreigegebenesDossierDetailView(
                                    dossierKontext: .freigegebenesDossier(
                                        dossierID: zugriff.dossierID,
                                        zugriffID: zugriff.zugriffID,
                                        besitzerName: besitzerName(fuer: zugriff),
                                        besitzerEmail: besitzerProfil(fuer: zugriff)?.email
                                    )
                                )
                            } label: {
                                zugriffsZeile(
                                    symbol: "folder.fill.badge.person.crop",
                                    farbe: akzent,
                                    titel: "Dossier von \(besitzerName(fuer: zugriff))",
                                    text: aktiverZugriffText(fuer: zugriff),
                                    zeigtPfeil: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(hintergrund.ignoresSafeArea())
        .navigationTitle("Dossier von anderen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await aktualisiereEinladungszustaende()
        }
        .refreshable {
            await aktualisiereEinladungszustaende()
        }
    }

    private func zugriffsUntertitel(fuer zugriff: DossierZugriffModell) -> String {
        switch zugriff.status {
        case DossierZugriffStatus.bestaetigungAusstehend:
            "Sichtbare Bereiche öffnen · Erweiterungsanfrage ausstehend"
        case DossierZugriffStatus.abgelehnt:
            "Sichtbare Bereiche öffnen · Erweiterung abgelehnt"
        case DossierZugriffStatus.angenommen, DossierZugriffStatus.freigegeben:
            "Vollständig freigegeben · Im Lesemodus öffnen"
        default:
            "Freigegebene Bereiche im Lesemodus öffnen"
        }
    }

    private func aktiverZugriffText(fuer zugriff: DossierZugriffModell) -> String {
        let status = zugriffsUntertitel(fuer: zugriff)
        guard let datum = gespeicherteDossiers.first(where: { $0.dossierID == zugriff.dossierID })?.aktualisiertAm else {
            return status
        }
        return "\(status)\nZuletzt aktualisiert: \(formatiereZugriffsdatum(datum))"
    }

    private func widerrufenerZugriffText(fuer zugriff: DossierZugriffModell) -> String {
        let hinweis = "Zugriff auf das Dossier wurde von \(besitzerName(fuer: zugriff)) entfernt."
        guard let datum = zugriff.widerrufenAm else { return hinweis }
        return "\(hinweis)\nZugriff entzogen am: \(formatiereZugriffsdatum(datum))"
    }

    private func formatiereZugriffsdatum(_ datum: Date) -> String {
        datum.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
                .year()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func zugriffsKarte<Inhalt: View>(
        symbol: String,
        farbe: Color,
        @ViewBuilder inhalt: () -> Inhalt
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2).foregroundStyle(farbe).frame(width: 30)
            VStack(alignment: .leading, spacing: 8) { inhalt() }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(farbe.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func zugriffsZeile(
        symbol: String,
        farbe: Color,
        titel: String,
        text: String,
        zeigtPfeil: Bool = false
    ) -> some View {
        zugriffsKarte(symbol: symbol, farbe: farbe) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titel).font(.headline).foregroundStyle(.primary)
                    Text(text).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if zeigtPfeil {
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func homeKopfzeile(profilbildGroesse: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(begruessung)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(anzeigename) 👋")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Schön, dass du heute an deine Vorsorge denkst.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button { ziel = .profil } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.appCard)
                        .frame(width: profilbildGroesse, height: profilbildGroesse)
                        .overlay {
                            if let daten = aktivesProfil?.profilbildDaten,
                               let bild = UIImage(data: daten) {
                                Image(uiImage: bild)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: profilbildGroesse, height: profilbildGroesse)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: profilbildGroesse * 0.9))
                                    .foregroundStyle(akzent.opacity(0.55))
                            }
                        }
                        .overlay(Circle().stroke(Color.appBorder, lineWidth: 3))
                        .shadow(color: akzent.opacity(0.14), radius: 14, y: 8)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(akzent)
                        .frame(width: 28, height: 28)
                        .background(Color.appRaisedCard, in: Circle())
                        .shadow(color: Color.appShadow, radius: 7, y: 3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profil öffnen")
        }
        .appPagePadding()
    }

    private var orbitNavigation: some View {
        Group {
            if appLayout.prefersLinearNavigation {
                barrierearmeNavigation
            } else {
                orbitDarstellung
            }
        }
    }

    /// Bei sehr grossen Systemschriftgrössen wird die dekorative Umlaufbahn
    /// zu einer linearen Navigation. So bleiben Texte vollständig lesbar und
    /// die Bedienflächen wachsen mit ihrem Inhalt.
    private var barrierearmeNavigation: some View {
        VStack(spacing: 12) {
            Button { exportAnzeigen = true } label: {
                Label("Mein Vorsorge-Dossier", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(Color.appOnAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(appLayout.cardPadding)
                    .background(akzent, in: RoundedRectangle(cornerRadius: appLayout.cardCornerRadius))
            }
            .buttonStyle(.plain)

            ForEach(HomeNavigationKnoten.satelliten) { knoten in
                Button { oeffne(knoten) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: knoten.symbol)
                            .font(appLayout.prefersCompactNavigationIcons
                                ? .body.weight(.semibold)
                                : .title3.weight(.semibold))
                            .foregroundStyle(Color.orbitSatelliteIcon)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(knoten.titel)
                                .font(.headline)
                                .foregroundStyle(Color.orbitSatelliteTitle)
                            Text(untertitel(fuer: knoten))
                                .font(.subheadline)
                                .foregroundStyle(Color.orbitSatelliteSubtitle)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Color.orbitSatelliteIcon)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(appLayout.cardPadding)
                    .background(knoten.flaeche, in: RoundedRectangle(cornerRadius: appLayout.cardCornerRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(knoten.titel)
            }
        }
        .appPagePadding()
    }

    private var orbitDarstellung: some View {
        GeometryReader { proxy in
            let breite = proxy.size.width
            // Flüssige Skalierung anhand des real verfügbaren Containers.
            // 430 pt entsprechen der grosszügigen Referenzdarstellung; auf
            // schmaleren oder breiteren Geräten wird ohne Modellabfrage
            // proportional skaliert und nur an sinnvollen Grenzen geklemmt.
            let scale = min(max(breite / 430, 0.84), 1)
            let radiusX = min(breite * 0.34, 145)
            let radiusY: CGFloat = 176 * scale
            let orbitMitteY: CGFloat = 255 * scale
            let orbitHoehe: CGFloat = 510 * scale
            let kernGroesse: CGFloat = 178 * scale

            ZStack {
                ForEach(HomeNavigationKnoten.satelliten) { knoten in
                    Path { pfad in
                        let knotenDurchmesser = effektiverKnotenDurchmesser(knoten)
                        let mittelpunkt = CGPoint(x: breite / 2, y: orbitMitteY)
                        let punkt = aktuellePosition(fuer: knoten, radiusX: radiusX, radiusY: radiusY)
                        let distanz = max(hypot(punkt.width, punkt.height), 1)
                        let richtung = CGSize(width: punkt.width / distanz, height: punkt.height / distanz)
                        let start = CGPoint(
                            x: mittelpunkt.x + richtung.width * (kernGroesse / 2 - 8),
                            y: mittelpunkt.y + richtung.height * (kernGroesse / 2 - 8)
                        )
                        let ende = CGPoint(
                            x: mittelpunkt.x + punkt.width - richtung.width * (knotenDurchmesser * scale / 2 - 8),
                            y: mittelpunkt.y + punkt.height - richtung.height * (knotenDurchmesser * scale / 2 - 8)
                        )
                        let mitte = CGPoint(x: (start.x + ende.x) / 2, y: (start.y + ende.y) / 2)
                        let normal = CGSize(width: -richtung.height, height: richtung.width)
                        pfad.move(to: start)
                        pfad.addQuadCurve(
                            to: ende,
                            control: CGPoint(
                                x: mitte.x + normal.width * knoten.kurvenversatz,
                                y: mitte.y + normal.height * knoten.kurvenversatz
                            )
                        )
                    }
                    .stroke(
                        Color.orbitLine.opacity(orbitLinienDeckkraft(fuer: knoten)),
                        style: StrokeStyle(
                            lineWidth: orbitLinienBreite(fuer: knoten),
                            lineCap: .round,
                            dash: knoten == .dossierVon ? [5, 6] : []
                        )
                    )
                    .opacity(orbitAnimationsFortschritt)
                }

                ForEach(HomeNavigationKnoten.satelliten) { knoten in
                    knotenAnsicht(knoten, scale: scale)
                    .contentShape(Circle())
                    .offset(aktuellePosition(fuer: knoten, radiusX: radiusX, radiusY: radiusY))
                    .opacity(orbitAnimationsFortschritt)
                    .zIndex(gezogenerSatellit == knoten ? 2 : 1)
                    .onTapGesture { oeffne(knoten) }
                    .gesture(verschiebeGeste(fuer: knoten))
                    .accessibilityLabel(knoten.titel)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { oeffne(knoten) }
                }

                Button { exportAnzeigen = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2.weight(.semibold))
                        Text("Mein\nVorsorge-Dossier")
                            .font(.headline.bold())
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)
                        Text("\(anzahlBereicheMitDaten) von 7 Bereichen\nausgefüllt")
                            .font(.caption)
                            .foregroundStyle(Color.appOnAccent.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Color.appOnAccent)
                    .frame(width: kernGroesse, height: kernGroesse)
                    .background(Color.orbitCore, in: Circle())
                    .overlay(Circle().stroke(Color.appOnAccent.opacity(0.34), lineWidth: 2))
                    .shadow(color: Color.orbitCore.opacity(0.28), radius: 18, y: 9)
                }
                .buttonStyle(.plain)
            }
            .frame(width: breite, height: orbitHoehe)
            .onAppear {
                starteOrbitAnimation()
                starteBereicheGlowFallsNoetig()
            }
        }
        .containerRelativeFrame(.horizontal) { breite, _ in
            breite
        }
        .aspectRatio(430 / 510, contentMode: .fit)
        .frame(minHeight: 428, maxHeight: 510)
        .padding(.top, -20)
    }

    private func knotenAnsicht(_ knoten: HomeNavigationKnoten, scale: CGFloat) -> some View {
        let durchmesser = effektiverKnotenDurchmesser(knoten)

        return ZStack {
            if knoten == .bereiche {
                Circle()
                    .stroke(
                        Color.orbitGlow.opacity(bereicheGlowHervorgehoben ? 0.96 : 0.58),
                        lineWidth: bereicheGlowHervorgehoben ? 5 : 3
                    )
                    .blur(radius: bereicheGlowHervorgehoben ? 11 : 6)
                    .scaleEffect(bereicheGlowHervorgehoben ? 1.14 : 1.065)
                    .shadow(
                        color: Color.orbitGlow.opacity(bereicheGlowHervorgehoben ? 0.82 : 0.48),
                        radius: bereicheGlowHervorgehoben ? 18 : 10
                    )
                    .allowsHitTesting(false)
            }

            Circle().fill(knoten.flaeche)

            VStack(spacing: knoten == .bereiche ? 3 : 5) {
                Image(systemName: knoten.symbol)
                    .font(appLayout.prefersCompactNavigationIcons
                        ? .body.weight(.semibold)
                        : .title3.weight(.semibold))
                    .foregroundStyle(Color.orbitSatelliteIcon)
                Text(knoten.titel)
                    .font(.subheadline.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.orbitSatelliteTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(untertitel(fuer: knoten))
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSatelliteSubtitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                if knoten == .bereiche {
                    Text(anzahlGewaehlteVorsorgeBereiche == 1
                        ? "1 Bereich gewählt"
                        : "\(anzahlGewaehlteVorsorgeBereiche) Bereiche gewählt")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.orbitSatelliteSubtitle)
                }
            }
            .padding(.horizontal, knoten == .bereiche ? 8 : 10)
            .offset(y: -3)
        }
        // Den gesamten Knoten skalieren – nicht nur seinen Kreis. Andernfalls
        // bleiben Icon und Text in Originalgrösse und ragen auf schmalen
        // Displays aus dem verkleinerten Kreis heraus.
        .frame(width: durchmesser, height: durchmesser)
        .overlay(Circle().stroke(Color.orbitBorder, style: StrokeStyle(lineWidth: colorScheme == .dark ? 1.7 : 1.5, dash: knoten == .dossierVon ? [7, 6] : [])))
        .overlay(alignment: .bottom) {
            if knoten == .teilen, !offeneErweiterungsanfragen.isEmpty {
                Text("Zugriffsanfrage bearbeiten")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 108)
                .foregroundStyle(Color.appOnAccent)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.red, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: .red.opacity(0.24), radius: 7, y: 3)
                .offset(y: 16)
                .accessibilityLabel("Zugriffsanfrage bearbeiten")
            }
        }
        .shadow(color: Color.orbitLine.opacity(colorScheme == .dark ? 0.20 : 0.13), radius: 13, y: 6)
        .scaleEffect(scale)
    }

    private func orbitLinienDeckkraft(fuer knoten: HomeNavigationKnoten) -> Double {
        guard colorScheme == .dark else { return knoten.linienDeckkraft }
        return switch knoten {
        case .bereiche: 0.55
        case .teilen: 0.52
        case .profil: 0.46
        case .erinnerungen: 0.42
        case .dossierVon: 0.38
        }
    }

    private func orbitLinienBreite(fuer knoten: HomeNavigationKnoten) -> CGFloat {
        colorScheme == .dark ? knoten.linienBreite + 0.25 : knoten.linienBreite
    }

    private func effektiverKnotenDurchmesser(_ knoten: HomeNavigationKnoten) -> CGFloat {
        guard appLayout.dynamicTypeSize >= .xLarge else { return knoten.groesse }

        return switch knoten {
        case .bereiche:
            knoten.groesse + 10
        case .erinnerungen:
            knoten.groesse + 8
        default:
            knoten.groesse
        }
    }

    private var erinnerungenSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Jährliche Vorsorgeprüfung", isOn: Binding(
                        get: { erinnerungAktiv },
                        set: { neuerWert in
                            erinnerungAktiv = neuerWert
                            DossierEinstellungenStore.markiereGeaendert()
                        }
                    ))
                        .tint(akzent)
                } footer: {
                    Text("Du wirst einmal jährlich daran erinnert, dein Vorsorge-Dossier zu prüfen.")
                }
            }
            .navigationTitle("Erinnerungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func orbitPunkt(fuer knoten: HomeNavigationKnoten, radiusX: CGFloat, radiusY: CGFloat) -> CGSize {
        let winkel = knoten.winkel * .pi / 180
        let startFaktor: CGFloat = 0.84
        let animationsFaktor = startFaktor + (1 - startFaktor) * orbitAnimationsFortschritt
        return CGSize(
            width: (cos(winkel) * radiusX * knoten.abstand + knoten.versatz.width) * animationsFaktor,
            height: (sin(winkel) * radiusY * knoten.abstand + knoten.versatz.height) * animationsFaktor
        )
    }

    private func aktuellePosition(fuer knoten: HomeNavigationKnoten, radiusX: CGFloat, radiusY: CGFloat) -> CGSize {
        let basis = orbitPunkt(fuer: knoten, radiusX: radiusX, radiusY: radiusY)
        let verschiebung = satellitenVerschiebungen[knoten] ?? .zero
        return CGSize(
            width: basis.width + verschiebung.width,
            height: basis.height + verschiebung.height
        )
    }

    private func verschiebeGeste(fuer knoten: HomeNavigationKnoten) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { wert in
                gezogenerSatellit = knoten
                satellitenVerschiebungen[knoten] = wert.translation
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    satellitenVerschiebungen[knoten] = .zero
                }
                gezogenerSatellit = nil
            }
    }

    private func starteOrbitAnimation() {
        guard !animationWurdeAbgespielt else { return }
        animationWurdeAbgespielt = true
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.56)) {
                orbitAnimationsFortschritt = 1
            }
        }
    }

    private func starteBereicheGlowFallsNoetig() {
        guard dossierErstellungsart == .gefuehrt,
              naechsterGefuehrterSchritt == .bereiche,
              !accessibilityReduceMotion else {
            bereicheGlowHervorgehoben = false
            return
        }

        bereicheGlowHervorgehoben = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard dossierErstellungsart == .gefuehrt,
                  naechsterGefuehrterSchritt == .bereiche,
                  !accessibilityReduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.48)) {
                bereicheGlowHervorgehoben = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.easeOut(duration: 0.85)) {
                    bereicheGlowHervorgehoben = false
                }
            }
        }
    }

    private func oeffne(_ schritt: GefuehrterDossierSchritt) {
        switch schritt {
        case .profil: ziel = .profil
        case .recovery: ziel = .recovery
        case .bereiche: ziel = .bereicheVerwalten
        case .vertrauensperson: ziel = .teilen
        case .bereich(let bereich):
            switch bereich {
            case .profil: ziel = .profil
            case .gesundheit: ziel = .gesundheit
            case .wuensche: ziel = .wuensche
            case .finanzen: ziel = .finanzen
            case .hinterbliebene: ziel = .hinterbliebene
            case .dokumente: ziel = .dokumente
            case .abos: ziel = .abos
            case .herzensstuecke: ziel = .herzensstuecke
            }
        }
    }

    private func ueberspringe(_ schritt: GefuehrterDossierSchritt) {
        var schritte = uebersprungeneSchritte
        schritte.insert(schritt.id)
        uebersprungeneDossierSchritte = schritte.sorted().joined(separator: ",")
        DossierEinstellungenStore.markiereGeaendert()
    }

    private func ladeRecoveryStatus() async {
        recoveryVorhanden = await CloudFeldVerschluesselung.shared.hatRecoveryPaket()
        recoveryStatusGeladen = true
    }

    private func verarbeiteGespeichertenEntscheidungsPush() {
        guard let info = UserDefaults.standard.dictionary(forKey: "letzterVertrauenspersonPush") as? [String: String],
              info["type"] == "trust_invitation_decision",
              let token = info["token"],
              let zugriff = gespeicherteDossierZugriffe.first(where: { $0.einladungsToken == token }),
              zugriff.vertrauenspersonUserID == UUID(uuidString: aktiveUserID) else { return }

        if info["decision"] == "accepted", let userID = zugriff.vertrauenspersonUserID {
            zugriff.einladungAnnehmen(
                vertrauenspersonUserID: userID,
                registrierungsEmail: zugriff.registrierungsEmail
            )
        } else if info["decision"] == "declined" {
            zugriff.einladungAblehnen(registrierungsEmail: zugriff.registrierungsEmail)
        }
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: "letzterVertrauenspersonPush")
    }

    private func aktualisiereEinladungszustaende() async {
        if let fehler = await EinladungsStatusSynchronisation.aktualisieren(
            zugriffe: gespeicherteDossierZugriffe,
            dossiers: gespeicherteDossiers,
            aktiveUserID: UUID(uuidString: aktiveUserID),
            modelContext: modelContext
        ) {
            zugriffsFehler = fehler
        }
    }

    private func oeffne(_ knoten: HomeNavigationKnoten) {
        switch knoten {
        case .profil: ziel = .profil
        case .bereiche: ziel = .bereiche
        case .teilen: ziel = .teilen
        case .erinnerungen: erinnerungenAnzeigen = true
        case .dossierVon: ziel = .dossierVon
        }
    }

}

private enum HomeNavigationZiel: Hashable, Identifiable {
    case profil, bereiche, bereicheVerwalten, teilen, dossierVon, recovery
    case gesundheit, wuensche, finanzen, hinterbliebene, dokumente, abos, herzensstuecke
    var id: Self { self }
}

enum DossierErstellungsart: String, CaseIterable, Identifiable {
    case gefuehrt
    case selbstaendig

    var id: Self { self }
    var titel: String {
        switch self {
        case .gefuehrt: "Geführt"
        case .selbstaendig: "Selbständig"
        }
    }

}

private enum GefuehrterDossierSchritt: Hashable {
    case profil
    case recovery
    case bereiche
    case bereich(VorsorgeBereichID)
    case vertrauensperson

    var id: String {
        switch self {
        case .profil: "profil"
        case .recovery: "recovery"
        case .bereiche: "bereiche"
        case .bereich(let bereich): "bereich-\(bereich.rawValue)"
        case .vertrauensperson: "vertrauensperson"
        }
    }

    var titel: String {
        switch self {
        case .profil: "Persönliche Angaben ergänzen"
        case .recovery: "Zugang zum Dossier sichern"
        case .bereiche: "Vorsorgebereiche auswählen"
        case .bereich(let bereich): "Mit \(bereich.gefuehrterTitel) beginnen"
        case .vertrauensperson: "Vertrauensperson hinterlegen"
        }
    }

    var beschreibung: String {
        switch self {
        case .profil:
            "Erfasse Name, Adresse, Wohnort und Geburtsdatum als Grundlage deines Dossiers."
        case .recovery:
            "Ein Wiederherstellungsschlüssel schützt deinen Zugang bei einem Gerätewechsel."
        case .bereiche:
            "Wähle die Themen, die für deine persönliche Vorsorge wichtig sind."
        case .bereich(let bereich):
            "Öffne den Bereich „\(bereich.bereichTitel)“ und erfasse einen ersten relevanten Eintrag."
        case .vertrauensperson:
            "Bestimme, wer später Zugriff auf dein Vorsorge-Dossier erhalten darf."
        }
    }
}

private extension VorsorgeBereichID {
    var gefuehrterTitel: String {
        switch self {
        case .profil: "deinem Profil"
        case .gesundheit: "Gesundheit"
        case .wuensche: "deinen Wünschen"
        case .finanzen: "Finanzen & Werten"
        case .hinterbliebene: "Wichtige Menschen"
        case .dokumente: "Dokumenten"
        case .abos: "Abos & digitalen Zugängen"
        case .herzensstuecke: "Herzensstücken"
        }
    }

    var bereichTitel: String {
        switch self {
        case .profil: "Profil"
        case .gesundheit: "Gesundheit"
        case .wuensche: "Meine Wünsche"
        case .finanzen: "Finanzen & Werte"
        case .hinterbliebene: "Wichtige Menschen"
        case .dokumente: "Dokumente"
        case .abos: "Abos & digitale Zugänge"
        case .herzensstuecke: "Herzensstücke"
        }
    }
}

private enum HomeNavigationKnoten: String, CaseIterable, Identifiable {
    case profil, bereiche, teilen, erinnerungen, dossierVon

    static let satelliten: [Self] = [.profil, .bereiche, .teilen, .dossierVon, .erinnerungen]
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .profil: "Mein Profil"
        case .bereiche: "Meine Bereiche"
        case .teilen: "Teilen & Zugriff"
        case .erinnerungen: "Erinnerungen"
        case .dossierVon: "Dossier von anderen"
        }
    }

    var untertitel: String {
        switch self {
        case .profil: "Deine Daten & Login"
        case .bereiche: "Erfassen & verwalten"
        case .teilen: "Vertrauensperson hinterlegen"
        case .erinnerungen: "Jährliche Prüfung"
        case .dossierVon: ""
        }
    }

    var symbol: String {
        switch self {
        case .profil: "person.fill"
        case .bereiche: "square.grid.2x2.fill"
        case .teilen: "person.2.fill"
        case .erinnerungen: "calendar.badge.clock"
        case .dossierVon: "qrcode.viewfinder"
        }
    }

    var winkel: Double {
        switch self {
        case .profil: 205
        case .bereiche: 270
        case .teilen: 335
        case .erinnerungen: 145
        case .dossierVon: 42
        }
    }

    var groesse: CGFloat {
        switch self {
        case .profil: 122
        case .bereiche: 138
        case .teilen: 124
        case .erinnerungen: 112
        case .dossierVon: 146
        }
    }

    var abstand: CGFloat {
        switch self {
        case .profil: 0.93
        case .bereiche: 1.26
        case .teilen: 0.96
        case .erinnerungen: 1.08
        case .dossierVon: 1.08
        }
    }

    var versatz: CGSize {
        switch self {
        case .profil: CGSize(width: -20, height: 0)
        case .bereiche: CGSize(width: 0, height: 38)
        case .teilen: CGSize(width: 10, height: -32)
        case .dossierVon: .zero
        case .erinnerungen: CGSize(width: 0, height: 26)
        }
    }

    var linienDeckkraft: Double {
        switch self {
        case .bereiche: 0.42
        case .teilen: 0.38
        case .profil: 0.28
        case .erinnerungen: 0.24
        case .dossierVon: 0.18
        }
    }

    var linienBreite: CGFloat {
        switch self {
        case .bereiche, .teilen: 1.05
        case .profil, .erinnerungen: 0.85
        case .dossierVon: 0.75
        }
    }

    var kurvenversatz: CGFloat {
        switch self {
        case .profil: -10
        case .bereiche: 8
        case .teilen: -14
        case .erinnerungen: 11
        case .dossierVon: -8
        }
    }

    var flaeche: Color {
        Color.appRaisedCard
    }
}

#Preview {
    HomeNavigation()
        .modelContainer(for: ProfilModell.self, inMemory: true)
}
