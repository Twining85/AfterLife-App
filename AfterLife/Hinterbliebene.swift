import SwiftUI
import SwiftData
import ContactsUI

struct HinterbliebeneView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteKontakte: [HinterbliebeneModell]
    @Query private var gesundheitsDatensaetze: [GesundheitModell]

    private let vertrauenHintergrundFarbe = Color(red: 0.985, green: 0.975, blue: 0.955)
    private let vertrauenKartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let vertrauenAkzentFarbe = Color(red: 0.24, green: 0.50, blue: 0.34)
    private let vertrauenTextFarbe = Color.black.opacity(0.86)

    @State private var aktiveKategorie: VertrauenspersonKategorie = .partner
    @State private var showKontaktPicker = false
    @State private var eingeklappteKategorien: Set<VertrauenspersonKategorie> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    vertrauensHero
                        .padding(.top, 18)

                    vertrauenspersonSection(
                        titel: "Partner",
                        untertitel: "Die wichtigste Bezugsperson in deinem Alltag.",
                        icon: "heart.fill",
                        kategorie: .partner,
                        kontakte: kontakteFuerKategorie(.partner)
                    )

                    vertrauenspersonSection(
                        titel: "Familie",
                        untertitel: "Familienmitglieder, die informiert oder einbezogen werden sollen.",
                        icon: "figure.2.and.child.holdinghands",
                        kategorie: .familie,
                        kontakte: kontakteFuerKategorie(.familie)
                    )

                    vertrauenspersonSection(
                        titel: "Freunde",
                        untertitel: "Freundinnen und Freunde, die dir nahestehen.",
                        icon: "person.2.fill",
                        kategorie: .freunde,
                        kontakte: kontakteFuerKategorie(.freunde)
                    )

                    vertrauenspersonSection(
                        titel: "Andere Kontakte",
                        untertitel: "Beispielsweise dein Arbeitgeber, Beistand, Anwalt oder weitere Personen.",
                        icon: "person.crop.circle.badge.checkmark",
                        kategorie: .beguenstigte,
                        kontakte: kontakteFuerKategorie(.beguenstigte)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(vertrauenHintergrundFarbe.ignoresSafeArea())
            .navigationTitle("Menschen meines Vertrauens")
            .tint(vertrauenAkzentFarbe)
            .sheet(isPresented: $showKontaktPicker) {
                HinterbliebeneKontaktPicker { kontakt in
                    if let kontakt {
                        kontaktHinzufuegen(kontakt, zu: aktiveKategorie)
                    }
                    showKontaktPicker = false
                }
            }
        }
    }

    private var vertrauensHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(vertrauenAkzentFarbe))
                    .shadow(color: vertrauenAkzentFarbe.opacity(0.22), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dein Vertrauenskreis")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(vertrauenTextFarbe)

                    Text("Hinterlege die Menschen, die informiert werden oder im Ernstfall helfen sollen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vertrauenKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(vertrauenAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func vertrauenspersonSection(
        titel: String,
        untertitel: String,
        icon: String,
        kategorie: VertrauenspersonKategorie,
        kontakte: [HinterbliebeneModell]
    ) -> some View {
        let istEingeklappt = eingeklappteKategorien.contains(kategorie)
        let sichtbareKontakte = istEingeklappt ? Array(kontakte.prefix(2)) : kontakte

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(vertrauenAkzentFarbe)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(vertrauenAkzentFarbe.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(titel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(vertrauenTextFarbe)

                    Text(untertitel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }


            if kontakte.isEmpty {
                Text("Noch kein Kontakt hinterlegt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 10) {
                    ForEach(sichtbareKontakte) { kontakt in
                        kontaktZeile(kontakt)
                    }
                }

                if kontakte.count > 2 {
                    Button {
                        toggleKategorie(kategorie)
                    } label: {
                        HStack(spacing: 8) {
                            Text(istEingeklappt ? "Alle Kontakte anzeigen" : "Kontakte einklappen")
                                .font(.footnote.weight(.semibold))

                            Spacer()

                            Image(systemName: istEingeklappt ? "chevron.down" : "chevron.up")
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(vertrauenAkzentFarbe)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                aktiveKategorie = kategorie
                showKontaktPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))

                    Text("Kontakt hinzufügen")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(vertrauenAkzentFarbe)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vertrauenKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(vertrauenAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func kontaktZeile(_ kontakt: HinterbliebeneModell) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(initialenFuerKontakt(kontakt))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(vertrauenAkzentFarbe.opacity(0.88)))

            VStack(alignment: .leading, spacing: 6) {
                Text(anzeigenameFuerKontakt(kontakt))
                    .font(.headline)
                    .foregroundStyle(vertrauenTextFarbe)

                if !kontakt.adresse.isEmpty || !kontakt.plz.isEmpty || !kontakt.stadt.isEmpty {
                    Text([kontakt.adresse, plzOrtFuerKontakt(kontakt)].filter { !$0.isEmpty }.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !kontakt.email.isEmpty {
                    Label(kontakt.email, systemImage: "envelope")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !kontakt.telefon.isEmpty {
                    Label(kontakt.telefon, systemImage: "phone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if !istAbgeleiteterHausarztKontakt(kontakt) {
                Button(role: .destructive) {
                    modelContext.delete(kontakt)
                } label: {
                    Image(systemName: "trash")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.red.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(vertrauenAkzentFarbe.opacity(0.08), lineWidth: 1)
        }
    }

    private func initialenFuerKontakt(_ kontakt: HinterbliebeneModell) -> String {
        let vornameInitial = kontakt.vorname.trimmingCharacters(in: .whitespacesAndNewlines).first
        let nameInitial = kontakt.name.trimmingCharacters(in: .whitespacesAndNewlines).first
        let initialen = [vornameInitial, nameInitial]
            .compactMap { $0 }
            .map { String($0).uppercased() }
            .joined()

        return initialen.isEmpty ? "?" : initialen
    }

    private func kontaktHinzufuegen(_ kontakt: HinterbliebeneKontakt, zu kategorie: VertrauenspersonKategorie) {
        let neuerKontakt = HinterbliebeneModell(
            vorname: kontakt.vorname,
            name: kontakt.name,
            rolle: kategorie.anzeigetitel,
            beziehung: kategorie.rawValue,
            telefon: kontakt.telefon,
            email: kontakt.email,
            adresse: kontakt.adresse,
            plz: kontakt.plz,
            stadt: kontakt.ort,
            istVertrauensperson: true,
            sollInformiertWerden: true
        )

        modelContext.insert(neuerKontakt)
    }

    private func kontakteFuerKategorie(_ kategorie: VertrauenspersonKategorie) -> [HinterbliebeneModell] {
        var kontakte = gespeicherteKontakte
            .filter { $0.beziehung == kategorie.rawValue }

        if kategorie == .beguenstigte,
           let hausarztKontakt = abgeleiteterHausarztKontakt(),
           !kontakte.contains(where: { istDerselbeAndereKontakt($0, wie: hausarztKontakt) }) {
            kontakte.append(hausarztKontakt)
        }

        return kontakte
            .sorted { linkerKontakt, rechterKontakt in
                if istAbgeleiteterHausarztKontakt(linkerKontakt) != istAbgeleiteterHausarztKontakt(rechterKontakt) {
                    return istAbgeleiteterHausarztKontakt(linkerKontakt)
                }

                return anzeigenameFuerKontakt(linkerKontakt) < anzeigenameFuerKontakt(rechterKontakt)
            }
    }

    private func abgeleiteterHausarztKontakt() -> HinterbliebeneModell? {
        guard let gesundheit = gesundheitsDatensaetze.first,
              gesundheit.hatHausarzt else {
            return nil
        }

        let getrimmterName = gesundheit.hausarztName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmterName.isEmpty else {
            return nil
        }

        return HinterbliebeneModell(
            vorname: "",
            name: getrimmterName,
            rolle: "Arzt",
            beziehung: VertrauenspersonKategorie.beguenstigte.rawValue,
            telefon: gesundheit.hausarztTelefon.trimmingCharacters(in: .whitespacesAndNewlines),
            email: gesundheit.hausarztEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            adresse: gesundheit.hausarztAdresse.trimmingCharacters(in: .whitespacesAndNewlines),
            plz: gesundheit.hausarztPLZ.trimmingCharacters(in: .whitespacesAndNewlines),
            stadt: gesundheit.hausarztOrt.trimmingCharacters(in: .whitespacesAndNewlines),
            istVertrauensperson: false,
            sollInformiertWerden: false
        )
    }

    private func istDerselbeAndereKontakt(_ kontakt: HinterbliebeneModell, wie andererKontakt: HinterbliebeneModell) -> Bool {
        let linkerName = anzeigenameFuerKontakt(kontakt).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rechterName = anzeigenameFuerKontakt(andererKontakt).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return linkerName == rechterName
            && kontakt.beziehung == VertrauenspersonKategorie.beguenstigte.rawValue
            && andererKontakt.beziehung == VertrauenspersonKategorie.beguenstigte.rawValue
    }

    private func istAbgeleiteterHausarztKontakt(_ kontakt: HinterbliebeneModell) -> Bool {
        let rolle = kontakt.rolle.trimmingCharacters(in: .whitespacesAndNewlines)

        return (rolle == "Arzt" || rolle == "Andere|Hausarzt" || rolle == "Hausarzt")
            && kontakt.beziehung == VertrauenspersonKategorie.beguenstigte.rawValue
    }

    private func anzeigenameFuerKontakt(_ kontakt: HinterbliebeneModell) -> String {
        let name = [kontakt.vorname, kontakt.name]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return name.isEmpty ? "Unbenannter Kontakt" : name
    }


    private func plzOrtFuerKontakt(_ kontakt: HinterbliebeneModell) -> String {
        [kontakt.plz, kontakt.stadt]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func toggleKategorie(_ kategorie: VertrauenspersonKategorie) {
        if eingeklappteKategorien.contains(kategorie) {
            eingeklappteKategorien.remove(kategorie)
        } else {
            eingeklappteKategorien.insert(kategorie)
        }
    }
}

struct HinterbliebeneKontakt: Identifiable, Equatable {
    let id = UUID()
    var vorname: String
    var name: String
    var adresse: String
    var plz: String
    var ort: String
    var email: String
    var telefon: String

    var anzeigename: String {
        [vorname, name].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var plzOrt: String {
        [plz, ort].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum VertrauenspersonKategorie: String, Identifiable, Hashable {
    case partner
    case familie
    case freunde
    case beguenstigte

    var id: String { rawValue }

    var anzeigetitel: String {
        switch self {
        case .partner:
            return "Partner"
        case .familie:
            return "Familie"
        case .freunde:
            return "Freunde"
        case .beguenstigte:
            return "Andere"
        }
    }
}

struct HinterbliebeneKontaktPicker: UIViewControllerRepresentable {

    var onSelect: (HinterbliebeneKontakt?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPostalAddressesKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {

        let onSelect: (HinterbliebeneKontakt?) -> Void

        init(onSelect: @escaping (HinterbliebeneKontakt?) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let postalAddress = contact.postalAddresses.first?.value

            let kontakt = HinterbliebeneKontakt(
                vorname: contact.givenName,
                name: contact.familyName,
                adresse: [postalAddress?.street, postalAddress?.subLocality]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", "),
                plz: postalAddress?.postalCode ?? "",
                ort: postalAddress?.city ?? "",
                email: contact.emailAddresses.first.map { String($0.value) } ?? "",
                telefon: contact.phoneNumbers.first.map { $0.value.stringValue } ?? ""
            )

            onSelect(kontakt)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onSelect(nil)
        }
    }
}

#Preview {
    HinterbliebeneView()
        .modelContainer(for: [HinterbliebeneModell.self, GesundheitModell.self], inMemory: true)
}
