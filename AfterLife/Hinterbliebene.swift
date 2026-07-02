import SwiftUI
import SwiftData
import ContactsUI

struct HinterbliebeneView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteKontakte: [HinterbliebeneModell]
    @Query private var gesundheitsDatensaetze: [GesundheitModell]

    @State private var aktiveKategorie: VertrauenspersonKategorie = .partner
    @State private var showKontaktPicker = false
    @State private var eingeklappteKategorien: Set<VertrauenspersonKategorie> = []

    var body: some View {
        NavigationStack {
            Form {
                vertrauenspersonSection(
                    titel: "Partner",
                    kategorie: .partner,
                    kontakte: kontakteFuerKategorie(.partner)
                )

                vertrauenspersonSection(
                    titel: "Familie",
                    kategorie: .familie,
                    kontakte: kontakteFuerKategorie(.familie)
                )

                vertrauenspersonSection(
                    titel: "Freunde",
                    kategorie: .freunde,
                    kontakte: kontakteFuerKategorie(.freunde)
                )

                vertrauenspersonSection(
                    titel: "Andere",
                    kategorie: .beguenstigte,
                    kontakte: kontakteFuerKategorie(.beguenstigte)
                )
            }
            .navigationTitle("Menschen meines Vertrauens")
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

    private func vertrauenspersonSection(
        titel: String,
        kategorie: VertrauenspersonKategorie,
        kontakte: [HinterbliebeneModell]
    ) -> some View {
        Section(titel) {
            Button {
                aktiveKategorie = kategorie
                showKontaktPicker = true
            } label: {
                Label("Kontakt hinzufügen", systemImage: "person.crop.circle.badge.plus")
            }

            if kontakte.isEmpty {
                Text("Noch kein Kontakt hinterlegt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let istEingeklappt = eingeklappteKategorien.contains(kategorie)
                let sichtbareKontakte = istEingeklappt ? Array(kontakte.prefix(2)) : kontakte

                ForEach(sichtbareKontakte) { kontakt in
                    kontaktZeile(kontakt)
                }
                .onDelete { indexSet in
                    let zuLoeschendeKontakte = indexSet.map { sichtbareKontakte[$0] }
                    zuLoeschendeKontakte.forEach { kontakt in
                        guard !istAbgeleiteterHausarztKontakt(kontakt) else { return }
                        modelContext.delete(kontakt)
                    }
                }

                if kontakte.count > 2 {
                    Button {
                        toggleKategorie(kategorie)
                    } label: {
                        HStack {
                            Text(istEingeklappt ? "Alle Kontakte anzeigen" : "Kontakte einklappen")
                            Spacer()
                            Image(systemName: istEingeklappt ? "chevron.down" : "chevron.up")
                        }
                    }
                }
            }
        }
    }

    private func kontaktZeile(_ kontakt: HinterbliebeneModell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(anzeigenameFuerKontakt(kontakt))
                .font(.headline)

            let angezeigteRolle = angezeigteRolleFuerKontakt(kontakt)

            if !angezeigteRolle.isEmpty {
                Text(angezeigteRolle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !kontakt.adresse.isEmpty || !kontakt.plz.isEmpty || !kontakt.stadt.isEmpty {
                Text([kontakt.adresse, plzOrtFuerKontakt(kontakt)].filter { !$0.isEmpty }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !kontakt.email.isEmpty {
                Label(kontakt.email, systemImage: "envelope")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !kontakt.telefon.isEmpty {
                Label(kontakt.telefon, systemImage: "phone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
            .sorted { anzeigenameFuerKontakt($0) < anzeigenameFuerKontakt($1) }
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
            rolle: "Andere|Hausarzt",
            beziehung: VertrauenspersonKategorie.beguenstigte.rawValue,
            telefon: "",
            email: "",
            adresse: "",
            plz: "",
            stadt: "",
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
        kontakt.rolle == "Andere|Hausarzt"
            && kontakt.beziehung == VertrauenspersonKategorie.beguenstigte.rawValue
    }

    private func anzeigenameFuerKontakt(_ kontakt: HinterbliebeneModell) -> String {
        let name = [kontakt.vorname, kontakt.name]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return name.isEmpty ? "Unbenannter Kontakt" : name
    }

    private func angezeigteRolleFuerKontakt(_ kontakt: HinterbliebeneModell) -> String {
        let roheRolle = kontakt.rolle.components(separatedBy: "|").first ?? kontakt.rolle

        switch roheRolle.lowercased() {
        case VertrauenspersonKategorie.partner.rawValue:
            return "Partner"
        case VertrauenspersonKategorie.familie.rawValue:
            return "Familie"
        case VertrauenspersonKategorie.freunde.rawValue:
            return "Freunde"
        case VertrauenspersonKategorie.beguenstigte.rawValue:
            if kontakt.rolle.contains("Hausarzt") {
                return "Andere · Hausarzt"
            }
            return "Andere"
        default:
            return roheRolle
        }
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
            return "Begünstigte"
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
