import SwiftUI
import ContactsUI
import PhotosUI
import UniformTypeIdentifiers

struct WuenscheView: View {
    @State private var hatBesondereWuensche = true

    @State private var bestattungsart: Bestattungsart = .kremation
    @State private var bestattungswuensche = ""
    @State private var kremationHinweise = ""
    @State private var erdbestattungHinweise = ""
    @State private var sonstigeBemerkungen = ""

    @State private var besondereMusik = false
    @State private var besondereMusikText = ""

    @State private var zeremonie = false
    @State private var zeremonieText = ""
    @State private var zeremonieBereitsOrganisiert = false
    @State private var zeremonieOrganisiertDetails = ""
    @State private var zeremonieFinanziellAbgesichert = false

    @State private var moechteNochWasSagen = false
    @State private var letzteWorteText = ""

    @State private var nachrufVorstellung = false
    @State private var nachrufText = ""
    @State private var nachrufBildAuswahl: PhotosPickerItem?
    @State private var nachrufBildData: Data?

    @State private var kontakte: [BeisetzungsKontakt] = []
    @State private var ausgeklappteKontaktIDs: Set<UUID> = []
    @AppStorage("hinterbliebeneKontakteJSON") private var hinterbliebeneKontakteJSON = "[]"
    @State private var kontaktPickerAnzeigen = false

    @State private var hatTestament = false
    @State private var testamentDateiName: String?
    @State private var testamentDateiURL: URL?
    @State private var testamentHochgeladenAm: Date?
    @State private var testamentErinnerungAktiv = true
    @State private var testamentErinnerungDatum = Date()

    @State private var hatPatientenverfuegung = false
    @State private var patientenverfuegungDateiName: String?
    @State private var patientenverfuegungDateiURL: URL?
    @State private var patientenverfuegungHochgeladenAm: Date?
    @State private var patientenverfuegungErinnerungAktiv = true
    @State private var patientenverfuegungErinnerungDatum = Date()

    @State private var hatVorsorgeauftrag = false
    @State private var vorsorgeauftragDateiName: String?
    @State private var vorsorgeauftragDateiURL: URL?
    @State private var vorsorgeauftragHochgeladenAm: Date?
    @State private var vorsorgeauftragErinnerungAktiv = true
    @State private var vorsorgeauftragErinnerungDatum = Date()

    @State private var offenFuerSterbebegleitung = false
    @State private var sterbebegleitungDateiName: String?
    @State private var sterbebegleitungDateiURL: URL?
    @State private var sterbebegleitungHochgeladenAm: Date?
    @State private var sterbebegleitungErinnerungAktiv = true
    @State private var sterbebegleitungErinnerungDatum = Date()

    @State private var hatSchwereGesundheitlicheErkrankung = false
    @State private var schwereErkrankung: SchwereErkrankung?
    @State private var sterbebegleitungWichtig = ""
    @State private var lebensqualitaetRegelmaessigBeurteilen = true

