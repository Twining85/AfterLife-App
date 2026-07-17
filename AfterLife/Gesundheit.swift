import SwiftUI
import ContactsUI
#if canImport(SwiftData)
import SwiftData
#endif


struct GesundheitView: View {
    @State private var zeigtHausarztKontaktPicker = false
#if canImport(SwiftData)
    @Environment(\.modelContext) private var modelContext
    @Query private var gesundheitDatensaetze: [GesundheitModell]
    @Query private var wuenscheDatensaetze: [WuenscheModell]
    @State private var datensatz: GesundheitModell?
#else
    // TODO: Sobald ein GesundheitModell für SwiftData existiert,
    // diese View auf das Modell und SwiftData migrieren.
    // Bis dahin KEINE neue Persistenz über @AppStorage einführen!
    @State private var hatHausarzt = false
    @State private var hausarztName = ""
    @State private var hausarztTelefon = ""
    @State private var hausarztEmail = ""
    @State private var hausarztAdresse = ""
    @State private var hausarztPLZ = ""
    @State private var hausarztOrt = ""
    @State private var blutgruppe = ""
    @State private var organspende = "Nicht angegeben"
    @State private var hatAllergien = false
    @State private var allergien = ""
    @State private var nimmtMedikamente = false
    @State private var medikamente = ""
    @State private var gesundheitlicheHinweise = ""
#endif


    private let akzentFarbe = Color(red: 0.76, green: 0.24, blue: 0.30)
    private let kartenFarbe = Color(red: 0.98, green: 0.96, blue: 0.94)

    private let blutgruppen = [
        "A+",
        "A-",
        "B+",
        "B-",
        "AB+",
        "AB-",
        "0+",
        "0-",
        "Unbekannt"
    ]

    private let organspendeOptionen = [
        "Nicht angegeben",
        "Ja",
        "Nein"
    ]

    var body: some View {
        #if canImport(SwiftData)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroBereich
                if let _ = datensatz {
                    hausarztBereich
                    medizinischeInformationenBereich
                    vorsorgedokumenteBereich
                }
                hinweisBereich
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Gesundheit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if datensatz == nil {
                if let vorhanden = gesundheitDatensaetze.first {
                    datensatz = vorhanden
                } else {
                    let neu = GesundheitModell()
                    modelContext.insert(neu)
                    datensatz = neu
                }
            }
        }
        .sheet(isPresented: $zeigtHausarztKontaktPicker) {
            KontaktPickerView { kontakt in
                hausarztAusKontaktUebernehmen(kontakt)
            }
        }
        .dossierFloatingNavigation(.gesundheit)

#else
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroBereich
                hausarztBereich
                medizinischeInformationenBereich
                vorsorgedokumenteBereich
                hinweisBereich
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Gesundheit")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $zeigtHausarztKontaktPicker) {
            KontaktPickerView { kontakt in
                hausarztAusKontaktUebernehmen(kontakt)
            }
        }
        .dossierFloatingNavigation(.gesundheit)
#endif
    }

    private var heroBereich: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(akzentFarbe.opacity(0.14))
                        .frame(width: 58, height: 58)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(akzentFarbe)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gesundheit & Notfall")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                    Text("Diese Angaben sind freiwillig. Sie können Angehörigen oder medizinischem Personal im Ernstfall helfen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(kartenFarbe)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: akzentFarbe.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var hausarztBereich: some View {
        #if canImport(SwiftData)
        GesundheitKarte(
            icon: "stethoscope",
            titel: "Hausarzt",
            untertitel: "Eine wichtige Kontaktperson im Ernstfall.",
            akzentFarbe: akzentFarbe
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Ich habe einen Hausarzt", isOn: Binding(
                    get: { datensatz?.hatHausarzt ?? false },
                    set: { newValue in
                        datensatz?.hatHausarzt = newValue
                        speichern()
                    }
                ))
                .font(.body.weight(.medium))
                .tint(akzentFarbe)

                if datensatz?.hatHausarzt ?? false {
                    if (datensatz?.hausarztName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        hausarztKontaktAuswaehlenButton
                    } else {
                        hausarztKontaktKarte(
                            name: datensatz?.hausarztName ?? "",
                            adresse: datensatz?.hausarztAdresse ?? "",
                            plz: datensatz?.hausarztPLZ ?? "",
                            ort: datensatz?.hausarztOrt ?? "",
                            email: datensatz?.hausarztEmail ?? "",
                            telefon: datensatz?.hausarztTelefon ?? ""
                        )

                        Button("Hausarzt ändern") {
                            zeigtHausarztKontaktPicker = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(akzentFarbe)
                    }

                }
            }
        }
        #else
        GesundheitKarte(
            icon: "stethoscope",
            titel: "Hausarzt",
            untertitel: "Eine wichtige Kontaktperson im Ernstfall.",
            akzentFarbe: akzentFarbe
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Ich habe einen Hausarzt", isOn: $hatHausarzt)
                    .font(.body.weight(.medium))
                    .tint(akzentFarbe)

                if hatHausarzt {
                    if hausarztName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        hausarztKontaktAuswaehlenButton
                    } else {
                        hausarztKontaktKarte(
                            name: hausarztName,
                            adresse: hausarztAdresse,
                            plz: hausarztPLZ,
                            ort: hausarztOrt,
                            email: hausarztEmail,
                            telefon: hausarztTelefon
                        )

                        Button("Hausarzt ändern") {
                            zeigtHausarztKontaktPicker = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(akzentFarbe)
                    }

                }
            }
        }
