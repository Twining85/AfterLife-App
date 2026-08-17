import SwiftUI

struct PasswortAendernView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bisherigesPasswort = ""
    @State private var neuesPasswort = ""
    @State private var neuesPasswortWiederholt = ""
    @State private var arbeitet = false
    @State private var fehlermeldung = ""
    @State private var erfolgsmeldung = ""

    private var istGueltig: Bool {
        !bisherigesPasswort.isEmpty
            && neuesPasswort.count >= 12
            && neuesPasswort.count <= 128
            && neuesPasswort == neuesPasswortWiederholt
            && neuesPasswort != bisherigesPasswort
    }

    var body: some View {
        Form {
            Section("Bisheriges Passwort") {
                SecureField("Bisheriges Passwort", text: $bisherigesPasswort)
                    .textContentType(.password)
            }
            Section("Neues Passwort") {
                SecureField("Mindestens 12 Zeichen", text: $neuesPasswort)
                    .textContentType(.newPassword)
                SecureField("Neues Passwort wiederholen", text: $neuesPasswortWiederholt)
                    .textContentType(.newPassword)
                Text("Das neue Passwort muss 12 bis 128 Zeichen lang sein und sich vom bisherigen Passwort unterscheiden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !neuesPasswortWiederholt.isEmpty && neuesPasswort != neuesPasswortWiederholt {
                    Text("Die neuen Passwörter stimmen nicht überein.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            if !fehlermeldung.isEmpty {
                Section { Text(fehlermeldung).foregroundStyle(.red) }
            }
            if !erfolgsmeldung.isEmpty {
                Section { Text(erfolgsmeldung).foregroundStyle(.green) }
            }
            Section {
                Button(arbeitet ? "Passwort wird geändert …" : "Passwort ändern") {
                    passwortAendern()
                }
                .disabled(arbeitet || !istGueltig)
            }
        }
        .navigationTitle("Passwort ändern")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(arbeitet)
    }

    private func passwortAendern() {
        arbeitet = true
        fehlermeldung = ""
        erfolgsmeldung = ""
        Task {
            do {
                try await CloudKontoService.shared.passwortAendern(
                    bisherigesPasswort: bisherigesPasswort,
                    neuesPasswort: neuesPasswort
                )
                bisherigesPasswort = ""
                neuesPasswort = ""
                neuesPasswortWiederholt = ""
                erfolgsmeldung = "Das Passwort wurde erfolgreich geändert."
            } catch {
                fehlermeldung = error.localizedDescription
            }
            arbeitet = false
        }
    }
}
