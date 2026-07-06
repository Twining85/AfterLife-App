//
//  EinladungEmailVerifizierung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI
import SwiftData

struct EinladungEmailVerifizierung: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]

    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("gespeicherteEmail") private var appStorageEmail = ""

    let eingeladeneEmail: String
    let einladungsToken: String

    @State private var eingegebenerCode = ""
    @State private var codeWurdeGesendet = false
    @State private var verifizierungErfolgreich = false
    @State private var fehlermeldung = ""
    @State private var simulierterCode = ""
    @State private var einladungBereitsGeprueft = false

    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let kartenFarbe = Color.white.opacity(0.88)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let akzentHell = Color(red: 0.16, green: 0.36, blue: 0.42).opacity(0.12)
    private let textFarbe = Color.black.opacity(0.86)
    private let sekundTextFarbe = Color.black.opacity(0.58)

    var body: some View {
        NavigationStack {
            ZStack {
                hintergrundFarbe
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroBild

                        VStack(spacing: 16) {
                            kopfBereich
                            emailInfoKarte

                            if emailStimmtUeberein || verifizierungErfolgreich {
                                erfolgreichAnsicht
                            } else {
                                zusaetzlicheVerifizierungAnsicht
                            }

                            if !fehlermeldung.isEmpty {
                                warnHinweis(text: fehlermeldung)
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
                        .padding(.bottom, 18)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Einladung")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                pruefeEinladungBeimStart()
            }
        }
    }

    private var aktuellesProfil: ProfilModell? {
        if let aktiveID = UUID(uuidString: aktiveUserID),
           let profil = gespeicherteProfile.first(where: { $0.userID == aktiveID }) {
            return profil
        }

        return gespeicherteProfile.first
    }

    private var aktuellerDossierZugriff: DossierZugriffModell? {
        gespeicherteDossierZugriffe.first {
            $0.einladungsToken == einladungsToken
        }
    }

    private var profilEmail: String {
        let emailAusProfil = aktuellesProfil?.registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normaleProfilEmail = aktuellesProfil?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let gespeicherteEmail = appStorageEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        if !emailAusProfil.isEmpty { return emailAusProfil }
        if !normaleProfilEmail.isEmpty { return normaleProfilEmail }
        return gespeicherteEmail
    }

    private var bereinigteProfilEmail: String {
        profilEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var bereinigteEingeladeneEmail: String {
        eingeladeneEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var emailStimmtUeberein: Bool {
        !bereinigteProfilEmail.isEmpty &&
        !bereinigteEingeladeneEmail.isEmpty &&
        bereinigteProfilEmail == bereinigteEingeladeneEmail
    }

    private var kopfBereich: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(akzentHell)
                    .frame(width: 58, height: 58)

                Image(systemName: emailStimmtUeberein || verifizierungErfolgreich ? "checkmark.seal.fill" : "envelope.badge.shield.leadinghalf.filled")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(akzentFarbe)
            }

            VStack(spacing: 6) {
                Text("E-Mail prüfen")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(textFarbe)
                    .multilineTextAlignment(.center)

                Text("Wir prüfen, ob dein Profil zur Einladung passt. Falls du eine andere E-Mail nutzt, bestätigst du kurz die ursprünglich eingeladene Adresse.")
                    .font(.subheadline)
                    .foregroundStyle(sekundTextFarbe)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
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

    private var emailInfoKarte: some View {
        VStack(alignment: .leading, spacing: 10) {
            emailZeile(
                icon: "envelope.fill",
                titel: "E-Mail der Einladung",
                wert: eingeladeneEmail.isEmpty ? "Nicht gefunden" : eingeladeneEmail
            )

            emailZeile(
                icon: "person.crop.circle.fill",
                titel: "E-Mail deines Profils",
                wert: profilEmail.isEmpty ? "Nicht gefunden" : profilEmail
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private func emailZeile(icon: String, titel: String, wert: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(akzentFarbe)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(titel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(sekundTextFarbe)

                Text(wert)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(textFarbe)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var erfolgreichAnsicht: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(akzentFarbe)

            Text("Einladung bestätigt")
                .font(.headline)
                .foregroundStyle(textFarbe)

            Text(emailStimmtUeberein ? "Die E-Mail deines Profils stimmt mit der Einladung überein. Die Einladung wurde angenommen." : "Die ursprünglich eingeladene E-Mail-Adresse wurde bestätigt. Die Einladung wurde angenommen.")
                .font(.subheadline)
                .foregroundStyle(sekundTextFarbe)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            NavigationLink {
                Home()
            } label: {
                Text("Weiter zu Tschlüssli")
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
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private var zusaetzlicheVerifizierungAnsicht: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text("E-Mail stimmt nicht mit der Einladung überein")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)

                    Text("Du meldest dich mit einem bestehenden Profil an, dessen E-Mail von der Einladung abweicht. Bitte verifiziere die ursprünglich eingeladene E-Mail-Adresse.")
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if codeWurdeGesendet {
                VStack(spacing: 10) {
                    #if DEBUG
                    Text("Testcode: \(simulierterCode)")
                        .font(.caption.monospaced())
                        .foregroundStyle(sekundTextFarbe)
                        .textSelection(.enabled)
                    #endif

                    TextField("6-stelliger Code", text: $eingegebenerCode)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
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

                    Button {
                        pruefeCode()
                    } label: {
                        Text("E-Mail-Adresse verifizieren")
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
            } else {
                Button {
                    sendeCode()
                } label: {
                    Text("Code an eingeladene E-Mail senden")
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
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.20), lineWidth: 1)
        )
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

    private func pruefeEinladungBeimStart() {
        guard !einladungBereitsGeprueft else { return }
        einladungBereitsGeprueft = true
        fehlermeldung = ""

        guard aktuellesProfil != nil else {
            fehlermeldung = "Es wurde kein bestehendes Profil gefunden."
            return
        }

        guard !bereinigteEingeladeneEmail.isEmpty else {
            fehlermeldung = "Die eingeladene E-Mail-Adresse konnte nicht gelesen werden."
            return
        }

        guard !bereinigteProfilEmail.isEmpty else {
            fehlermeldung = "Die E-Mail deines Profils konnte nicht gelesen werden."
            return
        }

        if emailStimmtUeberein {
            einladungAnnehmen()
        }
    }

    private func sendeCode() {
        simulierterCode = String(Int.random(in: 100000...999999))
        eingegebenerCode = ""
        codeWurdeGesendet = true
        fehlermeldung = ""
    }

    private func pruefeCode() {
        guard eingegebenerCode.trimmingCharacters(in: .whitespacesAndNewlines) == simulierterCode else {
            fehlermeldung = "Der Verifizierungscode ist nicht korrekt."
            return
        }

        einladungAnnehmen()
    }

    private func einladungAnnehmen() {
        guard let profil = aktuellesProfil else {
            fehlermeldung = "Es wurde kein bestehendes Profil gefunden."
            return
        }

        guard let zugriff = aktuellerDossierZugriff else {
            fehlermeldung = "Diese Einladung konnte nicht gefunden werden."
            return
        }

        guard zugriff.kannRegistrierungFortsetzen else {
            fehlermeldung = "Diese Einladung ist ungültig oder wurde bereits verwendet."
            return
        }

        zugriff.einladungAnnehmen(
            vertrauenspersonUserID: profil.userID,
            registrierungsEmail: profilEmail
        )

        do {
            try modelContext.save()
            verifizierungErfolgreich = true
            fehlermeldung = ""
        } catch {
            fehlermeldung = "Die Einladung konnte nicht gespeichert werden. Bitte versuche es erneut."
        }
    }
}

#Preview {
    EinladungEmailVerifizierung(
        eingeladeneEmail: "vertrauensperson@mail.ch",
        einladungsToken: "test-token-123"
    )
    .modelContainer(for: [ProfilModell.self, DossierZugriffModell.self], inMemory: true)
}
