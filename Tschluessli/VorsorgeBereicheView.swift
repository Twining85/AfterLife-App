import SwiftUI

struct VorsorgeBereicheView: View {
    @Environment(\.appLayout) private var appLayout
    @AppStorage("homeBereicheReihenfolge") private var gespeicherteReihenfolge = ""
    @AppStorage("homeAktiveBereiche") private var gespeicherteAuswahl = ""
    @AppStorage("homeBereicheAuswahlInitialisiert") private var auswahlWurdeInitialisiert = false
    @AppStorage(VorsorgeBereichStatusStore.storageKey) private var bereichStatusJSON = ""

    @State private var bereiche: [VorsorgeBereich] = []
    @State private var auswahl: Set<VorsorgeBereich> = []
    @State private var verwaltungAnzeigen: Bool

    private let akzent = Color.appAccent
    private let hintergrund = Color.appCanvas

    init(startetMitVerwaltung: Bool = false) {
        _verwaltungAnzeigen = State(initialValue: startetMitVerwaltung)
    }

    private var aktiveBereiche: [VorsorgeBereich] {
        bereiche.filter { auswahl.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero

                if aktiveBereiche.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(akzent)
                        Text("Noch keine Bereiche ausgewählt")
                            .font(.headline)
                        Text("Wähle die Vorsorgebereiche, die du vorbereiten möchtest über «Verwalten» aus.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .appPagePadding()
                    .padding(.vertical, 62)
                } else {
                    LazyVGrid(columns: gridSpalten, spacing: 14) {
                        ForEach(aktiveBereiche) { bereich in
                            NavigationLink {
                                zielView(fuer: bereich)
                                    .rueckkehrZuVorsorgeBereichen()
                            } label: {
                                bereichKachel(bereich)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .appPagePadding()
                    .padding(.top, 22)
                }
            }
            .padding(.bottom, 28)
        }
        .background(hintergrund.ignoresSafeArea())
        .navigationTitle("Vorsorge Bereiche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Verwalten") { verwaltungAnzeigen = true }
                    .foregroundStyle(akzent)
            }
        }
        .sheet(isPresented: $verwaltungAnzeigen) {
            verwaltung
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear(perform: ladeBereiche)
    }

    private var hero: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                heroSymbol
                heroText
            }
            VStack(alignment: .leading, spacing: 12) {
                heroSymbol
                heroText
            }
        }
        .padding(appLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: appLayout.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: appLayout.cardCornerRadius, style: .continuous)
                .stroke(akzent.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.appShadow, radius: 10, y: 4)
        .appPagePadding()
        .padding(.top, 18)
    }

    private var heroSymbol: some View {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appOnAccent)
                .frame(width: 48, height: 48)
                .background(Circle().fill(akzent))
                .shadow(color: akzent.opacity(0.20), radius: 8, y: 4)

    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 6) {
                Text("Vorsorge Bereiche")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Wähle die Themen, die für deine Vorsorge wichtig sind, und bringe sie in deine persönliche Reihenfolge.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gridSpalten: [GridItem] {
        if appLayout.prefersSingleColumnAreaGrid {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    private func bereichKachel(_ bereich: VorsorgeBereich) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: bereich.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(bereich.farbe)
                    .frame(width: 45, height: 45)
                    .background(bereich.farbe.opacity(0.12), in: Circle())

                Spacer(minLength: 0)

                Text(statusText(fuer: bereich))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusFarbe(fuer: bereich))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(statusFarbe(fuer: bereich).opacity(0.11), in: Capsule())
            }
            Spacer(minLength: 0)
            Text(bereich.titel)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(bereich.untertitel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(bereich.details)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 198, alignment: .leading)
        .padding(appLayout.cardPadding)
        .background(Color.appRaisedCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(bereich.farbe.opacity(0.15)))
    }

    private func statusText(fuer bereich: VorsorgeBereich) -> String {
        _ = bereichStatusJSON
        let status = VorsorgeBereichStatusStore.status(fuer: bereich.statusID)
        if status.wurdeSeitPruefungGeaendert { return "Geändert" }
        if status.istAktuellGeprueft { return "Aktuell" }
        if status.wurdeBegonnen { return "Begonnen" }
        return "Nicht begonnen"
    }

    private func statusFarbe(fuer bereich: VorsorgeBereich) -> Color {
        switch statusText(fuer: bereich) {
        case "Aktuell": .green
        case "Geändert": .orange
        case "Begonnen": bereich.farbe
        default: .secondary
        }
    }

    private var verwaltung: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(bereiche) { bereich in
                        Toggle(isOn: binding(fuer: bereich)) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: bereich.symbol)
                                    .foregroundStyle(bereich.farbe)
                                    .frame(width: 24, height: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bereich.titel)
                                        .foregroundStyle(.primary)
                                    Text(bereich.nutzen)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .tint(akzent)
                    }
                    .onMove(perform: verschiebeBereiche)
                } header: {
                    Text("Sichtbare Bereiche")
                } footer: {
                    Text("Halte einen Bereich gedrückt, um seine Reihenfolge zu ändern. Das Profil gehört zur Navigation und erscheint deshalb nicht als Kachel.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Bereiche verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") { verwaltungAnzeigen = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        speichereBereiche()
                        verwaltungAnzeigen = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(akzent)
                }
            }
        }
    }

    private func binding(fuer bereich: VorsorgeBereich) -> Binding<Bool> {
        Binding(
            get: { auswahl.contains(bereich) },
            set: { istAktiv in
                if istAktiv {
                    auswahl.insert(bereich)
                } else {
                    auswahl.remove(bereich)
                }
                speichereBereiche()
            }
        )
    }

    private func ladeBereiche() {
        let gespeicherteIDs = gespeicherteReihenfolge.split(separator: ",").map(String.init)
        let gespeicherte = gespeicherteIDs.compactMap(VorsorgeBereich.init(rawValue:))
        let fehlende = VorsorgeBereich.allCases.filter { !gespeicherte.contains($0) }
        bereiche = gespeicherte + fehlende

        let aktiveIDs = gespeicherteAuswahl.split(separator: ",").map(String.init)
        auswahl = Set(aktiveIDs.compactMap(VorsorgeBereich.init(rawValue:)))
        if !auswahlWurdeInitialisiert,
           gespeicherteAuswahl.isEmpty,
           !gespeicherteReihenfolge.isEmpty {
            auswahl = Set(bereiche)
        }
    }

    private func verschiebeBereiche(von quelle: IndexSet, nach ziel: Int) {
        bereiche.move(fromOffsets: quelle, toOffset: ziel)
        speichereBereiche()
    }

    private func speichereBereiche() {
        auswahlWurdeInitialisiert = true
        gespeicherteReihenfolge = bereiche.map(\.rawValue).joined(separator: ",")
        gespeicherteAuswahl = bereiche.filter { auswahl.contains($0) }.map(\.rawValue).joined(separator: ",")
        DossierEinstellungenStore.markiereGeaendert()
    }

    @ViewBuilder
    private func zielView(fuer bereich: VorsorgeBereich) -> some View {
        switch bereich {
        case .hinterbliebene: HinterbliebeneView()
        case .wuensche: WuenscheView()
        case .finanzen: FinanzenView()
        case .dokumente: DokumenteView()
        case .abos: AbosView()
        case .herzensstuecke: HerzensstueckeView()
        case .gesundheit: GesundheitView()
        }
    }
}

