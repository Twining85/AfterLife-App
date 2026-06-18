import SwiftUI

struct WeiteresView: View {
    private let kreisFarbe = Color(.systemGray5)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    Text("Zugangsdaten & Abos")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 30
                    ) {
                        KreisKachel(
                            icon: "lock.fill",
                            titel: "Digitale Konten",
                            farbe: kreisFarbe
                       
                        )

                        KreisKachel(
                            icon: "newspaper.fill",
                            titel: "Abos",
                            farbe: kreisFarbe
                        )

                        KreisKachel(
                            icon: "person.2.fill",
                            titel: "Mitgliedschaften",
                            farbe: kreisFarbe
                        )

                        KreisKachel(
                            icon: "note.text",
                            titel: "Notizen",
                            farbe: kreisFarbe
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
        }
    }
}

struct KreisKachel: View {
    let icon: String
    let titel: String
    let farbe: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(farbe)
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(.black)
            }

            Text(titel)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    WeiteresView()
}