#endif
    }

    private var hausarztKontaktAuswaehlenButton: some View {
        Button {
            zeigtHausarztKontaktPicker = true
        } label: {
            Label(
                "Hausarzt aus Kontakten auswählen",
                systemImage: "person.crop.circle.badge.plus"
            )
            .font(.headline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .center)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .controlSize(.large)
        .tint(akzentFarbe)
        .accessibilityHint("Öffnet deine Kontakte zur Auswahl eines Hausarztes")
    }

    private func hausarztKontaktKarte(
        name: String,
        adresse: String,
        plz: String,
        ort: String,
        email: String,
        telefon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(initialenFuerHausarzt(name))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(akzentFarbe.opacity(0.88)))

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                    .fixedSize(horizontal: false, vertical: true)

                Label("Hausarzt", systemImage: "stethoscope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(akzentFarbe)

                let adressText = formatierteHausarztAdresse(adresse: adresse, plz: plz, ort: ort)
                if !adressText.isEmpty {
                    Text(adressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(email, systemImage: "envelope")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !telefon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(telefon, systemImage: "phone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Button(role: .destructive) {
                hausarztEntfernen()
            } label: {
                Image(systemName: "trash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.75))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.red.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(akzentFarbe.opacity(0.08), lineWidth: 1)
        }
    }

    private func formatierteHausarztAdresse(adresse: String, plz: String, ort: String) -> String {
        let plzOrt = [plz, ort]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return [adresse.trimmingCharacters(in: .whitespacesAndNewlines), plzOrt]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func initialenFuerHausarzt(_ name: String) -> String {
        let teile = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()

        return teile.isEmpty ? "?" : teile
    }

    private var medizinischeInformationenBereich: some View {
#if canImport(SwiftData)
        GesundheitKarte(
            icon: "cross.case.fill",
            titel: "Medizinische Informationen",
            untertitel: "Nur das erfassen, was wirklich hilfreich ist.",
            akzentFarbe: akzentFarbe
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blutgruppe")
                        .font(.subheadline.weight(.semibold))

                    BlutgruppenChipAuswahl(
                        ausgewaehlterWert: datensatz?.blutgruppe ?? "",
                        optionen: blutgruppen,
                        akzentFarbe: akzentFarbe
                    ) { neuerWert in
                        datensatz?.blutgruppe = neuerWert
                        speichern()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Organspende")
                        .font(.subheadline.weight(.semibold))

                    Picker("Organspende", selection: Binding(
                        get: { datensatz?.organspende ?? "Nicht angegeben" },
                        set: { newValue in
                            datensatz?.organspende = newValue
                            speichern()
                        }
                    )) {
                        ForEach(organspendeOptionen, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                Toggle("Allergien vorhanden", isOn: Binding(
                    get: { datensatz?.hatAllergien ?? false },
                    set: { newValue in
                        datensatz?.hatAllergien = newValue
                        speichern()
                    }
                ))
                .font(.body.weight(.medium))
                .tint(akzentFarbe)

                if datensatz?.hatAllergien ?? false {
                    GesundheitTextfeld(
                        titel: "Welche Allergien sind wichtig?",
                        platzhalter: "z. B. Penicillin, Nüsse, Latex …",
                        text: Binding(
                            get: { datensatz?.allergien ?? "" },
                            set: { newValue in
                                datensatz?.allergien = newValue
                                speichern()
                            }
                        )
                    )
                }

                Toggle("Regelmässige Medikamente", isOn: Binding(
                    get: { datensatz?.nimmtMedikamente ?? false },
                    set: { newValue in
                        datensatz?.nimmtMedikamente = newValue
                        speichern()
                    }
                ))
                .font(.body.weight(.medium))
                .tint(akzentFarbe)

                if datensatz?.nimmtMedikamente ?? false {
                    GesundheitTextfeld(
                        titel: "Welche Medikamente nimmst du regelmässig?",
                        platzhalter: "Name, Dosierung oder wichtige Hinweise …",
                        text: Binding(
                            get: { datensatz?.medikamente ?? "" },
                            set: { newValue in
                                datensatz?.medikamente = newValue
                                speichern()
                            }
                        )
                    )
                }

                GesundheitTextfeld(
                    titel: "Wichtige gesundheitliche Hinweise",
                    platzhalter: "z. B. Diabetes, Herzschrittmacher, Epilepsie, Hörgerät, eingeschränkte Mobilität …",
                    text: Binding(
                        get: { datensatz?.gesundheitlicheHinweise ?? "" },
                        set: { newValue in
                            datensatz?.gesundheitlicheHinweise = newValue
                            speichern()
                        }
                    )
                )
            }
        }
#else
        GesundheitKarte(
            icon: "cross.case.fill",
            titel: "Medizinische Informationen",
            untertitel: "Nur das erfassen, was wirklich hilfreich ist.",
            akzentFarbe: akzentFarbe
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blutgruppe")
                        .font(.subheadline.weight(.semibold))

                    BlutgruppenChipAuswahl(
                        ausgewaehlterWert: blutgruppe,
                        optionen: blutgruppen,
                        akzentFarbe: akzentFarbe
                    ) { neuerWert in
                        blutgruppe = neuerWert
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Organspende")
                        .font(.subheadline.weight(.semibold))

                    Picker("Organspende", selection: $organspende) {
                        ForEach(organspendeOptionen, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                Toggle("Allergien vorhanden", isOn: $hatAllergien)
                    .font(.body.weight(.medium))
                    .tint(akzentFarbe)

                if hatAllergien {
                    GesundheitTextfeld(
                        titel: "Welche Allergien sind wichtig?",
                        platzhalter: "z. B. Penicillin, Nüsse, Latex …",
                        text: $allergien
                    )
                }

                Toggle("Regelmässige Medikamente", isOn: $nimmtMedikamente)
                    .font(.body.weight(.medium))
                    .tint(akzentFarbe)

                if nimmtMedikamente {
                    GesundheitTextfeld(
                        titel: "Welche Medikamente nimmst du regelmässig?",
                        platzhalter: "Name, Dosierung oder wichtige Hinweise …",
                        text: $medikamente
                    )
                }

                GesundheitTextfeld(
                    titel: "Wichtige gesundheitliche Hinweise",
                    platzhalter: "z. B. Diabetes, Herzschrittmacher, Epilepsie, Hörgerät, eingeschränkte Mobilität …",
                    text: $gesundheitlicheHinweise
                )
            }
        }
#endif
    }

    // MARK: - Vorsorgedokumente-Bereich
    private var vorsorgedokumenteBereich: some View {
#if canImport(SwiftData)
        let wuensche = wuenscheDatensaetze.first
        return VStack {
            GesundheitKarte(
                icon: "doc.text.fill",
                titel: "Vorsorgedokumente",
                untertitel: "Wichtige Dokumente für medizinische und rechtliche Entscheidungen.",
                akzentFarbe: akzentFarbe
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Patientenverfügung und Vorsorgeauftrag werden im Bereich ‹Meine Wünsche› verwaltet. Hier siehst du auf einen Blick, ob diese bereits hinterlegt wurden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        vorsorgedokumentStatusZeile(
                            titel: "Patientenverfügung",
                            vorhanden: wuensche?.patientenverfuegungVorhanden == true
                        )

                        vorsorgedokumentStatusZeile(
                            titel: "Vorsorgeauftrag",
                            vorhanden: wuensche?.vorsorgeauftragVorhanden == true
                        )
                    }

                    NavigationLink {
                        WuenscheView()
                    } label: {
                        Text("In «Meine Wünsche» bearbeiten")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(akzentFarbe)
                }
            }
        }
#else
        VStack {
            GesundheitKarte(
                icon: "doc.text.fill",
                titel: "Vorsorgedokumente",
                untertitel: "Wichtige Dokumente für medizinische und rechtliche Entscheidungen.",
                akzentFarbe: akzentFarbe
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Patientenverfügung und Vorsorgeauftrag werden im Bereich ‹Meine Wünsche› verwaltet. Hier siehst du auf einen Blick, ob diese bereits hinterlegt wurden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        vorsorgedokumentStatusZeile(titel: "Patientenverfügung", vorhanden: false)
                        vorsorgedokumentStatusZeile(titel: "Vorsorgeauftrag", vorhanden: false)
                    }

                    NavigationLink {
                        WuenscheView()
                    } label: {
                        Text("In «Meine Wünsche» bearbeiten")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(akzentFarbe)
                }
            }
        }
#endif
    }

    private func vorsorgedokumentStatusZeile(titel: String, vorhanden: Bool) -> some View {
        HStack {
            Text(titel)
                .font(.body)

            Spacer()

            if vorhanden {
                Label("Vorhanden", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Label("Nicht hinterlegt", systemImage: "exclamationmark.circle")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }

    private func hausarztAusKontaktUebernehmen(_ kontakt: CNContact) {
        let vollerName = CNContactFormatter.string(from: kontakt, style: .fullName) ?? ""
        let getrimmterName = vollerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmterName.isEmpty else { return }

        let telefon = kontakt.phoneNumbers.first?.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = kontakt.emailAddresses.first.map { String($0.value).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""

        let postAdresse = kontakt.postalAddresses.first?.value
        let strasse = postAdresse?.street.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let plz = postAdresse?.postalCode.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ort = postAdresse?.city.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

#if canImport(SwiftData)
        datensatz?.hausarztAktualisieren(
            hatHausarzt: true,
            hausarztName: getrimmterName,
            hausarztTelefon: telefon,
            hausarztEmail: email,
            hausarztAdresse: strasse,
            hausarztPLZ: plz,
            hausarztOrt: ort
        )
        speichern()
#else
        hatHausarzt = true
        hausarztName = getrimmterName
        hausarztTelefon = telefon
        hausarztEmail = email
        hausarztAdresse = strasse
        hausarztPLZ = plz
        hausarztOrt = ort
#endif
    }

    private func hausarztEntfernen() {
#if canImport(SwiftData)
        datensatz?.hausarztAktualisieren(hatHausarzt: false)
        speichern()
#else
        hatHausarzt = false
        hausarztName = ""
        hausarztTelefon = ""
        hausarztEmail = ""
        hausarztAdresse = ""
        hausarztPLZ = ""
        hausarztOrt = ""
#endif
    }

#if canImport(SwiftData)
    private func speichern() {
        do {
            try modelContext.save()
            VorsorgeBereichStatusStore.markiereBearbeitet(.gesundheit)
        } catch {
            // Fehlerbehandlung (z.B. Logging)
        }
    }
#endif

    private var hinweisBereich: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(akzentFarbe)

            Text("Diese Angaben ersetzen keine medizinische Beratung. Sie dienen dazu, wichtige Informationen für Angehörige oder Helfende rasch auffindbar zu machen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct GesundheitKarte<Content: View>: View {
    let icon: String
    let titel: String
    let untertitel: String
    let akzentFarbe: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(akzentFarbe.opacity(0.14))
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(akzentFarbe)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(titel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                    Text(untertitel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.74), lineWidth: 1)
        )
        .shadow(color: akzentFarbe.opacity(0.10), radius: 16, x: 0, y: 8)
    }
}

struct GesundheitTextfeld: View {
    let titel: String
    let platzhalter: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel)
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: 140, alignment: .topLeading)
                    .scrollContentBackground(.hidden)
                    .padding(10)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(platzhalter)
                        .font(.body)
                        .foregroundStyle(.secondary.opacity(0.65))
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
        }
    }
}



struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > 0 && currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            totalWidth = max(totalWidth, currentX + size.width)
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > bounds.minX && currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct BlutgruppenChipAuswahl: View {
    let ausgewaehlterWert: String
    let optionen: [String]
    let akzentFarbe: Color
    let onAuswahl: (String) -> Void

    var body: some View {
        FlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(optionen, id: \.self) { option in
                chip(option)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
    }

    private func chip(_ wert: String) -> some View {
        let istAusgewaehlt = ausgewaehlterWert == wert

        return Button {
            let neuerWert = istAusgewaehlt ? "" : wert
            onAuswahl(neuerWert)
        } label: {
            Text(wert)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(istAusgewaehlt ? Color.white : Color.primary)
                .background(
                    Capsule(style: .continuous)
                        .fill(istAusgewaehlt ? akzentFarbe : Color.white.opacity(0.78))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(istAusgewaehlt ? akzentFarbe.opacity(0.55) : Color.white.opacity(0.85), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 8))
    }
}

struct KontaktPickerView: UIViewControllerRepresentable {
    let onKontaktAusgewaehlt: (CNContact) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onKontaktAusgewaehlt: onKontaktAusgewaehlt)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onKontaktAusgewaehlt: (CNContact) -> Void

        init(onKontaktAusgewaehlt: @escaping (CNContact) -> Void) {
            self.onKontaktAusgewaehlt = onKontaktAusgewaehlt
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onKontaktAusgewaehlt(contact)
        }
    }
}

#Preview {
    NavigationStack {
        GesundheitView()
    }
}
