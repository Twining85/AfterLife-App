import SwiftUI
import SwiftData
import UIKit

struct Registrierung: View {
    init(einladungsToken: String? = nil) {
        _einladungsToken = State(initialValue: einladungsToken)
    }

    private enum Eingabefeld {
        case email
        case passwort
        case captcha
        case verifizierungscode
    }

    private let registrierungHintergrund = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let registrierungAkzent = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let registrierungKarte = Color.white.opacity(0.88)
    private let registrierungTextPrimaer = Color(red: 0.12, green: 0.12, blue: 0.11)
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""
    @State private var registrierungsformularAnzeigen = false
    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    @State private var showHome = false
    @State private var akzeptiertDisclaimer = false
    @State private var captchaAntwort = ""
    @State private var captchaZahl1 = Int.random(in: 2...9)
    @State private var captchaZahl2 = Int.random(in: 2...9)
    @State private var einladungsToken: String?
    @State private var eingeladeneEmailVerifiziert = false
    @State private var emailVerifizierungCode = ""
    @State private var emailVerifizierungAntwort = ""
    @State private var emailVerifizierungWurdeGestartet = false
    @FocusState private var aktivesEingabefeld: Eingabefeld?

    var body: some View {
        NavigationStack {
            ZStack {
                registrierungHintergrund
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerBereich

                        if registrierungsformularAnzeigen {
                            zugangKarte
                                .transition(.opacity.combined(with: .move(edge: .bottom)))

                            if !fehlermeldung.isEmpty {
                                fehlermeldungBox
                            }

                            if let zugriff = aktuellerDossierZugriff,
                               emailAbweichungSollAngezeigtWerden,
                               !eingeladeneEmailVerifiziert {
                                sicherheitsPruefungKarte(zugriff: zugriff)
                            }

                            if eingeladeneEmailVerifiziert {
                                erfolgsHinweisBox
                            }

                            hinweisKarte
                            captchaKarte
                            registrierungsButtonBereich
                            weitereAnmeldungHinweis
                        } else {
                            jetztVorsorgenButton
                        }

                        logoFooter
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 22)
                }
            }
            .navigationDestination(isPresented: $showHome) {
                Home()
            }
        }
    }

    private var headerBereich: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .top) {
                Image("Home2")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 145)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                registrierungHintergrund.opacity(0.04),
                                registrierungHintergrund.opacity(0.32),
                                registrierungHintergrund.opacity(0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.58), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 7)

                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .opacity(0.95)
                    .padding(.top, 16)
            }

            VStack(spacing: 7) {
                Text("Für dich. Und für die Menschen, die dir wichtig sind.")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(registrierungTextPrimaer)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tschlüssli hilft dir, persönliche Informationen, Wünsche und wichtige Dokumente sicher festzuhalten. So gibst du deinen Angehörigen Orientierung und nimmst ihnen in einem schwierigen Moment etwas Last ab.")
                    .font(.callout)
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    private var jetztVorsorgenButton: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    registrierungsformularAnzeigen = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    aktivesEingabefeld = .email
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Jetzt vorsorgen")
                        .font(.body.weight(.semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(registrierungAkzent)
                )
            }
            .buttonStyle(.plain)
            
            Text("Dauert nur einen kurzen Moment. Du kannst dein Dossier danach Schritt für Schritt ergänzen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var zugangKarte: some View {
        registrierungKarteView(titel: "Zugang erstellen", systemImage: "lock.shield.fill") {
            VStack(spacing: 14) {
                registrierungTextfeld(
                    titel: "E-Mail-Adresse",
                    systemImage: "envelope.fill",
                    platzhalter: "name@example.ch",
                    text: $email,
                    tastatur: .emailAddress,
                    fokus: .email
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit {
                    aktivesEingabefeld = .passwort
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(registrierungAkzent)
                            .frame(width: 22)

                        SecureField("Mindestens 8 Zeichen", text: $passwort)
                            .focused($aktivesEingabefeld, equals: .passwort)
                            .submitLabel(.next)
                            .onSubmit {
                                aktivesEingabefeld = .captcha
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(registrierungAkzent.opacity(0.12), lineWidth: 1)
                    )

                    Text("Dein Passwort wird sicher in der Keychain deines Geräts gespeichert.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var fehlermeldungBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(fehlermeldung)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private var erfolgsHinweisBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("Eingeladene E-Mail-Adresse wurde verifiziert. Du kannst mit dieser Registrierungs-E-Mail fortfahren.")
                .font(.footnote)
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.green.opacity(0.09))
        )
    }

    private func sicherheitsPruefungKarte(zugriff: DossierZugriffModell) -> some View {
        registrierungKarteView(titel: "Sicherheitsprüfung erforderlich", systemImage: "shield.lefthalf.filled") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Du kannst für die Registrierung grundsätzlich eine andere E-Mail-Adresse verwenden. Aus Sicherheitsgründen prüfen wir kurz, dass wirklich die richtige Person diese persönliche Einladung annimmt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Die Einladung wurde ursprünglich an \(zugriff.eingeladeneEmail) gesendet.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(registrierungTextPrimaer)
                    .fixedSize(horizontal: false, vertical: true)

                if emailVerifizierungWurdeGestartet {
                    #if DEBUG
                    Text("Testcode: \(emailVerifizierungCode)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    #endif

                    registrierungTextfeld(
                        titel: "Verifizierungscode",
                        systemImage: "number.circle.fill",
                        platzhalter: "6-stelliger Code",
                        text: $emailVerifizierungAntwort,
                        tastatur: .numberPad,
                        fokus: .verifizierungscode
                    )

                    Button {
                        verifiziereEingeladeneEmail()
                    } label: {
                        Text("E-Mail-Adresse verifizieren")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(registrierungAkzent)
                    )
                    .buttonStyle(.plain)
                } else {
                    Button {
                        starteEingeladeneEmailVerifizierung()
                    } label: {
                        Text("Code an eingeladene E-Mail senden")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(registrierungAkzent)
                    )
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hinweisKarte: some View {
        registrierungKarteView(titel: "Wichtiger Hinweis", systemImage: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 13) {
                Text("Tschlüssli dient ausschliesslich der Organisation persönlicher Informationen und ersetzt keine Rechts-, Steuer-, Finanz- oder Vorsorgeberatung sowie keine rechtsgültigen Dokumente wie Testamente, Erbverträge, Vorsorgeaufträge oder Patientenverfügungen. Die Nutzung erfolgt in eigener Verantwortung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $akzeptiertDisclaimer) {
                    Text("Ich habe den Hinweis gelesen und verstanden.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(registrierungTextPrimaer)
                }
                .tint(registrierungAkzent)
            }
        }
    }

    private var captchaKarte: some View {
        registrierungKarteView(titel: "Kurze Sicherheitsfrage", systemImage: "person.crop.circle.badge.checkmark") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Damit stellen wir sicher, dass die Registrierung bewusst erfolgt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text("Was ist \(captchaZahl1) + \(captchaZahl2)?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(registrierungTextPrimaer)

                    Spacer(minLength: 0)

                    TextField("Antwort", text: $captchaAntwort)
                        .keyboardType(.numberPad)
                        .focused($aktivesEingabefeld, equals: .captcha)
                        .multilineTextAlignment(.center)
                        .frame(width: 92)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(registrierungAkzent.opacity(0.12), lineWidth: 1)
                        )
                }

                if !captchaAntwort.isEmpty && !captchaIstGueltig {
                    Text("Die Antwort ist nicht korrekt.")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var registrierungsButtonBereich: some View {
        VStack(spacing: 8) {
            Button {
                registrierenMitEmail()
            } label: {
                Text("Persönliches Dossier erstellen")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(registrierungErlaubt ? registrierungAkzent : Color.gray.opacity(0.42))
            )
            .buttonStyle(.plain)
            .disabled(!registrierungErlaubt)

            Text("Du kannst deine Angaben danach jederzeit ergänzen oder ändern.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
    }

    private var weitereAnmeldungHinweis: some View {
        Text("Apple- und Google-Anmeldung folgen in einer späteren Version.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private var logoFooter: some View {
        Group {
            if registrierungsformularAnzeigen {
                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                    .opacity(0.34)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private func registrierungKarteView<Content: View>(titel: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(registrierungAkzent)
                    .frame(width: 24)

                Text(titel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(registrierungTextPrimaer)

                Spacer(minLength: 0)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(registrierungKarte)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 7)
    }

    private func registrierungTextfeld(
        titel: String,
        systemImage: String,
        platzhalter: String,
        text: Binding<String>,
        tastatur: UIKeyboardType,
        fokus: Eingabefeld
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(registrierungTextPrimaer)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(registrierungAkzent)
                    .frame(width: 22)

                TextField(platzhalter, text: text)
                    .keyboardType(tastatur)
                    .focused($aktivesEingabefeld, equals: fokus)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(registrierungAkzent.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var registrierungErlaubt: Bool {
        akzeptiertDisclaimer &&
        captchaIstGueltig &&
        registrierungsEmailIstFormalGueltig &&
        bereinigtesPasswort.count >= 8
    }

    private var captchaIstGueltig: Bool {
        Int(captchaAntwort.trimmingCharacters(in: .whitespacesAndNewlines)) == captchaZahl1 + captchaZahl2
    }

    private var aktuellerDossierZugriff: DossierZugriffModell? {
        guard let einladungsToken else { return nil }

        return gespeicherteDossierZugriffe.first {
            $0.einladungsToken == einladungsToken
        }
    }

    private var bereinigteRegistrierungsEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var bereinigteEmailOriginalschreibweise: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bereinigtesPasswort: String {
        passwort.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dossierZugriffService: DossierZugriffService {
        DossierZugriffService()
    }

    private var registrierungsEmailIstFormalGueltig: Bool {
        bereinigteRegistrierungsEmail.contains("@") && bereinigteRegistrierungsEmail.contains(".")
    }

    private var bereinigteEingeladeneEmail: String? {
        aktuellerDossierZugriff?.normalisierteEingeladeneEmail
    }

    private var registrierungsEmailWeichtVonEinladungAb: Bool {
        guard let bereinigteEingeladeneEmail, !bereinigteRegistrierungsEmail.isEmpty else { return false }
        return bereinigteRegistrierungsEmail != bereinigteEingeladeneEmail
    }

    private var emailAbweichungSollAngezeigtWerden: Bool {
        registrierungsEmailIstFormalGueltig &&
        registrierungsEmailWeichtVonEinladungAb &&
        (aktivesEingabefeld == .passwort || !passwort.isEmpty || emailVerifizierungWurdeGestartet)
    }

    private func registrierenMitEmail() {
        fehlermeldung = ""

        guard akzeptiertDisclaimer else {
            fehlermeldung = "Bitte akzeptiere zuerst den Haftungsausschluss."
            return
        }

        guard captchaIstGueltig else {
            fehlermeldung = "Bitte löse das Captcha korrekt."
            captchaNeuLaden()
            return
        }

        guard registrierungsEmailIstFormalGueltig else {
            fehlermeldung = "Bitte gib eine gültige E-Mail-Adresse ein."
            return
        }

        guard bereinigtesPasswort.count >= 8 else {
            fehlermeldung = "Das Passwort muss mindestens 8 Zeichen lang sein."
            return
        }

        if let zugriff = aktuellerDossierZugriff {
            guard zugriff.kannRegistrierungFortsetzen else {
                fehlermeldung = "Diese Einladung ist ungültig oder wurde bereits verwendet."
                return
            }

            if registrierungsEmailWeichtVonEinladungAb && !eingeladeneEmailVerifiziert {
                fehlermeldung = "Bitte verifiziere zuerst die ursprünglich eingeladene E-Mail-Adresse \(zugriff.eingeladeneEmail). Danach kannst du dich mit der aktuell eingegebenen E-Mail-Adresse registrieren."

                if !emailVerifizierungWurdeGestartet {
                    starteEingeladeneEmailVerifizierung()
                }

                return
            }
        }

        let bereinigteEmail = bereinigteEmailOriginalschreibweise

        do {
            try KeychainHelper.shared.save(
                bereinigtesPasswort,
                service: "AfterLife.Login",
                account: bereinigteEmail
            )

            gespeicherteEmail = bereinigteEmail
            gespeichertesPasswort = bereinigtesPasswort
            registrierungsArt = "E-Mail"

            speichereRegistrierungsdaten(art: "E-Mail", email: bereinigteEmail)
            showHome = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                direktNachRegistrierungEingeloggt = true
                profilIstVorhanden = true
            }
        } catch {
            fehlermeldung = "Das Passwort konnte nicht sicher gespeichert werden. Bitte versuche es erneut."
        }
    }

    private func starteEingeladeneEmailVerifizierung() {
        emailVerifizierungCode = String(Int.random(in: 100000...999999))
        emailVerifizierungAntwort = ""
        emailVerifizierungWurdeGestartet = true
        fehlermeldung = ""
    }

    private func verifiziereEingeladeneEmail() {
        guard emailVerifizierungAntwort.trimmingCharacters(in: .whitespacesAndNewlines) == emailVerifizierungCode else {
            fehlermeldung = "Der Verifizierungscode ist nicht korrekt."
            return
        }

        eingeladeneEmailVerifiziert = true
        fehlermeldung = ""
    }


    private func speichereRegistrierungsdaten(art: String, email: String) {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let profil = ProfilModell()
        modelContext.insert(profil)

        profil.registrierungsart = art
        profil.registrierungsEmail = bereinigteEmail

        if let zugriff = aktuellerDossierZugriff {
            zugriff.einladungAnnehmen(
                vertrauenspersonUserID: profil.userID,
                registrierungsEmail: bereinigteEmail
            )
        }

        erstelleDossierFallsNoetig(fuer: profil, email: bereinigteEmail)
        aktiveUserID = profil.userID.uuidString
        direktNachRegistrierungEingeloggt = true
        gespeicherteEmail = bereinigteEmail
        registrierungsArt = art

        if profil.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profil.email = bereinigteEmail
        }
    }

    private func erstelleDossierFallsNoetig(fuer profil: ProfilModell, email: String) {
        if let vorhandeneDossierID = profil.dossierID {
            aktivesDossierID = vorhandeneDossierID.uuidString
            return
        }

        let titelName = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let neuesDossier = DossierModell(
            besitzerUserID: profil.userID,
            vorsorgendePersonName: titelName.isEmpty ? "mir" : titelName
        )

        modelContext.insert(neuesDossier)
        profil.dossierID = neuesDossier.dossierID
        aktivesDossierID = neuesDossier.dossierID.uuidString
    }


    private func captchaNeuLaden() {
        captchaAntwort = ""
        captchaZahl1 = Int.random(in: 2...9)
        captchaZahl2 = Int.random(in: 2...9)
    }
}

#Preview {
    Registrierung()
        .modelContainer(for: [ProfilModell.self, DossierModell.self, DossierZugriffModell.self], inMemory: true)
}
