//
//  Relogin.swift
//  AfterLife
//
//  Created by René Engeler on 18.06.2026.
//

import SwiftUI
import SwiftData
import LocalAuthentication

struct ReloginView: View {

    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let kartenFarbe = Color.white.opacity(0.86)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let textFarbe = Color.black.opacity(0.86)
    private let sekundTextFarbe = Color.black.opacity(0.58)

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
        ZStack {
            hintergrundFarbe
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .accessibilityHidden(true)
                    .padding(.top, -52)

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(akzentFarbe.opacity(0.12))
                            .frame(width: 86, height: 86)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                    }

                    VStack(spacing: 8) {
                        Text("Willkommen zurück")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(textFarbe)
                            .multilineTextAlignment(.center)

                        Text("Melde dich an, um sicher auf dein Tschlüssli-Dossier zuzugreifen.")
                            .font(.body)
                            .foregroundStyle(sekundTextFarbe)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    if biometrieAktiviert {
                        Button {
                            loginMitFaceID()
                        } label: {
                            Label("Mit Face ID anmelden", systemImage: "faceid")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(akzentFarbe)
                    }

                    if zeigtEmailLogin {
                        emailLoginBereich
                    }

                    if !fehlermeldung.isEmpty {
                        Text(fehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(kartenFarbe)
                        .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
                .padding(.horizontal, 22)
                .padding(.top, -8)

                Text("Deine Angaben bleiben geschützt und sind nur nach erfolgreicher Anmeldung sichtbar.")
                    .font(.footnote)
                    .foregroundStyle(sekundTextFarbe)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 72)
            }
        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emailLoginBereich: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("E-Mail")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(textFarbe)

                TextField("deine.email@beispiel.ch", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(akzentFarbe.opacity(0.18), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Passwort")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(textFarbe)

                HStack(spacing: 10) {
                    if showPassword {
                        TextField("Passwort", text: $passwort)
                    } else {
                        SecureField("Passwort", text: $passwort)
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(akzentFarbe.opacity(0.85))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(akzentFarbe.opacity(0.18), lineWidth: 1)
                )
            }

            Button {
                loginMitEmailUndPasswort()
            } label: {
                Text("Mit E-Mail anmelden")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(akzentFarbe)
            )
            .padding(.top, 4)
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
            localizedReason: "Melde dich sicher mit Face ID bei Tschlüssli an."
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
}

#Preview {
    ReloginView()
        .modelContainer(for: [ProfilModell.self], inMemory: true)
}
