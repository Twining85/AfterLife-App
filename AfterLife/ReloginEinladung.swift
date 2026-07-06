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
    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let kartenFarbe = Color.white.opacity(0.88)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let akzentHell = Color(red: 0.16, green: 0.36, blue: 0.42).opacity(0.12)
    private let textFarbe = Color.black.opacity(0.86)
    private let sekundTextFarbe = Color.black.opacity(0.58)
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
                    EinladungEmailVerifizierung(
                        eingeladeneEmail: eingeladeneEmail,
                        einladungsToken: einladungsToken
                    )
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
        ZStack {
            hintergrundFarbe
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroBild

                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(akzentHell)
                                    .frame(width: 58, height: 58)

                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(akzentFarbe)
                            }

                            VStack(spacing: 6) {
                                Text("Bestehendes Profil")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(textFarbe)
                                    .multilineTextAlignment(.center)

                                Text("Melde dich mit deinem bestehenden Profil an, um die Einladung als Vertrauensperson zu prüfen.")
                                    .font(.subheadline)
                                    .foregroundStyle(sekundTextFarbe)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                            }
                        }

                        if biometrieAktiviert {
                            Button {
                                loginMitFaceID()
                            } label: {
                                Label("Mit Face ID anmelden", systemImage: "faceid")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(akzentFarbe)
                            )
                        }

                        if zeigtEmailLogin {
                            emailLoginBereich
                        }

                        if !fehlermeldung.isEmpty {
                            warnHinweis(text: fehlermeldung)
                        }

                        Text("Die Einladung bleibt an die ursprünglich eingeladene E-Mail-Adresse gebunden und wird nach dem Login geprüft.")
                            .font(.caption)
                            .foregroundStyle(sekundTextFarbe)
                            .multilineTextAlignment(.center)
                            .lineSpacing(1)
                            .padding(.horizontal, 4)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(kartenFarbe)
                            .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Einladung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var keinBestehendesProfilAnsicht: some View {
        ZStack {
            hintergrundFarbe
                .ignoresSafeArea()

            VStack(spacing: 14) {
                heroBild

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(akzentHell)
                            .frame(width: 58, height: 58)

                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                    }

                    VStack(spacing: 6) {
                        Text("Kein bestehendes Profil gefunden")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(textFarbe)
                            .multilineTextAlignment(.center)

                        Text("Auf diesem Gerät wurde noch kein bestehendes Profil gefunden. Bitte gehe zurück und erstelle ein neues Profil für die Einladung.")
                            .font(.subheadline)
                            .foregroundStyle(sekundTextFarbe)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(kartenFarbe)
                        .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .navigationTitle("Einladung")
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
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(akzentFarbe)
            )
            .padding(.top, 2)
        }
    }

    private var heroBild: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(kartenFarbe)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)

            Image("Home2")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.01),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )

            Image("Icon1_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
        }
        .frame(height: 150)
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
    }

    private func warnHinweis(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(width: 24)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.red.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.20), lineWidth: 1)
        )
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
    ReloginEinladung(
        eingeladeneEmail: "vertrauensperson@mail.ch",
        einladungsToken: "test-token-123"
    )
    .modelContainer(for: [ProfilModell.self, DossierZugriffModell.self], inMemory: true)
}
