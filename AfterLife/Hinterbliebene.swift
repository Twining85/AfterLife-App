import SwiftUI
import ContactsUI

struct HinterbliebeneView: View {

    @State private var partnerKontakte: [HinterbliebeneKontakt] = []
    @State private var familieKontakte: [HinterbliebeneKontakt] = []
    @State private var freundeKontakte: [HinterbliebeneKontakt] = []
    @State private var beguenstigteKontakte: [HinterbliebeneKontakt] = []

    @State private var aktiveKategorie: VertrauenspersonKategorie = .partner
    @State private var showKontaktPicker = false
    @State private var eingeklappteKategorien: Set<VertrauenspersonKategorie> = []

    var body: some View {
        NavigationStack {
            Form {
                vertrauenspersonSection(
                    titel: "Partner",
                    kategorie: .partner,
                    kontakte: $partnerKontakte
                )

                vertrauenspersonSection(
                    titel: "Familie",
                    kategorie: .familie,
                    kontakte: $familieKontakte
                )

                vertrauenspersonSection(
                    titel: "Freunde",
                    kategorie: .freunde,
                    kontakte: $freundeKontakte
                )

                vertrauenspersonSection(
                    titel: "Begünstigte",
                    kategorie: .beguenstigte,
                    kontakte: $beguenstigteKontakte
                )
            }
            .navigationTitle("Hinterbliebene")
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
        kontakte: Binding<[HinterbliebeneKontakt]>
    ) -> some View {
        Section(titel) {
            Button {
                aktiveKategorie = kategorie
                showKontaktPicker = true
            } label: {
                Label("Kontakt hinzufügen", systemImage: "person.crop.circle.badge.plus")
            }

            if kontakte.wrappedValue.isEmpty {
                Text("Noch kein Kontakt hinterlegt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let istEingeklappt = eingeklappteKategorien.contains(kategorie)
                let sichtbareKontakte = istEingeklappt ? Array(kontakte.wrappedValue.prefix(2)) : kontakte.wrappedValue

                ForEach(sichtbareKontakte) { kontakt in
                    kontaktZeile(kontakt)
                }
                .onDelete { indexSet in
                    kontakte.wrappedValue.remove(atOffsets: indexSet)
                }

                if kontakte.wrappedValue.count > 2 {
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

    private func kontaktZeile(_ kontakt: HinterbliebeneKontakt) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kontakt.anzeigename)
                .font(.headline)

            if !kontakt.adresse.isEmpty || !kontakt.plz.isEmpty || !kontakt.ort.isEmpty {
                Text([kontakt.adresse, kontakt.plzOrt].filter { !$0.isEmpty }.joined(separator: ", "))
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
        switch kategorie {
        case .partner:
            partnerKontakte.append(kontakt)
        case .familie:
            familieKontakte.append(kontakt)
        case .freunde:
            freundeKontakte.append(kontakt)
        case .beguenstigte:
            beguenstigteKontakte.append(kontakt)
        }
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
}
