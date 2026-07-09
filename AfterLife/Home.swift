import SwiftUI
import SwiftData
import UIKit

struct Home: View {
    @Environment(\.scenePhase) private var scenePhase
    private let kachelFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let schluessliAkzent = Color(red: 0.16, green: 0.36, blue: 0.42)
    // TEST: später durch echte Beziehungen aus dem Einladungs-/VertrauenspersonModell ersetzen
    private let verknuepfteVorsorgedossiers = ["René Engeler"]
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("dossierZuletztGeprueftAmISO") private var dossierZuletztGeprueftAmISO = ""
    @AppStorage("homeBereicheReihenfolge") private var homeBereicheReihenfolge = ""
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteGesundheitsdaten: [GesundheitModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]
    @Query private var gespeicherteBankkonten: [BankkontoModell]
    @Query private var gespeicherteVersicherungen: [VersicherungModell]
    @Query private var gespeicherteWertsachen: [WertsacheModell]
    @Query private var gespeicherteDokumente: [DokumenteModell]
    @Query private var gespeicherteAbos: [AboModell]
    @State private var heroIstSichtbar = false
    @State private var bereicheTitelIstSichtbar = false
    @State private var kachelnSindSichtbar = false
    @State private var homeBearbeitungsmodus = false
    @State private var kachelWackelPhase = false
    @State private var vorsorgedossierAuswahlAnzeigen = false
    @State private var direktesVorsorgedossierOeffnen = false
    @State private var ausgewaehltesVorsorgedossier = ""
    @State private var bearbeiteteHomeBereiche: [HomeBereich] = []
    @State private var dossierPruefungRefreshDatum = Date()
    @State private var dossierPruefungSheetAnzeigen = false
    private let heroDossierTitelGroesse: CGFloat = 19
    private let heroDossierStatusGroesse: CGFloat = 16
    private let heroDossierBeschreibungGroesse: CGFloat = 14
    private let heroDossierAktionGroesse: CGFloat = 13
    private let heroProzentGroesse: CGFloat = 14
        
    private var tageszeitBegruessung: String {
        let kalender = Calendar.current
        let jetzt = Date()
        
        let stunde = kalender.component(.hour, from: jetzt)
        let minute = kalender.component(.minute, from: jetzt)
        let minutenSeitMitternacht = stunde * 60 + minute
        
        if minutenSeitMitternacht <= (12 * 60 + 30) {
            return "Guten Morgen,"
        } else if minutenSeitMitternacht <= (17 * 60 + 45) {
            return "Guten Nachmittag,"
        } else {
            return "Guten Abend,"
        }
    }
    
    private var aktivesProfil: ProfilModell? {
        if let aktiveUserUUID = UUID(uuidString: aktiveUserID),
           let profil = gespeicherteProfile.first(where: { $0.userID == aktiveUserUUID }) {
            return profil
        }
        
        return gespeicherteProfile.first
    }
    
    private var aktiveGesundheitsdaten: GesundheitModell? {
        if let aktiveUserUUID = UUID(uuidString: aktiveUserID),
           let gesundheit = gespeicherteGesundheitsdaten.first(where: { $0.userID == aktiveUserUUID }) {
            return gesundheit
        }
        
        if let dossierID = aktivesProfil?.dossierID,
           let gesundheit = gespeicherteGesundheitsdaten.first(where: { $0.dossierID == dossierID }) {
            return gesundheit
        }
        
        return gespeicherteGesundheitsdaten.first
    }
    
    private var homeAnzeigename: String {
        let vorname = aktivesProfil?.vorname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return vorname.isEmpty ? "Willkommen" : vorname
    }

    private var sortierteHomeBereiche: [HomeBereich] {
        let gespeicherteIDs = homeBereicheReihenfolge
            .split(separator: ",")
            .map { String($0) }

        let gespeicherteBereiche = gespeicherteIDs.compactMap { HomeBereich(rawValue: $0) }
        let fehlendeBereiche = HomeBereich.allCases.filter { !gespeicherteBereiche.contains($0) }

        if gespeicherteBereiche.isEmpty {
            return HomeBereich.allCases
        }

        return gespeicherteBereiche + fehlendeBereiche
    }

    private var angezeigteHomeBereiche: [HomeBereich] {
        bearbeiteteHomeBereiche.isEmpty ? sortierteHomeBereiche : bearbeiteteHomeBereiche
    }
    
    private var dossierNaechstePruefungAm: Date? {
        _ = dossierPruefungRefreshDatum

        guard let datum = ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO) else {
            return nil
        }

