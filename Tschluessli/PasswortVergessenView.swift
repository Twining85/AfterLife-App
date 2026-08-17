import SwiftUI

struct PasswortVergessenView: View {
    let initialEmail: String
    let onErfolg: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var code = ""
    @State private var neuesPasswort = ""
    @State private var wiederholung = ""
    @State private var challenge: PasswortResetChallenge?
    @State private var arbeitet = false
    @State private var fehlermeldung = ""

    init(initialEmail: String, onErfolg: @escaping () -> Void) {
        self.initialEmail = initialEmail
        self.onErfolg = onErfolg
        _email = State(initialValue: initialEmail)
    }

    private var emailGueltig: Bool {
        let wert = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return wert.contains("@") && wert.contains(".")
    }

    private var resetGueltig: Bool {
        code.count == 6
            && code.allSatisfy(\.isNumber)
            && neuesPasswort.count >= 12
            && neuesPasswort.count <= 128
            && neuesPasswort == wiederholung
    }

    var body: some View {
        Form {
            if challenge == nil {
                Section("Konto") {
                    TextField("E-Mail-Adresse", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                    Text("Wenn ein Konto besteht, senden wir einen sechsstelligen Code an diese Adresse.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(arbeitet ? "Code wird gesendet …" : "Code senden") { codeSenden() }
                        .disabled(arbeitet || !emailGueltig)
                }
            } else {
                Section("Bestätigungscode") {
                    TextField("6-stelliger Code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: code) { _, wert in
                            code = String(wert.filter(\.isNumber).prefix(6))
                        }
                    Text("Der Code ist zehn Minuten gültig und kann nur einmal verwendet werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Neues Passwort") {
                    SecureField("Mindestens 12 Zeichen", text: $neuesPasswort)
                        .textContentType(.newPassword)
                    SecureField("Neues Passwort wiederholen", text: $wiederholung)
                        .textContentType(.newPassword)
                    if !wiederholung.isEmpty && neuesPasswort != wiederholung {
                        Text("Die Passwörter stimmen nicht überein.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button(arbeitet ? "Passwort wird gespeichert …" : "Neues Passwort speichern") {
                        passwortZuruecksetzen()
                    }
                    .disabled(arbeitet || !resetGueltig)
                }
                Section {
                    Button("Anderen Code anfordern") {
                        challenge = nil
                        code = ""
                        fehlermeldung = ""
                    }
                }
            }
            if !fehlermeldung.isEmpty {
                Section { Text(fehlermeldung).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Passwort vergessen")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(arbeitet)
    }

    private func codeSenden() {
        arbeitet = true
        fehlermeldung = ""
        Task {
            do {
                challenge = try await CloudKontoService.shared.passwortResetAnfordern(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                )
            } catch { fehlermeldung = error.localizedDescription }
            arbeitet = false
        }
    }

    private func passwortZuruecksetzen() {
        guard let challenge else { return }
        arbeitet = true
        fehlermeldung = ""
        Task {
            do {
                try await CloudKontoService.shared.passwortZuruecksetzen(
                    challenge: challenge,
                    code: code,
                    neuesPasswort: neuesPasswort
                )
                onErfolg()
                dismiss()
            } catch { fehlermeldung = error.localizedDescription }
            arbeitet = false
        }
    }
}
