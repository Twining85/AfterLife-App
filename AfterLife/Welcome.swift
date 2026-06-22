import SwiftUI

struct WelcomeView: View {
    private let backgroundImageName = "Welcomescreen" // Hier später den Namen deines Assets eintragen

    var body: some View {
        NavigationStack {
            ZStack {
                Image(backgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.02),
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    VStack(spacing: 20) {
                        Text("Die schönste Fürsorge beginnt heute.")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("""
                        Niemand spricht gerne über Notfälle oder das Lebensende. Doch wenn etwas passiert, sind klare Informationen und bekannte Wünsche eines der grössten Geschenke für die Menschen, die uns wichtig sind.

                        AfterLife hilft dir, alles Wichtige sicher zu dokumentieren – damit deine Liebsten sich auf das Wesentliche konzentrieren können: füreinander da zu sein.
                        """)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(4)
                    }
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 24)

                    NavigationLink {
                        Registrierung()
                    } label: {
                        Text("Jetzt kostenlos registrieren")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
        }
    }
}

#Preview {
    WelcomeView()
}
