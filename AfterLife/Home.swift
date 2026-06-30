import SwiftUI

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
