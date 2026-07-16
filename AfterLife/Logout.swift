import SwiftUI

struct Logout: View {
    var erneutAnmelden: (() -> Void)? = nil
    private let hintergrundFarbe = Color(red: 0.985, green: 0.98, blue: 0.965)
    private let kartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)

    @State private var haekchenSichtbar = false
    @State private var textSichtbar = false

    var body: some View {
        ZStack {
            hintergrundFarbe
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 44)

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(akzentFarbe.opacity(0.12))
                            .frame(width: 118, height: 118)
                            .scaleEffect(haekchenSichtbar ? 1 : 0.55)
                            .opacity(haekchenSichtbar ? 1 : 0)

                        Circle()
                            .stroke(akzentFarbe.opacity(0.18), lineWidth: 1)
                            .frame(width: 94, height: 94)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                            .symbolEffect(.bounce, value: haekchenSichtbar)
                            .scaleEffect(haekchenSichtbar ? 1 : 0.25)
                            .opacity(haekchenSichtbar ? 1 : 0)
                    }

                    VStack(spacing: 10) {
                        Text("Erfolgreich ausgeloggt")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                        Text("Deine Daten bleiben sicher gespeichert. Melde dich erneut an, wenn du dein Vorsorge-Dossier wieder öffnen möchtest.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(textSichtbar ? 1 : 0)
                    .offset(y: textSichtbar ? 0 : 10)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 38)
                .frame(maxWidth: 430)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(kartenFarbe.opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                )
                .shadow(color: akzentFarbe.opacity(0.11), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)

                Spacer()

                if let erneutAnmelden {
                    Button("Erneut anmelden", action: erneutAnmelden)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(akzentFarbe)
                        )
                        .buttonStyle(.plain)
                        .opacity(textSichtbar ? 1 : 0)
                }

                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64)
                    .opacity(0.45)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.68)) {
                haekchenSichtbar = true
            }

            withAnimation(.easeOut(duration: 0.38).delay(0.22)) {
                textSichtbar = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        Logout()
    }
}
