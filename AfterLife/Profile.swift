import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import LocalAuthentication


struct ProfilView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteWuensche: [WuenscheModell]
    @Query private var gespeicherteHinterbliebene: [HinterbliebeneModell]
    @Query private var gespeicherteBankkonten: [BankkontoModell]
    @Query private var gespeicherteSchulden: [SchuldenModell]
    @Query private var gespeicherteVersicherungen: [VersicherungModell]
    @Query private var gespeicherteLiegenschaften: [LiegenschaftModell]
    @Query private var gespeicherteWertsachen: [WertsacheModell]
    @Query private var gespeicherteSteuerdokumente: [SteuerdokumentModell]
    @Query private var gespeicherteAboModelle: [AboModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]

    private let profilKartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let profilAkzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let profilHintergrundFarbe = Color(red: 0.985, green: 0.98, blue: 0.965)

    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("biometrieAktiviert") private var biometrieAktiviert = false

    @State private var vorname = ""

    @State private var name = ""

    @State private var geburtsdatum = Calendar.current.date(from: DateComponents(year: 1978, month: 6, day: 1)) ?? Date()
    @State private var geburtsdatumText = "01.06.1978"

    @State private var adresse = ""
    @State private var hausnummer = ""
    @State private var adressVorschlaege: [PostAdressVorschlag] = []
    @State private var adressSucheLaeuft = false
    @State private var adressVorschlagWurdeGewaehlt = false
    @State private var adresseManuellBearbeitet = false

    @State private var plz = ""

    @State private var stadt = ""
    @State private var plzSucheLaeuft = false

    @State private var land = "Schweiz"

    private let laender = [
        "Schweiz",
        "Deutschland",
        "Österreich",
        "Liechtenstein",
        "Frankreich",
        "Italien",
        "Spanien",
        "Portugal",
        "Niederlande",
        "Belgien",
        "Luxemburg",
        "Vereinigtes Königreich",
        "Irland",
        "USA",
        "Kanada",
        "Australien",
        "Neuseeland",
        "Andere"
    ]
    // Vercel Proxy für Schweizer Post Adressservices.
    // Nicht durch direkte Post URLs ersetzen, sonst wären Zugangsdaten in der App erforderlich.
    private let postAutocompleteURL = "https://afterlife-address-proxy.vercel.app/api/autocomplete"

    private let postBuildingVerificationURL = "https://afterlife-address-proxy.vercel.app/api/building-verification"


    @State private var telefon = ""

    @State private var email = ""

    @State private var profilbildAuswahl: PhotosPickerItem?

    @AppStorage("profilbildData") private var profilbildData: Data?

    @State private var showLogout = false

    @State private var showDeleted = false

    @State private var profilLoeschenBestaetigen = false

    @State private var passwortAendernAnzeigen = false
    @State private var registrierungsPasswortAnzeigen = false
    @State private var aktuellesPasswort = ""
    @State private var neuesPasswort = ""
    @State private var neuesPasswortWiederholen = ""
    @State private var passwortAendernFehler = ""
    @State private var passwortAendernErfolg = ""



    @State private var dossierPDF: ExportiertesDossier?
    @State private var passwortExportAuswahlAnzeigen = false
    @State private var profilGeladen = false
    @State private var biometriePruefungLaeuft = false
    @State private var biometrieFehlermeldung = ""



    private var istEmailGueltig: Bool {

        if email.isEmpty { return true }

        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        return email.range(of: emailRegex, options: .regularExpression) != nil

    }

    private var istEmailRegistrierung: Bool {
        registrierungsArt == "E-Mail" || registrierungsArt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var angezeigtesRegistrierungsPasswort: String {
        guard !gespeichertesPasswort.isEmpty else { return "Nicht erfasst" }
        return registrierungsPasswortAnzeigen ? gespeichertesPasswort : String(repeating: "•", count: max(6, gespeichertesPasswort.count))
    }

    var body: some View {

        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        if let profilbildData,
                           let uiImage = UIImage(data: profilbildData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .foregroundStyle(profilAkzentFarbe.opacity(0.65))
                        }
                        PhotosPicker(
                            selection: $profilbildAuswahl,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text(profilbildData == nil ? "Profilbild auswählen" : "Profilbild ändern")
                                .font(.headline)
                                .foregroundStyle(profilAkzentFarbe)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(profilKartenFarbe)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section("Persönliche Angaben") {
                    TextField("Vorname", text: $vorname)
                        .textContentType(.name)
                    
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    TextField("Strasse", text: $adresse)
                        .textContentType(.streetAddressLine1)
                        .onChange(of: adresse) { _, _ in
                            guard profilGeladen else { return }
                            adresseManuellBearbeitet = true
                        }

                    if adressSucheLaeuft {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Adressvorschläge werden gesucht …")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !adressVorschlaege.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(adressVorschlaege) { vorschlag in
                                    Button {
                                        adressVorschlagWurdeGewaehlt = true
                                        adresse = vorschlag.streetName
                                        hausnummer = vorschlag.vollstaendigeHausnummer
                                        plz = vorschlag.zipCode
                                        stadt = vorschlag.townName
                                        adressVorschlaege = []

                                        Task {
                                            await verifizierePostAdresse(vorschlag)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(vorschlag.anzeigeTitel)
                                                .foregroundStyle(.primary)
                                            Text(vorschlag.anzeigeUntertitel)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    if vorschlag.id != adressVorschlaege.last?.id {
                                        Divider()
                                            .padding(.horizontal, 10)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                        .background(Color.white.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(profilAkzentFarbe.opacity(0.14))
                                .frame(width: 1)
                        }
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(profilAkzentFarbe.opacity(0.14))
                                .frame(width: 1)
                        }
                        .padding(.vertical, 4)
                    }

                    TextField("Hausnummer", text: $hausnummer)
                        .textContentType(.streetAddressLine2)

                    HStack {
                        TextField("PLZ", text: $plz)
                            .keyboardType(.numberPad)
                        TextField("Stadt", text: $stadt)
                    }

                    Picker("Land", selection: $land) {
                        ForEach(laender, id: \.self) { land in
                            Text(land).tag(land)
                        }
                    }

                    TextField("Telefon", text: $telefon)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("E-Mail", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)

                        if !istEmailGueltig {
                            Text("Bitte gib eine gültige E-Mail-Adresse ein.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Geburtsdatum")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(profilAkzentFarbe)

                        TextField("TT.MM.JJJJ", text: $geburtsdatumText)
                            .keyboardType(.numberPad)
                            .textContentType(.birthdate)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 12)
                            .background(profilKartenFarbe)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onChange(of: geburtsdatumText) { _, neuerWert in
                                verarbeiteGeburtsdatumEingabe(neuerWert)
                            }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AHV-Nr.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(profilAkzentFarbe)

                        TextField("756.XXXX.XXXX.XX", text: $ahvNummer)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 12)
                            .background(profilKartenFarbe)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onChange(of: ahvNummer) { _, neuerWert in
                                let formatiert = formatiereAHVNummer(neuerWert)
                                if formatiert != ahvNummer {
                                    ahvNummer = formatiert
                                }
                            }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(profilKartenFarbe)
                .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))

                Section("Zugriff im Notfall") {
                    NavigationLink {
                        VertrauenspersonView()
                    } label: {
                        Label(
                            gespeicherteDossierZugriffe.isEmpty
                                ? "Vertrauensperson Zugriff geben"
                                : "Vertrauenspersonen verwalten",
                            systemImage: "person.badge.key.fill"
                        )
                        .foregroundStyle(profilAkzentFarbe)
                    }
                    Text("Hier kannst du Vertrauenspersonen einladen und verwalten, damit deine Daten im Notfall kontrolliert abrufbar sind.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(profilKartenFarbe)
                .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))
                Section("Dossier exportieren") {
                    Button {
                        passwortExportAuswahlAnzeigen = true
                    } label: {
                        Label("Dossier als PDF exportieren", systemImage: "doc.richtext.fill")
                            .foregroundStyle(profilAkzentFarbe)
                    }
                    Text("Erzeugt ein PDF-Dossier mit den aktuell erfassten Informationen aus Profil, Wünsche, Finanzen, Hinterbliebenen, Dokumenten sowie weiteren gespeicherten Bereichen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(profilKartenFarbe)
                .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))

                Section("Zugangsdaten") {
                    if registrierungsArt == "Google" {
                        LabeledContent("Registrierungsart", value: "Mit Google registriert")
                        LabeledContent("E-Mail-Adresse", value: gespeicherteEmail.isEmpty ? "Nicht erfasst" : gespeicherteEmail)
                    } else if registrierungsArt == "Apple" || registrierungsArt == "Apple ID" {
                        LabeledContent("Registrierungsart", value: "Mit Apple ID registriert")
                        LabeledContent("E-Mail-Adresse", value: gespeicherteEmail.isEmpty ? "Nicht erfasst" : gespeicherteEmail)
                    } else {
                        LabeledContent("Benutzername", value: gespeicherteEmail.isEmpty ? "Nicht erfasst" : gespeicherteEmail)
                        HStack {
                            Text("Passwort")
                            Spacer()
                            Text(angezeigtesRegistrierungsPasswort)
                                .foregroundStyle(.secondary)
                            Button {
                                registrierungsPasswortAnzeigen.toggle()
                            } label: {
                                Image(systemName: registrierungsPasswortAnzeigen ? "eye.slash" : "eye")
                                    .foregroundStyle(profilAkzentFarbe)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(registrierungsPasswortAnzeigen ? "Passwort ausblenden" : "Passwort anzeigen")
                        }
                        Button {
                            passwortAendernAnzeigen = true
                        } label: {
                            Label("Passwort ändern", systemImage: "key.fill")
                                .foregroundStyle(profilAkzentFarbe)
                        }
                    }
                    Divider()
                    Toggle("Biometrische Anmeldung verwenden", isOn: Binding(
                        get: {
                            biometrieAktiviert
                        },
                        set: { neuerWert in
                            if neuerWert {
                                pruefeUndAktiviereBiometrie()
                            } else {
                                biometrieAktiviert = false
                                biometrieFehlermeldung = ""
                                speichereProfil()
                            }
                        }
                    ))
                    .disabled(biometriePruefungLaeuft)
                    if biometriePruefungLaeuft {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Face ID wird geprüft …")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !biometrieFehlermeldung.isEmpty {
                        Text(biometrieFehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Text("Wenn aktiviert, kann die App beim Öffnen Face ID oder Touch ID für die Anmeldung verwenden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Diese Angaben stammen aus der Registrierung. Für eine produktive App sollten Passwörter nicht im Klartext gespeichert oder angezeigt werden, sondern sicher über die Keychain verwaltet werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(profilKartenFarbe)
                .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))
                Section {
                    Button {
                        showLogout = true
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) {
                        profilLoeschenBestaetigen = true
                    } label: {
                        Label("Profil löschen", systemImage: "trash.fill")
                    }
                }
                .listRowBackground(profilKartenFarbe)
                .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))

            }
            .scrollContentBackground(.hidden)
            .background(profilHintergrundFarbe.ignoresSafeArea())
            .tint(profilAkzentFarbe)
            .navigationTitle("Mein Profil")

            .navigationDestination(isPresented: $showLogout) {

                Logout()

            }

            .navigationDestination(isPresented: $showDeleted) {

                Deleted()

            }

            .alert("Profil wirklich löschen?", isPresented: $profilLoeschenBestaetigen) {

                Button("Abbrechen", role: .cancel) { }

                Button("Ja, löschen", role: .destructive) {

                    profilLoeschen()

                    showDeleted = true

                }

            } message: {

                Text("Alle Daten werden unwiderruflich gelöscht.")

            }
            .sheet(item: $dossierPDF) { dossier in

                ShareSheet(activityItems: [dossier.url])

            }
            .confirmationDialog(
                "Sollen Passwörter im PDF mitgedruckt werden?",
                isPresented: $passwortExportAuswahlAnzeigen,
                titleVisibility: .visible
            ) {
                Button("Ja, Passwörter mitdrucken") {
                    if let url = erstelleDossierPDF(passwoerterMitdrucken: true) {
                        dossierPDF = ExportiertesDossier(url: url)
                    }
                }

                Button("Nein, ohne Passwörter exportieren") {
                    if let url = erstelleDossierPDF(passwoerterMitdrucken: false) {
                        dossierPDF = ExportiertesDossier(url: url)
                    }
                }

                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Aus Sicherheitsgründen kannst du entscheiden, ob Passwörter und Abo-Logins im Dossier erscheinen sollen.")
            }

            .sheet(isPresented: $passwortAendernAnzeigen) {
                NavigationStack {
                    Form {
                        Section("Passwort ändern") {
                            SecureField("Aktuelles Passwort", text: $aktuellesPasswort)
                            SecureField("Neues Passwort", text: $neuesPasswort)
                            SecureField("Neues Passwort wiederholen", text: $neuesPasswortWiederholen)
                        }

                        if !passwortAendernFehler.isEmpty {
                            Section {
                                Text(passwortAendernFehler)
                                    .foregroundStyle(.red)
                            }
                        }

                        if !passwortAendernErfolg.isEmpty {
                            Section {
                                Text(passwortAendernErfolg)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .navigationTitle("Passwort ändern")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                schliessePasswortAendern()
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                passwortAendern()
                            }
                        }
                    }
                }
                .onAppear {
                    passwortAendernFehler = ""
                    passwortAendernErfolg = ""
                    aktuellesPasswort = ""
                    neuesPasswort = ""
                    neuesPasswortWiederholen = ""
                }
            }
            .onAppear {
                ladeOderErstelleProfil()
            }
            .onChange(of: vorname) { _, _ in speichereProfil() }
            .onChange(of: name) { _, _ in speichereProfil() }
            .onChange(of: geburtsdatum) { _, _ in
                geburtsdatumText = formatiereGeburtsdatum(geburtsdatum)
                speichereProfil()
            }
            .onChange(of: adresse) { _, _ in speichereProfil() }
            .onChange(of: hausnummer) { _, _ in speichereProfil() }
            .onChange(of: plz) { _, _ in speichereProfil() }
            .onChange(of: stadt) { _, _ in speichereProfil() }
            .onChange(of: land) { _, _ in speichereProfil() }
            .onChange(of: telefon) { _, _ in speichereProfil() }
            .onChange(of: ahvNummer) { _, _ in speichereProfil() }
            .onChange(of: email) { _, _ in speichereProfil() }
            .onChange(of: adresse) { _, neueAdresse in
                guard land == "Schweiz" else {
                    adressVorschlaege = []
                    adresseManuellBearbeitet = false
                    return
                }

                if adressVorschlagWurdeGewaehlt {
                    adressVorschlagWurdeGewaehlt = false
                    adresseManuellBearbeitet = false
                    adressVorschlaege = []
                    return
                }

                guard adresseManuellBearbeitet else {
                    adressVorschlaege = []
                    return
                }

                let bereinigteAdresse = neueAdresse.trimmingCharacters(in: .whitespacesAndNewlines)

                guard bereinigteAdresse.count >= 3 else {
                    adressVorschlaege = []
                    return
                }

                Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)

                    guard adresseManuellBearbeitet else { return }

                    guard bereinigteAdresse == adresse.trimmingCharacters(in: .whitespacesAndNewlines) else {
                        return
                    }

                    await ladePostAdressVorschlaege(fuer: bereinigteAdresse)
                }
            }
            .onChange(of: plz) { _, neuePLZ in
                guard land == "Schweiz" else { return }

                let bereinigtePLZ = neuePLZ.trimmingCharacters(in: .whitespacesAndNewlines)

                guard bereinigtePLZ.count == 4 else {
                    stadt = ""
                    return
                }

                Task {
                    await ladeSchweizerOrtFuerPLZ(bereinigtePLZ)
                }
            }
            .onChange(of: profilbildAuswahl) { _, neueAuswahl in
                Task {
                    if let data = try? await neueAuswahl?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpegData = image.jpegData(compressionQuality: 0.85) {
                        profilbildData = jpegData
                        speichereProfil()
                    }
                }
            }
        }
    }

    @State private var ahvNummer = ""

    @FocusState private var profilFokus: ProfilFokusFeld?

    private enum ProfilFokusFeld: Hashable {
        case adresse
        case hausnummer
    }

    private func formatiereGeburtsdatum(_ datum: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: datum)
    }

    private func formatiereAHVNummer(_ eingabe: String) -> String {
        let ziffern = eingabe.filter { $0.isNumber }
        let begrenzteZiffern = String(ziffern.prefix(13))

        var formatiert = ""

        for (index, zeichen) in begrenzteZiffern.enumerated() {
            if index == 3 || index == 7 || index == 11 {
                formatiert.append(".")
            }

            formatiert.append(zeichen)
        }

        return formatiert
    }

    private func datumAusGeburtsdatumText(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.isLenient = false
        return formatter.date(from: text)
    }

    private var technischesDefaultGeburtsdatum: Date {
        Calendar.current.date(from: DateComponents(year: 1978, month: 6, day: 1)) ?? Date()
    }

    private func istTechnischesDefaultGeburtsdatum(_ datum: Date) -> Bool {
        Calendar.current.isDate(datum, inSameDayAs: technischesDefaultGeburtsdatum)
    }

    private var geburtsdatumExportText: String {
        let bereinigterText = geburtsdatumText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !bereinigterText.isEmpty,
              datumAusGeburtsdatumText(bereinigterText) != nil else {
            return "Nicht erfasst"
        }

        return bereinigterText
    }

    private func verarbeiteGeburtsdatumEingabe(_ eingabe: String) {
        let ziffern = eingabe.filter { $0.isNumber }
        let begrenzteZiffern = String(ziffern.prefix(8))

        var formatiert = ""

        for (index, zeichen) in begrenzteZiffern.enumerated() {
            if index == 2 || index == 4 {
                formatiert.append(".")
            }

            formatiert.append(zeichen)
        }

        if formatiert != geburtsdatumText {
            geburtsdatumText = formatiert
            return
        }

        guard formatiert.count == 10,
              let neuesDatum = datumAusGeburtsdatumText(formatiert) else {
            return
        }

        geburtsdatum = neuesDatum
    }

    

    private func pruefeUndAktiviereBiometrie() {
        guard !biometriePruefungLaeuft else { return }

        biometriePruefungLaeuft = true
        biometrieFehlermeldung = ""

        let context = LAContext()
        context.localizedCancelTitle = "Abbrechen"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometriePruefungLaeuft = false
            biometrieAktiviert = false
            biometrieFehlermeldung = "Face ID oder Touch ID ist auf diesem Gerät nicht verfügbar oder noch nicht eingerichtet."
            speichereProfil()
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Bestätige, um die biometrische Anmeldung zu aktivieren."
        ) { success, authenticationError in
            DispatchQueue.main.async {
                biometriePruefungLaeuft = false

                if success {
                    biometrieAktiviert = true
                    biometrieFehlermeldung = ""
                    speichereProfil()
                    return
                }

                biometrieAktiviert = false
                speichereProfil()

                if let laError = authenticationError as? LAError {
                    switch laError.code {
                    case .userCancel, .systemCancel, .appCancel:
                        biometrieFehlermeldung = ""
                    case .biometryLockout:
                        biometrieFehlermeldung = "Face ID oder Touch ID ist vorübergehend gesperrt. Bitte entsperre dein Gerät und versuche es danach erneut."
                    case .biometryNotAvailable:
                        biometrieFehlermeldung = "Face ID oder Touch ID ist auf diesem Gerät nicht verfügbar."
                    case .biometryNotEnrolled:
                        biometrieFehlermeldung = "Face ID oder Touch ID ist auf diesem Gerät noch nicht eingerichtet."
                    default:
                        biometrieFehlermeldung = "Die biometrische Anmeldung konnte nicht bestätigt werden."
                    }
                } else {
                    biometrieFehlermeldung = "Die biometrische Anmeldung konnte nicht bestätigt werden."
                }
            }
        }
    }

    @AppStorage("aktiveUserID") private var aktiveUserID = ""

    private var aktivesProfil: ProfilModell? {
        if !aktiveUserID.isEmpty,
           let profil = gespeicherteProfile.first(where: { $0.userID.uuidString == aktiveUserID }) {
            return profil
        }

        return gespeicherteProfile.first
    }

    private func ladeOderErstelleProfil() {
        guard !profilGeladen else { return }
        adresseManuellBearbeitet = false

        if let vorhandenesProfil = aktivesProfil {
            vorname = vorhandenesProfil.vorname
            name = vorhandenesProfil.name
            geburtsdatum = vorhandenesProfil.geburtsdatum
            geburtsdatumText = istTechnischesDefaultGeburtsdatum(vorhandenesProfil.geburtsdatum) ? "" : formatiereGeburtsdatum(vorhandenesProfil.geburtsdatum)
            adresse = vorhandenesProfil.strasse
            hausnummer = vorhandenesProfil.hausnummer
            plz = vorhandenesProfil.plz
            stadt = vorhandenesProfil.stadt
            land = vorhandenesProfil.land
            telefon = vorhandenesProfil.telefon
            ahvNummer = vorhandenesProfil.ahvNummer
            email = vorhandenesProfil.email
            gespeicherteEmail = vorhandenesProfil.registrierungsEmail.isEmpty ? gespeicherteEmail : vorhandenesProfil.registrierungsEmail
            registrierungsArt = vorhandenesProfil.registrierungsart.isEmpty ? registrierungsArt : vorhandenesProfil.registrierungsart
            biometrieAktiviert = vorhandenesProfil.biometrieAktiviert
            if vorhandenesProfil.istVertrauensperson {
                print("Aktives Profil ist Vertrauensperson:", vorhandenesProfil.userID.uuidString)
            }
            if let gespeichertesProfilbild = vorhandenesProfil.profilbildDaten {
                profilbildData = gespeichertesProfilbild
            }
            if !vorhandenesProfil.registrierungsPasswort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                gespeichertesPasswort = vorhandenesProfil.registrierungsPasswort
            }
        } else {
            let neuesProfil = ProfilModell(
                registrierungsart: registrierungsArt,
                registrierungsEmail: gespeicherteEmail,
                registrierungsPasswort: gespeichertesPasswort,
                profilbildDaten: profilbildData
            )
            neuesProfil.biometrieAktiviert = biometrieAktiviert
            modelContext.insert(neuesProfil)
            geburtsdatumText = ""
        }

        profilGeladen = true
        adresseManuellBearbeitet = false
    }

    private func speichereProfil() {
        guard profilGeladen else { return }

        let profil: ProfilModell

        if let vorhandenesProfil = aktivesProfil {
            profil = vorhandenesProfil
        } else {
            let neuesProfil = ProfilModell()
            modelContext.insert(neuesProfil)
            profil = neuesProfil
        }

        profil.vorname = vorname
        profil.name = name
        if let gueltigesGeburtsdatum = datumAusGeburtsdatumText(geburtsdatumText) {
            profil.geburtsdatum = gueltigesGeburtsdatum
        }
        profil.strasse = adresse
        profil.hausnummer = hausnummer
        profil.plz = plz
        profil.stadt = stadt
        profil.land = land
        profil.telefon = telefon
        profil.ahvNummer = ahvNummer
        profil.email = email
        profil.registrierungsart = registrierungsArt
        profil.registrierungsEmail = gespeicherteEmail
        profil.registrierungsPasswort = gespeichertesPasswort
        profil.profilbildDaten = profilbildData
        profil.biometrieAktiviert = biometrieAktiviert
        synchronisiereAfterLifeDigitaleIdentitaet()
    }

    private func synchronisiereAfterLifeDigitaleIdentitaet(email: String? = nil, passwort: String? = nil) {
        let zielEmail = (email ?? gespeicherteEmail).trimmingCharacters(in: .whitespacesAndNewlines)
        let zielPasswort = passwort ?? gespeichertesPasswort

        guard istEmailRegistrierung, !zielEmail.isEmpty else { return }

        let aboModell: AboModell
        if let vorhandenesModell = gespeicherteAboModelle.first {
            aboModell = vorhandenesModell
        } else {
            let neuesModell = AboModell()
            modelContext.insert(neuesModell)
            aboModell = neuesModell
        }

        let eintrag = aboModell.abos.first { $0.istSystemEintrag && $0.anbieter == "AfterLife" } ?? AboEintrag()

        if !aboModell.abos.contains(where: { $0.id == eintrag.id }) {
            modelContext.insert(eintrag)
            aboModell.abos.append(eintrag)
        }

        eintrag.aboTyp = "Software / Apps"
        eintrag.anbieter = "AfterLife"
        eintrag.digitaleIdentitaetAnbieter = ""
        eintrag.bezeichnung = "AfterLife"
        eintrag.benutzername = zielEmail
        eintrag.passwort = zielPasswort
        eintrag.istAktiv = true
        eintrag.istSystemEintrag = true
        eintrag.aktualisiertAm = Date()
        aboModell.aktualisiertAm = Date()

        do {
            try modelContext.save()
        } catch {
            print("AfterLife Login konnte nicht synchronisiert werden: \(error.localizedDescription)")
        }
    }

    private func schliessePasswortAendern() {
        passwortAendernAnzeigen = false
        aktuellesPasswort = ""
        neuesPasswort = ""
        neuesPasswortWiederholen = ""
        passwortAendernFehler = ""
        passwortAendernErfolg = ""
        registrierungsPasswortAnzeigen = false
    }

    private func passwortAendern() {
        passwortAendernFehler = ""
        passwortAendernErfolg = ""

        guard istEmailRegistrierung else {
            passwortAendernFehler = "Das Passwort kann nur bei einer Registrierung mit E-Mail geändert werden."
            return
        }

        let bereinigteEmail = gespeicherteEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !bereinigteEmail.isEmpty else {
            passwortAendernFehler = "Es ist keine Registrierungs-E-Mail vorhanden."
            return
        }

        guard !aktuellesPasswort.isEmpty, !neuesPasswort.isEmpty, !neuesPasswortWiederholen.isEmpty else {
            passwortAendernFehler = "Bitte alle Passwortfelder ausfüllen."
            return
        }

        guard neuesPasswort == neuesPasswortWiederholen else {
            passwortAendernFehler = "Das neue Passwort stimmt nicht mit der Wiederholung überein."
            return
        }

        guard neuesPasswort.count >= 6 else {
            passwortAendernFehler = "Das neue Passwort muss mindestens 6 Zeichen lang sein."
            return
        }

        do {
            let gespeichertesKeychainPasswort = try KeychainHelper.shared.read(
                service: "AfterLife.Login",
                account: bereinigteEmail
            )

            guard aktuellesPasswort == gespeichertesKeychainPasswort || aktuellesPasswort == gespeichertesPasswort else {
                passwortAendernFehler = "Das aktuelle Passwort ist nicht korrekt."
                return
            }

            try KeychainHelper.shared.save(
                neuesPasswort,
                service: "AfterLife.Login",
                account: bereinigteEmail
            )

            gespeichertesPasswort = neuesPasswort

            if let profil = aktivesProfil {
                profil.registrierungsPasswort = neuesPasswort
                profil.registrierungsEmail = bereinigteEmail
                profil.registrierungsart = "E-Mail"
                try modelContext.save()
            }

            synchronisiereAfterLifeDigitaleIdentitaet(email: bereinigteEmail, passwort: neuesPasswort)

            passwortAendernErfolg = "Passwort wurde geändert."

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                schliessePasswortAendern()
            }
        } catch {
            passwortAendernFehler = "Passwort konnte nicht geändert werden."
        }
    }

    // MARK: - Schweizer Post Adressservice
    //
    // Die App spricht niemals direkt mit der Post API.
    // Stattdessen werden alle Anfragen über den Vercel Proxy geleitet:
    //
    // /api/autocomplete
    // → liefert Strassenvorschläge
    //
    // /api/building-verification
    // → verifiziert Strasse, Hausnummer, PLZ und Ort
    //
    // Die Zugangsdaten der Post liegen ausschliesslich als
    // Vercel Environment Variables:
    //
    // POST_API_USERNAME (gem. Geschäfts-Account rxxx.exxx.@
    // POST_API_PASSWORD
    //
    // Falls die Post Zugangsdaten geändert werden müssen,
    // nur die Vercel Environment Variables anpassen.
    // In der iOS App sind keine Post Zugangsdaten gespeichert.
    
    private func postAPIRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    @MainActor
    private func ladePostAdressVorschlaege(fuer suchbegriff: String) async {
        guard !adressSucheLaeuft else { return }

        adressSucheLaeuft = true
        defer { adressSucheLaeuft = false }

        var components = URLComponents(string: postAutocompleteURL)
        components?.queryItems = [
            URLQueryItem(name: "streetname", value: suchbegriff)
        ]

        guard let url = components?.url else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: postAPIRequest(url: url))

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                adressVorschlaege = []
                return
            }

            let antwort = try JSONDecoder().decode(PostAutocompleteAntwort.self, from: data)
            adressVorschlaege = Array(antwort.vorschlaege.prefix(25))
        } catch {
            adressVorschlaege = []
            print("Post Adressvorschläge konnten nicht geladen werden: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func verifizierePostAdresse(_ vorschlag: PostAdressVorschlag) async {
        var components = URLComponents(string: postBuildingVerificationURL)
        components?.queryItems = [
            URLQueryItem(name: "streetname", value: vorschlag.streetName),
            URLQueryItem(name: "houseno", value: vorschlag.houseNo),
            URLQueryItem(name: "housenoaddition", value: vorschlag.houseNoAddition),
            URLQueryItem(name: "zipcode", value: vorschlag.zipCode),
            URLQueryItem(name: "townname", value: vorschlag.townName)
        ]

        guard let url = components?.url else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: postAPIRequest(url: url))

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }

            let antwort = try JSONDecoder().decode(PostBuildingVerificationAntwort.self, from: data)
            guard let verifizierteAdresse = antwort.verifizierteAdresse else { return }

            adressVorschlagWurdeGewaehlt = true
            adresseManuellBearbeitet = false
            adresse = verifizierteAdresse.streetName
            hausnummer = verifizierteAdresse.vollstaendigeHausnummer
            plz = verifizierteAdresse.zipCode
            stadt = verifizierteAdresse.townName
            speichereProfil()
            profilFokus = .hausnummer
        } catch {
            print("Post Adresse konnte nicht verifiziert werden: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func ladeSchweizerOrtFuerPLZ(_ postleitzahl: String) async {
        guard !plzSucheLaeuft else { return }

        plzSucheLaeuft = true
        defer { plzSucheLaeuft = false }

        var components = URLComponents(string: "https://openplzapi.org/ch/Localities")
        components?.queryItems = [
            URLQueryItem(name: "postalCode", value: postleitzahl),
            URLQueryItem(name: "pageSize", value: "1")
        ]

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.setValue("text/json", forHTTPHeaderField: "accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }

            let orte = try JSONDecoder().decode([SchweizerOrt].self, from: data)

            if let ersterOrt = orte.first {
                stadt = ersterOrt.name
            }
        } catch {
            print("PLZ konnte nicht automatisch gefunden werden: \(error.localizedDescription)")
        }
    }

    private func profilLoeschen() {

        vorname = ""

        name = ""

        adresse = ""
        hausnummer = ""
        adressVorschlaege = []
        adressSucheLaeuft = false
        adressVorschlagWurdeGewaehlt = false
        adresseManuellBearbeitet = false
        plz = ""
        stadt = ""

        land = "Schweiz"

        telefon = ""

        ahvNummer = ""

        email = ""

        profilbildData = nil

        profilbildAuswahl = nil

        gespeichertesPasswort = ""
        aktuellesPasswort = ""
        neuesPasswort = ""
        neuesPasswortWiederholen = ""
        passwortAendernFehler = ""
        passwortAendernErfolg = ""
        registrierungsPasswortAnzeigen = false

        geburtsdatum = technischesDefaultGeburtsdatum
        geburtsdatumText = ""

        gespeicherteAboModelle.forEach { aboModell in
            aboModell.abos
                .filter { $0.istSystemEintrag && $0.anbieter == "AfterLife" }
                .forEach { systemEintrag in
                    if let index = aboModell.abos.firstIndex(where: { $0.id == systemEintrag.id }) {
                        aboModell.abos.remove(at: index)
                    }
                    modelContext.delete(systemEintrag)
                }
        }

        gespeicherteProfile.forEach { profil in
            modelContext.delete(profil)
        }

        profilGeladen = false
    }

    private func erstelleDossierPDF(passwoerterMitdrucken: Bool) -> URL? {

        let pdfMetaData = [

            kCGPDFContextCreator: "AfterLife",

            kCGPDFContextAuthor: "AfterLife App",

            kCGPDFContextTitle: "Persönliches Dossier"

        ]

        let format = UIGraphicsPDFRendererFormat()

        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 595.2

        let pageHeight = 841.8

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = "AfterLife_Dossier_\(Int(Date().timeIntervalSince1970)).pdf"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let dateFormatter = DateFormatter()

        dateFormatter.locale = Locale(identifier: "de_CH")

        dateFormatter.dateStyle = .long

        dateFormatter.timeStyle = .none

        do {

            try renderer.writePDF(to: url) { context in

                var yPosition: CGFloat = 48

                func beginPDFPage() {
                    context.beginPage()
                    yPosition = 48
                }

                beginPDFPage()

                func drawProfileImageIfAvailable() {

                    guard let profilbildData,
                          let uiImage = UIImage(data: profilbildData) else {
                        return
                    }

                    let imageSize: CGFloat = 82
                    let imageRect = CGRect(x: pageWidth - imageSize - 48, y: 48, width: imageSize, height: imageSize)

                    context.cgContext.saveGState()

                    let circlePath = UIBezierPath(ovalIn: imageRect)
                    circlePath.addClip()

                    let imageAspect = uiImage.size.width / uiImage.size.height
                    let rectAspect = imageRect.width / imageRect.height

                    var drawRect = imageRect

                    if imageAspect > rectAspect {
                        let scaledWidth = imageRect.height * imageAspect
                        drawRect = CGRect(
                            x: imageRect.midX - scaledWidth / 2,
                            y: imageRect.minY,
                            width: scaledWidth,
                            height: imageRect.height
                        )
                    } else {
                        let scaledHeight = imageRect.width / imageAspect
                        drawRect = CGRect(
                            x: imageRect.minX,
                            y: imageRect.midY - scaledHeight / 2,
                            width: imageRect.width,
                            height: scaledHeight
                        )
                    }

                    uiImage.draw(in: drawRect)

                    context.cgContext.restoreGState()

                    context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
                    context.cgContext.setLineWidth(1)
                    context.cgContext.strokeEllipse(in: imageRect)
                }

                func fittingSubstring(
                    from text: String,
                    attributes: [NSAttributedString.Key: Any],
                    width: CGFloat,
                    maxHeight: CGFloat
                ) -> String {
                    guard !text.isEmpty else { return "" }

                    let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
                    var result = ""

                    for word in words {
                        let candidate = result.isEmpty ? word : result + " " + word
                        let attributedCandidate = NSAttributedString(string: candidate, attributes: attributes)
                        let rect = attributedCandidate.boundingRect(
                            with: CGSize(width: width, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil
                        )

                        if ceil(rect.height) > maxHeight {
                            break
                        }

                        result = candidate
                    }

                    if result.isEmpty {
                        var fallback = ""

                        for character in text {
                            let candidate = fallback + String(character)
                            let attributedCandidate = NSAttributedString(string: candidate, attributes: attributes)
                            let rect = attributedCandidate.boundingRect(
                                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                context: nil
                            )

                            if ceil(rect.height) > maxHeight {
                                break
                            }

                            fallback = candidate
                        }

                        return fallback
                    }

                    return result
                }

                func drawText(_ text: String, font: UIFont = .systemFont(ofSize: 13), color: UIColor = .label, spacing: CGFloat = 24) {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineBreakMode = .byWordWrapping

                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraphStyle
                    ]

                    let maxTextWidth = pageWidth - 96
                    let availableHeight = pageHeight - yPosition - 48
                    let attributedText = NSAttributedString(string: text, attributes: attributes)
                    let boundingRect = attributedText.boundingRect(
                        with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )

                    let textHeight = ceil(boundingRect.height)
                    let requiredHeight = textHeight + spacing

                    if requiredHeight <= availableHeight {
                        attributedText.draw(in: CGRect(x: 48, y: yPosition, width: maxTextWidth, height: textHeight))
                        yPosition += requiredHeight
                        return
                    }

                    if textHeight <= pageHeight - 96 {
                        beginPDFPage()
                        attributedText.draw(in: CGRect(x: 48, y: yPosition, width: maxTextWidth, height: textHeight))
                        yPosition += requiredHeight
                        return
                    }

                    var remainingText = text

                    while !remainingText.isEmpty {
                        let remainingAvailableHeight = pageHeight - yPosition - 48

                        if remainingAvailableHeight < 60 {
                            beginPDFPage()
                        }

                        let fittingText = fittingSubstring(
                            from: remainingText,
                            attributes: attributes,
                            width: maxTextWidth,
                            maxHeight: pageHeight - yPosition - 48
                        )

                        guard !fittingText.isEmpty else {
                            beginPDFPage()
                            continue
                        }

                        let fittingAttributedText = NSAttributedString(string: fittingText, attributes: attributes)
                        let fittingRect = fittingAttributedText.boundingRect(
                            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil
                        )

                        fittingAttributedText.draw(in: CGRect(x: 48, y: yPosition, width: maxTextWidth, height: ceil(fittingRect.height)))
                        yPosition += ceil(fittingRect.height) + spacing

                        remainingText.removeFirst(fittingText.count)
                        remainingText = remainingText.trimmingCharacters(in: .whitespacesAndNewlines)

                        if !remainingText.isEmpty {
                            beginPDFPage()
                        }
                    }
                }

                func drawIndentedText(
                    _ text: String,
                    font: UIFont = .systemFont(ofSize: 12),
                    color: UIColor = .label,
                    spacing: CGFloat = 4
                ) {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineBreakMode = .byWordWrapping

                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraphStyle
                    ]

                    let xPosition: CGFloat = 76
                    let maxTextWidth = pageWidth - xPosition - 48
                    let attributedText = NSAttributedString(string: text, attributes: attributes)

                    let boundingRect = attributedText.boundingRect(
                        with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )

                    let textHeight = ceil(boundingRect.height)
                    let requiredHeight = textHeight + spacing

                    if requiredHeight <= pageHeight - yPosition - 48 {
                        attributedText.draw(in: CGRect(x: xPosition, y: yPosition, width: maxTextWidth, height: textHeight))
                        yPosition += requiredHeight
                        return
                    }

                    if textHeight <= pageHeight - 96 {
                        beginPDFPage()
                        attributedText.draw(in: CGRect(x: xPosition, y: yPosition, width: maxTextWidth, height: textHeight))
                        yPosition += requiredHeight
                        return
                    }

                    var remainingText = text

                    while !remainingText.isEmpty {
                        if pageHeight - yPosition - 48 < 60 {
                            beginPDFPage()
                        }

                        let fittingText = fittingSubstring(
                            from: remainingText,
                            attributes: attributes,
                            width: maxTextWidth,
                            maxHeight: pageHeight - yPosition - 48
                        )

                        guard !fittingText.isEmpty else {
                            beginPDFPage()
                            continue
                        }

                        let fittingAttributedText = NSAttributedString(string: fittingText, attributes: attributes)
                        let fittingRect = fittingAttributedText.boundingRect(
                            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil
                        )

                        fittingAttributedText.draw(in: CGRect(x: xPosition, y: yPosition, width: maxTextWidth, height: ceil(fittingRect.height)))
                        yPosition += ceil(fittingRect.height) + spacing

                        remainingText.removeFirst(fittingText.count)
                        remainingText = remainingText.trimmingCharacters(in: .whitespacesAndNewlines)

                        if !remainingText.isEmpty {
                            beginPDFPage()
                        }
                    }
                }

                func drawField(_ label: String, _ value: String) {
                    let cleanValue = value.isEmpty ? "Nicht erfasst" : value
                    beginNewPageIfNeeded(minimumSpace: 36)
                    drawIndentedText("\(label): \(cleanValue)", font: .systemFont(ofSize: 12), spacing: 4)
                }

                func drawSectionTitle(_ title: String) {
                    beginNewPageIfNeeded(minimumSpace: 70)
                    drawText(title, font: .boldSystemFont(ofSize: 18), spacing: 16)
                }

                func beginNewPageIfNeeded(minimumSpace: CGFloat = 90) {
                    if yPosition > pageHeight - minimumSpace {
                        beginPDFPage()
                    }
                }

                func drawDivider() {
                    beginNewPageIfNeeded(minimumSpace: 36)
                    let lineY = yPosition
                    context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
                    context.cgContext.setLineWidth(0.8)
                    context.cgContext.move(to: CGPoint(x: 48, y: lineY))
                    context.cgContext.addLine(to: CGPoint(x: pageWidth - 48, y: lineY))
                    context.cgContext.strokePath()
                    yPosition += 18
                }

                func drawSubsectionTitle(_ title: String, color: UIColor = .label) {
                    beginNewPageIfNeeded(minimumSpace: 58)
                    drawText(title, font: .boldSystemFont(ofSize: 14), color: color, spacing: 6)
                }

                func drawEmpty(_ text: String = "Keine Angaben erfasst.") {
                    drawIndentedText(text, font: .italicSystemFont(ofSize: 12), color: .secondaryLabel, spacing: 8)
                }

                func drawFieldIfNotEmpty(_ label: String, _ value: String) {
                    let bereinigt = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !bereinigt.isEmpty else { return }
                    guard !bereinigt.contains("_SwiftData") else { return }
                    guard !bereinigt.contains("SwiftData") else { return }
                    drawField(label, bereinigt)
                }

                func readableLabel(_ raw: String) -> String {
                    raw
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "([a-zäöü])([A-ZÄÖÜ])", with: "$1 $2", options: .regularExpression)
                        .capitalized
                }

                func readableValue(_ value: Any) -> String {
                    if let string = value as? String {
                        return string
                    }

                    if let bool = value as? Bool {
                        return bool ? "Ja" : "Nein"
                    }

                    if let date = value as? Date {
                        return dateFormatter.string(from: date)
                    }

                    if let double = value as? Double {
                        return double == 0 ? "" : double.formatted(.number.precision(.fractionLength(0...2)))
                    }

                    if let int = value as? Int {
                        return int == 0 ? "" : String(int)
                    }

                    if let uuid = value as? UUID {
                        return uuid.uuidString
                    }

                    let mirror = Mirror(reflecting: value)
                    if mirror.displayStyle == .optional {
                        guard let optionalValue = mirror.children.first?.value else { return "" }
                        return readableValue(optionalValue)
                    }

                    let text = String(describing: value)
                    if text == "nil" { return "" }
                    if text.contains("_SwiftData") { return "" }
                    if text.contains("SwiftData") { return "" }
                    if text.contains("PersistentIdentifier") { return "" }
                    if text.contains("ObservationRegistrar") { return "" }
                    if text.contains("BackingData") { return "" }
                    return text
                }

                func drawSafeModelObject(_ object: Any, title: String) {
                    beginNewPageIfNeeded(minimumSpace: 90)
                    drawSubsectionTitle(title)

                    let ignoredLabels: Set<String> = [
                        "id",
                        "persistentModelID",
                        "_$backingData",
                        "_$observationRegistrar",
                        "$backingData",
                        "$observationRegistrar"
                    ]

                    var hasContent = false

                    for child in Mirror(reflecting: object).children {
                        guard let label = child.label else { continue }
                        guard !ignoredLabels.contains(label) else { continue }
                        guard !label.contains("backing") else { continue }
                        guard !label.contains("observation") else { continue }

                        let value = readableValue(child.value)
                        let bereinigt = value.trimmingCharacters(in: .whitespacesAndNewlines)

                        guard !bereinigt.isEmpty else { continue }
                        guard !bereinigt.contains("_SwiftData") else { continue }
                        guard !bereinigt.contains("SwiftData") else { continue }

                        hasContent = true
                        drawField(readableLabel(label), bereinigt)
                    }

                    if !hasContent {
                        drawEmpty("Keine auslesbaren Angaben vorhanden.")
                    }

                    yPosition += 8
                }

                func drawWuensche() {
                    drawDivider()
                    drawSectionTitle("Meine Wünsche")

                    guard !gespeicherteWuensche.isEmpty else {
                        drawEmpty()
                        return
                    }

                    for (index, wunsch) in gespeicherteWuensche.enumerated() {
                        beginNewPageIfNeeded(minimumSpace: 160)
                        drawSubsectionTitle(gespeicherteWuensche.count == 1 ? "Meine Wünsche" : "Wünsche \(index + 1)")

                        drawField("Ich habe besondere Wünsche", wunsch.hatWuensche ? "Ja" : "Nein")

                        drawSubsectionTitle("Beisetzung")
                        drawField("Beisetzungsart", wunsch.beisetzungsArt)
                        drawField("Hinweis zur Beisetzung", wunsch.beisetzungHinweis)
                        drawField("Sonstige Bemerkungen", wunsch.sonstigeBemerkungen)

                        drawSubsectionTitle("Musik")
                        drawField("Besondere Musik", wunsch.besondereMusik ? "Ja" : "Nein")
                        drawField("Musikwunsch", wunsch.musikWunsch)

                        drawSubsectionTitle("Zeremonie")
                        drawField("Zeremonie gewünscht", wunsch.zeremonieGewuenscht ? "Ja" : "Nein")
                        drawField("Zeremonie Details", wunsch.zeremonieDetails)
                        drawField("Zeremonie organisiert", wunsch.zeremonieOrganisiert ? "Ja" : "Nein")
                        drawField("Finanziell abgesichert", wunsch.zeremonieFinanziellAbgesichert ? "Ja" : "Nein")

                        let kontakteZuWuenschen = gespeicherteHinterbliebene
                            .filter { $0.quelle == "WuenscheView" || $0.bemerkungen == "Quelle: WuenscheView" }
                            .sorted { $0.erstelltAm < $1.erstelltAm }

                        drawSubsectionTitle("Personen informieren / einladen")

                        if kontakteZuWuenschen.isEmpty {
                            drawEmpty()
                        } else {
                            for (kontaktIndex, kontakt) in kontakteZuWuenschen.enumerated() {
                                beginNewPageIfNeeded(minimumSpace: 120)
                                let kontaktTitel = [kontakt.vorname, kontakt.name]
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " ")

                                drawSubsectionTitle(kontaktTitel.isEmpty ? "Kontakt \(kontaktIndex + 1)" : kontaktTitel)
                                drawFieldIfNotEmpty("Vorname", kontakt.vorname)
                                drawFieldIfNotEmpty("Name", kontakt.name)
                                drawField("Informieren", kontakt.sollInformiertWerden ? "Ja" : "Nein")
                                drawField("Einladen", kontakt.darfDokumenteErhalten ? "Ja" : "Nein")
                                yPosition += 8
                            }
                        }

                        drawSubsectionTitle("Haustiere")
                        drawField("Ich habe Haustiere", wunsch.hatHaustiere ? "Ja" : "Nein")

                        if wunsch.hatHaustiere,
                           let haustiereData = wunsch.haustiereData,
                           let haustiere = try? JSONDecoder().decode([PDFHaustierEintrag].self, from: haustiereData),
                           !haustiere.isEmpty {
                            for (haustierIndex, haustier) in haustiere.enumerated() {
                                beginNewPageIfNeeded(minimumSpace: 110)
                                let titel = haustier.anzeigename.isEmpty ? "Haustier \(haustierIndex + 1)" : haustier.anzeigename
                                drawSubsectionTitle(titel)
                                drawField("Art", haustier.art)
                                drawFieldIfNotEmpty("Name", haustier.name)
                                drawFieldIfNotEmpty("Tierarzt", haustier.tierarzt)
                                drawFieldIfNotEmpty("Bemerkungen", haustier.bemerkungen)
                                yPosition += 8
                            }
                        } else if wunsch.hatHaustiere {
                            drawEmpty("Keine Haustiere erfasst.")
                        }

                        drawSubsectionTitle("Letzte Worte")
                        drawField("Ich möchte noch etwas sagen", wunsch.moechteNochEtwasSagen ? "Ja" : "Nein")
                        drawField("Letzte Botschaft", wunsch.letzteBotschaft)

                        drawSubsectionTitle("Nachruf")
                        drawField("Nachruf gewünscht", wunsch.nachrufGewuenscht ? "Ja" : "Nein")
                        drawField("Nachruf Text", wunsch.nachrufText)
                        drawField("Nachruf Bild", wunsch.nachrufBildDateiName)

                        drawSubsectionTitle("Testament")
                        drawField("Testament vorhanden", wunsch.testamentVorhanden ? "Ja" : "Nein")
                        drawField("Dateiname", wunsch.testamentDateiName)
                        if let datum = wunsch.testamentHochgeladenAm {
                            drawField("Hochgeladen am", dateFormatter.string(from: datum))
                        }
                        drawField("Erinnerung aktiv", wunsch.testamentErinnerungAktiv ? "Ja" : "Nein")
                        if let datum = wunsch.testamentErinnerungAm {
                            drawField("Erinnerung am", dateFormatter.string(from: datum))
                        }

                        drawSubsectionTitle("Patientenverfügung")
                        drawField("Patientenverfügung vorhanden", wunsch.patientenverfuegungVorhanden ? "Ja" : "Nein")
                        drawField("Dateiname", wunsch.patientenverfuegungDateiName)
                        if let datum = wunsch.patientenverfuegungHochgeladenAm {
                            drawField("Hochgeladen am", dateFormatter.string(from: datum))
                        }
                        drawField("Erinnerung aktiv", wunsch.patientenverfuegungErinnerungAktiv ? "Ja" : "Nein")
                        if let datum = wunsch.patientenverfuegungErinnerungAm {
                            drawField("Erinnerung am", dateFormatter.string(from: datum))
                        }

                        drawSubsectionTitle("Vorsorgeauftrag")
                        drawField("Vorsorgeauftrag vorhanden", wunsch.vorsorgeauftragVorhanden ? "Ja" : "Nein")
                        drawField("Dateiname", wunsch.vorsorgeauftragDateiName)
                        if let datum = wunsch.vorsorgeauftragHochgeladenAm {
                            drawField("Hochgeladen am", dateFormatter.string(from: datum))
                        }
                        drawField("Erinnerung aktiv", wunsch.vorsorgeauftragErinnerungAktiv ? "Ja" : "Nein")
                        if let datum = wunsch.vorsorgeauftragErinnerungAm {
                            drawField("Erinnerung am", dateFormatter.string(from: datum))
                        }

                        drawSubsectionTitle("Sterbebegleitung")
                        drawField("Sterbebegleitung gewünscht", wunsch.sterbebegleitungGewuenscht ? "Ja" : "Nein")
                        drawField("Dateiname", wunsch.sterbebegleitungDateiName)
                        if let datum = wunsch.sterbebegleitungHochgeladenAm {
                            drawField("Hochgeladen am", dateFormatter.string(from: datum))
                        }
                        drawField("Erinnerung aktiv", wunsch.sterbebegleitungErinnerungAktiv ? "Ja" : "Nein")
                        if let datum = wunsch.sterbebegleitungErinnerungAm {
                            drawField("Erinnerung am", dateFormatter.string(from: datum))
                        }

                        drawSubsectionTitle("Schwere Erkrankung / Lebensqualität")
                        drawField("Schwere Erkrankung vorhanden", wunsch.schwereErkrankungVorhanden ? "Ja" : "Nein")
                        drawField("Art der Erkrankung", wunsch.schwereErkrankungArt)
                        drawField("Mir ist wichtig", wunsch.mirIstWichtig)
                        drawField("Regelmässig beurteilen", wunsch.regelmaessigBeurteilen ? "Ja" : "Nein")

                        yPosition += 8
                    }
                }

                func drawFormattedAmount(_ label: String, amount: Double, currency: String) {
                    guard amount != 0 else { return }
                    let formattedAmount = amount.formatted(.number.precision(.fractionLength(0...2)))
                    drawField(label, "\(formattedAmount) \(currency)")
                }

                func drawFinanzen() {
                    drawDivider()
                    drawSectionTitle("Finanzen")

                    if gespeicherteBankkonten.isEmpty && gespeicherteSchulden.isEmpty && gespeicherteVersicherungen.isEmpty && gespeicherteLiegenschaften.isEmpty && gespeicherteWertsachen.isEmpty {
                        drawEmpty()
                        return
                    }

                    if !gespeicherteBankkonten.isEmpty {
                        drawSubsectionTitle("Konten & Vermögen")

                        for (index, bankkonto) in gespeicherteBankkonten.sorted(by: { $0.erstelltAm < $1.erstelltAm }).enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 120)
                            drawSubsectionTitle("Konto \(index + 1)")
                            drawFieldIfNotEmpty("Art des Kontos", bankkonto.kontoArt)
                            drawFieldIfNotEmpty("IBAN / Konto-Nr.", bankkonto.iban)
                            drawFieldIfNotEmpty("Name der Bank", bankkonto.bankname)
                            drawFieldIfNotEmpty("Adresse der Bank", bankkonto.bankAdresse)
                            drawFieldIfNotEmpty("Berater", bankkonto.berater)
                            drawFormattedAmount("Vermögenswerte", amount: bankkonto.vermoegenswert, currency: bankkonto.waehrung)
                            yPosition += 8
                        }
                    }

                    if !gespeicherteSchulden.isEmpty {
                        drawSubsectionTitle("Schulden")

                        for (index, schuld) in gespeicherteSchulden.sorted(by: { $0.erstelltAm < $1.erstelltAm }).enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 100)
                            drawSubsectionTitle("Schuld \(index + 1)")
                            drawFieldIfNotEmpty("Art der Schuld", schuld.art)
                            drawFieldIfNotEmpty("Name der Bank oder Person", schuld.glaeubiger)
                            drawFormattedAmount("Betrag", amount: schuld.betrag, currency: schuld.waehrung)
                            yPosition += 8
                        }
                    }

                    if !gespeicherteVersicherungen.isEmpty {
                        drawSubsectionTitle("Versicherungen")

                        for (index, versicherung) in gespeicherteVersicherungen.sorted(by: { $0.erstelltAm < $1.erstelltAm }).enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 120)
                            drawSubsectionTitle("Versicherung \(index + 1)")
                            drawFieldIfNotEmpty("Art der Versicherung", versicherung.art)
                            drawFieldIfNotEmpty("Name der Versicherung", versicherung.anbieter)
                            drawFieldIfNotEmpty("Police-Nr. / Vertrags-Nr.", versicherung.policenNummer)
                            drawFormattedAmount("Betrag / Versicherungssumme", amount: versicherung.praemie, currency: versicherung.waehrung)
                            drawFieldIfNotEmpty("Bemerkungen", versicherung.bemerkungen)
                            yPosition += 8
                        }
                    }

                    if !gespeicherteLiegenschaften.isEmpty {
                        drawSubsectionTitle("Liegenschaften")

                        for (index, liegenschaft) in gespeicherteLiegenschaften.sorted(by: { $0.erstelltAm < $1.erstelltAm }).enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 100)
                            drawSubsectionTitle("Liegenschaft \(index + 1)")
                            drawFieldIfNotEmpty("Art", liegenschaft.art)
                            drawFormattedAmount("Verkehrswert", amount: liegenschaft.verkehrswert, currency: liegenschaft.waehrung)
                            drawFormattedAmount("Eigenmietwert", amount: liegenschaft.eigenmietwert, currency: liegenschaft.waehrung)
                            yPosition += 8
                        }
                    }

                    if !gespeicherteWertsachen.isEmpty {
                        drawSubsectionTitle("Wertsachen")

                        for (index, wertsache) in gespeicherteWertsachen.sorted(by: { $0.erstelltAm < $1.erstelltAm }).enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 90)
                            drawSubsectionTitle("Wertsache \(index + 1)")
                            drawFieldIfNotEmpty("Art", wertsache.art)
                            drawFormattedAmount("Betrag", amount: wertsache.betrag, currency: wertsache.waehrung)
                            yPosition += 8
                        }
                    }
                }

                func drawHinterbliebene() {
                    drawDivider()
                    drawSectionTitle("Hinterbliebene")

                    guard !gespeicherteHinterbliebene.isEmpty else {
                        drawEmpty()
                        return
                    }

                    for (index, kontakt) in gespeicherteHinterbliebene.enumerated() {
                        beginNewPageIfNeeded(minimumSpace: 120)

                        let kontaktTitel = [kontakt.vorname, kontakt.name]
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")

                        let stammtAusWuenschen = kontakt.quelle == "WuenscheView" || kontakt.bemerkungen == "Quelle: WuenscheView"
                        let istRelevantFuerWuensche = stammtAusWuenschen && (kontakt.sollInformiertWerden || kontakt.darfDokumenteErhalten)

                        drawSubsectionTitle(
                            kontaktTitel.isEmpty ? "Kontakt \(index + 1)" : kontaktTitel,
                            color: istRelevantFuerWuensche ? .systemGreen : .label
                        )

                        drawFieldIfNotEmpty("Vorname", kontakt.vorname)
                        drawFieldIfNotEmpty("Name", kontakt.name)
                        drawFieldIfNotEmpty("Beziehung", kontakt.beziehung)
                        drawFieldIfNotEmpty("Telefon", kontakt.telefon)
                        drawFieldIfNotEmpty("E-Mail", kontakt.email)
                        drawFieldIfNotEmpty("Adresse", kontakt.adresse)

                        if stammtAusWuenschen && kontakt.sollInformiertWerden {
                            drawField("Informieren", "Ja")
                        }

                        if stammtAusWuenschen && kontakt.darfDokumenteErhalten {
                            drawField("Einladen", "Ja")
                        }

                        yPosition += 8
                    }
                }

                func drawDokumente() {
                    drawDivider()
                    drawSectionTitle("Dokumente")

                    guard !gespeicherteSteuerdokumente.isEmpty else {
                        drawEmpty()
                        return
                    }

                    for (index, dokument) in gespeicherteSteuerdokumente.sorted(by: { $0.hochgeladenAm < $1.hochgeladenAm }).enumerated() {
                        beginNewPageIfNeeded(minimumSpace: 90)
                        drawSubsectionTitle(gespeicherteSteuerdokumente.count == 1 ? "Steuerdokument" : "Steuerdokument \(index + 1)")
                        drawFieldIfNotEmpty("Dateiname", dokument.dateiName)
                        drawFieldIfNotEmpty("Dokumentpfad", dokument.dokumentPfad)
                        drawField("Hochgeladen am", dateFormatter.string(from: dokument.hochgeladenAm))
                        yPosition += 8
                    }
                }

                drawProfileImageIfAvailable()

                drawText("Persönliches AfterLife Dossier", font: .boldSystemFont(ofSize: 24), spacing: 12)

                drawText("Erstellt am \(dateFormatter.string(from: Date()))", font: .systemFont(ofSize: 12), color: .secondaryLabel, spacing: 28)

                drawSectionTitle("Persönliche Angaben")

                drawField("Vorname", vorname)

                drawField("Name", name)

                drawField("Geburtsdatum", geburtsdatumExportText)

                drawField("AHV-Nr.", ahvNummer)

                let vollstaendigeAdresse = [adresse, hausnummer]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                drawField("Adresse", vollstaendigeAdresse)
                drawField("Strasse", adresse)
                drawField("Hausnummer", hausnummer)
                drawField("PLZ", plz)
                drawField("Stadt", stadt)

                drawField("Land", land)

                drawField("Telefon", telefon)

                drawField("E-Mail", email)

                yPosition += 14

                drawSectionTitle("Zugangsdaten")

                if registrierungsArt == "Google" {
                    drawField("Registrierungsart", "Mit Google registriert")
                    drawField("E-Mail-Adresse", gespeicherteEmail)
                } else if registrierungsArt == "Apple" || registrierungsArt == "Apple ID" {
                    drawField("Registrierungsart", "Mit Apple ID registriert")
                    drawField("E-Mail-Adresse", gespeicherteEmail)
                } else {
                    drawField("Benutzername", gespeicherteEmail)
                    if passwoerterMitdrucken {
                        drawField("Passwort", gespeichertesPasswort)
                    } else {
                        drawField("Passwort", "Nicht mitgedruckt")
                    }
                }

                drawWuensche()
                drawFinanzen()
                drawHinterbliebene()
                drawDokumente()

                func aboTitelFuerExport(_ abo: AboEintrag, fallbackIndex: Int) -> String {
                    let bezeichnung = abo.bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines)
                    let unternehmen = abo.unternehmen.trimmingCharacters(in: .whitespacesAndNewlines)
                    let aboArt = abo.aboArt.trimmingCharacters(in: .whitespacesAndNewlines)
                    let anbieter = abo.anbieter.trimmingCharacters(in: .whitespacesAndNewlines)
                    let streamingAnbieter = abo.streamingAnbieter.trimmingCharacters(in: .whitespacesAndNewlines)
                    let socialMediaPlattform = abo.socialMediaPlattform.trimmingCharacters(in: .whitespacesAndNewlines)
                    let digitaleIdentitaetAnbieter = abo.digitaleIdentitaetAnbieter.trimmingCharacters(in: .whitespacesAndNewlines)
                    let emailAnbieter = abo.emailAnbieter.trimmingCharacters(in: .whitespacesAndNewlines)
                    let geraeteArt = abo.geraeteArt.trimmingCharacters(in: .whitespacesAndNewlines)
                    let geraeteBezeichnung = abo.geraeteBezeichnung.trimmingCharacters(in: .whitespacesAndNewlines)

                    if (abo.aboTyp == "Meine Geräte" || abo.aboTyp == "Mein Mobile Telefon") && !geraeteBezeichnung.isEmpty {
                        return geraeteBezeichnung
                    }

                    if (abo.aboTyp == "Meine Geräte" || abo.aboTyp == "Mein Mobile Telefon") && !bezeichnung.isEmpty && bezeichnung != "Bitte wählen" {
                        return bezeichnung
                    }

                    if (abo.aboTyp == "Meine Geräte" || abo.aboTyp == "Mein Mobile Telefon") && !geraeteArt.isEmpty && geraeteArt != "Bitte wählen" {
                        return geraeteArt
                    }

                    if abo.aboTyp == "Social Media" && !socialMediaPlattform.isEmpty && socialMediaPlattform != "Bitte wählen" {
                        return socialMediaPlattform
                    }

                    if abo.aboTyp == "Digitale Identitäten" && !digitaleIdentitaetAnbieter.isEmpty && digitaleIdentitaetAnbieter != "Bitte wählen" {
                        return digitaleIdentitaetAnbieter
                    }

                    if abo.aboTyp == "E-Mail-Konten" && !emailAnbieter.isEmpty && emailAnbieter != "Bitte wählen" {
                        return emailAnbieter
                    }

                    if abo.aboTyp == "Streamingdienst" && !streamingAnbieter.isEmpty && streamingAnbieter != "Bitte wählen" {
                        return streamingAnbieter
                    }

                    if !bezeichnung.isEmpty && bezeichnung != "Bitte wählen" {
                        return bezeichnung
                    }

                    if !unternehmen.isEmpty && !aboArt.isEmpty {
                        return "\(unternehmen) – \(aboArt)"
                    }

                    if !unternehmen.isEmpty {
                        return unternehmen
                    }

                    if !anbieter.isEmpty && anbieter != "Bitte wählen" {
                        return anbieter
                    }

                    if !aboArt.isEmpty {
                        return aboArt
                    }

                    return "Eintrag \(fallbackIndex)"
                }

                func sollteFeldGedrucktWerden(_ value: String) -> Bool {
                    let bereinigt = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !bereinigt.isEmpty else { return false }
                    guard bereinigt != "Bitte wählen" else { return false }
                    guard !bereinigt.contains("_SwiftData") else { return false }
                    guard !bereinigt.contains("SwiftData") else { return false }
                    return true
                }

                func drawAboFeld(_ label: String, _ value: String) {
                    guard sollteFeldGedrucktWerden(value) else { return }
                    drawField(label, value)
                }


                drawDivider()
                drawSectionTitle("Abos & Profile")

                let gespeicherteAbos = gespeicherteAboModelle.flatMap { $0.abos }

                if gespeicherteAbos.isEmpty {
                    drawEmpty()
                } else {
                    let reihenfolge = AboType.allCases.map(\.rawValue)
                    let gruppierteAbos = Dictionary(grouping: gespeicherteAbos) { abo in
                        abo.aboTyp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Typ" : abo.aboTyp
                    }
                    .map { typ, abos in
                        (
                            typ: typ,
                            abos: abos.sorted { $0.erstelltAm < $1.erstelltAm }
                        )
                    }
                    .sorted { links, rechts in
                        let linkerIndex = reihenfolge.firstIndex(of: links.typ) ?? Int.max
                        let rechterIndex = reihenfolge.firstIndex(of: rechts.typ) ?? Int.max

                        if linkerIndex == rechterIndex {
                            return links.typ < rechts.typ
                        }

                        return linkerIndex < rechterIndex
                    }

                    for gruppe in gruppierteAbos {
                        beginNewPageIfNeeded(minimumSpace: 90)
                        drawSubsectionTitle(gruppe.typ)

                        for (index, abo) in gruppe.abos.enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 130)
                            drawSubsectionTitle(aboTitelFuerExport(abo, fallbackIndex: index + 1))

                            switch abo.aboTyp {
                            case "Streamingdienst":
                                drawAboFeld("Anbieter", abo.streamingAnbieter.isEmpty ? abo.anbieter : abo.streamingAnbieter)
                                drawAboFeld("Bezeichnung", abo.bezeichnung)

                            case "Social Media":
                                drawAboFeld("Plattform", abo.socialMediaPlattform.isEmpty ? abo.anbieter : abo.socialMediaPlattform)
                                drawAboFeld("Bezeichnung", abo.bezeichnung)

                            case "Digitale Identitäten":
                                drawAboFeld("Anbieter", abo.digitaleIdentitaetAnbieter.isEmpty ? abo.anbieter : abo.digitaleIdentitaetAnbieter)
                                drawAboFeld("Benutzername / E-Mail", abo.benutzername)

                            case "E-Mail-Konten":
                                drawAboFeld("Anbieter", abo.emailAnbieter.isEmpty ? abo.anbieter : abo.emailAnbieter)
                                drawAboFeld("E-Mail-Adresse", abo.benutzername)

                            case "Meine Geräte", "Mein Mobile Telefon":
                                let geraeteArt = abo.geraeteArt.isEmpty ? abo.aboArt : abo.geraeteArt
                                drawAboFeld("Geräteart", geraeteArt)
                                drawAboFeld("Bezeichnung / Gerät", abo.geraeteBezeichnung.isEmpty ? abo.bezeichnung : abo.geraeteBezeichnung)

                                if geraeteArt != "Mobile Telefon" {
                                    drawAboFeld("Benutzername / Login", abo.benutzername)
                                }

                                if passwoerterMitdrucken {
                                    drawAboFeld("PIN / Code", abo.geraetePIN.isEmpty ? abo.passwort : abo.geraetePIN)
                                }

                            case "Zeitschriften":
                                drawAboFeld("Name der Zeitschrift", abo.bezeichnung)

                            case "Öffentlicher Verkehr":
                                drawAboFeld("ÖV-Unternehmen", abo.oevUnternehmen)
                                drawAboFeld("ÖV-Abo-Typ", abo.oevAboTyp)
                                drawAboFeld("Andere Bezeichnung", abo.andereBezeichnung)
                                drawAboFeld("Abo-Nr.", abo.aboNummer)

                            case "Software / Apps", "Software / App":
                                drawAboFeld("Name", abo.bezeichnung)
                                drawAboFeld("Anbieter", abo.anbieter)

                                if abo.istSystemEintrag {
                                    drawAboFeld("Benutzername", abo.benutzername)
                                    drawAboFeld("Hinweis", "Automatisch aus der Registrierung")
                                }

                            case "Fitness / Sport":
                                drawAboFeld("Um was handelt es sich?", abo.bezeichnung)
                                drawAboFeld("Aboart", abo.aboArt)
                                drawAboFeld("Unternehmen", abo.unternehmen)

                            case "Online Zeitschriften", "Online-Zeitschrift":
                                drawAboFeld("Um was handelt es sich?", abo.bezeichnung)
                                drawAboFeld("Aboart", abo.aboArt)
                                drawAboFeld("Unternehmen", abo.unternehmen)

                            case "Mitgliedschaft":
                                drawAboFeld("Aboart", abo.aboArt)
                                drawAboFeld("Abo-Nr.", abo.aboNummer)
                                drawAboFeld("Bezeichnung", abo.bezeichnung)

                            default:
                                drawAboFeld("Anbieter", abo.anbieter)
                                drawAboFeld("Unternehmen", abo.unternehmen)
                                drawAboFeld("Bezeichnung", abo.bezeichnung)
                                drawAboFeld("Aboart", abo.aboArt)
                                drawAboFeld("Abo-Nr.", abo.aboNummer)
                            }

                            if passwoerterMitdrucken
                                && abo.aboTyp != "Meine Geräte"
                                && abo.aboTyp != "Mein Mobile Telefon"
                                && abo.aboTyp != "Digitale Identitäten"
                                && abo.aboTyp != "E-Mail-Konten"
                                && !(abo.istSystemEintrag && (abo.aboTyp == "Software / Apps" || abo.aboTyp == "Software / App")) {
                                drawAboFeld("Benutzername", abo.benutzername)
                                drawAboFeld("Passwort", abo.passwort)
                            }

                            if passwoerterMitdrucken && (abo.aboTyp == "Digitale Identitäten" || abo.aboTyp == "E-Mail-Konten" || ((abo.aboTyp == "Software / Apps" || abo.aboTyp == "Software / App") && abo.istSystemEintrag)) {
                                drawAboFeld("Passwort", abo.passwort)
                            }

                            drawAboFeld("Bankkonto", abo.bankkontoName)
                            drawAboFeld("Bankkonto-Art", abo.bankkontoArt)
                            drawAboFeld("Notizen", abo.notizen)

                            if !abo.istAktiv {
                                drawField("Aktiv", "Nein")
                            }

                            yPosition += 8
                        }
                    }
                }

            }

            return url

        } catch {

            print("PDF konnte nicht erstellt werden: \(error.localizedDescription)")

            return nil

        }

    }

    private struct PostAutocompleteAntwort: Decodable {
        let vorschlaege: [PostAdressVorschlag]

        enum CodingKeys: String, CodingKey {
            case result = "QueryAutoComplete4Result"
            case result2 = "QueryAutoComplete2Result"
            case directAutoCompleteResult = "AutoCompleteResult"
            case directAutoCompleteData = "AutoCompleteData"
            case directSuggestions = "Suggestions"
            case suggestions = "suggestions"
            case results = "results"
            case data = "data"
            case items = "items"
        }

        enum ResultCodingKeys: String, CodingKey {
            case autoCompleteResult = "AutoCompleteResult"
            case autoCompleteData = "AutoCompleteData"
            case suggestions = "Suggestions"
            case buildingData = "BuildingData"
            case results = "results"
            case data = "data"
            case items = "items"
        }

        init(from decoder: Decoder) throws {
            if let values = try? [PostAdressVorschlag](from: decoder) {
                vorschlaege = values
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let resultContainer = try? container.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result) {
                if let values = PostAutocompleteAntwort.decodeVorschlaege(from: resultContainer) {
                    vorschlaege = values
                    return
                }
            }

            if let resultContainer = try? container.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result2) {
                if let values = PostAutocompleteAntwort.decodeVorschlaege(from: resultContainer) {
                    vorschlaege = values
                    return
                }
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .directAutoCompleteResult) {
                vorschlaege = values
                return
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .directAutoCompleteData) {
                vorschlaege = values
                return
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .directSuggestions) {
                vorschlaege = values
                return
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .suggestions) {
                vorschlaege = values
                return
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .results) {
                vorschlaege = values
                return
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .data) {
                vorschlaege = values
                return
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .items) {
                vorschlaege = values
                return
            }

            vorschlaege = []
        }

        private static func decodeVorschlaege(from container: KeyedDecodingContainer<ResultCodingKeys>) -> [PostAdressVorschlag]? {
            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .autoCompleteResult) {
                return values
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .autoCompleteData) {
                return values
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .suggestions) {
                return values
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .buildingData) {
                return values
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .results) {
                return values
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .data) {
                return values
            }

            if let values = try? container.decode([PostAdressVorschlag].self, forKey: .items) {
                return values
            }

            return nil
        }
    }

    private struct PostBuildingVerificationAntwort: Decodable {
        let verifizierteAdresse: PostAdressVorschlag?

        enum CodingKeys: String, CodingKey {
            case result4 = "QueryBuildingVerification4Result"
            case result2 = "QueryBuildingVerification2Result"
            case directData = "BuildingVerificationData"
        }

        enum ResultCodingKeys: String, CodingKey {
            case data = "BuildingVerificationData"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let resultContainer = try? container.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result4),
               let data = try? resultContainer.decode(PostAdressVorschlag.self, forKey: .data) {
                verifizierteAdresse = data
                return
            }

            if let resultContainer = try? container.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result2),
               let data = try? resultContainer.decode(PostAdressVorschlag.self, forKey: .data) {
                verifizierteAdresse = data
                return
            }

            if let directData = try? container.decode(PostAdressVorschlag.self, forKey: .directData) {
                verifizierteAdresse = directData
                return
            }

            verifizierteAdresse = nil
        }
    }

    private struct PostAdressVorschlag: Decodable, Identifiable {
        let id = UUID()
        let canton: String
        let countryCode: String
        let houseKey: String
        let houseNo: String
        let houseNoAddition: String
        let streetName: String
        let townName: String
        let zipCode: String

        var vollstaendigeHausnummer: String {
            [houseNo, houseNoAddition]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        var anzeigeTitel: String {
            let hausnummerText = vollstaendigeHausnummer
            return hausnummerText.isEmpty ? streetName : "\(streetName) \(hausnummerText)"
        }

        var anzeigeUntertitel: String {
            [zipCode, townName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        enum CodingKeys: String, CodingKey {
            case canton = "Canton"
            case countryCode = "CountryCode"
            case houseKey = "HouseKey"
            case houseNo = "HouseNo"
            case houseNoAddition = "HouseNoAddition"
            case streetName = "StreetName"
            case townName = "TownName"
            case zipCode = "ZipCode"
            case cantonLower = "canton"
            case countryCodeLower = "countryCode"
            case houseKeyLower = "houseKey"
            case houseNoLower = "houseNo"
            case houseNoAdditionLower = "houseNoAddition"
            case streetNameLower = "streetName"
            case townNameLower = "townName"
            case zipCodeLower = "zipCode"
            case postalCodeLower = "postalCode"
            case cityLower = "city"
            case localityLower = "locality"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            canton = try container.decodeIfPresent(String.self, forKey: .canton) ?? container.decodeIfPresent(String.self, forKey: .cantonLower) ?? ""
            countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode) ?? container.decodeIfPresent(String.self, forKey: .countryCodeLower) ?? ""
            houseKey = try PostAdressVorschlag.decodeStringOrInt(from: container, preferredKey: .houseKey, fallbackKey: .houseKeyLower)
            houseNo = try PostAdressVorschlag.decodeStringOrInt(from: container, preferredKey: .houseNo, fallbackKey: .houseNoLower)
            houseNoAddition = try container.decodeIfPresent(String.self, forKey: .houseNoAddition) ?? container.decodeIfPresent(String.self, forKey: .houseNoAdditionLower) ?? ""
            streetName = try container.decodeIfPresent(String.self, forKey: .streetName) ?? container.decodeIfPresent(String.self, forKey: .streetNameLower) ?? ""
            townName = try container.decodeIfPresent(String.self, forKey: .townName) ?? container.decodeIfPresent(String.self, forKey: .townNameLower) ?? container.decodeIfPresent(String.self, forKey: .cityLower) ?? container.decodeIfPresent(String.self, forKey: .localityLower) ?? ""
            zipCode = try PostAdressVorschlag.decodeStringOrInt(from: container, preferredKey: .zipCode, fallbackKey: .zipCodeLower, secondFallbackKey: .postalCodeLower)
        }

        private static func decodeStringOrInt(from container: KeyedDecodingContainer<CodingKeys>, preferredKey: CodingKeys, fallbackKey: CodingKeys, secondFallbackKey: CodingKeys? = nil) throws -> String {
            for key in [preferredKey, fallbackKey, secondFallbackKey].compactMap({ $0 }) {
                if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
                    return stringValue
                }

                if let intValue = try container.decodeIfPresent(Int.self, forKey: key) {
                    return String(intValue)
                }
            }

            return ""
        }
    }

    private struct SchweizerOrt: Decodable {
        let name: String
        let postalCode: String

        enum CodingKeys: String, CodingKey {
            case name
            case postalCode
        }
    }

}

struct ExportiertesDossier: Identifiable {

    let id = UUID()

    let url: URL

}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif

private struct PDFHaustierEintrag: Decodable {
    let art: String
    let name: String
    let tierarzt: String
    let bemerkungen: String

    var anzeigename: String {
        let bereinigterName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return bereinigterName.isEmpty ? "Unbenanntes Haustier" : bereinigterName
    }
}

#Preview {
    ProfilView()
        .modelContainer(for: [
            ProfilModell.self,
            WuenscheModell.self,
            HinterbliebeneModell.self,
            BankkontoModell.self,
            SchuldenModell.self,
            VersicherungModell.self,
            LiegenschaftModell.self,
            WertsacheModell.self,
            SteuerdokumentModell.self,
            AboModell.self,
            AboEintrag.self,
            VertrauenspersonModell.self,
            VertrauenspersonEinladungsHistorieModell.self
        ], inMemory: true)
}


    
    
