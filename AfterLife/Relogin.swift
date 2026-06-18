//
//  Relogin.swift
//  AfterLife
//
//  Created by René Engeler on 18.06.2026.
//

import SwiftUI
import LocalAuthentication

struct ReloginView: View {

    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""

    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    private let loginFuerTestsUeberspringen = false

    @State private var istEingeloggt = false
    @State private var zeigtEmailLogin = true

    private var hatBestehendenLogin: Bool {
        profilIstVorhanden || (!gespeicherteEmail.isEmpty && !gespeichertesPasswort.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Group {
                if istEingeloggt {
                    Home()
                } else if hatBestehendenLogin {
                    loginAnsicht
                } else {
                    Registrierung()
                }
            }
            .onAppear {
                if loginFuerTestsUeberspringen {
                    istEingeloggt = true
                } else {
                    bereiteLoginBeimStartVor()
                }
            }
        }
    }

    private var loginAnsicht: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Willkommen zurück")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Melde dich an, um auf dein AfterLife-Dossier zuzugreifen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if zeigtEmailLogin {
                VStack(spacing: 16) {
                    TextField("E-Mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Passwort", text: $passwort)
                        .textFieldStyle(.roundedBorder)

                    Button("Mit E-Mail und Passwort anmelden") {
                        loginMitEmailUndPasswort()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }

            Button {
                loginMitFaceID()
            } label: {
                Label("Alternativ mit Face ID anmelden", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            if !fehlermeldung.isEmpty {
                Text(fehlermeldung)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("Login")
    }

    private func bereiteLoginBeimStartVor() {
        guard hatBestehendenLogin else {
            zeigtEmailLogin = false
            return
        }

        email = gespeicherteEmail
        passwort = ""
        zeigtEmailLogin = true
        fehlermeldung = ""
    }

    private func loginMitFaceID() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            zeigtEmailLogin = true
            fehlermeldung = "Face ID ist nicht verfügbar. Bitte melde dich mit E-Mail und Passwort an."
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Melde dich sicher mit Face ID bei AfterLife an."
        ) { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    istEingeloggt = true
                    fehlermeldung = ""
                } else {
                    zeigtEmailLogin = true
                    fehlermeldung = "Face ID konnte nicht bestätigt werden. Bitte melde dich mit E-Mail und Passwort an."
                }
            }
        }
    }

    private func loginMitEmailUndPasswort() {
        guard !email.isEmpty, !passwort.isEmpty else {
            fehlermeldung = "Bitte E-Mail und Passwort eingeben."
            return
        }

        guard email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == gespeicherteEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              passwort == gespeichertesPasswort else {
            fehlermeldung = "E-Mail oder Passwort ist nicht korrekt."
            return
        }

        fehlermeldung = ""
        istEingeloggt = true
    }
}

#Preview {
    ReloginView()
}
