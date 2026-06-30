//
//  EinladungAngenommen.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI

struct EinladungAngenommen: View {
    let einladenderName: String
    let eingeladeneEmail: String
    // TEST: später aus dem echten Einladungslink / Token ersetzen
    let einladungsToken: String = UUID().uuidString
    @State private var einladungWurdeAngenommen = false
    @State private var einladungWurdeAbgelehnt = false
    @State private var bestaetigungAblehnenAnzeigen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    Image("Icon1_trans")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .padding(.top, 30)

                    VStack(spacing: 12) {
                    Text("Einladung als Vertrauensperson")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Du wurdest von")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text(einladenderName)
                        .font(.headline)

                    Text("als Vertrauensperson eingeladen.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Text("Diese Einladung wurde an folgende E-Mail-Adresse gesendet:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text(eingeladeneEmail)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Divider()
                    .padding(.top, 0)
                    .padding(.bottom, 6)

                if einladungWurdeAbgelehnt {
                    VStack(spacing: 14) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)

                        Text("Einladung abgelehnt")
                            .font(.headline)

                        Text("Die Einladung wurde erfolgreich abgelehnt. Der Einladungslink wurde ungültig gemacht. Die vorsorgende Person wird über die Ablehnung informiert.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                } else if einladungWurdeAngenommen {
                    VStack(spacing: 24) {
                        Text("Wie möchtest du fortfahren?")
                            .font(.title3.bold())

                        VStack(alignment: .leading, spacing: 16) {
                            Label("Ich habe bereits ein Profil", systemImage: "person.crop.circle")
                                .font(.headline)

                            Text("Melde dich mit deinem bestehenden Profil an, um die Einladung anzunehmen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            NavigationLink {
                                // TODO: Einladungs-Kontext übergeben: eingeladeneEmail, einladungsToken
                                ReloginEinladung()
                            } label: {
                                Text("Anmelden")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 16) {
                            Label("Ich bin neu bei AfterLife", systemImage: "person.badge.plus")
                                .font(.headline)

                            Text("Erstelle ein neues Profil, um diese Einladung als Vertrauensperson anzunehmen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            NavigationLink {
                                // TODO: Einladungs-Kontext übergeben: eingeladeneEmail, einladungsToken
                                VertrauenspersonRegistrierung()
                            } label: {
                                Text("Profil erstellen")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray5))
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.top, 8)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            einladungWurdeAngenommen = true
                        } label: {
                            Text("Einladung annehmen und fortfahren")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            bestaetigungAblehnenAnzeigen = true
                        } label: {
                            Text("Ablehnen")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.top, 8)
                }

                    Text("🔒 Diese Einladung ist persönlich, an die angezeigte E-Mail-Adresse gebunden und kann nur einmal verwendet werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 30)

                }
                .padding(24)
            }
            .alert("Einladung ablehnen?", isPresented: $bestaetigungAblehnenAnzeigen) {
                Button("Abbrechen", role: .cancel) {
                    bestaetigungAblehnenAnzeigen = false
                }

                Button("Einladung ablehnen", role: .destructive) {
                    // TODO: Token ungültig machen: einladungsToken
                    // TODO: EinladungStatus auf abgelehnt setzen
                    // TODO: Vorsorgende Person benachrichtigen
                    einladungWurdeAbgelehnt = true
                }
            } message: {
                Text("Möchtest du die Einladung als Vertrauensperson wirklich ablehnen? Danach verliert der Einladungslink seine Gültigkeit. Die vorsorgende Person wird über die Ablehnung informiert.")
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    EinladungAngenommen(
        einladenderName: "René Engeler",
        eingeladeneEmail: "vertrauensperson@mail.ch"
    )
}
