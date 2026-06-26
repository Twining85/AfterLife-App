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

                HStack(alignment: .top, spacing: 10) {

                    VStack(spacing: 12) {
                        Text("Neues Profil")
                            .font(.headline)

                        Text("Falls du die App zum ersten Mal nutzt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 40)

                        NavigationLink {
                            VertrauenspersonRegistrierung()
                        } label: {
                            Text("Erstellen")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 12) {
                        Text("Bestehendes Profil")
                            .font(.headline)

                        Text("Falls du bereits ein Profil besitzt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 40)

                        NavigationLink {
                            ReloginView()
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
                    .frame(maxWidth: .infinity)
                }

                    Text("🔒 Diese Einladung ist persönlich und kann nur einmal verwendet werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 30)

                }
                .padding(24)
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
