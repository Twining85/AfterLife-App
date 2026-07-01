import SwiftUI

struct GesundheitView: View {
    @State private var hatHausarzt = false
    @State private var hausarztName = ""
    @State private var blutgruppe = "Unbekannt"
    @State private var organspende = "Nicht angegeben"
    @State private var hatAllergien = false
    @State private var allergien = ""
    @State private var nimmtMedikamente = false
    @State private var medikamente = ""
    @State private var gesundheitlicheHinweise = ""

    private let akzentFarbe = Color(red: 0.76, green: 0.24, blue: 0.30)
    private let kartenFarbe = Color(red: 0.98, green: 0.96, blue: 0.94)

    private let blutgruppen = [
        "Unbekannt",
        "A+",
        "A-",
        "B+",
        "B-",
        "AB+",
        "AB-",
        "0+",
        "0-"
    ]

    private let organspendeOptionen = [
        "Nicht angegeben",
        "Ja",
        "Nein"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroBereich

                hausarztBereich

                medizinischeInformationenBereich

                hinweisBereich
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Gesundheit")
        .navigationBarTitleDisplayMode(.inline)
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
                        Button {
                            // TODO: Kontakt-Auswahl anbinden.
                        } label: {
                            Label("Hausarzt aus Kontakten auswählen", systemImage: "person.crop.circle.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(akzentFarbe)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(hausarztName)
                                .font(.headline.weight(.semibold))

                            Text("Hausarzt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                        Button("Hausarzt ändern") {
                            // TODO: Kontakt-Auswahl anbinden.
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(akzentFarbe)
                    }

                    Button {
                        // TODO: Neuen Kontakt erfassen und als Hausarzt übernehmen.
                    } label: {
                        Label("Neuen Kontakt erfassen", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(akzentFarbe)
                }
            }
        }
    }

    private var medizinischeInformationenBereich: some View {
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

                    Picker("Blutgruppe", selection: $blutgruppe) {
                        ForEach(blutgruppen, id: \.self) { gruppe in
                            Text(gruppe).tag(gruppe)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
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
    }

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

            TextEditor(text: $text)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(alignment: .topLeading) {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(platzhalter)
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.65))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        GesundheitView()
    }
}
