
import SwiftUI

struct Finanzkonto: Identifiable {
    let id = UUID()
    var name: String
    var art: String
    var benutzername: String
    var passwort: String
}

struct DigitalekontenView: View {
    @Binding var konten: [Finanzkonto]
    @State private var showPasswords = false

    private func neuesKonto() {
        konten.append(
            Finanzkonto(
                name: "Neues Konto",
                art: "Konto",
                benutzername: "",
                passwort: ""
            )
        )
    }

    var body: some View {
        List {
            ForEach($konten) { $konto in
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Konten aus FinanzView (bankEntries) werden hier automatisch angezeigt,
                        // sofern dieselben Finanzkonto-Objekte via Binding übergeben werden.
                        TextField("Name", text: $konto.name)
                            .font(.headline)

                        TextField("Art", text: $konto.art)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Benutzername", text: $konto.benutzername)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            if showPasswords {
                                TextField("Passwort", text: $konto.passwort)
                            } else {
                                SecureField("Passwort", text: $konto.passwort)
                            }

                            Button {
                                showPasswords.toggle()
                            } label: {
                                Image(systemName: showPasswords ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Digitale Konten")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    neuesKonto()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DigitalekontenView(konten: .constant([
            Finanzkonto(name: "Privatkonto", art: "Bankkonto", benutzername: "rene@example.com", passwort: "1234"),
            Finanzkonto(name: "Sparkonto", art: "Sparkonto", benutzername: "", passwort: "")
        ]))
    }
}
