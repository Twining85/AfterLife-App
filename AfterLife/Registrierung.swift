import SwiftUI
import SwiftData
import AuthenticationServices

struct Registrierung: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    @State private var showHome = false
    @State private var akzeptiertDisclaimer = false
    @State private var captchaAntwort = ""
    @State private var captchaZahl1 = Int.random(in: 2...9)
    @State private var captchaZahl2 = Int.random(in: 2...9)

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

                    SecureField("Passwort", text: $passwort)
                        .textFieldStyle(.roundedBorder)
                }

                if !fehlermeldung.isEmpty {
                    Text(fehlermeldung)
                        .foregroundStyle(.red)
                        .font(.footnote)
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
        let profil: ProfilModell

        if let vorhandenesProfil = gespeicherteProfile.first {
            profil = vorhandenesProfil
        } else {
            let neuesProfil = ProfilModell()
            modelContext.insert(neuesProfil)
            profil = neuesProfil
        }

        profil.registrierungsart = art
        profil.registrierungsEmail = bereinigteEmail
        direktNachRegistrierungEingeloggt = true
        gespeicherteEmail = bereinigteEmail
        registrierungsArt = art

        if profil.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profil.email = bereinigteEmail
        }
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
        .modelContainer(for: [ProfilModell.self], inMemory: true)
}
