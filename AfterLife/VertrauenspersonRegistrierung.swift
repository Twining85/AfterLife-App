//
//  VertrauenspersonRegistrierung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct VertrauenspersonRegistrierung: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]

    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""

    // Simulation: Diese E-Mail kommt später aus dem Einladungs-Token.
    private let einladungsEmail = "vertrauensperson@mail.ch"

    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    @State private var showHome = false
    @State private var showEinladungEmailVerifizierung = false
    @State private var bestaetigungEmailAenderungAnzeigen = false
    @State private var pendingRegistrierungsArt = "E-Mail"
    @State private var pendingRegistrierungsEmail = ""
    @State private var pendingPasswort = ""

    @State private var akzeptiertDisclaimer = false
    @State private var captchaAntwort = ""
    @State private var captchaZahl1 = Int.random(in: 2...9)
    @State private var captchaZahl2 = Int.random(in: 2...9)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Registrierung als Vertrauensperson")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-Mail aus der Einladung")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(einladungsEmail)
                            .font(.headline)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(spacing: 16) {
                        TextField("E-Mail", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("Passwort", text: $passwort)
                            .textFieldStyle(.roundedBorder)
                    }

                    if emailWurdeGeaendert {
                        Text("Du verwendest eine andere E-Mail-Adresse als jene, an welche die Einladung gesendet wurde. Beim Registrieren ist deshalb eine zusätzliche Bestätigung nötig.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    if !fehlermeldung.isEmpty {
                        Text(fehlermeldung)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
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
                            vorbereitenUndAbschliessen(art: "Apple ID", email: appleEmail, passwort: "")
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

                    Image("Icon1_trans")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70)
                        .opacity(0.55)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationDestination(isPresented: $showHome) {
                Home()
            }
            .navigationDestination(isPresented: $showEinladungEmailVerifizierung) {
                EinladungEmailVerifizierung()
            }
            .alert("E-Mail-Adresse ändern?", isPresented: $bestaetigungEmailAenderungAnzeigen) {
                Button("Abbrechen", role: .cancel) {
                    pendingRegistrierungsArt = "E-Mail"
                    pendingRegistrierungsEmail = ""
                    pendingPasswort = ""
                }

                Button("Ja, E-Mail ändern") {
                    registrierungAbschliessen(
                        art: pendingRegistrierungsArt,
                        email: pendingRegistrierungsEmail,
                        passwort: pendingPasswort,
                        benoetigtEinladungsVerifizierung: true
                    )
                }
            } message: {
                Text("Du wurdest über \(einladungsEmail) als Vertrauensperson eingeladen. Du möchtest dein Profil mit einer anderen E-Mail-Adresse registrieren. Damit wir sicherstellen können, dass die Einladung tatsächlich für dich bestimmt ist, musst du im nächsten Schritt bestätigen, dass du Zugriff auf die ursprünglich eingeladene E-Mail-Adresse hast.")
            }
            .onAppear {
                if email.isEmpty {
                    email = einladungsEmail
                }
            }
        }
    }

    private var registrierungErlaubt: Bool {
        akzeptiertDisclaimer && captchaIstGueltig
    }

    private var captchaIstGueltig: Bool {
        Int(captchaAntwort.trimmingCharacters(in: .whitespacesAndNewlines)) == captchaZahl1 + captchaZahl2
    }

    private var emailWurdeGeaendert: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != einladungsEmail.lowercased()
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
        vorbereitenUndAbschliessen(art: "E-Mail", email: bereinigteEmail, passwort: passwort)
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
        vorbereitenUndAbschliessen(art: "Google", email: bereinigteEmail, passwort: "")
    }

    private func vorbereitenUndAbschliessen(art: String, email: String, passwort: String) {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !bereinigteEmail.isEmpty else {
            fehlermeldung = "Bitte gib eine gültige E-Mail-Adresse ein."
            return
        }

        if bereinigteEmail.lowercased() == einladungsEmail.lowercased() {
            registrierungAbschliessen(
                art: art,
                email: bereinigteEmail,
                passwort: passwort,
                benoetigtEinladungsVerifizierung: false
            )
        } else {
            pendingRegistrierungsArt = art
            pendingRegistrierungsEmail = bereinigteEmail
            pendingPasswort = passwort
            bestaetigungEmailAenderungAnzeigen = true
        }
    }

    private func registrierungAbschliessen(art: String, email: String, passwort: String, benoetigtEinladungsVerifizierung: Bool) {
        do {
            if art == "E-Mail" {
                try KeychainHelper.shared.save(
                    passwort,
                    service: "AfterLife.Login",
                    account: email
                )
            }

            gespeicherteEmail = email
            gespeichertesPasswort = art == "E-Mail" ? passwort : ""
            registrierungsArt = art

            speichereRegistrierungsdaten(art: art, email: email)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                direktNachRegistrierungEingeloggt = true
                profilIstVorhanden = true
            }

            if benoetigtEinladungsVerifizierung {
                showEinladungEmailVerifizierung = true
            } else {
                showHome = true
            }
        } catch {
            fehlermeldung = "Das Passwort konnte nicht sicher gespeichert werden. Bitte versuche es erneut."
        }
    }

    private func speichereRegistrierungsdaten(art: String, email: String) {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let profil = ProfilModell()
        modelContext.insert(profil)

        profil.registrierungsart = art
        profil.registrierungsEmail = bereinigteEmail
        profil.istVertrauensperson = true
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
    VertrauenspersonRegistrierung()
        .modelContainer(for: [ProfilModell.self, DossierModell.self], inMemory: true)
}
