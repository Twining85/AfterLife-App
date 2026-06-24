//
//  Relogin.swift
//  AfterLife
//
//  Created by René Engeler on 18.06.2026.
//

import SwiftUI
import SwiftData
import LocalAuthentication
import AuthenticationServices

struct ReloginView: View {

    @Query private var gespeicherteProfile: [ProfilModell]

    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var appStorageEmail = ""
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false

    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    @State private var istEingeloggt = false
    @State private var zeigtEmailLogin = true
    @State private var showPassword = false
    @State private var biometrieLoginLaeuft = false

    private let loginFuerTestsUeberspringen = false

    private var profil: ProfilModell? {
        gespeicherteProfile.first
    }

    private var registrierungsEmail: String {
        let emailAusProfil = profil?.registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let profilEmail = profil?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appEmail = appStorageEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        if !emailAusProfil.isEmpty { return emailAusProfil }
        if !profilEmail.isEmpty { return profilEmail }
        return appEmail
    }

    private var registrierungsArt: String {
        let art = profil?.registrierungsart.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return art.isEmpty ? "E-Mail" : art
    }

    private var biometrieAktiviert: Bool {
        profil?.biometrieAktiviert ?? false
    }

    private var hatBestehendenLogin: Bool {
        profilIstVorhanden || !registrierungsEmail.isEmpty || profil != nil
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
                if direktNachRegistrierungEingeloggt {
                    direktNachRegistrierungEingeloggt = false
                    istEingeloggt = true
                    return
                }

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

            if biometrieAktiviert {
                Button {
                    loginMitFaceID()
                } label: {
                    Label("Mit Face ID anmelden", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }

            if zeigtEmailLogin {
                emailLoginBereich
            }

            alternativeLoginBereiche

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

    private var emailLoginBereich: some View {
        VStack(spacing: 16) {
            TextField("E-Mail", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            HStack {
                if showPassword {
                    TextField("Passwort", text: $passwort)
                } else {
                    SecureField("Passwort", text: $passwort)
                }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.35))
            )

            Button("Mit E-Mail und Passwort anmelden") {
                loginMitEmailUndPasswort()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    private var alternativeLoginBereiche: some View {
        VStack(spacing: 12) {
            if registrierungsArt == "Apple" || registrierungsArt == "Apple ID" {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email]
                } onCompletion: { result in
                    switch result {
                    case .success:
                        istEingeloggt = true
                        fehlermeldung = ""
                    case .failure:
                        fehlermeldung = "Apple Login konnte nicht abgeschlossen werden."
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .padding(.horizontal)
            }

            if registrierungsArt == "Google" {
                Button {
                    loginMitGoogle()
                } label: {
                    Label("Mit Google anmelden", systemImage: "g.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
        }
    }

    private func bereiteLoginBeimStartVor() {
        guard hatBestehendenLogin else {
            zeigtEmailLogin = false
            return
        }

        email = registrierungsEmail
        passwort = ""
        zeigtEmailLogin = true
        fehlermeldung = ""
    }

    private func loginMitFaceID(zeigeFehlerBeiAbbruch: Bool = true) {
        guard biometrieAktiviert else {
            zeigtEmailLogin = true
            if zeigeFehlerBeiAbbruch {
                fehlermeldung = "Biometrische Anmeldung ist nicht aktiviert."
            }
            return
        }

        guard !biometrieLoginLaeuft else { return }
        biometrieLoginLaeuft = true

        let context = LAContext()
        context.localizedCancelTitle = "E-Mail Login verwenden"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometrieLoginLaeuft = false
            zeigtEmailLogin = true
            if zeigeFehlerBeiAbbruch {
                fehlermeldung = "Face ID ist nicht verfügbar. Bitte melde dich mit E-Mail und Passwort an."
            }
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Melde dich sicher mit Face ID bei AfterLife an."
        ) { success, authenticationError in
            DispatchQueue.main.async {
                biometrieLoginLaeuft = false

                if success {
                    istEingeloggt = true
                    fehlermeldung = ""
                    return
                }

                zeigtEmailLogin = true

                guard zeigeFehlerBeiAbbruch else { return }

                if let laError = authenticationError as? LAError {
                    switch laError.code {
                    case .userCancel, .systemCancel, .appCancel:
                        fehlermeldung = ""
                    case .userFallback:
                        fehlermeldung = "Bitte melde dich mit E-Mail und Passwort an."
                    case .biometryLockout:
                        fehlermeldung = "Face ID ist vorübergehend gesperrt. Bitte entsperre dein Gerät und melde dich danach erneut an."
                    case .biometryNotAvailable:
                        fehlermeldung = "Face ID ist auf diesem Gerät nicht verfügbar."
                    case .biometryNotEnrolled:
                        fehlermeldung = "Face ID ist auf diesem Gerät noch nicht eingerichtet."
                    default:
                        fehlermeldung = "Face ID konnte nicht bestätigt werden. Bitte melde dich mit E-Mail und Passwort an."
                    }
                } else {
                    fehlermeldung = "Face ID konnte nicht bestätigt werden. Bitte melde dich mit E-Mail und Passwort an."
                }
            }
        }
    }

    private func loginMitEmailUndPasswort() {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let gespeicherteBereinigteEmail = registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !bereinigteEmail.isEmpty, !passwort.isEmpty else {
            fehlermeldung = "Bitte E-Mail und Passwort eingeben."
            return
        }

        guard bereinigteEmail == gespeicherteBereinigteEmail else {
            fehlermeldung = "E-Mail oder Passwort ist nicht korrekt."
            return
        }

        do {
            let gespeichertesKeychainPasswort = try KeychainHelper.shared.read(
                service: "AfterLife.Login",
                account: registrierungsEmail
            )

            guard passwort == gespeichertesKeychainPasswort else {
                fehlermeldung = "E-Mail oder Passwort ist nicht korrekt."
                return
            }

            fehlermeldung = ""
            istEingeloggt = true
        } catch {
            fehlermeldung = "Login-Daten konnten nicht sicher gelesen werden. Bitte registriere dich erneut."
        }
    }

    private func loginMitGoogle() {
        guard registrierungsArt == "Google" else {
            fehlermeldung = "Dieses Profil wurde nicht mit Google registriert."
            return
        }

        fehlermeldung = ""
        istEingeloggt = true
    }
}

#Preview {
    ReloginView()
        .modelContainer(for: [ProfilModell.self], inMemory: true)
}
