//
//  EinladungEmailVerifizierung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//


//
//  EinladungEmailVerifizierung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI
import SwiftData

struct EinladungEmailVerifizierung: View {

    @Query private var gespeicherteProfile: [ProfilModell]
    @AppStorage("gespeicherteEmail") private var appStorageEmail = ""

    // Simulation: Diese E-Mail kommt später aus dem Einladungs-Token.
    private let eingeladeneEmail = "vertrauensperson@mail.ch"
    private let simulierterCode = "123456"

    @State private var eingegebenerCode = ""
    @State private var codeWurdeGesendet = false
    @State private var verifizierungErfolgreich = false
    @State private var fehlermeldung = ""

    private var profil: ProfilModell? {
        gespeicherteProfile.first
    }

    private var profilEmail: String {
        let emailAusProfil = profil?.registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normaleProfilEmail = profil?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let gespeicherteEmail = appStorageEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        if !emailAusProfil.isEmpty { return emailAusProfil }
        if !normaleProfilEmail.isEmpty { return normaleProfilEmail }
        return gespeicherteEmail
    }

    private var emailStimmtUeberein: Bool {
        profilEmail.lowercased() == eingeladeneEmail.lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {

                    Image("Icon1_trans")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .padding(.top, 30)

                    VStack(spacing: 10) {
                        Text("E-Mail bestätigen")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Wir prüfen, ob dieses Profil zur Einladung gehört.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        emailZeile(titel: "E-Mail der Einladung", wert: eingeladeneEmail)
                        emailZeile(titel: "E-Mail deines Profils", wert: profilEmail.isEmpty ? "Nicht gefunden" : profilEmail)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Divider()

                    if verifizierungErfolgreich || emailStimmtUeberein {
                        erfolgreichAnsicht
                    } else {
                        zusaetzlicheVerifizierungAnsicht
                    }

                    if !fehlermeldung.isEmpty {
                        Text(fehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Einladung")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func emailZeile(titel: String, wert: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(wert)
                .font(.headline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var erfolgreichAnsicht: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("E-Mail bestätigt")
                .font(.headline)

            Text("Die Einladung kann mit diesem Profil verknüpft werden.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                Home()
            } label: {
                Text("Registrierung abschliessen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var zusaetzlicheVerifizierungAnsicht: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Zusätzliche Bestätigung nötig")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Dieses Profil verwendet eine andere E-Mail-Adresse als die Einladung. Bitte bestätige, dass du Zugriff auf die eingeladene E-Mail-Adresse hast.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if codeWurdeGesendet {
                VStack(spacing: 12) {
                    Text("Simulierter Bestätigungscode: \(simulierterCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Bestätigungscode", text: $eingegebenerCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)

                    Button {
                        pruefeCode()
                    } label: {
                        Text("Code bestätigen")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            } else {
                Button {
                    sendeCode()
                } label: {
                    Text("Code an Einladungs-E-Mail senden")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func sendeCode() {
        codeWurdeGesendet = true
        fehlermeldung = ""
    }

    private func pruefeCode() {
        let bereinigterCode = eingegebenerCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard bereinigterCode == simulierterCode else {
            fehlermeldung = "Der eingegebene Code ist nicht korrekt."
            return
        }

        fehlermeldung = ""
        verifizierungErfolgreich = true
    }
}

#Preview {
    EinladungEmailVerifizierung()
        .modelContainer(for: [ProfilModell.self], inMemory: true)
}
