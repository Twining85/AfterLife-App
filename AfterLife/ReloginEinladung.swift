//
//  RegistrierungEinladung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//


//
//  ReloginEinladung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI
import SwiftData
import LocalAuthentication

struct ReloginEinladung: View {
    let eingeladeneEmail: String
    let einladungsToken: String

    init(eingeladeneEmail: String = "", einladungsToken: String = "") {
        self.eingeladeneEmail = eingeladeneEmail
        self.einladungsToken = einladungsToken
    }

    @Query private var gespeicherteProfile: [ProfilModell]

    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var appStorageEmail = ""

    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    @State private var istEingeloggt = false
    @State private var zeigtEmailLogin = true
    @State private var showPassword = false
    @State private var biometrieLoginLaeuft = false

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
                    EinladungEmailVerifizierung()
                } else if hatBestehendenLogin {
                    loginAnsicht
                } else {
                    keinBestehendesProfilAnsicht
                }
            }
            .onAppear {
                bereiteLoginBeimStartVor()
            }
        }
    }

    private var loginAnsicht: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Bestehendes Profil")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Melde dich mit deinem bestehenden Profil an, um die Einladung als Vertrauensperson zu prüfen.")
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


            if !fehlermeldung.isEmpty {
                Text(fehlermeldung)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("Einladung")
    }

    private var keinBestehendesProfilAnsicht: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("Icon1_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .opacity(0.65)

            Text("Kein bestehendes Profil gefunden")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Auf diesem Gerät wurde noch kein bestehendes Profil gefunden. Bitte gehe zurück und erstelle ein neues Profil für die Einladung.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Einladung")
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

}

#Preview {
    ReloginEinladung(
        eingeladeneEmail: "vertrauensperson@mail.ch",
        einladungsToken: "test-token-123"
    )
    .modelContainer(for: [ProfilModell.self, DossierZugriffModell.self], inMemory: true)
}
