//
//  EinladungAngenommen.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI
import SwiftData

struct EinladungAngenommen: View {
    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let kartenFarbe = Color.white.opacity(0.88)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let akzentHell = Color(red: 0.16, green: 0.36, blue: 0.42).opacity(0.12)
    private let textFarbe = Color.black.opacity(0.86)
    private let sekundTextFarbe = Color.black.opacity(0.58)
    @Environment(\.modelContext) private var modelContext
    @Query private var dossierZugriffe: [DossierZugriffModell]

    let einladenderName: String
    let eingeladeneEmail: String
    let einladungsToken: String

    @State private var einladungWurdeAngenommen = false
    @State private var einladungWurdeAbgelehnt = false
    @State private var bestaetigungAblehnenAnzeigen = false

    @State private var fehlermeldung = ""

    private var aktuellerDossierZugriff: DossierZugriffModell? {
        dossierZugriffe.first { zugriff in
            zugriff.einladungsToken == einladungsToken
        }
    }

    var body: some View {
        NavigationStack {
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

                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(akzentFarbe)
                                }

                                VStack(spacing: 6) {
                                    Text("Einladung als Vertrauensperson")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(textFarbe)
                                        .multilineTextAlignment(.center)

                                    Text("Du wurdest von \(einladenderName) als Vertrauensperson eingeladen.")
                                        .font(.subheadline)
                                        .foregroundStyle(sekundTextFarbe)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(2)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                einladungsInfoZeile(
                                    icon: "person.fill",
                                    titel: "Eingeladen von",
                                    wert: einladenderName
                                )

                                einladungsInfoZeile(
                                    icon: "envelope.fill",
                                    titel: "Gesendet an",
                                    wert: eingeladeneEmail
                                )
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(hintergrundFarbe.opacity(0.72))
                            )

                            if !fehlermeldung.isEmpty {
                                Text(fehlermeldung)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                            }

                            zustandsBereich

                            Text("Diese Einladung ist persönlich und kann nur einmal verwendet werden.")
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
            .alert("Einladung ablehnen?", isPresented: $bestaetigungAblehnenAnzeigen) {
                Button("Abbrechen", role: .cancel) {
                    bestaetigungAblehnenAnzeigen = false
                }

                Button("Einladung ablehnen", role: .destructive) {
                    einladungAblehnen()
                }
            } message: {
                Text("Möchtest du die Einladung als Vertrauensperson wirklich ablehnen? Danach verliert der Einladungslink seine Gültigkeit. Die vorsorgende Person wird über die Ablehnung informiert.")
            }
            .navigationTitle("Einladung")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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

    @ViewBuilder
    private var zustandsBereich: some View {
        if einladungWurdeAbgelehnt {
            statusKarte(
                icon: "xmark.circle.fill",
                titel: "Einladung abgelehnt",
                text: "Die Einladung wurde erfolgreich abgelehnt. Der Einladungslink wurde ungültig gemacht. Die vorsorgende Person wird über die Ablehnung informiert."
            )
        } else if einladungWurdeAngenommen {
            VStack(spacing: 16) {
                Text("Wie möchtest du fortfahren?")
                    .font(.title3.bold())
                    .foregroundStyle(textFarbe)

                fortfahrenKarte(
                    icon: "person.badge.plus",
                    titel: "Ich bin neu bei Tschlüssli",
                    text: "Erstelle ein neues Profil, um diese Einladung als Vertrauensperson anzunehmen.",
                    buttonTitel: "Profil erstellen",
                    istPrimaer: true
                ) {
                    VertrauenspersonRegistrierung(
                        eingeladeneEmail: eingeladeneEmail,
                        einladungsToken: einladungsToken
                    )
                }
                .padding(.vertical, 11)

                fortfahrenKarte(
                    icon: "person.crop.circle",
                    titel: "Ich habe bereits ein Profil",
                    text: "Melde dich mit deinem bestehenden Profil an, um die Einladung anzunehmen.",
                    buttonTitel: "Anmelden",
                    istPrimaer: false
                ) {
                    ReloginEinladung(
                        eingeladeneEmail: eingeladeneEmail,
                        einladungsToken: einladungsToken
                    )
                }
                .padding(.vertical, 11)
            }
            .padding(.top, 2)
        } else {
            VStack(spacing: 10) {
                Button {
                    einladungWurdeAngenommen = true
                } label: {
                    Text("Einladung annehmen und fortfahren")
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

                Button {
                    bestaetigungAblehnenAnzeigen = true
                } label: {
                    Text("Ablehnen")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(textFarbe)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(hintergrundFarbe.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(akzentFarbe.opacity(0.16), lineWidth: 1)
                )
            }
        }
    }

    private func einladungsInfoZeile(icon: String, titel: String, wert: String) -> some View {
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
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
    }

    private func statusKarte(icon: String, titel: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(akzentFarbe.opacity(0.72))

            Text(titel)
                .font(.headline)
                .foregroundStyle(textFarbe)

            Text(text)
                .font(.body)
                .foregroundStyle(sekundTextFarbe)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private func fortfahrenKarte<Ziel: View>(
        icon: String,
        titel: String,
        text: String,
        buttonTitel: String,
        istPrimaer: Bool,
        @ViewBuilder ziel: @escaping () -> Ziel
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(titel, systemImage: icon)
                .font(.headline)
                .foregroundStyle(textFarbe)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(sekundTextFarbe)
                .lineSpacing(2)

            NavigationLink {
                ziel()
            } label: {
                Text(buttonTitel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .foregroundStyle(istPrimaer ? .white : textFarbe)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(istPrimaer ? akzentFarbe : hintergrundFarbe.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(istPrimaer ? Color.clear : akzentFarbe.opacity(0.16), lineWidth: 1)
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private func einladungAblehnen() {
        fehlermeldung = ""

        guard let zugriff = aktuellerDossierZugriff else {
            fehlermeldung = "Diese Einladung konnte nicht gefunden werden."
            return
        }

        guard zugriff.status == DossierZugriffStatus.erstellt else {
            fehlermeldung = "Diese Einladung kann nicht mehr abgelehnt werden."
            return
        }

        zugriff.einladungAblehnen()

        do {
            try modelContext.save()
            einladungWurdeAbgelehnt = true
        } catch {
            fehlermeldung = "Die Ablehnung konnte nicht gespeichert werden."
        }
    }
}

#Preview {
    EinladungAngenommen(
        einladenderName: "René Engeler",
        eingeladeneEmail: "vertrauensperson@mail.ch",
        einladungsToken: "test-token-123"
    )
    .modelContainer(for: [DossierZugriffModell.self], inMemory: true)
}