private enum VorsorgeBereich: String, CaseIterable, Identifiable {
    case hinterbliebene, wuensche, finanzen, dokumente, abos, herzensstuecke, gesundheit

    var id: String { rawValue }

    var statusID: VorsorgeBereichID {
        VorsorgeBereichID(rawValue: rawValue) ?? .profil
    }

    var titel: String {
        switch self {
        case .hinterbliebene: "Wichtige Menschen"
        case .wuensche: "Meine Wünsche"
        case .finanzen: "Finanzen"
        case .dokumente: "Dokumente & Fotoalbum"
        case .abos: "Abos & Profile"
        case .herzensstuecke: "Herzensstücke"
        case .gesundheit: "Gesundheit"
        }
    }

    var untertitel: String {
        switch self {
        case .hinterbliebene: "Wichtige Menschen im Leben"
        case .wuensche: "Was dir wichtig ist"
        case .finanzen: "Deine finanzielle Übersicht"
        case .dokumente: "Alles sicher abgelegt"
        case .abos: "Digitales Leben"
        case .herzensstuecke: "Dinge mit Bedeutung"
        case .gesundheit: "Für den Ernstfall"
        }
    }

    var details: String {
        switch self {
        case .hinterbliebene: "Alle Personen in deinem Leben in einer Liste festhalten"
        case .wuensche: "Persönliche Wünsche festhalten, Testament oder Vorsorgeauftrag hinterlegen"
        case .finanzen: "Konten, Schulden, Versicherungen und Wertsachen auflisten"
        case .dokumente: "Wichtige Dokumente hochladen und Fotoalbum erstellen"
        case .abos: "Digitale Profile & Social Media, Streamingdienste und Zugänge und Abos"
        case .herzensstuecke: "Persönliche Gegenstände, ihre Geschichten und deine Wünsche dazu"
        case .gesundheit: "Hausarzt, Medikamente, Allergien und wichtige medizinische Informationen"
        }
    }

    var nutzen: String {
        switch self {
        case .hinterbliebene: "Ansprechpersonen und wichtige Beziehungen dokumentieren"
        case .wuensche: "Letzte Wünsche, Vorsorgeauftrag und Testament festhalten"
        case .finanzen: "Vermögen, Verpflichtungen und Versicherungen überblicken"
        case .dokumente: "Wichtige Unterlagen zentral und schnell auffindbar halten"
        case .abos: "Online-Konten, Abonnemente und digitale Zugänge regeln"
        case .herzensstuecke: "Erinnerungsstücke zuordnen und Wünsche dazu festhalten"
        case .gesundheit: "Medizinische Angaben für Notfälle bereithalten"
        }
    }

    var symbol: String {
        switch self {
        case .hinterbliebene: "person.3.fill"
        case .wuensche: "sparkles"
        case .finanzen: "dollarsign.circle.fill"
        case .dokumente: "folder.fill"
        case .abos: "rectangle.stack.badge.person.crop.fill"
        case .herzensstuecke: "archivebox.fill"
        case .gesundheit: "heart.text.square.fill"
        }
    }

    var farbe: Color {
        switch self {
        case .hinterbliebene: Color.areaContacts
        case .wuensche: Color.areaWishes
        case .finanzen: Color.areaFinance
        case .dokumente: Color.areaDocuments
        case .abos: Color.areaSubscriptions
        case .herzensstuecke: Color.areaKeepsakes
        case .gesundheit: Color.areaHealth
        }
    }
}

#Preview {
    NavigationStack {
        VorsorgeBereicheView()
    }
}