    @State private var dokumentImporterAnzeigen = false
    @State private var aktiverDokumentTyp: DokumentTyp?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Ich habe besondere Wünsche nach meinem Tod", isOn: $hatBesondereWuensche)
                }

                if hatBesondereWuensche {
                    Section("Meine Beisetzung") {
                        TextField("Bestattungswünsche", text: $bestattungswuensche, axis: .vertical)
                            .lineLimit(3...8)

                        Picker("Bestattungsart", selection: $bestattungsart) {
                            ForEach(Bestattungsart.allCases) { art in
                                Text(art.rawValue).tag(art)
                            }
                        }
                        .pickerStyle(.segmented)

                        if bestattungsart == .kremation {
                            TextField("Was ist bei der Kremation zu beachten? z.B. Art der Urne, Urnengrab, Waldfriedhof", text: $kremationHinweise, axis: .vertical)
                                .lineLimit(3...8)
                        }

                        if bestattungsart == .erdbestattung {
                            TextField("Was ist bei der Erdbestattung zu beachten? z.B. Art des Sarges, Kleidung, Ort und Ablauf", text: $erdbestattungHinweise, axis: .vertical)
                                .lineLimit(3...8)
                        }

                        TextField("Sonstige Bemerkungen", text: $sonstigeBemerkungen, axis: .vertical)
                            .lineLimit(3...8)
                    }

                    Section("Wünsche zur Beisetzung") {
                        Toggle("Zeremonie", isOn: $zeremonie)

                        if zeremonie {
                            DetailBox {
                                TextField("Wie soll die Zeremonie gestaltet sein?", text: $zeremonieText, axis: .vertical)
                                    .lineLimit(2...6)

                                Divider()

                                Toggle("Bereits organisiert", isOn: $zeremonieBereitsOrganisiert)

                                if zeremonieBereitsOrganisiert {
                                    DetailBox {
                                        TextField("Details zur Organisation", text: $zeremonieOrganisiertDetails, axis: .vertical)
                                            .lineLimit(2...6)
                                    }
                                }

                                Divider()

                                Button {
                                    zeremonieFinanziellAbgesichert.toggle()
                                } label: {
                                    HStack {
                                        Image(systemName: zeremonieFinanziellAbgesichert ? "checkmark.square.fill" : "square")
                                        Text("Finanziell abgesichert, diese zu begleichen")
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Toggle("Besondere Musik", isOn: $besondereMusik)

                        if besondereMusik {
                            DetailBox {
                                TextField("Welche Musik soll gespielt werden?", text: $besondereMusikText, axis: .vertical)
                                    .lineLimit(2...6)
                            }
                        }

                        Toggle("Persönliche Botschaft", isOn: $moechteNochWasSagen)

                        if moechteNochWasSagen {
                            DetailBox {
                                TextField("Was möchtest du noch sagen?", text: $letzteWorteText, axis: .vertical)
                                    .lineLimit(3...8)
                            }
                        }

                        Toggle("Ich habe eine Vorstellung, wie der Nachruf sein soll", isOn: $nachrufVorstellung)

                        if nachrufVorstellung {
                            DetailBox {
                                TextField("Wie soll der Nachruf sein? z.B Zeitung, Karte", text: $nachrufText, axis: .vertical)
                                    .lineLimit(3...8)

                                Divider()

                                VStack(spacing: 12) {
                                    if let nachrufBildData,
                                       let uiImage = UIImage(data: nachrufBildData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                            .clipped()
                                    } else {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.secondary)
                                    }

                                    PhotosPicker(
                                        selection: $nachrufBildAuswahl,
                                        matching: .images,
                                        photoLibrary: .shared()
                                    ) {
                                        Label(nachrufBildData == nil ? "Bild für Nachruf hochladen" : "Bild für Nachruf ändern", systemImage: "photo.on.rectangle")
                                    }
                                    .buttonStyle(.borderless)

                                    if nachrufBildData != nil {
                                        Button(role: .destructive) {
                                            nachrufBildEntfernen()
                                        } label: {
                                            Label("Bild entfernen", systemImage: "trash")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    Section("Personen informieren / einladen") {
                        if kontakte.isEmpty {
                            Text("Noch keine Kontakte erfasst.")
                                .foregroundStyle(.secondary)
                        }

                        ForEach($kontakte) { $kontakt in
                            if kontakte.count > 3 {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { ausgeklappteKontaktIDs.contains(kontakt.id) },
                                        set: { istOffen in
                                            if istOffen {
                                                ausgeklappteKontaktIDs.insert(kontakt.id)
                                            } else {
                                                ausgeklappteKontaktIDs.remove(kontakt.id)
                                            }
                                        }
                                    )
                                ) {
                                    kontaktDetailFormular(kontakt: $kontakt)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(kontakt.anzeigename)
                                            .font(.headline)

                                        Text(kontakt.art.rawValue)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                kontaktDetailFormular(kontakt: $kontakt)
                            }
                        }
                        .onDelete(perform: kontaktLoeschen)

                        Button {
                            kontaktHinzufuegen()
                        } label: {
                            Label("Kontakt manuell hinzufügen", systemImage: "plus.circle.fill")
                        }

                        Button {
                            kontaktPickerAnzeigen = true
                        } label: {
                            Label("Aus Adressbuch hinzufügen", systemImage: "person.crop.circle.badge.plus")
                        }
                    }

                    Section("Nachlass") {
                        Toggle("Ich habe ein Testament", isOn: $hatTestament)

                        if hatTestament {
                            DetailBox {
                                Text("Ein Testament muss den gesetzlichen und formellen Anforderungen entsprechen. Du bist selbst dafür verantwortlich, dass Inhalt, Form und Aufbewahrung korrekt und rechtsgültig sind. Diese App ersetzt keine rechtliche Beratung.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Divider()

                                VStack(spacing: 12) {
                                    Image(systemName: testamentDateiName == nil ? "doc.fill" : "doc.text.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)

                                    if let testamentDateiName {
                                        Text(testamentDateiName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                    }

                                    if let testamentHochgeladenAm {
                                        Text("Testament hochgeladen am \(testamentHochgeladenAm.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                    }

                                    Button {
                                        dokumentImportStarten(.testament)
                                    } label: {
                                        Label(testamentDateiName == nil ? "Testament hochladen" : "Testament ändern", systemImage: "doc.badge.plus")
                                    }
                                    .buttonStyle(.borderless)

                                    if testamentDateiName != nil {
                                        Button(role: .destructive) {
                                            testamentDateiEntfernen()
                                        } label: {
                                            Label("Testament entfernen", systemImage: "trash")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)

                                        Divider()

                                        Toggle("Erinnerung zur Überprüfung", isOn: $testamentErinnerungAktiv)

                                        if testamentErinnerungAktiv {
                                            DatePicker(
                                                "Überprüfung am",
                                                selection: $testamentErinnerungDatum,
                                                displayedComponents: .date
                                            )
                                            .environment(\.locale, Locale(identifier: "de_CH"))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    Section("Patientenverfügung") {
                        Toggle("Ich habe eine Patientenverfügung", isOn: $hatPatientenverfuegung)

                        if hatPatientenverfuegung {
                            DetailBox {
                                DokumentUploadBox(
                                    dateiName: patientenverfuegungDateiName,
                                    hochgeladenAm: patientenverfuegungHochgeladenAm,
                                    timestampTitel: "Patientenverfügung hochgeladen am",
                                    uploadTitel: patientenverfuegungDateiName == nil ? "Patientenverfügung hochladen" : "Patientenverfügung ändern",
                                    entfernenTitel: "Patientenverfügung entfernen",
                                    erinnerungAktiv: $patientenverfuegungErinnerungAktiv,
                                    erinnerungDatum: $patientenverfuegungErinnerungDatum,
                                    uploadAktion: {
                                        dokumentImportStarten(.patientenverfuegung)
                                    },
                                    entfernenAktion: {
                                        patientenverfuegungDateiEntfernen()
                                    }
                                )
                            }
                        }
                    }

                    Section("Vorsorgeauftrag") {
                        Toggle("Ich habe einen Vorsorgeauftrag", isOn: $hatVorsorgeauftrag)

                        if hatVorsorgeauftrag {
                            DetailBox {
                                DokumentUploadBox(
                                    dateiName: vorsorgeauftragDateiName,
                                    hochgeladenAm: vorsorgeauftragHochgeladenAm,
                                    timestampTitel: "Vorsorgeauftrag hochgeladen am",
                                    uploadTitel: vorsorgeauftragDateiName == nil ? "Vorsorgeauftrag hochladen" : "Vorsorgeauftrag ändern",
                                    entfernenTitel: "Vorsorgeauftrag entfernen",
                                    erinnerungAktiv: $vorsorgeauftragErinnerungAktiv,
                                    erinnerungDatum: $vorsorgeauftragErinnerungDatum,
                                    uploadAktion: {
                                        dokumentImportStarten(.vorsorgeauftrag)
                                    },
                                    entfernenAktion: {
                                        vorsorgeauftragDateiEntfernen()
                                    }
                                )
                            }
                        }
                    }

                    Section("Sterbebegleitung") {
                        Toggle("Ich bin offen für eine Sterbebegleitung", isOn: $offenFuerSterbebegleitung)

                        if offenFuerSterbebegleitung {
                            DetailBox {
                                Toggle("Ich habe eine schwerwiegende gesundheitliche Erkrankung", isOn: $hatSchwereGesundheitlicheErkrankung)

                                if hatSchwereGesundheitlicheErkrankung {
                                    DetailBox {
                                        Picker("Erkrankung", selection: $schwereErkrankung) {
                                            Text("Bitte wählen").tag(nil as SchwereErkrankung?)
                                            ForEach(SchwereErkrankung.allCases) { erkrankung in
                                                Text(erkrankung.rawValue).tag(erkrankung as SchwereErkrankung?)
                                            }
                                        }

                                        TextField("Das ist für mich wichtig", text: $sterbebegleitungWichtig, axis: .vertical)
                                            .lineLimit(3...8)

                                        if schwereErkrankung != nil {
                                            Toggle(
                                                "Ich möchte regelmässig bewusst beurteilen, ob mein Leben für mich noch lebenswert ist und welcher Weg sich für mich stimmig anfühlt.",
                                                isOn: $lebensqualitaetRegelmaessigBeurteilen
                                                //Funktion wird später erfolgen
                                            )
                                        }
                                    }
                                }

                                Divider()

                                DokumentUploadBox(
                                    dateiName: sterbebegleitungDateiName,
                                    hochgeladenAm: sterbebegleitungHochgeladenAm,
                                    timestampTitel: "Sterbebegleitung hochgeladen am",
                                    uploadTitel: sterbebegleitungDateiName == nil ? "Dokument zur Sterbebegleitung hochladen" : "Dokument zur Sterbebegleitung ändern",
                                    entfernenTitel: "Dokument zur Sterbebegleitung entfernen",
                                    erinnerungAktiv: $sterbebegleitungErinnerungAktiv,
                                    erinnerungDatum: $sterbebegleitungErinnerungDatum,
                                    uploadAktion: {
                                        dokumentImportStarten(.sterbebegleitung)
                                    },
                                    entfernenAktion: {
                                        sterbebegleitungDateiEntfernen()
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Meine Wünsche")
            .sheet(isPresented: $kontaktPickerAnzeigen) {
                KontaktPicker { kontakt in
                    kontakte.append(kontakt)
                    gemeinsameKontakteSpeichern()
                    kontaktPickerAnzeigen = false
                }
            }
            .fileImporter(
                isPresented: $dokumentImporterAnzeigen,
                allowedContentTypes: [.pdf, .image, .text, .plainText, .rtf, .data],
                allowsMultipleSelection: false
            ) { result in
                dokumentImportVerarbeiten(result)
            }
            .onChange(of: nachrufBildAuswahl) { _, neueAuswahl in
                Task {
                    if let data = try? await neueAuswahl?.loadTransferable(type: Data.self) {
                        nachrufBildData = data
                    }
                }
            }
        }
    }

    private func kontaktHinzufuegen() {
        kontakte.append(BeisetzungsKontakt())
    }

    private func kontaktLoeschen(at offsets: IndexSet) {
        for index in offsets {
            if kontakte.indices.contains(index) {
                ausgeklappteKontaktIDs.remove(kontakte[index].id)
            }
        }

        kontakte.remove(atOffsets: offsets)
    }

    private func kontaktEntfernen(_ kontakt: BeisetzungsKontakt) {
        ausgeklappteKontaktIDs.remove(kontakt.id)
        kontakte.removeAll { $0.id == kontakt.id }
    }

    private func gemeinsameKontakteSpeichern() {
        if let data = try? JSONEncoder().encode(kontakte),
           let json = String(data: data, encoding: .utf8) {
            hinterbliebeneKontakteJSON = json
        }
    }

    @ViewBuilder
    private func kontaktDetailFormular(kontakt: Binding<BeisetzungsKontakt>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Art", selection: kontakt.art) {
                ForEach(KontaktArt.allCases) { art in
                    Text(art.rawValue).tag(art)
                }
            }

            TextField("Vorname", text: kontakt.vorname)
                .textContentType(.givenName)

            TextField("Name", text: kontakt.name)
                .textContentType(.familyName)

            TextField("Adresse", text: kontakt.adresse, axis: .vertical)
                .textContentType(.fullStreetAddress)
                .lineLimit(2...4)

            TextField("Telefonnummer", text: kontakt.telefon)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)

            TextField("E-Mail", text: kontakt.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)

            Toggle("Informieren", isOn: kontakt.informieren)
            Toggle("Zur Beisetzung einladen", isOn: kontakt.einladen)
        }
        .padding(.vertical, 6)
    }

    private func nachrufBildEntfernen() {
        nachrufBildData = nil
        nachrufBildAuswahl = nil
    }

    private func dokumentImportStarten(_ typ: DokumentTyp) {
        aktiverDokumentTyp = typ
        dokumentImporterAnzeigen = true
    }

    private func dokumentImportVerarbeiten(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            switch aktiverDokumentTyp {
            case .testament:
                testamentDateiURL = url
                testamentDateiName = url.lastPathComponent
                testamentHochgeladenAm = Date()
                testamentErinnerungAktiv = true
                testamentErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .patientenverfuegung:
                patientenverfuegungDateiURL = url
                patientenverfuegungDateiName = url.lastPathComponent
                patientenverfuegungHochgeladenAm = Date()
                patientenverfuegungErinnerungAktiv = true
                patientenverfuegungErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .vorsorgeauftrag:
                vorsorgeauftragDateiURL = url
                vorsorgeauftragDateiName = url.lastPathComponent
                vorsorgeauftragHochgeladenAm = Date()
                vorsorgeauftragErinnerungAktiv = true
                vorsorgeauftragErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .sterbebegleitung:
                sterbebegleitungDateiURL = url
                sterbebegleitungDateiName = url.lastPathComponent
                sterbebegleitungHochgeladenAm = Date()
                sterbebegleitungErinnerungAktiv = true
                sterbebegleitungErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .none:
                break
            }

        case .failure:
            break
        }

        aktiverDokumentTyp = nil
    }

    private func testamentDateiEntfernen() {
        testamentDateiName = nil
        testamentDateiURL = nil
        testamentHochgeladenAm = nil
        testamentErinnerungAktiv = true
        testamentErinnerungDatum = Date()
    }

    private func patientenverfuegungDateiEntfernen() {
        patientenverfuegungDateiName = nil
        patientenverfuegungDateiURL = nil
        patientenverfuegungHochgeladenAm = nil
        patientenverfuegungErinnerungAktiv = true
        patientenverfuegungErinnerungDatum = Date()
    }

    private func vorsorgeauftragDateiEntfernen() {
        vorsorgeauftragDateiName = nil
        vorsorgeauftragDateiURL = nil
        vorsorgeauftragHochgeladenAm = nil
        vorsorgeauftragErinnerungAktiv = true
        vorsorgeauftragErinnerungDatum = Date()
    }

    private func sterbebegleitungDateiEntfernen() {
        sterbebegleitungDateiName = nil
        sterbebegleitungDateiURL = nil
        sterbebegleitungHochgeladenAm = nil
        sterbebegleitungErinnerungAktiv = true
        sterbebegleitungErinnerungDatum = Date()
    }

    private func erinnerungsDatumInEinemJahr() -> Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }
}

enum Bestattungsart: String, CaseIterable, Identifiable {
    case kremation = "Kremation"
    case erdbestattung = "Erdbestattung"

    var id: String { rawValue }
}

enum KontaktArt: String, CaseIterable, Identifiable, Codable {
    case partner = "Partner"
    case familie = "Familie"
    case freunde = "Freunde"
    case anderes = "Anderes"

    var id: String { rawValue }
}

enum DokumentTyp {
    case testament
    case patientenverfuegung
    case vorsorgeauftrag
    case sterbebegleitung
}

enum SchwereErkrankung: String, CaseIterable, Identifiable {
    case demenz = "Demenz"
    case alzheimer = "Alzheimer"
    case fortgeschrittenerKrebs = "Fortgeschrittener Krebs"
    case andere = "Andere"

    var id: String { rawValue }
}

struct BeisetzungsKontakt: Identifiable, Codable, Equatable {
    var id = UUID()
    var vorname = ""
    var name = ""
    var adresse = ""
    var telefon = ""
    var email = ""
    var art: KontaktArt = .familie
    var informieren = true
    var einladen = true

    var anzeigename: String {
        let nameTeile = [vorname, name].filter { !$0.isEmpty }
        return nameTeile.isEmpty ? "Unbenannter Kontakt" : nameTeile.joined(separator: " ")
    }
}

struct KontaktPicker: UIViewControllerRepresentable {
    let kontaktAusgewaehlt: (BeisetzungsKontakt) -> Void

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
        Coordinator(kontaktAusgewaehlt: kontaktAusgewaehlt)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let kontaktAusgewaehlt: (BeisetzungsKontakt) -> Void

        init(kontaktAusgewaehlt: @escaping (BeisetzungsKontakt) -> Void) {
            self.kontaktAusgewaehlt = kontaktAusgewaehlt
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let adresse = contact.postalAddresses.first.map { adresseFormatieren($0.value) } ?? ""
            let telefon = contact.phoneNumbers.first?.value.stringValue ?? ""
            let email = contact.emailAddresses.first.map { String($0.value) } ?? ""

            let beisetzungsKontakt = BeisetzungsKontakt(
                vorname: contact.givenName,
                name: contact.familyName,
                adresse: adresse,
                telefon: telefon,
                email: email
            )

            kontaktAusgewaehlt(beisetzungsKontakt)
        }

        private func adresseFormatieren(_ adresse: CNPostalAddress) -> String {
            [
                adresse.street,
                "\(adresse.postalCode) \(adresse.city)",
                adresse.country
            ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        }
    }
}

struct DetailBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DokumentUploadBox: View {
    let dateiName: String?
    let hochgeladenAm: Date?
    let timestampTitel: String
    let uploadTitel: String
    let entfernenTitel: String
    @Binding var erinnerungAktiv: Bool
    @Binding var erinnerungDatum: Date
    let uploadAktion: () -> Void
    let entfernenAktion: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: dateiName == nil ? "doc.fill" : "doc.text.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if let dateiName {
                Text(dateiName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let hochgeladenAm {
                Text("\(timestampTitel) \(hochgeladenAm.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                uploadAktion()
            } label: {
                Label(uploadTitel, systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderless)

            if dateiName != nil {
                Button(role: .destructive) {
                    entfernenAktion()
                } label: {
                    Label(entfernenTitel, systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Divider()

                Toggle("Erinnerung zur Überprüfung", isOn: $erinnerungAktiv)

                if erinnerungAktiv {
                    DatePicker(
                        "Überprüfung am",
                        selection: $erinnerungDatum,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "de_CH"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    WuenscheView()
}
