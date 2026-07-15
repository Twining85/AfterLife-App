import SwiftUI

struct Deleted: View {
    private let hintergrundFarbe = Color(red: 0.985, green: 0.98, blue: 0.965)
    private let kartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)

    @State private var symbolSichtbar = false
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
                            .scaleEffect(symbolSichtbar ? 1 : 0.55)
                            .opacity(symbolSichtbar ? 1 : 0)

                        Circle()
                            .stroke(akzentFarbe.opacity(0.18), lineWidth: 1)
                            .frame(width: 94, height: 94)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                            .symbolEffect(.bounce, value: symbolSichtbar)
                            .scaleEffect(symbolSichtbar ? 1 : 0.25)
                            .opacity(symbolSichtbar ? 1 : 0)
                    }

                    VStack(spacing: 10) {
                        Text("Profil vollständig gelöscht")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                            .multilineTextAlignment(.center)

                        Text("Dein Profil und alle damit verbundenen Daten wurden dauerhaft von diesem Gerät entfernt.")
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
                symbolSichtbar = true
            }

            withAnimation(.easeOut(duration: 0.38).delay(0.22)) {
                textSichtbar = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        Deleted()
    }
}