        // TEST: Für den iPhone-Test bewusst auf 1 Minute gesetzt.
        // Für Produktion wieder auf `.year, value: 1` ändern.
        return Calendar.current.date(byAdding: .minute, value: 1, to: datum)
    }

    private var dossierPruefungIstFaellig: Bool {
        guard let naechstePruefung = dossierNaechstePruefungAm else {
            return false
        }

        return Date() >= naechstePruefung
    }

    private var dossierWurdeGeprueft: Bool {
        guard dossierNaechstePruefungAm != nil else {
            return false
        }

        return !dossierPruefungIstFaellig
    }

    private var bereicheTitelTopAbstand: CGFloat {
        dossierPruefungIstFaellig ? 34 : 8
    }
    
    private var dossierZuletztGeprueftText: String {
        guard let datum = ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO) else {
            return dossierFortschritt.aktionsText
        }

        if dossierPruefungIstFaellig {
            return "Jährliche Prüfung fällig"
        }

        if dossierWurdeGeprueft {
            return "Zuletzt geprüft am \(datum.formatted(.dateTime.locale(Locale(identifier: "de_CH")).day().month(.wide).year()))"
        }

        return dossierFortschritt.aktionsText
    }
    
    // TODO: Fortschrittsberechnung fachlich weiter verfeinern.
    // Aktuell werden erste robuste Kriterien aus bestehenden Modellen gezählt.
    private var dossierFortschritt: DossierFortschritt {
        DossierFortschrittService.berechne(
            profil: aktivesProfil,
            gesundheit: aktiveGesundheitsdaten,
            wurdeVomUserGeprueft: dossierWurdeGeprueft,
            anzahlDossierZugriffe: gespeicherteDossierZugriffe.count,
            anzahlBankkonten: gespeicherteBankkonten.count,
            anzahlVersicherungen: gespeicherteVersicherungen.count,
            anzahlWertsachen: gespeicherteWertsachen.count,
            anzahlDokumente: gespeicherteDokumente.count,
            anzahlAbos: gespeicherteAbos.count
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    //MARK: wird ggf. ganz entfernt oder durch ein Logo ersetzt
                    //Text("Tschlüssli")
                    //  .font(.largeTitle)
                    //  .fontWeight(.bold)
                    //  .padding(.horizontal, 24)
                    //   .padding(.top, 24)
                    //   .padding(.bottom, 8)
                    
                    
                    GeometryReader { geometry in
                        let breite = geometry.size.width
                        let heroHoehe = max(360, min(430, breite * 1.02))
                        let profilbildGroesse = max(76, min(96, breite * 0.22))
                        let titelGroesse = max(34, min(46, breite * 0.105))
                        
                        ZStack(alignment: .topLeading) {
                            Image("Home2")
                                .resizable()
                                .scaledToFill()
                                .frame(width: breite, height: heroHoehe)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [
                                            Color(.systemBackground).opacity(0.02),
                                            Color(.systemBackground).opacity(0.58),
                                            Color(.systemBackground).opacity(0.96)
                                        ],
                                        startPoint: .trailing,
                                        endPoint: .leading
                                    )
                                )
                                .overlay(
                                    LinearGradient(
                                        colors: [
                                            Color(.systemBackground).opacity(0.00),
                                            Color(.systemBackground).opacity(0.90)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(tageszeitBegruessung)
                                            .font(.title3.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        
                                        Text("\(homeAnzeigename) 👋")
                                            .font(.system(size: titelGroesse, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.18))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)
                                        
                                        Text("Schön, dass du heute an deine Vorsorge denkst.")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.9)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    NavigationLink {
                                        ProfilView()
                                    } label: {
                                        ZStack(alignment: .bottomTrailing) {
                                            Circle()
                                                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                                                .frame(width: profilbildGroesse, height: profilbildGroesse)
                                                .overlay {
                                                    Group {
                                                        if let bildDaten = aktivesProfil?.profilbildDaten,
                                                           let uiImage = UIImage(data: bildDaten) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: profilbildGroesse, height: profilbildGroesse)
                                                                .clipShape(Circle())
                                                        } else {
                                                            Image(systemName: "person.crop.circle.fill")
                                                                .font(.system(size: profilbildGroesse * 0.92))
                                                                .foregroundStyle(schluessliAkzent.opacity(0.55))
                                                        }
                                                    }
                                                }
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.85), lineWidth: 3)
                                                )
                                                .shadow(color: schluessliAkzent.opacity(0.13), radius: 14, x: 0, y: 8)
                                            
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white)
                                                    .frame(width: 32, height: 32)
                                                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                                                
                                                Image(systemName: "gearshape.fill")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(schluessliAkzent)
                                            }
                                            .offset(y: 8)
                                        }
                                        .padding(.bottom, 8)
                                        .accessibilityLabel("Profil öffnen")
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                HStack(alignment: .top, spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .stroke(schluessliAkzent.opacity(0.13), lineWidth: 7)
                                            .frame(width: 66, height: 66)
                                        
                                        Circle()
                                            .trim(from: 0, to: dossierFortschritt.kreisFortschritt)
                                            .stroke(
                                                dossierFortschritt.farbe,
                                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                            )
                                            .frame(width: 66, height: 66)
                                            .rotationEffect(.degrees(-90))
                                        
                                        Text(dossierFortschritt.prozentText)
                                            .font(.system(size: heroProzentGroesse, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.18))
                                    }
                                    .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Dein Vorsorge-Dossier")
                                            .font(.system(size: heroDossierTitelGroesse, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.18))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.88)
                                        
                                        Text(dossierFortschritt.titel)
                                            .font(.system(size: heroDossierStatusGroesse, weight: .semibold, design: .rounded))
                                            .foregroundStyle(dossierFortschritt.farbe)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.9)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Text(dossierFortschritt.beschreibung)
                                            .font(.system(size: heroDossierBeschreibungGroesse, weight: .regular, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                            .minimumScaleFactor(0.86)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: (dossierWurdeGeprueft || dossierPruefungIstFaellig) ? "arrow.clockwise.circle.fill" : dossierFortschritt.aktionsIcon)
                                                .font(.system(size: heroDossierAktionGroesse, weight: .semibold, design: .rounded))
                                            
                                            Text(dossierZuletztGeprueftText)
                                                .font(.system(size: heroDossierAktionGroesse, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.82)
                                        }
                                        .foregroundStyle(schluessliAkzent)
                                        .padding(.top, 2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.84))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                                )
                                .shadow(color: schluessliAkzent.opacity(0.11), radius: 14, x: 0, y: 7)
                                .onTapGesture {
                                    if dossierPruefungIstFaellig {
                                        dossierPruefungSheetAnzeigen = true
                                    } else if !dossierWurdeGeprueft {
                                        dossierAlsGeprueftMarkieren()
                                    }
                                }

                                if dossierPruefungIstFaellig {
                                    Button {
                                        dossierPruefungSheetAnzeigen = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.clockwise.circle.fill")
                                                .font(.body.weight(.semibold))

                                            Text("Jährliche Prüfung starten")
                                                .font(.body.weight(.semibold))

                                            Spacer(minLength: 0)

                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 13)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(schluessliAkzent)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                        }
                        .frame(width: breite, height: heroHoehe)
                    }
                    .frame(height: 360)
                    .padding(.top, 14)
                    .opacity(heroIstSichtbar ? (homeBearbeitungsmodus ? 0.42 : 1) : 0)
                    .offset(y: heroIstSichtbar ? 0 : 14)
                    .allowsHitTesting(!homeBearbeitungsmodus && heroIstSichtbar)
                    .overlay {
                        Color(.systemBackground)
                            .opacity(homeBearbeitungsmodus ? 0.26 : 0)
                            .allowsHitTesting(false)
                    }
                    .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
                    .animation(.easeOut(duration: 0.55), value: heroIstSichtbar)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bereiche")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                        
                        Text("In den verschiedenen Bereichen kannst du deine Angaben machen und jederzeit ändern.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, bereicheTitelTopAbstand)
                    .opacity(bereicheTitelIstSichtbar ? (homeBearbeitungsmodus ? 0.45 : 1) : 0)
                    .offset(y: bereicheTitelIstSichtbar ? 0 : 10)
                    .allowsHitTesting(!homeBearbeitungsmodus && bereicheTitelIstSichtbar)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground).opacity(homeBearbeitungsmodus ? 0.20 : 0))
                            .allowsHitTesting(false)
                    }
                    .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
                    .animation(.easeInOut(duration: 0.22), value: dossierPruefungIstFaellig)
                    .animation(.easeOut(duration: 0.45), value: bereicheTitelIstSichtbar)
                    
                    alleKacheln
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .offset(y: kachelnSindSichtbar ? 0 : 18)
                        .opacity(kachelnSindSichtbar ? 1 : 0)
                        .animation(.easeOut(duration: 0.55), value: kachelnSindSichtbar)
                    
                    if !verknuepfteVorsorgedossiers.isEmpty {
                        vorsorgedossierWechselAktion
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                            .offset(y: kachelnSindSichtbar ? 0 : 20)
                            .opacity(kachelnSindSichtbar ? (homeBearbeitungsmodus ? 0.38 : 1) : 0)
                            .allowsHitTesting(!homeBearbeitungsmodus)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(homeBearbeitungsmodus ? 0.24 : 0))
                                    .allowsHitTesting(false)
                            }
                            .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
                    }
                    
