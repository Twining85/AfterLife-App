import SwiftUI
import SwiftData

struct WeiteresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteWeiteresModelle: [WeiteresModell]

    private let kreisFarbe = Color(.systemGray5)

    @State private var wurdeInitialisiert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    Text("Zugangsdaten & Abos")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 30
                    ) {
                        KreisKachel(
                            icon: "lock.fill",
                            titel: "Digitale Konten",
                            farbe: kreisFarbe
                        )

                        KreisKachel(
                            icon: "newspaper.fill",
                            titel: "Abos",
                            farbe: kreisFarbe
                        )

                        KreisKachel(
                            icon: "person.2.fill",
                            titel: "Mitgliedschaften",
                            farbe: kreisFarbe
                        )

                        KreisKachel(
                            icon: "note.text",
                            titel: "Notizen",
                            farbe: kreisFarbe
                        )
                    }
                    .padding(.horizontal)

                    if let modell = gespeicherteWeiteresModelle.first {
                        WeiteresInhaltView(modell: modell)
                    }
                }
                .padding(.top)
            }
            .task {
                ladeOderErstelleModellFallsNoetig()
            }
        }
    }

    // MARK: - SwiftData

    private func ladeOderErstelleModellFallsNoetig() {
        guard !wurdeInitialisiert else { return }
        wurdeInitialisiert = true

        guard gespeicherteWeiteresModelle.isEmpty else { return }

        let neuesModell = WeiteresModell()
        modelContext.insert(neuesModell)

        do {
            try modelContext.save()
        } catch {
            print("WeiteresModell konnte nicht erstellt werden: \(error.localizedDescription)")
        }
    }
}

// MARK: - Gespeicherte Inhalte

