import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import LocalAuthentication
import PDFKit
import SafariServices

private struct ProfilSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}


struct ProfilView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    var dossierKontext: DossierKontext = .eigenesDossier(dossierID: UUID())
    var dossierExportDirektAnzeigen = false
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteGesundheitsdaten: [GesundheitModell]
    @Query private var gespeicherteWuensche: [WuenscheModell]
    @Query private var gespeicherteHinterbliebene: [HinterbliebeneModell]
    @Query private var gespeicherteBankkonten: [BankkontoModell]
    @Query private var gespeicherteSchulden: [SchuldenModell]
    @Query private var gespeicherteVersicherungen: [VersicherungModell]
    @Query private var gespeicherteLiegenschaften: [LiegenschaftModell]
    @Query private var gespeicherteWertsachen: [WertsacheModell]
    @Query private var gespeicherteSteuerdokumente: [SteuerdokumentModell]
    @Query(sort: \FotoalbumBildModell.reihenfolge) private var gespeicherteFotos: [FotoalbumBildModell]
    @Query(sort: \DokumenteModell.hochgeladenAm) private var gespeicherteWeitereDokumente: [DokumenteModell]
    @Query private var gespeicherteAboModelle: [AboModell]
    @Query private var gespeicherteAboEintraege: [AboEintrag]
    @Query private var gespeicherteVertrauenspersonen: [VertrauenspersonModell]
    @Query private var gespeicherteEinladungsHistorien: [VertrauenspersonEinladungsHistorieModell]
    @Query private var gespeicherteDossiers: [DossierModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]

    private let profilKartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let profilAkzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let profilHintergrundFarbe = Color(red: 0.985, green: 0.98, blue: 0.965)

    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("biometrieAktiviert") private var biometrieAktiviert = false
    @AppStorage("biometriePruefungImProfilLaeuft") private var biometriePruefungImProfilLaeuft = false
    @AppStorage("systemdialogImProfilLaeuft") private var systemdialogImProfilLaeuft = false
    @AppStorage("istEingeloggt") private var istEingeloggt = false
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("dossierZuletztGeprueftAmISO") private var dossierZuletztGeprueftAmISO = ""
    @AppStorage("dossierLetzterExportAmISO") private var dossierLetzterExportAmISO = ""
    @AppStorage("profilWurdeGeradeGeloescht") private var profilWurdeGeradeGeloescht = false
    @AppStorage("wurdeGeradeAusgeloggt") private var wurdeGeradeAusgeloggt = false

    @State private var vorname = ""

    @State private var rechtlichesAnzeigen = false

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
    @State private var profilbildMediathekAnzeigen = false

    @AppStorage("profilbildData") private var profilbildData: Data?

    @State private var profilLoeschenBestaetigen = false

    @State private var passwortAendernAnzeigen = false
    @State private var registrierungsPasswortAnzeigen = false
    @State private var aktuellesPasswort = ""
    @State private var neuesPasswort = ""
    @State private var neuesPasswortWiederholen = ""
    @State private var passwortAendernFehler = ""
    @State private var passwortAendernErfolg = ""



    @State private var dossierPDF: ExportiertesDossier?
    @State private var dossierExportSheetAnzeigen = false
    @State private var sensibleDatenExportieren = false
    @State private var dokumenteAlsAnhangBeruecksichtigen = true
    @State private var dossierExportLaeuft = false
    @State private var dossierExportFehlermeldung = ""
    @State private var profilGeladen = false
    @State private var biometriePruefungLaeuft = false
    @State private var biometrieFehlermeldung = ""
    @State private var vertrauenspersonAnzeigen = false



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

    private var anzahlFinanzEintraege: Int {
        gespeicherteBankkonten.count
            + gespeicherteSchulden.count
            + gespeicherteVersicherungen.count
            + gespeicherteLiegenschaften.count
            + gespeicherteWertsachen.count
            + gespeicherteSteuerdokumente.count
    }

    private var anzahlAboEintraege: Int {
        gespeicherteAboModelle.reduce(0) { summe, modell in
            summe + modell.abos.filter { !$0.istSystemEintrag }.count
        }
    }

    private var lokalHinterlegteVertrauenspersonen: [VertrauenspersonModell] {
        guard let userID = aktivesProfil?.userID else { return [] }
        return gespeicherteVertrauenspersonen.filter {
            $0.vorsorgendeUserID == userID && $0.istLokalHinterlegt
        }
    }

    private var dossierExportBereiche: [DossierExportBereich] {
        [
            DossierExportBereich(
                titel: "Profil",
                detail: "Persönliche Angaben und Kontaktdaten",
                status: gespeicherteProfile.isEmpty ? "Noch nicht erfasst" : "Bereit",
                istGefuellt: !gespeicherteProfile.isEmpty
            ),
            DossierExportBereich(
                titel: "Gesundheit",
                detail: "Hausarzt, medizinische Hinweise, Allergien und Medikamente",
                status: gespeicherteGesundheitsdaten.isEmpty ? "Noch nicht erfasst" : "Bereit",
                istGefuellt: !gespeicherteGesundheitsdaten.isEmpty
            ),
            DossierExportBereich(
                titel: "Wünsche",
                detail: "Vorsorge, letzte Worte, Dokumente und Hinweise",
                status: gespeicherteWuensche.isEmpty ? "Noch nicht erfasst" : "Bereit",
                istGefuellt: !gespeicherteWuensche.isEmpty
            ),
            DossierExportBereich(
                titel: "Menschen meines Vertrauens",
                detail: "Kontakte, Rollen und Informationshinweise",
                status: lokalHinterlegteVertrauenspersonen.isEmpty
                    ? "Noch keine Vertrauensperson"
                    : "\(lokalHinterlegteVertrauenspersonen.count) hinterlegt",
                istGefuellt: !lokalHinterlegteVertrauenspersonen.isEmpty
            ),
            DossierExportBereich(
                titel: "Finanzen & Werte",
                detail: "Bankkonten, Schulden, Versicherungen und Werte",
                status: anzahlFinanzEintraege == 0 ? "Noch keine Einträge" : "\(anzahlFinanzEintraege) Einträge",
                istGefuellt: anzahlFinanzEintraege > 0
            ),
            DossierExportBereich(
                titel: "Abos & digitale Zugänge",
                detail: "Verträge, Mitgliedschaften und Logins",
                status: anzahlAboEintraege == 0 ? "Noch keine Einträge" : "\(anzahlAboEintraege) Einträge",
                istGefuellt: anzahlAboEintraege > 0
            )
        ]
    }

    private var anzahlBereiteExportBereiche: Int {
        dossierExportBereiche.filter(\.istGefuellt).count
    }

    var body: some View {
        Group {
            if dossierExportDirektAnzeigen {
                dossierExportSheet
                    .sheet(item: $dossierPDF, onDismiss: { dismiss() }) { dossier in
                        ShareSheet(activityItems: [dossier.url])
                    }
                    .onAppear {
                        ladeOderErstelleProfil()
                        dossierExportFehlermeldung = ""
                    }
            } else {
                profilHauptansicht
            }
        }
    }

    private var profilHauptansicht: some View {

        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        if dossierKontext.kannBearbeiten {
                            Button {
                                systemdialogImProfilLaeuft = true
                                profilbildMediathekAnzeigen = true
                            } label: {
                                profilbildAuswahlInhalt
                            }
                            .buttonStyle(.plain)
                            .photosPicker(
                                isPresented: $profilbildMediathekAnzeigen,
                                selection: $profilbildAuswahl,
                                matching: .images,
                                photoLibrary: .shared()
                            )
                        } else {
                            profilbildAnsicht
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
                        .disabled(dossierKontext.istReadOnly)
                    
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .disabled(dossierKontext.istReadOnly)

                    TextField("Strasse", text: $adresse)
                        .textContentType(.streetAddressLine1)
                        .disabled(dossierKontext.istReadOnly)
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

                    if !adressVorschlaege.isEmpty, dossierKontext.kannBearbeiten {
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
                        .disabled(dossierKontext.istReadOnly)

                    HStack {
                        TextField("PLZ", text: $plz)
                            .keyboardType(.numberPad)
                            .disabled(dossierKontext.istReadOnly)
                        TextField("Stadt", text: $stadt)
                            .disabled(dossierKontext.istReadOnly)
                    }

                    Picker("Land", selection: $land) {
                        ForEach(laender, id: \.self) { land in
                            Text(land).tag(land)
                        }
                    }
                    .disabled(dossierKontext.istReadOnly)

                    TextField("Telefon", text: $telefon)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .disabled(dossierKontext.istReadOnly)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("E-Mail", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .disabled(dossierKontext.istReadOnly)

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
                            .disabled(dossierKontext.istReadOnly)
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
                            .disabled(dossierKontext.istReadOnly)
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

                if dossierKontext.kannBearbeiten {
                    Section("Vertrauensperson") {
                        Button {
                            vertrauenspersonAnzeigen = true
                        } label: {
                            HStack(spacing: 12) {
                                Label(
                                    gespeicherteVertrauenspersonen.contains(where: \.istLokalHinterlegt)
                                        ? "Vertrauensperson verwalten"
                                        : "Vertrauensperson hinterlegen",
                                    systemImage: "person.crop.circle.badge.checkmark"
                                )

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(profilAkzentFarbe)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Text("Halte fest, wer im Ernstfall deine Vertrauensperson ist.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(profilKartenFarbe)
                    .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))
                }
                Section {
                    dossierExportKarte
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if dossierKontext.kannBearbeiten {
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
                }
                if dossierKontext.kannBearbeiten {
                    Section {
                        Button {
                            abmelden()
                        } label: {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            profilLoeschenBestaetigen = true
                        } label: {
                            Label("Profil löschen", systemImage: "trash.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                    .listRowBackground(profilKartenFarbe)
                    .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))
                }

                Section("Rechtliches") {
                    Button {
                        systemdialogImProfilLaeuft = true
                        rechtlichesAnzeigen = true
                    } label: {
                        Label("Nutzungsbedingungen", systemImage: "doc.text")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Button {
                        systemdialogImProfilLaeuft = true
                        rechtlichesAnzeigen = true
                    } label: {
                        Label("Haftungshinweise", systemImage: "exclamationmark.shield")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(profilKartenFarbe)
                .listRowSeparatorTint(profilAkzentFarbe.opacity(0.18))

            }
            .scrollContentBackground(.hidden)
            .background(profilHintergrundFarbe.ignoresSafeArea())
            .tint(profilAkzentFarbe)
            .navigationTitle("Mein Profil")
            .navigationDestination(isPresented: $vertrauenspersonAnzeigen) {
                VertrauenspersonView()
            }

            .alert("Profil wirklich löschen?", isPresented: $profilLoeschenBestaetigen) {

                Button("Abbrechen", role: .cancel) { }

                Button("Ja, löschen", role: .destructive) {

                    profilLoeschen()

                }

            } message: {

                Text("Alle Daten werden unwiderruflich gelöscht.")

            }
            .sheet(item: $dossierPDF) { dossier in

                ShareSheet(activityItems: [dossier.url])

            }
            .sheet(isPresented: $dossierExportSheetAnzeigen) {
                dossierExportSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $rechtlichesAnzeigen, onDismiss: {
                systemdialogImProfilLaeuft = false
            }) {
                ProfilSafariView(url: URL(string: "https://tschluessli.ch")!)
                    .ignoresSafeArea()
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
                guard dossierKontext.kannBearbeiten else { return }
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
                guard dossierKontext.kannBearbeiten else { return }
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
                guard dossierKontext.kannBearbeiten else { return }

                systemdialogImProfilLaeuft = false

                Task {
                    if let data = try? await neueAuswahl?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpegData = image.jpegData(compressionQuality: 0.85) {
                        profilbildData = jpegData
                        speichereProfil()
                    }
                }
            }
            .onChange(of: scenePhase) { _, neuePhase in
                guard neuePhase == .active else { return }
                guard systemdialogImProfilLaeuft else { return }

                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !profilbildMediathekAnzeigen else { return }
                    systemdialogImProfilLaeuft = false
                }
            }
        }
        .dossierFloatingNavigation(.profil)
    }

    private var profilbildAuswahlInhalt: some View {
        VStack(spacing: 12) {
            profilbildAnsicht

            Text(profilbildData == nil ? "Profilbild auswählen" : "Profilbild ändern")
                .font(.headline)
                .foregroundStyle(profilAkzentFarbe)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var profilbildAnsicht: some View {
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
        guard dossierKontext.kannBearbeiten else { return }
        guard !biometriePruefungLaeuft else { return }

        biometriePruefungLaeuft = true
        biometriePruefungImProfilLaeuft = true
        biometrieFehlermeldung = ""

        let context = LAContext()
        context.localizedCancelTitle = "Abbrechen"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometriePruefungLaeuft = false
            biometriePruefungImProfilLaeuft = false
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
                biometriePruefungImProfilLaeuft = false

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
        guard dossierKontext.kannBearbeiten else { return }
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
        try? modelContext.save()
    }

    private func synchronisiereAfterLifeDigitaleIdentitaet(email: String? = nil, passwort: String? = nil) {
        guard dossierKontext.kannBearbeiten else { return }
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
        eintrag.anbieter = "Tschlüssli"
        eintrag.digitaleIdentitaetAnbieter = ""
        eintrag.bezeichnung = "Tschlüssli"
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
        guard dossierKontext.kannBearbeiten else { return }
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
        guard dossierKontext.kannLoeschen else { return }

        let keychainKonten = Set(
            gespeicherteProfile
                .map(\.registrierungsEmail)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                + [gespeicherteEmail.trimmingCharacters(in: .whitespacesAndNewlines)]
                    .filter { !$0.isEmpty }
        )

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

        gespeicherteDossierZugriffe.forEach { modelContext.delete($0) }
        gespeicherteEinladungsHistorien.forEach { modelContext.delete($0) }
        gespeicherteVertrauenspersonen.forEach { modelContext.delete($0) }
        gespeicherteWeitereDokumente.forEach { modelContext.delete($0) }
        gespeicherteFotos.forEach { modelContext.delete($0) }
        gespeicherteAboEintraege.forEach { modelContext.delete($0) }
        gespeicherteAboModelle.forEach { modelContext.delete($0) }
        gespeicherteSteuerdokumente.forEach { modelContext.delete($0) }
        gespeicherteWertsachen.forEach { modelContext.delete($0) }
        gespeicherteLiegenschaften.forEach { modelContext.delete($0) }
        gespeicherteVersicherungen.forEach { modelContext.delete($0) }
        gespeicherteSchulden.forEach { modelContext.delete($0) }
        gespeicherteBankkonten.forEach { modelContext.delete($0) }
        gespeicherteHinterbliebene.forEach { modelContext.delete($0) }
        gespeicherteWuensche.forEach { modelContext.delete($0) }
        gespeicherteGesundheitsdaten.forEach { modelContext.delete($0) }
        gespeicherteDossiers.forEach { modelContext.delete($0) }
        gespeicherteProfile.forEach { modelContext.delete($0) }

        try? modelContext.save()

        keychainKonten.forEach { konto in
            try? KeychainHelper.shared.delete(
                service: "AfterLife.Login",
                account: konto
            )
        }

        NotificationService.shared.jaehrlicheDossierPruefungEntfernen()

        gespeicherteEmail = ""
        registrierungsArt = "E-Mail"
        biometrieAktiviert = false
        biometriePruefungImProfilLaeuft = false
        systemdialogImProfilLaeuft = false
        aktiveUserID = ""
        aktivesDossierID = ""
        profilIstVorhanden = false
        dossierZuletztGeprueftAmISO = ""
        UserDefaults.standard.removeObject(forKey: "homeBereicheReihenfolge")
        UserDefaults.standard.removeObject(forKey: "homeAktiveBereiche")
        UserDefaults.standard.removeObject(forKey: "dossierFloatingNavigationScrollOffset")
        UserDefaults.standard.removeObject(forKey: "eingehenderEinladungsToken")
        UserDefaults.standard.removeObject(forKey: "eingehendeEinladungsURL")

        profilGeladen = false
        direktNachRegistrierungEingeloggt = false
        istEingeloggt = false
        profilWurdeGeradeGeloescht = true
    }

    private func abmelden() {
        wurdeGeradeAusgeloggt = true
        direktNachRegistrierungEingeloggt = false
        istEingeloggt = false
    }

    private var dossierExportKarte: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Dein Vorsorge-Dossier")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Aus deinen erfassten Angaben wird ein vollständiges Vorsorge-Dossier als PDF erstellt.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.white)

                Text("\(anzahlBereiteExportBereiche) von \(dossierExportBereiche.count) Bereichen mit Daten bereit")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 11)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                dossierExportFehlermeldung = ""
                dossierExportSheetAnzeigen = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.body.weight(.semibold))

                    Text("Vorsorge-Dossier erstellen")
                        .font(.body.weight(.semibold))

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(profilKartenFarbe)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(dossierExportLaeuft)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(profilAkzentFarbe)
        )
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(profilAkzentFarbe.opacity(0.16))
        )
        .shadow(color: profilAkzentFarbe.opacity(0.12), radius: 10, x: 0, y: 5)
    }

    private var dossierExportSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Vollständiges Vorsorge-Dossier als PDF")
                            .font(.title3.weight(.bold))

                        Text("Bereiche prüfen und Exportoptionen wählen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(dossierExportBereiche) { bereich in
                            dossierExportBereichZeile(bereich)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $sensibleDatenExportieren) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Sensible Zugangsdaten einschliessen")
                                    .font(.subheadline.weight(.semibold))
                                Text("Passwörter und Abo-Logins erscheinen nur im PDF, wenn diese Option aktiv ist.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(profilAkzentFarbe)

                        Divider()

                        Toggle(isOn: $dokumenteAlsAnhangBeruecksichtigen) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Dokumente als Anhang berücksichtigen")
                                    .font(.subheadline.weight(.semibold))
                                Text("Hochgeladene Dokumente werden als Anhang hinzugefügt. Video und Fotoalben müssen separat heruntergeladen werden.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(profilAkzentFarbe)

                        if sensibleDatenExportieren {
                            Label("Teile dieses PDF nur mit Personen, denen du vollständig vertraust.", systemImage: "exclamationmark.shield.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(12)
                    .background(profilKartenFarbe)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if !dossierExportFehlermeldung.isEmpty {
                        Text(dossierExportFehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) {
                dossierExportButton
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(.regularMaterial)
            }
            .background(profilHintergrundFarbe.ignoresSafeArea())
            .navigationTitle("Vorsorge-Dossier erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        if dossierExportDirektAnzeigen {
                            dismiss()
                        } else {
                            dossierExportSheetAnzeigen = false
                        }
                    }
                    .disabled(dossierExportLaeuft)
                }
            }
        }
    }

    private var dossierExportButton: some View {
        Button {
            erstelleUndTeileDossier()
        } label: {
            HStack(spacing: 10) {
                Spacer(minLength: 0)

                if dossierExportLaeuft {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "doc.richtext.fill")
                        .font(.body.weight(.semibold))
                }

                Text(dossierExportLaeuft ? "Vorsorge-Dossier wird erstellt ..." : "Vorsorge-Dossier als PDF erstellen")
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(profilAkzentFarbe)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(dossierExportLaeuft)
    }

    private func dossierExportBereichZeile(_ bereich: DossierExportBereich) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: bereich.istGefuellt ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(bereich.istGefuellt ? profilAkzentFarbe : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(bereich.titel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)

                Text(bereich.status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(bereich.istGefuellt ? profilAkzentFarbe : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(Color(.systemBackground).opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func erstelleUndTeileDossier() {
        guard !dossierExportLaeuft else { return }

        dossierExportFehlermeldung = ""
        dossierExportLaeuft = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            do {
                let url = try erstelleModularesDossierPDF()
                dossierLetzterExportAmISO = ISO8601DateFormatter().string(from: Date())
                dossierExportLaeuft = false
                dossierExportSheetAnzeigen = false
                dossierPDF = ExportiertesDossier(url: url)
            } catch {
                dossierExportLaeuft = false
                dossierExportFehlermeldung = "Das Vorsorge-Dossier konnte nicht als PDF erstellt werden. Bitte versuche es erneut."
            }
        }
    }

    private func erstelleModularesDossierPDF() throws -> URL {
        let options = DossierPDFExportOptions(
            sensibleDatenEinschliessen: sensibleDatenExportieren,
            dokumenteAlsAnhangBeruecksichtigen: dokumenteAlsAnhangBeruecksichtigen,
            leereFelderAnzeigen: false
        )

        return try PDFExportService().exportVorsorgeDossier(
            profil: aktivesProfil,
            wuensche: gespeicherteWuensche,
            gesundheitsdaten: gespeicherteGesundheitsdaten,
            bankkonten: gespeicherteBankkonten,
            schulden: gespeicherteSchulden,
            versicherungen: gespeicherteVersicherungen,
            liegenschaften: gespeicherteLiegenschaften,
            wertsachen: gespeicherteWertsachen,
            dokumente: gespeicherteWeitereDokumente,
            fotoalbumBilder: gespeicherteFotos,
            aboModelle: gespeicherteAboModelle,
            vertrauenspersonen: lokalHinterlegteVertrauenspersonen,
            options: options,
            attachments: dossierAnhaenge()
        )
    }

    private func dossierAnhaenge() -> [DossierPDFAttachment] {
        guard dokumenteAlsAnhangBeruecksichtigen else { return [] }

        let kopieHinweis = "Hinweis: Dieses Dokument ist eine Kopie. Das Original sollte jederzeit auffindbar in einem physischen Ordner hinterlegt sein."
        var anhaenge: [DossierPDFAttachment] = []

        if let nachrufBildDaten = gespeicherteWuensche.compactMap(\.nachrufBildData).first,
           !nachrufBildDaten.isEmpty {
            anhaenge.append(
                DossierPDFAttachment(
                    titel: "Foto für Nachlass",
                    kategorie: "Meine Wünsche",
                    dateiname: "Nachruf-Foto",
                    daten: nachrufBildDaten
                )
            )
        }

        for wunsch in gespeicherteWuensche {
            if let data = wunsch.testamentDateiData, !data.isEmpty {
                anhaenge.append(
                    DossierPDFAttachment(
                        titel: "Testament",
                        kategorie: "Meine Wünsche",
                        dateiname: fallbackDateiname(wunsch.testamentDateiName, fallback: "Testament"),
                        erstelltAm: wunsch.testamentHochgeladenAm,
                        hinweis: kopieHinweis,
                        daten: data
                    )
                )
            }

            if let data = wunsch.patientenverfuegungDateiData, !data.isEmpty {
                anhaenge.append(
                    DossierPDFAttachment(
                        titel: "Patientenverfügung",
                        kategorie: "Meine Wünsche",
                        dateiname: fallbackDateiname(wunsch.patientenverfuegungDateiName, fallback: "Patientenverfuegung"),
                        erstelltAm: wunsch.patientenverfuegungHochgeladenAm,
                        hinweis: kopieHinweis,
                        daten: data
                    )
                )
            }

            if let data = wunsch.vorsorgeauftragDateiData, !data.isEmpty {
                anhaenge.append(
                    DossierPDFAttachment(
                        titel: "Vorsorgeauftrag",
                        kategorie: "Meine Wünsche",
                        dateiname: fallbackDateiname(wunsch.vorsorgeauftragDateiName, fallback: "Vorsorgeauftrag"),
                        erstelltAm: wunsch.vorsorgeauftragHochgeladenAm,
                        hinweis: kopieHinweis,
                        daten: data
                    )
                )
            }

            if let data = wunsch.sterbebegleitungDateiData, !data.isEmpty {
                anhaenge.append(
                    DossierPDFAttachment(
                        titel: "Sterbebegleitung",
                        kategorie: "Meine Wünsche",
                        dateiname: fallbackDateiname(wunsch.sterbebegleitungDateiName, fallback: "Sterbebegleitung"),
                        erstelltAm: wunsch.sterbebegleitungHochgeladenAm,
                        hinweis: kopieHinweis,
                        daten: data
                    )
                )
            }
        }

        for dokument in gespeicherteWeitereDokumente.sorted(by: { $0.hochgeladenAm < $1.hochgeladenAm }) where !dokument.dateiDaten.isEmpty {
            anhaenge.append(
                DossierPDFAttachment(
                    titel: dokument.kategorie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Weitere Dokumente" : dokument.kategorie,
                    kategorie: "Weitere Dokumente",
                    dateiname: fallbackDateiname(dokument.dateiName, fallback: "Dokument"),
                    erstelltAm: dokument.hochgeladenAm,
                    daten: dokument.dateiDaten
                )
            )
        }

        for (index, foto) in gespeicherteFotos.sorted(by: { $0.reihenfolge < $1.reihenfolge }).enumerated() where !foto.bildDaten.isEmpty {
            anhaenge.append(
                DossierPDFAttachment(
                    titel: "Fotoalbum",
                    kategorie: "Fotoalbum",
                    dateiname: fallbackDateiname(foto.dateiName, fallback: "Foto_\(index + 1)"),
                    erstelltAm: foto.hinzugefuegtAm,
                    daten: foto.bildDaten
                )
            )
        }

        return anhaenge
    }

    private func fallbackDateiname(_ dateiname: String, fallback: String) -> String {
        let bereinigterDateiname = dateiname.trimmingCharacters(in: .whitespacesAndNewlines)
        return bereinigterDateiname.isEmpty ? fallback : bereinigterDateiname
    }

    // MARK: - Fallback alter PDF-Export
    // Wird aktuell nicht mehr vom CTA verwendet. Bleibt vorerst als Rückfallpfad erhalten,
    // bis der modulare PDF-Export fachlich und visuell vollständig abgenommen ist.
    private func erstelleDossierPDF(passwoerterMitdrucken: Bool) -> URL? {

        let pdfMetaData = [

            kCGPDFContextCreator: "AfterLife",

            kCGPDFContextAuthor: "AfterLife App",

            kCGPDFContextTitle: "Persönliches Tschlüssli Dossier"

        ]

        let format = UIGraphicsPDFRendererFormat()

        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 595.2

        let pageHeight = 841.8

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = "Tschlüssli_Dossier_\(Int(Date().timeIntervalSince1970)).pdf"

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
                        if wunsch.letzteBotschaftVideoData != nil || !wunsch.letzteBotschaftVideoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            drawField("Video", "Video kann separat heruntergeladen werden")
                        }

                        drawSubsectionTitle("Nachruf")
                        drawField("Nachruf gewünscht", wunsch.nachrufGewuenscht ? "Ja" : "Nein")
                        drawField("Nachruf Text", wunsch.nachrufText)
                        if wunsch.nachrufBildData != nil || !wunsch.nachrufBildDateiName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            drawField("Nachruf Bild", "Foto im Anhang")
                        }

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

                func drawGesundheit() {
                    drawDivider()
                    drawSectionTitle("Gesundheit")

                    guard !gespeicherteGesundheitsdaten.isEmpty else {
                        drawEmpty()
                        return
                    }

                    for (index, gesundheit) in gespeicherteGesundheitsdaten.enumerated() {
                        beginNewPageIfNeeded(minimumSpace: 150)
                        drawSubsectionTitle(gespeicherteGesundheitsdaten.count == 1 ? "Gesundheit" : "Gesundheit \(index + 1)")

                        drawSubsectionTitle("Hausarzt")
                        drawField("Hausarzt vorhanden", gesundheit.hatHausarzt ? "Ja" : "Nein")
                        drawFieldIfNotEmpty("Name", gesundheit.hausarztName)
                        drawFieldIfNotEmpty("Telefon", gesundheit.hausarztTelefon)
                        drawFieldIfNotEmpty("E-Mail", gesundheit.hausarztEmail)

                        let hausarztAdresse = [gesundheit.hausarztAdresse, gesundheit.hausarztPLZ, gesundheit.hausarztOrt]
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .joined(separator: ", ")
                        drawFieldIfNotEmpty("Adresse", hausarztAdresse)

                        drawSubsectionTitle("Medizinische Informationen")
                        drawField("Blutgruppe", gesundheit.blutgruppe)
                        drawField("Organspende", gesundheit.organspende)
                        drawField("Allergien vorhanden", gesundheit.hatAllergien ? "Ja" : "Nein")
                        drawFieldIfNotEmpty("Allergien", gesundheit.allergien)
                        drawField("Medikamente vorhanden", gesundheit.nimmtMedikamente ? "Ja" : "Nein")
                        drawFieldIfNotEmpty("Medikamente", gesundheit.medikamente)
                        drawFieldIfNotEmpty("Gesundheitliche Hinweise", gesundheit.gesundheitlicheHinweise)

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

                    if gespeicherteSteuerdokumente.isEmpty && gespeicherteFotos.isEmpty {
                        drawEmpty()
                        return
                    }

                    if !gespeicherteSteuerdokumente.isEmpty {
                        for (index, dokument) in gespeicherteSteuerdokumente.sorted(by: { $0.hochgeladenAm < $1.hochgeladenAm }).enumerated() {
                            beginNewPageIfNeeded(minimumSpace: 90)
                            drawSubsectionTitle(gespeicherteSteuerdokumente.count == 1 ? "Steuerdokument" : "Steuerdokument \(index + 1)")
                            drawFieldIfNotEmpty("Dateiname", dokument.dateiName)
                            drawFieldIfNotEmpty("Dokumentpfad", dokument.dokumentPfad)
                            drawField("Hochgeladen am", dateFormatter.string(from: dokument.hochgeladenAm))
                            yPosition += 8
                        }
                    }

                    if !gespeicherteFotos.isEmpty {
                        beginNewPageIfNeeded(minimumSpace: 80)
                        drawSubsectionTitle("Fotoalbum")
                        drawField("Fotoalbum", "Foto(s) im Anhang. Kann aber auch separat gespeichert werden")
                    }
                }

                func drawAttachmentHeader(_ title: String, fileName: String? = nil, pageInfo: String? = nil) {
                    let titel = pageInfo == nil ? title : "\(title) - \(pageInfo ?? "")"
                    drawText(titel, font: .boldSystemFont(ofSize: 22), spacing: 8)

                    if let fileName,
                       !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        drawText(fileName, font: .systemFont(ofSize: 10), color: .secondaryLabel, spacing: 18)
                    } else {
                        yPosition += 10
                    }
                }

                func drawImageAttachment(title: String, fileName: String? = nil, image: UIImage) {
                    beginPDFPage()
                    drawAttachmentHeader(title, fileName: fileName)

                    let horizontalMargin: CGFloat = 48
                    let bottomMargin: CGFloat = 48
                    let maxImageWidth = pageWidth - horizontalMargin * 2
                    let maxImageHeight = pageHeight - yPosition - bottomMargin
                    let imageAspect = image.size.width / max(image.size.height, 1)
                    let availableAspect = maxImageWidth / max(maxImageHeight, 1)

                    let drawSize: CGSize
                    if imageAspect > availableAspect {
                        drawSize = CGSize(width: maxImageWidth, height: maxImageWidth / imageAspect)
                    } else {
                        drawSize = CGSize(width: maxImageHeight * imageAspect, height: maxImageHeight)
                    }

                    let imageRect = CGRect(
                        x: (pageWidth - drawSize.width) / 2,
                        y: yPosition,
                        width: drawSize.width,
                        height: drawSize.height
                    )

                    context.cgContext.saveGState()
                    context.cgContext.interpolationQuality = .high
                    image.draw(in: imageRect)
                    context.cgContext.restoreGState()
                }

                func drawPDFPageAttachment(title: String, fileName: String? = nil, pdf: PDFDocument) {
                    for pageIndex in 0..<pdf.pageCount {
                        guard let page = pdf.page(at: pageIndex) else { continue }

                        beginPDFPage()
                        drawAttachmentHeader(
                            title,
                            fileName: pageIndex == 0 ? fileName : nil,
                            pageInfo: pdf.pageCount > 1 ? "Seite \(pageIndex + 1) von \(pdf.pageCount)" : nil
                        )

                        let bounds = page.bounds(for: .mediaBox)
                        let horizontalMargin: CGFloat = 48
                        let bottomMargin: CGFloat = 48
                        let maxContentWidth = pageWidth - horizontalMargin * 2
                        let maxContentHeight = pageHeight - yPosition - bottomMargin
                        let scale = min(maxContentWidth / max(bounds.width, 1), maxContentHeight / max(bounds.height, 1))
                        let drawSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                        let drawRect = CGRect(
                            x: (pageWidth - drawSize.width) / 2,
                            y: yPosition,
                            width: drawSize.width,
                            height: drawSize.height
                        )

                        context.cgContext.saveGState()
                        context.cgContext.interpolationQuality = .high
                        context.cgContext.translateBy(x: drawRect.minX, y: drawRect.maxY)
                        context.cgContext.scaleBy(x: scale, y: -scale)
                        context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
                        page.draw(with: .mediaBox, to: context.cgContext)
                        context.cgContext.restoreGState()
                    }
                }

                func drawUnsupportedAttachment(title: String, fileName: String? = nil) {
                    beginPDFPage()
                    drawAttachmentHeader(title, fileName: fileName)
                    drawText("Dieses Dokument ist im Vorsorge-Dossier enthalten, kann aber nicht direkt im PDF dargestellt werden.", color: .secondaryLabel, spacing: 12)
                }

                func drawAttachment(title: String, fileName: String? = nil, data: Data) {
                    if let image = UIImage(data: data) {
                        drawImageAttachment(title: title, fileName: fileName, image: image)
                        return
                    }

                    if let pdf = PDFDocument(data: data), pdf.pageCount > 0 {
                        drawPDFPageAttachment(title: title, fileName: fileName, pdf: pdf)
                        return
                    }

                    drawUnsupportedAttachment(title: title, fileName: fileName)
                }

                func drawDokumentAnhaenge() {
                    guard dokumenteAlsAnhangBeruecksichtigen else { return }

                    if let bildDaten = gespeicherteWuensche.compactMap(\.nachrufBildData).first {
                        drawAttachment(title: "Foto für Nachlass", fileName: "Nachruf-Foto", data: bildDaten)
                    }

                    for wunsch in gespeicherteWuensche {
                        if let data = wunsch.testamentDateiData {
                            drawAttachment(title: "Testament", fileName: wunsch.testamentDateiName, data: data)
                        }

                        if let data = wunsch.patientenverfuegungDateiData {
                            drawAttachment(title: "Patientenverfügung", fileName: wunsch.patientenverfuegungDateiName, data: data)
                        }

                        if let data = wunsch.vorsorgeauftragDateiData {
                            drawAttachment(title: "Vorsorgeauftrag", fileName: wunsch.vorsorgeauftragDateiName, data: data)
                        }

                        if let data = wunsch.sterbebegleitungDateiData {
                            drawAttachment(title: "Sterbebegleitung", fileName: wunsch.sterbebegleitungDateiName, data: data)
                        }
                    }

                    let weitereDokumente = gespeicherteWeitereDokumente
                        .filter { $0.kategorie == "Weitere Dokumente" }
                        .sorted { $0.hochgeladenAm < $1.hochgeladenAm }

                    for dokument in weitereDokumente {
                        drawAttachment(title: "Weitere Dokumente", fileName: dokument.dateiName, data: dokument.dateiDaten)
                    }
                }

                drawProfileImageIfAvailable()

                drawText("Persönliches Tschlüssli Dossier", font: .boldSystemFont(ofSize: 24), spacing: 12)

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
                drawGesundheit()
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
                        return socialMediaPlattform == "Andere" && !bezeichnung.isEmpty ? bezeichnung : socialMediaPlattform
                    }

                    if abo.aboTyp == "Digitale Identitäten" && !digitaleIdentitaetAnbieter.isEmpty && digitaleIdentitaetAnbieter != "Bitte wählen" {
                        return digitaleIdentitaetAnbieter == "Andere" && !bezeichnung.isEmpty ? bezeichnung : digitaleIdentitaetAnbieter
                    }

                    if abo.aboTyp == "E-Mail-Konten" && !emailAnbieter.isEmpty && emailAnbieter != "Bitte wählen" {
                        return emailAnbieter == "Andere" && !bezeichnung.isEmpty ? bezeichnung : emailAnbieter
                    }

                    if abo.aboTyp == "Streamingdienst" && !streamingAnbieter.isEmpty && streamingAnbieter != "Bitte wählen" {
                        return streamingAnbieter == "Andere" && !bezeichnung.isEmpty ? bezeichnung : streamingAnbieter
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
                                let anbieter = abo.streamingAnbieter == "Andere" ? abo.anbieter : (abo.streamingAnbieter.isEmpty ? abo.anbieter : abo.streamingAnbieter)
                                drawAboFeld("Anbieter", anbieter)

                            case "Social Media":
                                let plattform = abo.socialMediaPlattform == "Andere" ? abo.anbieter : (abo.socialMediaPlattform.isEmpty ? abo.anbieter : abo.socialMediaPlattform)
                                drawAboFeld("Plattform", plattform)

                            case "Digitale Identitäten":
                                let anbieter = abo.digitaleIdentitaetAnbieter == "Andere" ? abo.anbieter : (abo.digitaleIdentitaetAnbieter.isEmpty ? abo.anbieter : abo.digitaleIdentitaetAnbieter)
                                drawAboFeld("Anbieter", anbieter)
                                drawAboFeld("Benutzername / E-Mail", abo.benutzername)

                            case "E-Mail-Konten":
                                let anbieter = abo.emailAnbieter == "Andere" ? abo.anbieter : (abo.emailAnbieter.isEmpty ? abo.anbieter : abo.emailAnbieter)
                                drawAboFeld("Anbieter", anbieter)
                                drawAboFeld("E-Mail-Adresse", abo.benutzername)

                            case "Meine Geräte", "Mein Mobile Telefon":
                                let geraeteArt = abo.geraeteArt.isEmpty ? abo.aboArt : abo.geraeteArt
                                drawAboFeld("Geräteart", geraeteArt)
                                drawAboFeld("Bezeichnung / Gerät", abo.geraeteBezeichnung.isEmpty ? abo.bezeichnung : abo.geraeteBezeichnung)

                                if geraeteArt != "Mobile Telefon" {
                                    drawAboFeld("Benutzername / Login", abo.benutzername)
                                }

                                if passwoerterMitdrucken {
                                    drawAboFeld("PIN / Code / Passwort", abo.geraetePIN.isEmpty ? abo.passwort : abo.geraetePIN)
                                }

                            case "Zeitschriften":
                                drawAboFeld("Name der Zeitschrift", abo.bezeichnung)

                            case "Öffentlicher Verkehr":
                                let unternehmen = abo.oevUnternehmen == "Andere" ? abo.andereBezeichnung : abo.oevUnternehmen
                                let aboTyp = abo.oevAboTyp == "Andere" ? abo.aboArt : abo.oevAboTyp
                                drawAboFeld("ÖV-Unternehmen", unternehmen)
                                drawAboFeld("ÖV-Abo-Typ", aboTyp)
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

                drawDokumentAnhaenge()
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

private struct DossierExportBereich: Identifiable {
    let id = UUID()
    let titel: String
    let detail: String
    let status: String
    let istGefuellt: Bool
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


    
    
