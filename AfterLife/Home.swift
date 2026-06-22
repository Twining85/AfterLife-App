import SwiftUI

struct Home: View {
    private let kachelFarbe = Color(red: 0.92, green: 0.92, blue: 0.94)
    @State private var bildIstSichtbar = false

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

                    ZStack(alignment: .bottom) {
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
                            }

                        ersteKachelReihe
                            .padding(.horizontal, 24)
                            .offset(y: 90)
                    }
                    .padding(.bottom, 110)

                    restlicheKacheln
                        .padding(.horizontal, 24)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarBackButtonHidden(true)
        }
    }

    private var ersteKachelReihe: some View {
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
                    //icon: "heart.fill",
                    icon: "sparkles",
                    titel: "Meine Wünsche",
                    farbe: kachelFarbe
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var restlicheKacheln: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ],
            spacing: 20
        ) {
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