struct WeiteresInhaltView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var modell: WeiteresModell

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            allgemeineNotizenSection
            haustiereSection
            fahrzeugeSection
            schluesselUndZugaengeSection
            weitereInformationenSection
        }
        .padding(.horizontal)
    }

    private var allgemeineNotizenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allgemeine Notizen")
                .font(.headline)

            TextEditor(text: $modell.allgemeineNotizen)
                .frame(minHeight: 110)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: modell.allgemeineNotizen) { _, _ in
                    speichereAenderung()
                }
        }
    }

    private var haustiereSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Ich habe Haustiere", isOn: $modell.hatHaustiere)
                .onChange(of: modell.hatHaustiere) { _, _ in
                    speichereAenderung()
                }

            if modell.hatHaustiere {
                DetailBox {
                    ForEach(Array(modell.haustiere.enumerated()), id: \.element.id) { index, haustier in
                        HaustierFormular(haustier: haustier, speichern: speichereAenderung)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    loescheHaustier(index: index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }

                    Button {
                        let neuerEintrag = HaustierEintrag()
                        modelContext.insert(neuerEintrag)
                        modell.haustiere.append(neuerEintrag)
                        speichereAenderung()
                    } label: {
                        Label("Haustier hinzufügen", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }

    private var fahrzeugeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Ich habe Fahrzeuge", isOn: $modell.hatFahrzeuge)
                .onChange(of: modell.hatFahrzeuge) { _, _ in
                    speichereAenderung()
                }

            if modell.hatFahrzeuge {
                DetailBox {
                    ForEach(Array(modell.fahrzeuge.enumerated()), id: \.element.id) { index, fahrzeug in
                        FahrzeugFormular(fahrzeug: fahrzeug, speichern: speichereAenderung)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    loescheFahrzeug(index: index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }

                    Button {
                        let neuerEintrag = FahrzeugEintrag()
                        modelContext.insert(neuerEintrag)
                        modell.fahrzeuge.append(neuerEintrag)
                        speichereAenderung()
                    } label: {
                        Label("Fahrzeug hinzufügen", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }

    private var schluesselUndZugaengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Ich habe Schlüssel oder wichtige Zugänge", isOn: $modell.hatSchluesselOderZugaenge)
                .onChange(of: modell.hatSchluesselOderZugaenge) { _, _ in
                    speichereAenderung()
                }

            if modell.hatSchluesselOderZugaenge {
                DetailBox {
                    ForEach(Array(modell.schluesselUndZugaenge.enumerated()), id: \.element.id) { index, eintrag in
                        SchluesselZugangFormular(eintrag: eintrag, speichern: speichereAenderung)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    loescheSchluesselZugang(index: index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }

                    Button {
                        let neuerEintrag = SchluesselZugangEintrag()
                        modelContext.insert(neuerEintrag)
                        modell.schluesselUndZugaenge.append(neuerEintrag)
                        speichereAenderung()
                    } label: {
                        Label("Zugang hinzufügen", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }

    private var weitereInformationenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Ich habe weitere wichtige Informationen", isOn: $modell.hatWeitereWichtigeInformationen)
                .onChange(of: modell.hatWeitereWichtigeInformationen) { _, _ in
                    speichereAenderung()
                }

            if modell.hatWeitereWichtigeInformationen {
                DetailBox {
                    ForEach(Array(modell.weitereInformationen.enumerated()), id: \.element.id) { index, eintrag in
                        WeitereInformationFormular(eintrag: eintrag, speichern: speichereAenderung)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    loescheWeitereInformation(index: index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }

                    Button {
                        let neuerEintrag = WeitereInformationEintrag()
                        modelContext.insert(neuerEintrag)
                        modell.weitereInformationen.append(neuerEintrag)
                        speichereAenderung()
                    } label: {
                        Label("Information hinzufügen", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }

    private func speichereAenderung() {
        let jetzt = Date()
        modell.aktualisiertAm = jetzt
        modell.haustiere.forEach { $0.aktualisiertAm = jetzt }
        modell.fahrzeuge.forEach { $0.aktualisiertAm = jetzt }
        modell.schluesselUndZugaenge.forEach { $0.aktualisiertAm = jetzt }
        modell.weitereInformationen.forEach { $0.aktualisiertAm = jetzt }

        do {
            try modelContext.save()
        } catch {
            print("Weiteres konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    private func loescheHaustier(index: Int) {
        guard modell.haustiere.indices.contains(index) else { return }
        let eintrag = modell.haustiere[index]
        modell.haustiere.remove(at: index)
        modelContext.delete(eintrag)
        speichereAenderung()
    }

    private func loescheFahrzeug(index: Int) {
        guard modell.fahrzeuge.indices.contains(index) else { return }
        let eintrag = modell.fahrzeuge[index]
        modell.fahrzeuge.remove(at: index)
        modelContext.delete(eintrag)
        speichereAenderung()
    }

    private func loescheSchluesselZugang(index: Int) {
        guard modell.schluesselUndZugaenge.indices.contains(index) else { return }
        let eintrag = modell.schluesselUndZugaenge[index]
        modell.schluesselUndZugaenge.remove(at: index)
        modelContext.delete(eintrag)
        speichereAenderung()
    }

    private func loescheWeitereInformation(index: Int) {
        guard modell.weitereInformationen.indices.contains(index) else { return }
        let eintrag = modell.weitereInformationen[index]
        modell.weitereInformationen.remove(at: index)
        modelContext.delete(eintrag)
        speichereAenderung()
    }
}

// MARK: - Formular-Komponenten

struct HaustierFormular: View {
    @Bindable var haustier: HaustierEintrag
    let speichern: () -> Void

    private let tierarten = ["Bitte wählen", "Andere", "Hund", "Katze", "Vogel", "Kleintier", "Reptil"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Haustier")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("Name", text: $haustier.name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: haustier.name) { _, _ in speichern() }

            Picker("Tierart", selection: $haustier.tierart) {
                ForEach(tierarten, id: \.self) { tierart in
                    Text(tierart).tag(tierart)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: haustier.tierart) { _, _ in speichern() }

            TextField("Wichtige Informationen", text: $haustier.wichtigeInformationen, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: haustier.wichtigeInformationen) { _, _ in speichern() }

            TextField("Betreuungsperson", text: $haustier.betreuungspersonName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: haustier.betreuungspersonName) { _, _ in speichern() }

            TextField("Telefon", text: $haustier.betreuungspersonTelefon)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: haustier.betreuungspersonTelefon) { _, _ in speichern() }

            TextField("E-Mail", text: $haustier.betreuungspersonEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .onChange(of: haustier.betreuungspersonEmail) { _, _ in speichern() }
        }
        .padding(.vertical, 8)
    }
}

struct FahrzeugFormular: View {
    @Bindable var fahrzeug: FahrzeugEintrag
    let speichern: () -> Void

    private let fahrzeugarten = ["Bitte wählen", "Andere", "Auto", "Motorrad", "Velo", "E-Bike", "Boot"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fahrzeug")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Fahrzeugart", selection: $fahrzeug.fahrzeugart) {
                ForEach(fahrzeugarten, id: \.self) { art in
                    Text(art).tag(art)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: fahrzeug.fahrzeugart) { _, _ in speichern() }

            TextField("Marke / Modell", text: $fahrzeug.markeModell)
                .textFieldStyle(.roundedBorder)
                .onChange(of: fahrzeug.markeModell) { _, _ in speichern() }

            TextField("Kennzeichen", text: $fahrzeug.kennzeichen)
                .textFieldStyle(.roundedBorder)
                .onChange(of: fahrzeug.kennzeichen) { _, _ in speichern() }

            TextField("Standort", text: $fahrzeug.standort)
                .textFieldStyle(.roundedBorder)
                .onChange(of: fahrzeug.standort) { _, _ in speichern() }

            TextField("Wichtige Informationen", text: $fahrzeug.wichtigeInformationen, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: fahrzeug.wichtigeInformationen) { _, _ in speichern() }
        }
        .padding(.vertical, 8)
    }
}

struct SchluesselZugangFormular: View {
    @Bindable var eintrag: SchluesselZugangEintrag
    let speichern: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schlüssel / Zugang")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("Bezeichnung", text: $eintrag.bezeichnung)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.bezeichnung) { _, _ in speichern() }

            TextField("Ort", text: $eintrag.ort)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.ort) { _, _ in speichern() }

            TextField("Zugangscode oder Hinweis", text: $eintrag.zugangscodeOderHinweis)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.zugangscodeOderHinweis) { _, _ in speichern() }

            TextField("Wichtige Informationen", text: $eintrag.wichtigeInformationen, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.wichtigeInformationen) { _, _ in speichern() }
        }
        .padding(.vertical, 8)
    }
}

struct WeitereInformationFormular: View {
    @Bindable var eintrag: WeitereInformationEintrag
    let speichern: () -> Void

    private let kategorien = ["Bitte wählen", "Andere", "Vertrag", "Vereinbarung", "Wichtiger Kontakt", "Wohnung / Haushalt", "Persönlicher Hinweis"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weitere Information")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Kategorie", selection: $eintrag.kategorie) {
                ForEach(kategorien, id: \.self) { kategorie in
                    Text(kategorie).tag(kategorie)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: eintrag.kategorie) { _, _ in speichern() }

            TextField("Titel", text: $eintrag.titel)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.titel) { _, _ in speichern() }

            TextField("Beschreibung", text: $eintrag.beschreibung, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.beschreibung) { _, _ in speichern() }

            TextField("Kontaktperson", text: $eintrag.kontaktperson)
                .textFieldStyle(.roundedBorder)
                .onChange(of: eintrag.kontaktperson) { _, _ in speichern() }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - UI-Komponenten

struct KreisKachel: View {
    let icon: String
    let titel: String
    let farbe: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(farbe)
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(.black)
            }

            Text(titel)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    WeiteresView()
        .modelContainer(for: [
            WeiteresModell.self,
            HaustierEintrag.self,
            FahrzeugEintrag.self,
            SchluesselZugangEintrag.self,
            WeitereInformationEintrag.self
        ], inMemory: true)
}
