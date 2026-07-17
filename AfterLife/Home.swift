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
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""
    @AppStorage("dossierZuletztGeprueftAmISO") private var dossierZuletztGeprueftAmISO = ""
    @AppStorage("dossierLetzterExportAmISO") private var dossierLetzterExportAmISO = ""
    @AppStorage("homeBereicheReihenfolge") private var homeBereicheReihenfolge = ""
    @AppStorage("homeAktiveBereiche") private var homeAktiveBereiche = ""
    @AppStorage(VorsorgeBereichStatusStore.storageKey) private var vorsorgeBereichStatusJSON = ""
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteGesundheitsdaten: [GesundheitModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]
    @Query private var gespeicherteVertrauenspersonen: [VertrauenspersonModell]
    @Query private var gespeicherteDossiers: [DossierModell]
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
    @State private var bereichsauswahl: Set<HomeBereich> = []
    @State private var bereichsauswahlAnzeigen = false
    @State private var dossierPruefungRefreshDatum = Date()
    @State private var dossierPruefungSheetAnzeigen = false
    @State private var dossierPruefungZuruecksetzenAnzeigen = false
    @State private var erinnerungsAuswahlAnzeigen = false
    @State private var mitteilungenEinstellungenAnzeigen = false
    @State private var ausstehendesPruefDatum: Date?
    @State private var dossierExportAnzeigen = false
    @State private var vertrauenspersonAnzeigen = false
    @State private var ersterVorsorgeBereichAnzeigen = false
    @State private var empfohlenerBereichAnzeigen: HomeBereich?
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

    private var aktiveHomeBereiche: Set<HomeBereich> {
        let gespeicherteBereiche = Set(
            homeAktiveBereiche
                .split(separator: ",")
                .compactMap { HomeBereich(rawValue: String($0)) }
        )

        if !gespeicherteBereiche.isEmpty {
            return gespeicherteBereiche.union([.profil])
        }

        // Bestehende Installationen behalten ihre bisher sichtbaren Kacheln.
        // Eine neue Installation startet bewusst nur mit dem Profil.
        return homeBereicheReihenfolge.isEmpty ? [.profil] : Set(HomeBereich.allCases)
    }

    private var sortierteHomeBereiche: [HomeBereich] {
        let gespeicherteIDs = homeBereicheReihenfolge
            .split(separator: ",")
            .map { String($0) }

        let gespeicherteBereiche = gespeicherteIDs
            .compactMap { HomeBereich(rawValue: $0) }
            .filter { aktiveHomeBereiche.contains($0) }
        let fehlendeBereiche = HomeBereich.allCases.filter {
            aktiveHomeBereiche.contains($0) && !gespeicherteBereiche.contains($0)
        }

        if gespeicherteBereiche.isEmpty {
            return HomeBereich.allCases.filter { aktiveHomeBereiche.contains($0) }
        }

        return gespeicherteBereiche + fehlendeBereiche
    }

    private var angezeigteHomeBereiche: [HomeBereich] {
        bearbeiteteHomeBereiche.isEmpty ? sortierteHomeBereiche : bearbeiteteHomeBereiche
    }

    private var profilGrundlageErfasst: Bool {
        guard let profil = aktivesProfil else { return false }
        return !profil.vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profil.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hatZusaetzlicheHomeBereiche: Bool {
        aktiveHomeBereiche.contains { $0 != .profil }
    }

    private var empfohlenerHomeBereich: HomeBereich? {
        let bereiche = angezeigteHomeBereiche.filter { $0 != .profil }

        if let nichtBegonnen = bereiche.first(where: {
            !bereichAktivitaet(fuer: $0).wurdeBegonnen
        }) {
            return nichtBegonnen
        }

        if let geaendert = bereiche.first(where: {
            bereichAktivitaet(fuer: $0).wurdeSeitPruefungGeaendert
        }) {
            return geaendert
        }

        return bereiche.max {
            (bereichAktivitaet(fuer: $0).zuletztGeaendertAm ?? .distantPast) <
            (bereichAktivitaet(fuer: $1).zuletztGeaendertAm ?? .distantPast)
        }
    }

    private func bereichAktivitaet(fuer bereich: HomeBereich) -> VorsorgeBereichAktivitaet {
        _ = vorsorgeBereichStatusJSON
        return VorsorgeBereichStatusStore.status(fuer: bereich.statusID)
    }

    private func bereichStatusText(fuer bereich: HomeBereich) -> String? {
        guard bereich != .profil || profilGrundlageErfasst else { return "Nicht begonnen" }
        let aktivitaet = bereichAktivitaet(fuer: bereich)
        if aktivitaet.wurdeSeitPruefungGeaendert { return "Geändert" }
        if aktivitaet.istAktuellGeprueft { return "Aktuell" }
        if aktivitaet.wurdeBegonnen || bereich == .profil { return "Begonnen" }
        return "Nicht begonnen"
    }
    
    private var dossierNaechstePruefungAm: Date? {
        _ = dossierPruefungRefreshDatum

        guard let datum = ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO) else {
            return nil
        }

    
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

    private var letztePruefungAm: Date? {
        ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO)
    }

    private var letzterExportAm: Date? {
        ISO8601DateFormatter().date(from: dossierLetzterExportAmISO)
    }

    private var aktivesDossier: DossierModell? {
        if let id = UUID(uuidString: aktivesDossierID),
           let dossier = gespeicherteDossiers.first(where: { $0.dossierID == id }) {
            return dossier
        }
        return gespeicherteDossiers.first(where: { $0.istHauptdossier }) ?? gespeicherteDossiers.first
    }

    private var zugriffeFuerAktivesDossier: [DossierZugriffModell] {
        guard let dossierID = aktivesDossier?.dossierID ?? aktivesProfil?.dossierID else { return [] }
        return gespeicherteDossierZugriffe.filter { $0.dossierID == dossierID && $0.istAktiv }
    }

    private var vertrauenspersonenFuerAktivenUser: [VertrauenspersonModell] {
        guard let userID = aktivesProfil?.userID else { return [] }
        return gespeicherteVertrauenspersonen.filter {
            $0.vorsorgendeUserID == userID && $0.istLokalHinterlegt
        }
    }

    private var vorsorgeStatus: VorsorgeStatus {
        let letzteBereichsaenderung = aktiveHomeBereiche
            .compactMap { bereichAktivitaet(fuer: $0).zuletztGeaendertAm }
            .max()
        let letzteInhaltlicheAenderung = [aktivesDossier?.aktualisiertAm, letzteBereichsaenderung]
            .compactMap { $0 }
            .max()

        return VorsorgeStatusService.berechne(
            vollstaendigkeit: dossierFortschritt.kreisFortschritt,
            wurdeGeprueft: dossierWurdeGeprueft,
            letzterExportAm: letzterExportAm,
            letzteInhaltlicheAenderungAm: letzteInhaltlicheAenderung,
            // Nicht im MVP Scope: Einladungsstatus und Dossier-Freigabe.
            hatOffeneEinladung: false,
            hatAktiveVertrauensperson: !vertrauenspersonenFuerAktivenUser.isEmpty
        )
    }

    private var heroTitel: String {
        if !profilGrundlageErfasst { return "Deine Vorsorge beginnt hier" }
        if !hatZusaetzlicheHomeBereiche { return "Gestalte deine Vorsorge" }
        if vorsorgeStatus == .dossierErstellt, !vertrauenspersonenFuerAktivenUser.isEmpty {
            return "Deine Vorsorge ist aktuell"
        }
        if vorsorgeStatus == .unvollstaendig { return dossierFortschritt.titel }
        return vorsorgeStatus.titel
    }

    private var heroBeschreibung: String {
        if !profilGrundlageErfasst {
            return "Lege mit deinen persönlichen Angaben die Grundlage für dein Vorsorge-Dossier."
        }
        if !hatZusaetzlicheHomeBereiche {
            return "Wähle die Bereiche aus, die für dich wichtig sind. Du kannst deine Auswahl jederzeit ändern."
        }
        if vorsorgeStatus == .dossierErstellt, !vertrauenspersonenFuerAktivenUser.isEmpty {
            return "Vorsorge-Dossier aktuell und Vertrauensperson hinterlegt."
        }
        if vorsorgeStatus == .unvollstaendig { return dossierFortschritt.beschreibung }
        return vorsorgeStatus.beschreibung
    }

    private var heroButtonTitel: String {
        if !profilGrundlageErfasst { return "Profil vervollständigen" }
        if !hatZusaetzlicheHomeBereiche { return "Vorsorge Bereiche zusammenstellen" }
        if dossierPruefungIstFaellig { return "Vorsorge-Dossier prüfen" }
        if !dossierWurdeGeprueft && vertrauenspersonenFuerAktivenUser.isEmpty {
            return "Vertrauensperson festlegen"
        }
        if !dossierWurdeGeprueft && dossierFortschritt.kreisFortschritt >= 0.7 {
            return "Vorsorge-Dossier jetzt abschliessen"
        }
        if vorsorgeStatus == .unvollstaendig, let empfohlenerHomeBereich {
            return bereichAktivitaet(fuer: empfohlenerHomeBereich).wurdeBegonnen
                ? "\(empfohlenerHomeBereich.titel) weiterführen"
                : "\(empfohlenerHomeBereich.titel) beginnen"
        }
        return vorsorgeStatus.buttonTitel
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
                            Image("etienne-bosiger-OWsdJ-MllYA-unsplash")
                           // Image("mark-basarab-z8ct_Q3oCqM-unsplash")
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
                                
                                VorsorgeStatusCard(
                                    status: vorsorgeStatus,
                                    titel: heroTitel,
                                    beschreibung: heroBeschreibung,
                                    buttonTitel: heroButtonTitel,
                                    fortschritt: dossierFortschritt.kreisFortschritt,
                                    letztePruefung: letztePruefungAm,
                                    vertrauenspersonen: vertrauenspersonenFuerAktivenUser.count,
                                    akzentFarbe: schluessliAkzent,
                                    fortschrittFarbe: dossierFortschritt.farbe,
                                    zeigtPrimaereAktion: !(vorsorgeStatus == .dossierErstellt
                                        && !vertrauenspersonenFuerAktivenUser.isEmpty),
                                    action: handleVorsorgeCTA,
                                    zeigtPruefenAktion: hatZusaetzlicheHomeBereiche
                                        && !dossierWurdeGeprueft
                                        && !dossierPruefungIstFaellig
                                        && (dossierFortschritt.kreisFortschritt < 0.7
                                            || vertrauenspersonenFuerAktivenUser.isEmpty),
                                    pruefenButtonTitel: dossierPruefungIstFaellig
                                        ? "Vorsorge-Dossier prüfen"
                                        : "Vorsorge-Dossier jetzt abschliessen",
                                    pruefenAction: { dossierPruefungSheetAnzeigen = true },
                                    pruefungZuruecksetzenAction: dossierWurdeGeprueft
                                        ? { dossierPruefungZuruecksetzenAnzeigen = true }
                                        : nil
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                        }
                        .frame(width: breite, height: heroHoehe)
                    }
                    .frame(height: 430)
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
                        HStack(alignment: .firstTextBaseline) {
                            Text("Bereiche")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                            Spacer()

                            Button("Verwalten") {
                                bereichsauswahl = aktiveHomeBereiche
                                bereichsauswahlAnzeigen = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(schluessliAkzent)
                        }

                        Text("In den verschiedenen Bereichen kannst du deine Angaben machen und jederzeit ändern.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .opacity(bereicheTitelIstSichtbar ? (homeBearbeitungsmodus ? 0.45 : 1) : 0)
                    .offset(y: bereicheTitelIstSichtbar ? 0 : 10)
                    .allowsHitTesting(!homeBearbeitungsmodus && bereicheTitelIstSichtbar)
                    .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
                    .animation(.easeInOut(duration: 0.22), value: dossierPruefungIstFaellig)
                    .animation(.easeOut(duration: 0.45), value: bereicheTitelIstSichtbar)
                    
                    alleKacheln
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .offset(y: kachelnSindSichtbar ? 0 : 18)
                        .opacity(kachelnSindSichtbar ? 1 : 0)
                        .animation(.easeOut(duration: 0.55), value: kachelnSindSichtbar)
                    
                    // MARK: - nicht in Scope MVP 1
                    // if !verknuepfteVorsorgedossiers.isEmpty {
                    //     vorsorgedossierWechselAktion
                    //         .padding(.horizontal, 24)
                    //         .padding(.top, 18)
                    //         .padding(.bottom, 28)
                    //         .offset(y: kachelnSindSichtbar ? 0 : 20)
                    //         .opacity(kachelnSindSichtbar ? (homeBearbeitungsmodus ? 0.38 : 1) : 0)
                    //         .allowsHitTesting(!homeBearbeitungsmodus)
                    //         .overlay {
                    //             RoundedRectangle(cornerRadius: 24, style: .continuous)
                    //                 .fill(Color(.systemBackground).opacity(homeBearbeitungsmodus ? 0.24 : 0))
                    //                 .allowsHitTesting(false)
                    //         }
                    //         .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
                    // }

                    Image("Icon1_trans")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 58)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                        .opacity(homeBearbeitungsmodus ? 0.35 : 0.82)
                        .accessibilityLabel("Tschlüssli")
                        .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
                    
#if DEBUG
                    // Nicht MPV Scope
                    // HomeDebugTestPanel()
                    //     .padding(.horizontal, 24)
                    //     .padding(.top, 8)
                    //     .padding(.bottom, 32)
                    //     .opacity(homeBearbeitungsmodus ? 0.35 : 1)
                    //     .allowsHitTesting(!homeBearbeitungsmodus)
                    //     .overlay {
                    //         RoundedRectangle(cornerRadius: 18, style: .continuous)
                    //             .fill(Color(.systemBackground).opacity(homeBearbeitungsmodus ? 0.24 : 0))
                    //             .allowsHitTesting(false)
                    //     }
                    //     .animation(.easeInOut(duration: 0.22), value: homeBearbeitungsmodus)
#endif
                }
                .background(Color(.systemBackground))
                .navigationDestination(isPresented: $vertrauenspersonAnzeigen) {
                    VertrauenspersonView()
                }
                .navigationDestination(isPresented: $ersterVorsorgeBereichAnzeigen) {
                    ProfilView()
                }
                .navigationDestination(item: $empfohlenerBereichAnzeigen) { bereich in
                    zielView(fuer: bereich)
                }
                // MARK: - nicht in Scope MVP 1
                // .navigationDestination(isPresented: $direktesVorsorgedossierOeffnen) {
                //     FreigegebenesDossierDetailView(
                //         dossierKontext: .freigegebenesDossier(
                //             dossierID: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                //             zugriffID: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                //             besitzerName: ausgewaehltesVorsorgedossier.isEmpty ? "Testperson" : ausgewaehltesVorsorgedossier,
                //             besitzerEmail: "testperson@example.com"
                //         )
                //     )
                // }
                // .confirmationDialog(
                //     "Vorsorge-Dossier auswählen",
                //     isPresented: $vorsorgedossierAuswahlAnzeigen,
                //     titleVisibility: .visible
                // ) {
                //     ForEach(verknuepfteVorsorgedossiers, id: \.self) { name in
                //         Button(name) {
                //             ausgewaehltesVorsorgedossier = name
                //             direktesVorsorgedossierOeffnen = true
                //         }
                //     }
                //
                //     Button("Abbrechen", role: .cancel) { }
                // } message: {
                //     Text("Wähle aus, welches Vorsorge-Dossier du öffnen möchtest.")
                // }
                .sheet(isPresented: $dossierPruefungSheetAnzeigen) {
                    DossierPruefungSheet(
                        accentColor: schluessliAkzent,
                        bereiche: angezeigteHomeBereiche,
                        statusText: { bereichStatusText(fuer: $0) ?? "Nicht begonnen" }
                    ) {
                        dossierAlsGeprueftMarkieren()
                        dossierPruefungSheetAnzeigen = false
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $bereichsauswahlAnzeigen) {
                    HomeBereichsauswahlSheet(
                        auswahl: $bereichsauswahl,
                        accentColor: schluessliAkzent,
                        speichern: bereichsauswahlSpeichern
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $dossierExportAnzeigen) {
                    ProfilView(dossierExportDirektAnzeigen: true)
                }
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    dossierPruefungRefreshDatum = Date()
                    starteHomeEinstiegsanimation()
                }
                .confirmationDialog(
                    "Prüfstatus zurücksetzen?",
                    isPresented: $dossierPruefungZuruecksetzenAnzeigen,
                    titleVisibility: .visible
                ) {
                    Button("Prüfstatus zurücksetzen", role: .destructive) {
                        dossierPruefungZuruecksetzen()
                    }
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Das Vorsorge-Dossier wird wieder als noch nicht geprüft angezeigt und die geplante Erinnerung wird entfernt.")
                }
                .confirmationDialog(
                    "Jährliche Erinnerung aktivieren?",
                    isPresented: $erinnerungsAuswahlAnzeigen,
                    titleVisibility: .visible
                ) {
                    Button("Erinnerung aktivieren") {
                        erinnerungAktivieren()
                    }

                    Button("Ohne Erinnerung", role: .cancel) {
                        ausstehendesPruefDatum = nil
                        NotificationService.shared.jaehrlicheDossierPruefungEntfernen()
                    }
                } message: {
                    Text("Tschlüssli kann dich nächstes Jahr daran erinnern, dein Vorsorge-Dossier erneut zu prüfen.")
                }
                .alert(
                    "Mitteilungen sind deaktiviert",
                    isPresented: $mitteilungenEinstellungenAnzeigen
                ) {
                    Button("Einstellungen öffnen") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Aktiviere Mitteilungen in den iOS-Einstellungen, damit Tschlüssli dich an die jährliche Vorsorge-Dossier-Prüfung erinnern kann.")
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

    private func handleVorsorgeCTA() {
        if !profilGrundlageErfasst {
            ersterVorsorgeBereichAnzeigen = true
            return
        }

        if !hatZusaetzlicheHomeBereiche {
            bereichsauswahl = aktiveHomeBereiche
            bereichsauswahlAnzeigen = true
            return
        }

        if dossierPruefungIstFaellig {
            dossierPruefungSheetAnzeigen = true
            return
        }

        if !dossierWurdeGeprueft && vertrauenspersonenFuerAktivenUser.isEmpty {
            vertrauenspersonAnzeigen = true
            return
        }

        if !dossierWurdeGeprueft && dossierFortschritt.kreisFortschritt >= 0.7 {
            dossierPruefungSheetAnzeigen = true
            return
        }

        switch vorsorgeStatus {
        case .unvollstaendig:
            empfohlenerBereichAnzeigen = empfohlenerHomeBereich ?? .profil
        case .bereitZurPruefung, .aktualisierungNoetig:
            dossierPruefungSheetAnzeigen = true
        case .geprueft:
            dossierExportAnzeigen = true
        case .dossierErstellt, .einladungOffen, .vertrauenspersonAktiv:
            vertrauenspersonAnzeigen = true
        }
    }

    private func bereichsauswahlSpeichern() {
        let neueAuswahl = bereichsauswahl.union([.profil])
        initialisiereHomeBereicheFallsNoetig()

        var neueReihenfolge = bearbeiteteHomeBereiche.filter { neueAuswahl.contains($0) }
        let neueBereiche = HomeBereich.allCases.filter {
            neueAuswahl.contains($0) && !neueReihenfolge.contains($0)
        }
        neueReihenfolge.append(contentsOf: neueBereiche)

        bearbeiteteHomeBereiche = neueReihenfolge
        homeAktiveBereiche = neueReihenfolge.map(\.rawValue).joined(separator: ",")
        homeBereicheReihenfolge = neueReihenfolge.map(\.rawValue).joined(separator: ",")
        bereichsauswahlAnzeigen = false
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
                        Text("Freigegebene Vorsorge-Dossiers")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                        
                        Text("Öffne ein Vorsorge-Dossier, für das du als Vertrauensperson berechtigt bist.")
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
            VorsorgeBereichStatusStore.markiereGeprueft(
                aktiveHomeBereiche.map(\.statusID),
                am: pruefDatum
            )
            ausstehendesPruefDatum = pruefDatum
            erinnerungsAuswahlAnzeigen = true
        }

        private func dossierPruefungZuruecksetzen() {
            dossierZuletztGeprueftAmISO = ""
            VorsorgeBereichStatusStore.pruefungZuruecksetzen()
            ausstehendesPruefDatum = nil
            dossierPruefungRefreshDatum = Date()
            NotificationService.shared.jaehrlicheDossierPruefungEntfernen()
        }

        private func erinnerungAktivieren() {
            guard let pruefDatum = ausstehendesPruefDatum else { return }

            NotificationService.shared.berechtigungAnfragen { erlaubt in
                if erlaubt {
                    NotificationService.shared.jaehrlicheDossierPruefungPlanen(ab: pruefDatum)
                } else {
                    mitteilungenEinstellungenAnzeigen = true
                }

                ausstehendesPruefDatum = nil
            }
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
                statusText: homeBearbeitungsmodus ? nil : bereichStatusText(fuer: bereich),
                farbe: kachelFarbe,
                akzentFarbe: bereich.akzentFarbe
            )
        }
        
        struct HomeKachel: View {
            let icon: String
            let titel: String
            let untertitel: String
            let details: String
            let statusText: String?
            let farbe: Color
            let akzentFarbe: Color

            private var statusFarbe: Color {
                switch statusText {
                case "Aktuell": return .green
                case "Geändert": return .orange
                case "Begonnen": return akzentFarbe
                default: return .secondary
                }
            }
            
            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(akzentFarbe.opacity(0.14))
                                .frame(width: 48, height: 48)

                            Image(systemName: icon)
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(akzentFarbe)
                        }

                        Spacer(minLength: 0)

                        if let statusText {
                            Text(statusText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(statusFarbe)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(statusFarbe.opacity(0.11), in: Capsule())
                        }
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
        let bereiche: [HomeBereich]
        let statusText: (HomeBereich) -> String
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
                    
                    Text(istAbgeschlossen ? "Vorsorge-Dossier geprüft" : "(Jährliche) Prüfung deines Vorsorge-Dossiers")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(istAbgeschlossen ? "Dein Vorsorge-Dossier ist jetzt wieder auf dem aktuellsten Stand. Wir erinnern dich nächstes Jahr erneut." : "Nimm dir kurz Zeit und prüfe, ob deine wichtigsten Angaben noch stimmen. Insbesondere deine persönlichen Daten, Wünsche und Personen denen du Zugriffe erteilt hast.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if !istAbgeschlossen {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(bereiche) { bereich in
                            pruefpunkt(bereich.titel, status: statusText(bereich))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Text("Du kannst dein Vorsorge-Dossier mit dem aktuellen Stand abschliessen. Noch nicht begonnene Bereiche bleiben verfügbar und können später ergänzt werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                    Text(istAbgeschlossen ? "Erledigt" : "Aktuellen Stand als geprüft bestätigen")
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
        
        private func pruefpunkt(_ titel: String, status: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: status == "Nicht begonnen" ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(status == "Nicht begonnen" ? Color.secondary : accentColor)
                Text(titel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                Spacer(minLength: 8)

                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct HomeBereichsauswahlSheet: View {
        @Binding var auswahl: Set<HomeBereich>
        let accentColor: Color
        let speichern: () -> Void
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Deine Vorsorgebereiche")
                                .font(.title2.weight(.bold))

                            Text("Wähle aus, welche Themen du auf deinem Homescreen vorbereiten möchtest. Deine Auswahl und Reihenfolge kannst du später jederzeit ändern.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            ForEach(HomeBereich.allCases.filter { $0 != .profil }) { bereich in
                                Button {
                                    if auswahl.contains(bereich) {
                                        auswahl.remove(bereich)
                                    } else {
                                        auswahl.insert(bereich)
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(bereich.akzentFarbe.opacity(0.14))
                                                .frame(width: 46, height: 46)

                                            Image(systemName: bereich.icon)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(bereich.akzentFarbe)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(bereich.titel)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(bereich.details)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        Spacer(minLength: 8)

                                        Image(systemName: auswahl.contains(bereich) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(auswahl.contains(bereich) ? accentColor : Color.secondary.opacity(0.45))
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(24)
                }
                .safeAreaInset(edge: .bottom) {
                    Button(action: speichern) {
                        Text(auswahl.filter { $0 != .profil }.isEmpty ? "Nur Profil anzeigen" : "Auswahl übernehmen")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accentColor))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Abbrechen") { dismiss() }
                            .foregroundStyle(accentColor)
                    }
                }
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

        var statusID: VorsorgeBereichID {
            VorsorgeBereichID(rawValue: rawValue) ?? .profil
        }

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
                return "Persönliche Wünsche festhalten, Testament oder Vorsorgeauftrag hinterlegen"
            case .finanzen:
                return "Konten, Schulden, Versicherungen und Wertsachen auflisten"
            case .hinterbliebene:
                return "Familie & Freunde, Anwälte als Kontakte hinterlegen"
            case .dokumente:
                return "Wichtige Dokumente hochladen und Fotoalbum erstellen"
            case .abos:
                return "Digitale Profile & Social Media, Streamingdienste und Zugänge und Abos"
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
            let einheitlicherAktionsText = "Vorsorge-Dossier als überprüft markieren"
            
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
            ? (dossierKontext.besitzerName ?? "Freigegebenes Vorsorge-Dossier")
            : "Freigegebenes Vorsorge-Dossier"
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
                                Text("Freigegebenes Vorsorge-Dossier")
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

                                Text("Vorsorge-Dossier öffnen")
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

                                    Text("Vorsorge-Dossier von \(dossierName) geöffnet")
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
                                    Text("Vorsorge-Dossier")
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

                                    Text("Vorsorge-Dossier als PDF exportieren")
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
                                        statusText: nil,
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
            .navigationTitle("Vorsorge-Dossier")
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
            GroupBox("🧪 Developer Test-Center") {
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
                                Text("Freigegebenes Vorsorge-Dossier testen")
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
                            Text("Vorsorge-Dossier-ID: \(aktivesDossier.dossierID.uuidString)")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text("Aktiv: \(aktivesDossier.istAktiv ? "Ja" : "Nein")")
                            Text("Freigegeben: \(aktivesDossier.istFreigegeben ? "Ja" : "Nein")")
                            Text("Schreibgeschützt: \(aktivesDossier.istSchreibgeschuetzt ? "Ja" : "Nein")")
                        } else {
                            Text("Kein Vorsorge-Dossier gefunden.")
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


       
