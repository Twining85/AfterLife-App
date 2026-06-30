import SwiftUI
import SwiftData

struct Home: View {
    private let kachelFarbe = Color(red: 0.92, green: 0.92, blue: 0.94)
    // TEST: später durch echte Beziehungen aus dem Einladungs-/VertrauenspersonModell ersetzen
    private let verknuepfteVorsorgedossiers = ["René Engeler"]
    @State private var bildIstSichtbar = false
    @State private var kachelnSindSichtbar = false
    @State private var vorsorgedossierAuswahlAnzeigen = false
    @State private var direktesVorsorgedossierOeffnen = false
    @State private var ausgewaehltesVorsorgedossier = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    Text("Home")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                    Image("Hand2")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color(.systemBackground).opacity(0.20),
                                    Color(.systemBackground)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(bildIstSichtbar ? 1 : 0)
                        .animation(.easeInOut(duration: 1.4), value: bildIstSichtbar)
                        .onAppear {
                            bildIstSichtbar = true

                            withAnimation(.easeOut(duration: 0.8).delay(0.25)) {
                                kachelnSindSichtbar = true
                            }
                        }

                    alleKacheln
                        .padding(.horizontal, 24)
                        .padding(.top, -40)
                        .offset(y: kachelnSindSichtbar ? 0 : 20)
                        .opacity(kachelnSindSichtbar ? 1 : 0)

