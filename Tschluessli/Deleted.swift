import SwiftUI

struct Deleted: View {
  @Environment(\.appLayout) private var appLayout
  var neuStarten: (() -> Void)? = nil
  private let hintergrundFarbe = Color.appCanvas
  private let kartenFarbe = Color.appCard
  private let akzentFarbe = Color.appAccent

  @State private var symbolSichtbar = false
  @State private var textSichtbar = false

  var body: some View {
    ZStack {
      hintergrundFarbe
        .ignoresSafeArea()

      GeometryReader { geometry in
        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            Spacer(minLength: appLayout.sectionSpacing)

            VStack(spacing: appLayout.sectionSpacing) {
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
                  .foregroundStyle(Color.appPrimaryText)
                  .multilineTextAlignment(.center)

                Text(
                  "Tschüss! Dein Profil und alle damit verbundenen Daten wurden dauerhaft aus der Cloud und von diesem Gerät entfernt."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
              }
              .opacity(textSichtbar ? 1 : 0)
              .offset(y: textSichtbar ? 0 : 10)
            }
            .padding(appLayout.authCardPadding)
            .frame(maxWidth: 430)
            .background(
              RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(kartenFarbe.opacity(0.96))
            )
            .overlay(
              RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
            )
            .shadow(color: akzentFarbe.opacity(0.11), radius: 20, x: 0, y: 10)
            .appPagePadding()

            Spacer(minLength: appLayout.sectionSpacing)

            if let neuStarten {
              Button("Neu registrieren", action: neuStarten)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.appOnAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .background(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(akzentFarbe)
                )
                .buttonStyle(.plain)
                .opacity(textSichtbar ? 1 : 0)
            }

            TschluessliLogo()
              .frame(width: 64)
              .opacity(0.45)
              .padding(.top, appLayout.sectionSpacing)
              .padding(.bottom, appLayout.sectionSpacing)
          }
          .frame(minHeight: geometry.size.height)
        }
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
