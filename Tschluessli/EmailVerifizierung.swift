import SwiftUI
import UIKit

struct EmailVerifizierung: View {
    let email: String
    let onVerifiziert: () -> Void

    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let textPrimaer = Color(red: 0.12, green: 0.12, blue: 0.11)

    @State private var code = ""
    @State private var fehlermeldung = ""
    @State private var wirdGeprueft = false
    @State private var wirdGesendet = false
    @State private var challenge: EmailVerifizierungsChallenge?
    @State private var verbleibendeSekunden = 120
    @State private var countdownID = UUID()
    @FocusState private var codeFeldIstFokussiert: Bool

    var body: some View {
        ZStack {
            hintergrundFarbe.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Image("Icon1_trans")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 58)
                        .accessibilityLabel("Tschlüssli")

                    VStack(spacing: 18) {
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(akzentFarbe)
                            .frame(width: 70, height: 70)
                            .background(akzentFarbe.opacity(0.11), in: Circle())

                        Text("E-Mail bestätigen")
                            .font(.title2.bold())
                            .foregroundStyle(textPrimaer)

                        Text("Wir haben einen 6-stelligen Code an\n\(maskierteEmail) gesendet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        codeEingabe

                        if wirdGeprueft {
                            ProgressView("Code wird geprüft …")
                                .tint(akzentFarbe)
                                .font(.footnote)
                        } else if !fehlermeldung.isEmpty {
                            Label(fehlermeldung, systemImage: "exclamationmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        if wirdGesendet {
                            ProgressView("Code wird gesendet …")
                                .tint(akzentFarbe)
                                .font(.footnote)
                        } else {
                            erneutSendenButton
                        }

                    }
                    .padding(24)
                    .frame(maxWidth: 520)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.88))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 14, y: 8)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .interactiveDismissDisabled()
        .task {
            codeFeldIstFokussiert = true
            await codeSenden()
        }
        .onChange(of: code) { _, neuerCode in
            let ziffern = String(neuerCode.filter(\.isNumber).prefix(6))
            if ziffern != neuerCode {
                code = ziffern
                return
            }
            fehlermeldung = ""
            if ziffern.count == 6 {
                codePruefen(ziffern)
            }
        }
    }

    private var codeEingabe: some View {
        ZStack {
            TextField("Bestätigungscode", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFeldIstFokussiert)
                .opacity(0.01)
                .frame(width: 1, height: 1)
                .accessibilityLabel("Sechsstelliger Bestätigungscode")

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    Text(ziffer(at: index))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(textPrimaer)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    index == code.count ? akzentFarbe : akzentFarbe.opacity(0.14),
                                    lineWidth: index == code.count ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { codeFeldIstFokussiert = true }
            .contextMenu {
                Button {
                    codeAusZwischenablageEinsetzen()
                } label: {
                    Label("Einfügen", systemImage: "doc.on.clipboard")
                }
            }
        }
    }

    private var erneutSendenButton: some View {
        Button {
            Task { await codeSenden() }
        } label: {
            if verbleibendeSekunden > 0 {
                Text("Code erneut senden in \(verbleibendeSekunden) s")
            } else {
                Text("Code erneut senden")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(verbleibendeSekunden > 0 ? Color.secondary : akzentFarbe)
        .disabled(verbleibendeSekunden > 0)
    }

    private var maskierteEmail: String {
        let teile = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard teile.count == 2, let erstesZeichen = teile[0].first else { return email }
        return "\(erstesZeichen)***@\(teile[1])"
    }

    private func ziffer(at index: Int) -> String {
        guard index < code.count else { return "" }
        let codeIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[codeIndex])
    }

    private func codeAusZwischenablageEinsetzen() {
        guard let text = UIPasteboard.general.string else { return }
        let ziffern = String(text.filter(\.isNumber).prefix(6))
        guard !ziffern.isEmpty else { return }

        code = ziffern
        codeFeldIstFokussiert = ziffern.count < 6
    }

    private func codePruefen(_ eingegebenerCode: String) {
        guard !wirdGeprueft, let challenge else { return }
        wirdGeprueft = true
        codeFeldIstFokussiert = false

        Task {
            do {
                try await EmailVerifizierungsService.shared.codePruefen(
                    eingegebenerCode,
                    challenge: challenge
                )
                wirdGeprueft = false
                onVerifiziert()
            } catch {
                wirdGeprueft = false
                code = ""
                fehlermeldung = error.localizedDescription
                codeFeldIstFokussiert = true
            }
        }
    }

    private func codeSenden() async {
        guard !wirdGesendet else { return }
        wirdGesendet = true
        code = ""
        fehlermeldung = ""

        do {
            challenge = try await EmailVerifizierungsService.shared.codeSenden(an: email)
            verbleibendeSekunden = 120
            countdownID = UUID()
            wirdGesendet = false
            codeFeldIstFokussiert = true
            await countdownStarten()
        } catch {
            wirdGesendet = false
            verbleibendeSekunden = 0
            fehlermeldung = error.localizedDescription
        }
    }

    private func countdownStarten() async {
        let aktuelleID = countdownID
        while verbleibendeSekunden > 0 && !Task.isCancelled && aktuelleID == countdownID {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, aktuelleID == countdownID else { return }
            verbleibendeSekunden -= 1
        }
    }
}

#Preview {
    EmailVerifizierung(email: "rene@example.ch", onVerifiziert: {})
}