                    if !verknuepfteVorsorgedossiers.isEmpty {
                        vorsorgedossierWechselAktion
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                            .offset(y: kachelnSindSichtbar ? 0 : 20)
                            .opacity(kachelnSindSichtbar ? 1 : 0)
                    }

#if DEBUG
                    HomeDebugTestPanel()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
#endif
                }
            }
            .background(Color(.systemBackground))
            .navigationDestination(isPresented: $direktesVorsorgedossierOeffnen) {
                VorsorgedossierPlatzhalter(name: ausgewaehltesVorsorgedossier)
            }
            .confirmationDialog(
                "Vorsorgedossier auswählen",
                isPresented: $vorsorgedossierAuswahlAnzeigen,
                titleVisibility: .visible
            ) {
                ForEach(verknuepfteVorsorgedossiers, id: \.self) { name in
                    Button(name) {
                        ausgewaehltesVorsorgedossier = name
                        direktesVorsorgedossierOeffnen = true
                    }
                }

                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Wähle aus, welches Vorsorgedossier du öffnen möchtest.")
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    private var vorsorgedossierWechselAktion: some View {
        HStack {
            Spacer()

            Button {
                vorsorgedossierWechseln()
            } label: {
                HStack(spacing: 8) {
                    Text("Zum Vorsorgedossier wechseln")
                        .font(.footnote.weight(.semibold))

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
    }

    private func vorsorgedossierWechseln() {
        guard !verknuepfteVorsorgedossiers.isEmpty else { return }

        if verknuepfteVorsorgedossiers.count == 1 {
            ausgewaehltesVorsorgedossier = verknuepfteVorsorgedossiers[0]
            direktesVorsorgedossierOeffnen = true
        } else {
            vorsorgedossierAuswahlAnzeigen = true
        }
    }

    private var alleKacheln: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ],
            spacing: 20
        ) {
            NavigationLink {
                ProfilView()
            } label: {
                HomeKachel(
                    icon: "person.fill",
                    titel: "Mein Profil",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WuenscheView()
            } label: {
                HomeKachel(
                    icon: "sparkles",
                    titel: "Meine Wünsche",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FinanzenView()
            } label: {
                HomeKachel(
                    icon: "dollarsign.circle.fill",
                    titel: "Finanzen",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                HinterbliebeneView()
            } label: {
                HomeKachel(
                    icon: "person.3.fill",
                    titel: "Hinterbliebene",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DokumenteView()
            } label: {
                HomeKachel(
                    icon: "folder.fill",
                    titel: "Dokumente & Fotoalbum",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AbosView()
            } label: {
                HomeKachel(
                    icon: "rectangle.stack.badge.person.crop.fill",
                    titel: "Abos & Profile",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct HomeKachel: View {
    let icon: String
    let titel: String
    let farbe: Color

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.black)

            Text(titel)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(farbe.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

#Preview {
    Home()
}

struct VorsorgedossierPlatzhalter: View {
    let name: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.person.crop")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            Text("Vorsorgedossier")
                .font(.largeTitle.bold())

            Text(name)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Diese Ansicht wird später das freigegebene Dossier der vorsorgenden Person anzeigen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Vorsorgedossier")
    }
}


#if DEBUG
private struct HomeDebugTestPanel: View {
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false

    @Query private var profile: [ProfilModell]
    @Query private var dossiers: [DossierModell]
    @Query private var dossierZugriffe: [DossierZugriffModell]

    private var aktivesProfil: ProfilModell? {
        guard let uuid = UUID(uuidString: aktiveUserID) else { return nil }
        return profile.first { $0.userID == uuid }
    }

    private var aktivesDossier: DossierModell? {
        if let profil = aktivesProfil {
            return dossiers.first { $0.dossierID == profil.dossierID }
        }

        return dossiers.first
    }

    var body: some View {
        GroupBox("🧪 Developer Testcenter") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktiver Benutzer")
                        .font(.headline)

                    Text("Profil vorhanden: \(profilIstVorhanden ? "Ja" : "Nein")")
                    Text("Direkt eingeloggt: \(direktNachRegistrierungEingeloggt ? "Ja" : "Nein")")
                    Text("E-Mail: \(gespeicherteEmail.isEmpty ? "-" : gespeicherteEmail)")
                    Text("User-ID: \(aktiveUserID.isEmpty ? "-" : aktiveUserID)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dossier")
                        .font(.headline)

                    if let aktivesDossier {
                        Text("Dossier-ID: \(aktivesDossier.dossierID.uuidString)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("Aktiv: \(aktivesDossier.istAktiv ? "Ja" : "Nein")")
                        Text("Freigegeben: \(aktivesDossier.istFreigegeben ? "Ja" : "Nein")")
                        Text("Schreibgeschützt: \(aktivesDossier.istSchreibgeschuetzt ? "Ja" : "Nein")")
                    } else {
                        Text("Kein Dossier gefunden.")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Einladungen")
                        .font(.headline)

                    if dossierZugriffe.isEmpty {
                        Text("Noch keine Einladungen vorhanden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dossierZugriffe) { zugriff in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(zugriff.eingeladeneEmail)
                                    .font(.subheadline.bold())

                                Text("Eingeladen an: \(zugriff.eingeladeneEmail)")

                                Text("Registriert mit: \((zugriff.registrierungsEmail?.isEmpty == false) ? (zugriff.registrierungsEmail ?? "-") : "-")")

                                if let registrierungsEmail = zugriff.registrierungsEmail,
                                   !registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   registrierungsEmail.lowercased() != zugriff.eingeladeneEmail.lowercased() {
                                    Text("Hinweis: Registrierung erfolgte mit abweichender E-Mail-Adresse.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }

                                Text("Token: \(zugriff.einladungsToken ?? "-")")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)

                                Text("Einladungslink: \(zugriff.kannRegistrierungFortsetzen ? "Noch verwendbar" : "Bereits verwendet")")
                                    .foregroundStyle(zugriff.kannRegistrierungFortsetzen ? .green : .orange)

                                Text("Status: \(zugriff.status)")
                                Text("Aktiv: \(zugriff.istAktiv ? "Ja" : "Nein")")
                                Text("Link verwendet: \(zugriff.einladungsLinkVerwendet ? "Ja" : "Nein")")

                                if let gueltigBis = zugriff.einladungGueltigBis {
                                    Text("Gültig bis: \(gueltigBis.formatted(date: .abbreviated, time: .shortened))")
                                }

                                if let verwendetAm = zugriff.einladungsLinkVerwendetAm {
                                    Text("Verwendet am: \(verwendetAm.formatted(date: .abbreviated, time: .shortened))")
                                }

                                if let userID = zugriff.vertrauenspersonUserID {
                                    Text("Vertrauensperson-ID: \(userID.uuidString)")
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 4)

                            Divider()
                        }
                    }
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
