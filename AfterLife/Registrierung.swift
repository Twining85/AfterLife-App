import SwiftUI
import SwiftData
import AuthenticationServices

struct Registrierung: View {
    init(einladungsToken: String? = nil) {
        _einladungsToken = State(initialValue: einladungsToken)
    }

    private enum Eingabefeld {
        case email
        case passwort
    }
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
            VStack(spacing: 24) {

                Text("Registrierung")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("E-Mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .focused($aktivesEingabefeld, equals: .email)

                    SecureField("Passwort", text: $passwort)
                        .textFieldStyle(.roundedBorder)
                        .focused($aktivesEingabefeld, equals: .passwort)
                }

                if !fehlermeldung.isEmpty {
                    Text(fehlermeldung)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if let zugriff = aktuellerDossierZugriff,
                   emailAbweichungSollAngezeigtWerden,
                   !eingeladeneEmailVerifiziert {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sicherheitsprüfung erforderlich")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Du kannst für die Registrierung grundsätzlich eine andere E-Mail-Adresse verwenden. Aus Sicherheitsgründen müssen wir jedoch kurz prüfen, dass wirklich die richtige Person diese persönliche Einladung annimmt.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Die Einladung wurde ursprünglich an \(zugriff.eingeladeneEmail) gesendet. Bitte bestätige kurz den Zugriff auf diese E-Mail-Adresse.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if emailVerifizierungWurdeGestartet {
                            #if DEBUG
                            Text("Testcode: \(emailVerifizierungCode)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            #endif

                            TextField("Verifizierungscode", text: $emailVerifizierungAntwort)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            Button("E-Mail-Adresse verifizieren") {
                                verifiziereEingeladeneEmail()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Code an eingeladene E-Mail senden") {
                                starteEingeladeneEmailVerifizierung()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if eingeladeneEmailVerifiziert {
                    Text("Eingeladene E-Mail-Adresse wurde verifiziert. Du kannst mit dieser Registrierungs-E-Mail fortfahren.")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $akzeptiertDisclaimer) {
                        Text("Ich akzeptiere den Haftungsausschluss.")
                            .font(.caption)
                    }

                    Text("""
                    AfterLife dient ausschliesslich der Organisation persönlicher Informationen und ersetzt keine Rechts-, Steuer-, Finanz- oder Vorsorgeberatung sowie keine rechtsgültigen Dokumente wie Testamente, Erbverträge, Vorsorgeaufträge oder Patientenverfügungen. Die Nutzung erfolgt in eigener Verantwortung.
                    """)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verifizierung, ich bin ein Mensch")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack(spacing: 12) {
                            Text("Was ist \(captchaZahl1) + \(captchaZahl2)?")
                                .font(.caption)

                            TextField("Antwort", text: $captchaAntwort)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }

                        if !captchaAntwort.isEmpty && !captchaIstGueltig {
                            Text("Die Antwort ist nicht korrekt.")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button("Mit E-Mail registrieren") {
                    registrierenMitEmail()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!registrierungErlaubt)

                SignInWithAppleButton(.signUp) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    guard akzeptiertDisclaimer else {
                        fehlermeldung = "Bitte akzeptiere zuerst den Haftungsausschluss."
                        return
                    }

                    guard captchaIstGueltig else {
                        fehlermeldung = "Bitte löse das Captcha korrekt."
                        captchaNeuLaden()
                        return
                    }

                    switch result {
                    case .success(let authorization):
                        let appleEmail = appleEmailAusAuthorization(authorization)
                        gespeicherteEmail = appleEmail
                        gespeichertesPasswort = ""
                        registrierungsArt = "Apple ID"
                        speichereRegistrierungsdaten(art: "Apple ID", email: appleEmail)
                        showHome = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            direktNachRegistrierungEingeloggt = true
                            profilIstVorhanden = true
                        }
                    case .failure:
                        fehlermeldung = "Apple Login konnte nicht abgeschlossen werden."
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .disabled(!registrierungErlaubt)

                Button {
                    googleLogin()
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Mit Google anmelden")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(height: 50)
                .disabled(!registrierungErlaubt)

                Spacer()

                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70)
                    .opacity(0.55)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            }
            .padding()
            .navigationDestination(isPresented: $showHome) {
                Home()
            }
        }
    }

    private var registrierungErlaubt: Bool {
        akzeptiertDisclaimer && captchaIstGueltig
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

    private var registrierungsEmailIstFormalGueltig: Bool {
        bereinigteRegistrierungsEmail.contains("@") && bereinigteRegistrierungsEmail.contains(".")
    }

    private var bereinigteEingeladeneEmail: String? {
        aktuellerDossierZugriff?.eingeladeneEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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

        guard email.contains("@"), email.contains(".") else {
            fehlermeldung = "Bitte gib eine gültige E-Mail-Adresse ein."
            return
        }

        guard passwort.count >= 8 else {
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

        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try KeychainHelper.shared.save(
                passwort,
                service: "AfterLife.Login",
                account: bereinigteEmail
            )

            gespeicherteEmail = bereinigteEmail
            gespeichertesPasswort = passwort
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

    private func googleLogin() {
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

        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        gespeicherteEmail = bereinigteEmail
        gespeichertesPasswort = ""
        registrierungsArt = "Google"

        speichereRegistrierungsdaten(art: "Google", email: bereinigteEmail)
        showHome = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            direktNachRegistrierungEingeloggt = true
            profilIstVorhanden = true
        }
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

    private func appleEmailAusAuthorization(_ authorization: ASAuthorization) -> String {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return email.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let appleEmail = credential.email, !appleEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return appleEmail
        }

        return email.trimmingCharacters(in: .whitespacesAndNewlines)
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