#if DEBUG
                    HomeDebugTestPanel()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .opacity(homeBearbeitungsmodus ? 0.35 : 1)
                        .allowsHitTesting(!homeBearbeitungsmodus)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground).opacity(homeBearbeitungsmodus ? 0.24 : 0))
                                .allowsHitTesting(false)
                        }
                        .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
#endif
                }
                .background(Color(.systemBackground))
                .navigationDestination(isPresented: $direktesVorsorgedossierOeffnen) {
                    FreigegebenesDossierDetailView(
                        dossierKontext: .freigegebenesDossier(
                            dossierID: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                            zugriffID: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                            besitzerName: ausgewaehltesVorsorgedossier.isEmpty ? "Testperson" : ausgewaehltesVorsorgedossier,
                            besitzerEmail: "testperson@example.com"
                        )
                    )
                }
                .confirmationDialog(
                    "Vorsorgedossier auswählen",
                    isPresented: $vorsorgedossierAuswahlAnzeigen,
                    titleVisibility: .visible
                ) {
                    ForEach(verknuepfteVorsorgedossiers, id: \.self) { name in
                        Button(name) {
                            ausgewaehltesVorsorgedossier = name
                            direktesVorsorgedossierOeffnen = true
                        }
                    }
                    
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Wähle aus, welches Vorsorgedossier du öffnen möchtest.")
                }
                .sheet(isPresented: $dossierPruefungSheetAnzeigen) {
                    DossierPruefungSheet(accentColor: schluessliAkzent) {
                        dossierAlsGeprueftMarkieren()
                        dossierPruefungSheetAnzeigen = false
                    }
                    .presentationDetents([.fraction(0.72), .large])
                    .presentationDragIndicator(.visible)
                }
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    NotificationService.shared.berechtigungAnfragen()
                    dossierPruefungRefreshDatum = Date()
                    starteHomeEinstiegsanimation()
                }
                .onChange(of: scenePhase) { _, neuePhase in
                    if neuePhase == .active {
                        dossierPruefungRefreshDatum = Date()
                    }
                }
                .toolbar {
                    if homeBearbeitungsmodus {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fertig") {
                                speichereHomeBereichReihenfolge()

                                withAnimation(.easeInOut(duration: 0.2)) {
                                    homeBearbeitungsmodus = false
                                    kachelWackelPhase = false
                                }
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(schluessliAkzent)
                        }
                    }
                }
            }
        }
    }
    
    private func starteHomeEinstiegsanimation() {
        heroIstSichtbar = false
        bereicheTitelIstSichtbar = false
        kachelnSindSichtbar = false

        withAnimation(.easeOut(duration: 0.55)) {
            heroIstSichtbar = true
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.16)) {
            bereicheTitelIstSichtbar = true
        }

        withAnimation(.easeOut(duration: 0.55).delay(0.28)) {
            kachelnSindSichtbar = true
        }
    }
    
    // TODO: Fachliche Funktion noch fertig definieren.
        // Aktuell wird mit Testdaten gearbeitet.
        private var vorsorgedossierWechselAktion: some View {
            Button {
                vorsorgedossierWechseln()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.14))
                            .frame(width: 46, height: 46)
                        
                        Image(systemName: "folder.badge.person.crop")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Freigegebene Dossiers")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                        
                        Text("Öffne ein Dossier, für das du als Vertrauensperson berechtigt bist.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.99, green: 0.96, blue: 0.91))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.orange.opacity(0.10), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        private func vorsorgedossierWechseln() {
            guard !verknuepfteVorsorgedossiers.isEmpty else { return }
            
            if verknuepfteVorsorgedossiers.count == 1 {
                ausgewaehltesVorsorgedossier = verknuepfteVorsorgedossiers[0]
                direktesVorsorgedossierOeffnen = true
            } else {
                vorsorgedossierAuswahlAnzeigen = true
            }
        }
        
        private func dossierAlsGeprueftMarkieren() {
            let pruefDatum = Date()
            dossierZuletztGeprueftAmISO = ISO8601DateFormatter().string(from: pruefDatum)
            NotificationService.shared.jaehrlicheDossierPruefungPlanen(ab: pruefDatum)
        }

        private func initialisiereHomeBereicheFallsNoetig() {
            if bearbeiteteHomeBereiche.isEmpty {
                bearbeiteteHomeBereiche = sortierteHomeBereiche
            }
        }

        private func speichereHomeBereichReihenfolge() {
            initialisiereHomeBereicheFallsNoetig()
            homeBereicheReihenfolge = bearbeiteteHomeBereiche
                .map(\.rawValue)
                .joined(separator: ",")
        }

        private func verschiebeHomeBereich(_ bereich: HomeBereich, richtung: Int) {
            initialisiereHomeBereicheFallsNoetig()

            guard let aktuellerIndex = bearbeiteteHomeBereiche.firstIndex(of: bereich) else { return }

            let neuerIndex = aktuellerIndex + richtung
            guard bearbeiteteHomeBereiche.indices.contains(neuerIndex) else { return }

            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                bearbeiteteHomeBereiche.move(
                    fromOffsets: IndexSet(integer: aktuellerIndex),
                    toOffset: richtung > 0 ? neuerIndex + 1 : neuerIndex
                )
            }
        }

        private var alleKacheln: some View {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ],
                spacing: 20
            ) {
                ForEach(angezeigteHomeBereiche) { bereich in
                    Group {
                        if homeBearbeitungsmodus {
                            homeKachel(fuer: bereich)
                                .overlay(alignment: .topTrailing) {
                                    VStack(spacing: 8) {
                                        Button {
                                            verschiebeHomeBereich(bereich, richtung: -1)
                                        } label: {
                                            Image(systemName: "chevron.up")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(bereich.akzentFarbe)
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    Circle()
                                                        .fill(Color(.systemBackground).opacity(0.94))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(angezeigteHomeBereiche.first == bereich)
                                        .opacity(angezeigteHomeBereiche.first == bereich ? 0.35 : 1)

                                        Button {
                                            verschiebeHomeBereich(bereich, richtung: 1)
                                        } label: {
                                            Image(systemName: "chevron.down")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(bereich.akzentFarbe)
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    Circle()
                                                        .fill(Color(.systemBackground).opacity(0.94))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(angezeigteHomeBereiche.last == bereich)
                                        .opacity(angezeigteHomeBereiche.last == bereich ? 0.35 : 1)
                                    }
                                    .padding(10)
                                }
                        } else {
                            NavigationLink {
                                zielView(fuer: bereich)
                            } label: {
                                homeKachel(fuer: bereich)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .rotationEffect(.degrees(homeBearbeitungsmodus ? (kachelWackelPhase ? 0.75 : -0.75) : 0))
                    .scaleEffect(homeBearbeitungsmodus ? (kachelWackelPhase ? 1.006 : 0.996) : 1)
                    .animation(.easeInOut(duration: 0.16), value: kachelWackelPhase)
                    .animation(.easeInOut(duration: 0.2), value: homeBearbeitungsmodus)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                initialisiereHomeBereicheFallsNoetig()

                                withAnimation(.easeInOut(duration: 0.2)) {
                                    homeBearbeitungsmodus = true
                                    kachelWackelPhase = false
                                }
                            }
                    )
                }
            }
            .onAppear {
                initialisiereHomeBereicheFallsNoetig()
            }
            .task(id: homeBearbeitungsmodus) {
                guard homeBearbeitungsmodus else {
                    kachelWackelPhase = false
                    return
                }

                kachelWackelPhase = false

                while homeBearbeitungsmodus && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 160_000_000)

                    guard homeBearbeitungsmodus && !Task.isCancelled else { break }

                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            kachelWackelPhase.toggle()
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func zielView(fuer bereich: HomeBereich) -> some View {
            switch bereich {
            case .profil:
                ProfilView()
            case .gesundheit:
                GesundheitView()
            case .wuensche:
                WuenscheView()
            case .finanzen:
                FinanzenView()
            case .hinterbliebene:
                HinterbliebeneView()
            case .dokumente:
                DokumenteView()
            case .abos:
                AbosView()
            }
        }

        private func homeKachel(fuer bereich: HomeBereich) -> HomeKachel {
            HomeKachel(
                icon: bereich.icon,
                titel: bereich.titel,
                untertitel: bereich.untertitel,
                details: bereich.details,
                farbe: kachelFarbe,
                akzentFarbe: bereich.akzentFarbe
            )
        }
        
        struct HomeKachel: View {
            let icon: String
            let titel: String
            let untertitel: String
            let details: String
            let farbe: Color
            let akzentFarbe: Color
            
            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(akzentFarbe.opacity(0.14))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: icon)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titel)
                            .font(.headline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                            .lineLimit(2)
                        
                        Text(untertitel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        Text(details)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 198, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(farbe.opacity(0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: akzentFarbe.opacity(0.12), radius: 16, x: 0, y: 8)
            }
        }
    }
    
    struct DossierPruefungSheet: View {
        let accentColor: Color
        let abschliessenAktion: () -> Void
        @State private var istAbgeschlossen = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((istAbgeschlossen ? Color.green : accentColor).opacity(0.14))
                            .frame(width: istAbgeschlossen ? 68 : 54, height: istAbgeschlossen ? 68 : 54)
                        
                        Image(systemName: istAbgeschlossen ? "checkmark.circle.fill" : "checkmark.seal.fill")
                            .font(.system(size: istAbgeschlossen ? 34 : 25, weight: .semibold))
                            .foregroundStyle(istAbgeschlossen ? Color.green : accentColor)
                            .scaleEffect(istAbgeschlossen ? 1.08 : 1.0)
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.72), value: istAbgeschlossen)
                    
                    Text(istAbgeschlossen ? "Dossier geprüft" : "Jährliche Prüfung deines Dossiers")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                    
                    Text(istAbgeschlossen ? "Dein Dossier ist jetzt wieder auf dem aktuellsten Stand. Wir erinnern dich nächstes Jahr erneut." : "Nimm dir kurz Zeit und prüfe, ob deine wichtigsten Angaben noch stimmen. Insbesondere deine persönlichen Daten, Wünsche und Personen denen du Zugriffe erteilt hast.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if !istAbgeschlossen {
                    VStack(alignment: .leading, spacing: 12) {
                        pruefpunkt("Persönliche Angaben")
                        pruefpunkt("Meine Wünsche")
                        pruefpunkt("Zugriffe auf dein Dossier")
                        pruefpunkt("Gesundheit")
                        pruefpunkt("Finanzen")
                        pruefpunkt("Dokumente & Fotoalbum")
                        pruefpunkt("Abos & Profile")
                        pruefpunkt("Menschen meines Vertrauens")
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer(minLength: 0)
                
                Button {
                    guard !istAbgeschlossen else { return }
                    
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        istAbgeschlossen = true
                    }
                    
                    Task {
                        try? await Task.sleep(nanoseconds: 2_050_000_000)
                        await MainActor.run {
                            abschliessenAktion()
                        }
                    }
                } label: {
                    Text(istAbgeschlossen ? "Erledigt" : "Alles geprüft, das Dossier ist auf dem aktuellsten Stand")
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(istAbgeschlossen ? Color.green : accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(istAbgeschlossen)
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 24)
        }
        
        private func pruefpunkt(_ titel: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                
                Text(titel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                
                Spacer(minLength: 0)
            }
        }
    }

    enum HomeBereich: String, CaseIterable, Identifiable {
        case profil
        case gesundheit
        case wuensche
        case finanzen
        case hinterbliebene
        case dokumente
        case abos

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .profil:
                return "person.text.rectangle.fill"
            case .gesundheit:
                return "heart.text.square.fill"
            case .wuensche:
                return "sparkles"
            case .finanzen:
                return "dollarsign.circle.fill"
            case .hinterbliebene:
                return "person.3.fill"
            case .dokumente:
                return "folder.fill"
            case .abos:
                return "rectangle.stack.badge.person.crop.fill"
            }
        }

        var titel: String {
            switch self {
            case .profil:
                return "Mein Profil"
            case .gesundheit:
                return "Gesundheit"
            case .wuensche:
                return "Meine Wünsche"
            case .finanzen:
                return "Finanzen"
            case .hinterbliebene:
                return "Menschen meines Vertrauens"
            case .dokumente:
                return "Dokumente & Fotoalbum"
            case .abos:
                return "Abos & Profile"
            }
        }

        var untertitel: String {
            switch self {
            case .profil:
                return "Persönliche Angaben"
            case .gesundheit:
                return "Für den Ernstfall"
            case .wuensche:
                return "Was dir wichtig ist"
            case .finanzen:
                return "Deine finanzielle Übersicht"
            case .hinterbliebene:
                return "Menschen, die dir wichtig sind"
            case .dokumente:
                return "Alles sicher abgelegt"
            case .abos:
                return "Digitales Leben"
            }
        }

        var details: String {
            switch self {
            case .profil:
                return "Kontaktdaten, Einstellungen und Sicherheit verwalten"
            case .gesundheit:
                return "Hausarzt, Medikamente, Allergien und wichtige medizinische Informationen"
            case .wuensche:
                return "Testament und persönliche Wünsche festhalten"
            case .finanzen:
                return "Konten, Schulden und Wertsachen auflisten"
            case .hinterbliebene:
                return "Familie & Freunde als Kontakte hinterlegen"
            case .dokumente:
                return "Dokumente hochladen und Fotoalbum erstellen"
            case .abos:
                return "Digitale Profile, Zugänge und Abos"
            }
        }

        var akzentFarbe: Color {
            switch self {
            case .profil:
                return Color(red: 0.16, green: 0.36, blue: 0.42)
            case .gesundheit:
                return Color(red: 0.76, green: 0.24, blue: 0.30)
            case .wuensche:
                return Color(red: 0.72, green: 0.42, blue: 0.28)
            case .finanzen:
                return Color(red: 0.62, green: 0.47, blue: 0.18)
            case .hinterbliebene:
                return Color(red: 0.24, green: 0.50, blue: 0.34)
            case .dokumente:
                return Color(red: 0.22, green: 0.43, blue: 0.68)
            case .abos:
                return Color(red: 0.46, green: 0.36, blue: 0.62)
            }
        }
    }

    

    struct DossierFortschritt {
        let prozent: Int
        let farbe: Color
        let titel: String
        let beschreibung: String
        let aktionsText: String
        let aktionsIcon: String
        
        var prozentText: String {
            "\(prozent)%"
        }
        
        var kreisFortschritt: Double {
            min(max(Double(prozent) / 100.0, 0), 1)
        }
    }
    
    struct DossierFortschrittService {
        static func berechne(
            profil: ProfilModell?,
            gesundheit: GesundheitModell?,
            wurdeVomUserGeprueft: Bool,
            anzahlDossierZugriffe: Int,
            anzahlBankkonten: Int,
            anzahlVersicherungen: Int,
            anzahlWertsachen: Int,
            anzahlDokumente: Int,
            anzahlAbos: Int
        ) -> DossierFortschritt {
            var punkte = 0
            
            
            if profil != nil {
                punkte += 5
            }
            
            if let profil {
                if !profil.vorname.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    punkte += 5
                }
                
                if !profil.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    punkte += 5
                }
                
                if !profil.telefon.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    punkte += 5
                }
                
                if let profilbildDaten = profil.profilbildDaten,
                   !profilbildDaten.isEmpty {
                    punkte += 2
                }
            }
            
            if let gesundheit {
                if gesundheit.hatHausarzt {
                    punkte += 8
                }
                
                if gesundheit.blutgruppe != GesundheitBlutgruppe.unbekannt {
                    punkte += 2
                }
                
                if gesundheit.organspende != GesundheitOrganspendeStatus.nichtAngegeben {
                    punkte += 2
                }
                
                if gesundheit.hatAllergien,
                   !gesundheit.allergien.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    punkte += 2
                }
                
                if gesundheit.nimmtMedikamente,
                   !gesundheit.medikamente.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    punkte += 2
                }
                
                if !gesundheit.gesundheitlicheHinweise.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    punkte += 2
                }
            }
            
            if anzahlDossierZugriffe > 0 {
                punkte += 15
            }
            
            if anzahlBankkonten > 0 {
                punkte += 10
            }
            
            if anzahlVersicherungen > 0 {
                punkte += 5
            }
            
            if anzahlWertsachen > 0 {
                punkte += 2
            }
            
            if anzahlDokumente > 1 {
                punkte += 15
            }
            
            if anzahlAbos >= 2 {
                punkte += 5
            } else if anzahlAbos == 1 {
                punkte += 3
            }
            
            if wurdeVomUserGeprueft {
                punkte = max(punkte, 100)
            }
            return berechne(statischerProzentwert: punkte)
        }
        
        static func berechne(statischerProzentwert: Int) -> DossierFortschritt {
            let prozent = min(max(statischerProzentwert, 0), 100)
            let einheitlicherAktionsText = "Dossier als überprüft markieren"
            
            if prozent >= 100 {
                return DossierFortschritt(
                    prozent: 100,
                    farbe: Color(red: 0.45, green: 0.82, blue: 0.62),
                    titel: "Dein Vorsorge-Dossier ist ausgefüllt",
                    beschreibung: "Super, du hast dir die Zeit genommen, die wichtigsten Informationen zu dir und deiner Lebenssituation festzuhalten. Damit schaffst du eine wertvolle Grundlage, die deinen Hinterbliebenen im Ernstfall Orientierung und Unterstützung bietet. Das nennt sich vorausschauende Vorsorge - top!",
                    aktionsText: einheitlicherAktionsText,
                    aktionsIcon: "checkmark.seal.fill"
                )
            }
            
            if prozent <= 30 {
                return DossierFortschritt(
                    prozent: prozent,
                    farbe: Color(red: 0.86, green: 0.32, blue: 0.28),
                    titel: "Du bist noch am Anfang.",
                    beschreibung: "Damit deine Hinterbliebenen wissen, was dir wichtig ist und wie deine Situation aussieht, erfasse weitere Informationen.",
                    aktionsText: einheitlicherAktionsText,
                    aktionsIcon: "checkmark.circle.fill"
                )
            }
            
            if prozent <= 60 {
                return DossierFortschritt(
                    prozent: prozent,
                    farbe: Color(red: 0.92, green: 0.56, blue: 0.22),
                    titel: "Du bist auf gutem Weg.",
                    beschreibung: "Zusätzliche Angaben zu deinen Wünschen, Finanzen und Dokumenten helfen deinen Hinterbliebenen im Ernstfall erheblich.",
                    aktionsText: einheitlicherAktionsText,
                    aktionsIcon: "checkmark.circle.fill"
                )
            }
            
            return DossierFortschritt(
                prozent: prozent,
                farbe: Color(red: 0.45, green: 0.82, blue: 0.62),
                titel: "Du bist sehr gut vorbereitet.",
                beschreibung: "Ergänze alles, was dir noch in den Sinn kommt. Jede zusätzliche Information kann deinen Hinterbliebenen helfen.",
                aktionsText: einheitlicherAktionsText,
                aktionsIcon: "checkmark.circle.fill"
            )
            
        }
    }
    
    struct HomeInfoChip: View {
        let icon: String
        let titel: String
        
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                
                Text(titel)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    #Preview {
        Home()
    }
    
    struct FreigegebenesDossierDetailView: View {
        let dossierKontext: DossierKontext
        private let kachelFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
        private let akzentFarbe = Color.orange
        private let schluessliAkzent = Color(red: 0.16, green: 0.36, blue: 0.42)
        @State private var dossierBereicheAnzeigen = false
        @State private var dossierGeoeffnetBestaetigungAnzeigen = false
        @State private var dossierGeoeffnetHaekchenAnimieren = false

        private var dossierName: String {
            dossierKontext.besitzerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (dossierKontext.besitzerName ?? "Freigegebenes Dossier")
            : "Freigegebenes Dossier"
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(akzentFarbe.opacity(0.14))
                                    .frame(width: 54, height: 54)

                                Image(systemName: "folder.badge.person.crop")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(akzentFarbe)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Freigegebenes Dossier")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(akzentFarbe)
                                    .textCase(.uppercase)

                                Text(dossierName)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                                if let lesemodusHinweis = dossierKontext.lesemodusHinweis {
                                    Text(lesemodusHinweis)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Label("Lesemodus", systemImage: "eye")
                            Label("Nicht bearbeitbar", systemImage: "lock.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(schluessliAkzent)

                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(kachelFarbe)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    }
                    .shadow(color: akzentFarbe.opacity(0.10), radius: 14, x: 0, y: 8)

                    if !dossierBereicheAnzeigen {
                        Button {
                            dossierGeoeffnetHaekchenAnimieren = false

                            withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) {
                                dossierBereicheAnzeigen = true
                                dossierGeoeffnetBestaetigungAnzeigen = true
                            }

                            Task {
                                try? await Task.sleep(nanoseconds: 120_000_000)
                                await MainActor.run {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) {
                                        dossierGeoeffnetHaekchenAnimieren = true
                                    }
                                }

                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                await MainActor.run {
                                    withAnimation(.easeOut(duration: 0.28)) {
                                        dossierGeoeffnetBestaetigungAnzeigen = false
                                        dossierGeoeffnetHaekchenAnimieren = false
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill.badge.person.crop")
                                    .font(.body.weight(.semibold))

                                Text("Dossier öffnen")
                                    .font(.body.weight(.semibold))

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(akzentFarbe)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if dossierBereicheAnzeigen {
                        VStack(alignment: .leading, spacing: 10) {
                            if dossierGeoeffnetBestaetigungAnzeigen {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .scaleEffect(dossierGeoeffnetHaekchenAnimieren ? 1.16 : 0.72)
                                        .opacity(dossierGeoeffnetHaekchenAnimieren ? 1 : 0.35)

                                    Text("Dossier von \(dossierName) geöffnet")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(Color.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.12))
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }

                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                    dossierBereicheAnzeigen = false
                                    dossierGeoeffnetBestaetigungAnzeigen = false
                                    dossierGeoeffnetHaekchenAnimieren = false
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Dossier")
                                        .font(.title3.weight(.bold))

                                    Image(systemName: "chevron.up.circle.fill")
                                        .font(.subheadline.weight(.semibold))

                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(akzentFarbe)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                // TODO: PDFExportService später hier anschliessen.
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.richtext.fill")
                                        .font(.body.weight(.semibold))

                                    Text("Dossier als PDF exportieren")
                                        .font(.body.weight(.semibold))

                                    Spacer(minLength: 0)

                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(akzentFarbe)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(akzentFarbe.opacity(0.10))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.28)))

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(HomeBereich.allCases) { bereich in
                                NavigationLink {
                                    zielView(fuer: bereich)
                                } label: {
                                    Home.HomeKachel(
                                        icon: bereich.icon,
                                        titel: bereich.titel,
                                        untertitel: bereich.untertitel,
                                        details: bereich.details,
                                        farbe: kachelFarbe,
                                        akzentFarbe: bereich.akzentFarbe
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.30), value: dossierBereicheAnzeigen)
                .animation(.easeInOut(duration: 0.24), value: dossierGeoeffnetBestaetigungAnzeigen)
                .animation(.spring(response: 0.32, dampingFraction: 0.58), value: dossierGeoeffnetHaekchenAnimieren)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Dossier")
            .navigationBarTitleDisplayMode(.inline)
        }

        @ViewBuilder
        private func zielView(fuer bereich: HomeBereich) -> some View {
            switch bereich {
            case .profil:
                ProfilView(dossierKontext: dossierKontext)
            case .gesundheit:
                GesundheitView()
            case .wuensche:
                WuenscheView(dossierKontext: dossierKontext)
            case .finanzen:
                FinanzenView()
            case .hinterbliebene:
                HinterbliebeneView()
            case .dokumente:
                DokumenteView(dossierKontext: dossierKontext)
            case .abos:
                AbosView()
            }
        }
    }
    
    
#if DEBUG
    private struct HomeDebugTestPanel: View {
        @AppStorage("aktiveUserID") private var aktiveUserID = ""
        @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
        @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
        @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
        
        @Query private var profile: [ProfilModell]
        @Query private var dossiers: [DossierModell]
        @Query private var dossierZugriffe: [DossierZugriffModell]
        
        private var aktivesProfil: ProfilModell? {
            guard let uuid = UUID(uuidString: aktiveUserID) else { return nil }
            return profile.first { $0.userID == uuid }
        }
        
        private var aktivesDossier: DossierModell? {
            if let profil = aktivesProfil {
                return dossiers.first { $0.dossierID == profil.dossierID }
            }
            
            return dossiers.first
        }
        
        var body: some View {
            GroupBox("🧪 Developer Testcenter") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktiver Benutzer")
                            .font(.headline)
                        
                        Text("Profil vorhanden: \(profilIstVorhanden ? "Ja" : "Nein")")
                        Text("Direkt eingeloggt: \(direktNachRegistrierungEingeloggt ? "Ja" : "Nein")")
                        Text("E-Mail: \(gespeicherteEmail.isEmpty ? "-" : gespeicherteEmail)")
                        Text("User-ID: \(aktiveUserID.isEmpty ? "-" : aktiveUserID)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    
                    Divider()

                    NavigationLink {
                        FreigegebenesDossierDetailView(
                            dossierKontext: .freigegebenesDossier(
                                dossierID: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                                zugriffID: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                                besitzerName: "Testperson",
                                besitzerEmail: "testperson@example.com"
                            )
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.2.badge.key")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Freigegebenes Dossier testen")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("Öffnet die spätere Vertrauenspersonen-Ansicht im Lesemodus.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dossier")
                            .font(.headline)
                        
                        if let aktivesDossier {
                            Text("Dossier-ID: \(aktivesDossier.dossierID.uuidString)")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text("Aktiv: \(aktivesDossier.istAktiv ? "Ja" : "Nein")")
                            Text("Freigegeben: \(aktivesDossier.istFreigegeben ? "Ja" : "Nein")")
                            Text("Schreibgeschützt: \(aktivesDossier.istSchreibgeschuetzt ? "Ja" : "Nein")")
                        } else {
                            Text("Kein Dossier gefunden.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Einladungen")
                            .font(.headline)
                        
                        if dossierZugriffe.isEmpty {
                            Text("Noch keine Einladungen vorhanden.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dossierZugriffe) { zugriff in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(zugriff.eingeladeneEmail)
                                        .font(.subheadline.bold())
                                    
                                    Text("Eingeladen an: \(zugriff.eingeladeneEmail)")
                                    
                                    Text("Registriert mit: \((zugriff.registrierungsEmail?.isEmpty == false) ? (zugriff.registrierungsEmail ?? "-") : "-")")
                                    
                                    if let registrierungsEmail = zugriff.registrierungsEmail,
                                       !registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                       registrierungsEmail.lowercased() != zugriff.eingeladeneEmail.lowercased() {
                                        Text("Hinweis: Registrierung erfolgte mit abweichender E-Mail-Adresse.")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                    
                                    Text("Token: \(zugriff.einladungsToken ?? "-")")
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                    
                                    Text("Einladungslink: \(zugriff.kannRegistrierungFortsetzen ? "Noch verwendbar" : "Bereits verwendet")")
                                        .foregroundStyle(zugriff.kannRegistrierungFortsetzen ? .green : .orange)
                                    
                                    Text("Status: \(zugriff.status)")
                                    Text("Aktiv: \(zugriff.istAktiv ? "Ja" : "Nein")")
                                    Text("Link verwendet: \(zugriff.einladungsLinkVerwendet ? "Ja" : "Nein")")
                                    
                                    if let gueltigBis = zugriff.einladungGueltigBis {
                                        Text("Gültig bis: \(gueltigBis.formatted(date: .abbreviated, time: .shortened))")
                                    }
                                    
                                    if let verwendetAm = zugriff.einladungsLinkVerwendetAm {
                                        Text("Verwendet am: \(verwendetAm.formatted(date: .abbreviated, time: .shortened))")
                                    }
                                    
                                    if let userID = zugriff.vertrauenspersonUserID {
                                        Text("Vertrauensperson-ID: \(userID.uuidString)")
                                            .font(.caption2.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                Divider()
                            }
                        }
                    }
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
#endif


       
