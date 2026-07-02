import SwiftUI
import SwiftData
import UIKit

struct Home: View {
    private let kachelFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let schluessliAkzent = Color(red: 0.16, green: 0.36, blue: 0.42)
    // TEST: später durch echte Beziehungen aus dem Einladungs-/VertrauenspersonModell ersetzen
    private let verknuepfteVorsorgedossiers = ["René Engeler"]
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("dossierZuletztGeprueftAmISO") private var dossierZuletztGeprueftAmISO = ""
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteGesundheitsdaten: [GesundheitModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]
    @Query private var gespeicherteBankkonten: [BankkontoModell]
    @Query private var gespeicherteVersicherungen: [VersicherungModell]
    @Query private var gespeicherteWertsachen: [WertsacheModell]
    @Query private var gespeicherteDokumente: [DokumenteModell]
    @Query private var gespeicherteAbos: [AboModell]
    @State private var kachelnSindSichtbar = false
    @State private var vorsorgedossierAuswahlAnzeigen = false
    @State private var direktesVorsorgedossierOeffnen = false
    @State private var ausgewaehltesVorsorgedossier = ""
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
    
    private var dossierWurdeGeprueft: Bool {
        guard let datum = ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO) else {
            return false
        }
        
        guard let naechstePruefung = Calendar.current.date(byAdding: .year, value: 1, to: datum) else {
            return false
        }
        
        return Date() < naechstePruefung
    }
    
    private var dossierZuletztGeprueftText: String {
        guard let datum = ISO8601DateFormatter().date(from: dossierZuletztGeprueftAmISO) else {
            return dossierFortschritt.aktionsText
        }
        
        if dossierWurdeGeprueft {
            return "Zuletzt überprüft am \(datum.formatted(date: .abbreviated, time: .omitted))"
        }
        
        return "Erneut überprüfen"
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
                                            Image(systemName: dossierWurdeGeprueft ? "arrow.clockwise.circle.fill" : dossierFortschritt.aktionsIcon)
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
                                    if dossierWurdeGeprueft {
                                        dossierZuletztGeprueftAmISO = ""
                                    } else {
                                        dossierZuletztGeprueftAmISO = ISO8601DateFormatter().string(from: Date())
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                        }
                        .frame(width: breite, height: heroHoehe)
                    }
                    .frame(height: 360)
                    .padding(.top, 14)
                    
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        
                        HomeInfoChip(icon: "shield.checkered", titel: "Sicher gespeichert")
                        HomeInfoChip(icon: "lock.fill", titel: "Privat")
                        HomeInfoChip(icon: "icloud.fill", titel: "Jederzeit verfügbar")
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, -2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bereiche")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                        
                        Text("In den verschiedenen Bereichen kannst du deine Angaben machen und jederzeit ändern.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    
                    alleKacheln
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                                kachelnSindSichtbar = true
                            }
                        }
                        .offset(y: kachelnSindSichtbar ? 0 : 20)
                        .opacity(kachelnSindSichtbar ? 1 : 0)
                    
                    if !verknuepfteVorsorgedossiers.isEmpty {
                        vorsorgedossierWechselAktion
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                            .offset(y: kachelnSindSichtbar ? 0 : 20)
                            .opacity(kachelnSindSichtbar ? 1 : 0)
                    }
                    
#if DEBUG
                    HomeDebugTestPanel()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
#endif
                }
                .background(Color(.systemBackground))
                .navigationDestination(isPresented: $direktesVorsorgedossierOeffnen) {
                    VorsorgedossierPlatzhalter(name: ausgewaehltesVorsorgedossier)
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
                .navigationBarBackButtonHidden(true)
            }
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
        
        private var alleKacheln: some View {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ],
                spacing: 20
            ) {
                NavigationLink {
                    ProfilView()
                } label: {
                    HomeKachel(
                        icon: "person.text.rectangle.fill",
                        titel: "Mein Profil",
                        untertitel: "Persönliche Angaben",
                        details: "Kontaktdaten, Einstellungen und Sicherheit verwalten",
                        farbe: kachelFarbe,
                        akzentFarbe: schluessliAkzent
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    GesundheitView()
                } label: {
                    HomeKachel(
                        icon: "heart.text.square.fill",
                        titel: "Gesundheit",
                        untertitel: "Für den Ernstfall",
                        details: "Hausarzt, Medikamente, Allergien und wichtige medizinische Informationen",
                        farbe: kachelFarbe,
                        akzentFarbe: Color(red: 0.76, green: 0.24, blue: 0.30)
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    WuenscheView()
                } label: {
                    HomeKachel(
                        icon: "sparkles",
                        titel: "Meine Wünsche",
                        untertitel: "Was dir wichtig ist",
                        details: "Testament und persönliche Wünsche festhalten",
                        farbe: kachelFarbe,
                        akzentFarbe: Color(red: 0.72, green: 0.42, blue: 0.28)
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    FinanzenView()
                } label: {
                    HomeKachel(
                        icon: "dollarsign.circle.fill",
                        titel: "Finanzen",
                        untertitel: "Deine finanzielle Übersicht",
                        details: "Konten, Schulden und Wertsachen auflisten",
                        farbe: kachelFarbe,
                        akzentFarbe: Color(red: 0.62, green: 0.47, blue: 0.18)
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    HinterbliebeneView()
                } label: {
                    HomeKachel(
                        icon: "person.3.fill",
                        titel: "Menschen meines Vertrauens",
                        untertitel: "Menschen, die dir wichtig sind",
                        details: "Familie & Freunde als Kontakte hinterlegen",
                        farbe: kachelFarbe,
                        akzentFarbe: Color(red: 0.24, green: 0.50, blue: 0.34)
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    DokumenteView()
                } label: {
                    HomeKachel(
                        icon: "folder.fill",
                        titel: "Dokumente & Fotoalbum",
                        untertitel: "Alles sicher abgelegt",
                        details: "Dokumente hochladen und Fotoalbum erstellen",
                        farbe: kachelFarbe,
                        akzentFarbe: Color(red: 0.22, green: 0.43, blue: 0.68)
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    AbosView()
                } label: {
                    HomeKachel(
                        icon: "rectangle.stack.badge.person.crop.fill",
                        titel: "Abos & Profile",
                        untertitel: "Digitales Leben",
                        details: "Digitale Profile, Zugänge und Abos",
                        farbe: kachelFarbe,
                        akzentFarbe: Color(red: 0.46, green: 0.36, blue: 0.62)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        
        struct HomeKachel: View {
            let icon: String
            let titel: String
            let untertitel: String
            let details: String
            let farbe: Color
            let akzentFarbe: Color
            
            var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(akzentFarbe.opacity(0.14))
                            .frame(width: 54, height: 54)
                        
                        Image(systemName: icon)
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(titel)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                            .lineLimit(2)
                        
                        Text(untertitel)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 232, alignment: .topLeading)
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
    
    struct VorsorgedossierPlatzhalter: View {
        let name: String
        
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "folder.badge.person.crop")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)
                
                Text("Vorsorgedossier")
                    .font(.largeTitle.bold())
                
                Text(name)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Diese Ansicht wird später das freigegebene Dossier der vorsorgenden Person anzeigen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Vorsorgedossier")
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

