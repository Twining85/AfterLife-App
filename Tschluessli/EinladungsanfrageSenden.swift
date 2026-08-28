import SwiftData
import SwiftUI

struct EinladungsanfrageSendenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [ProfilModell]
    @Bindable var zugriff: DossierZugriffModell
    @AppStorage("aktiveUserID") private var aktiveUserID = ""

    @State private var arbeitet = false
    @State private var meldung = ""
    @State private var fehler = false

    private let akzent = Color(red: 0.16, green: 0.36, blue: 0.42)

    private var requesterName: String {
        let userID = UUID(uuidString: aktiveUserID)
        let profil = profile.first { $0.userID == userID }
        let name = [profil?.vorname, profil?.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? (profil?.email ?? zugriff.eingeladeneEmail) : name
    }

    private var kannAnfragen: Bool {
        zugriff.status == DossierZugriffStatus.erstellt ||
            zugriff.status == DossierZugriffStatus.abgelehnt
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(akzent)

            Text("Vorsorge-Dossier gesperrt")
                .font(.title2.bold())

            Text("Der Zugang wurde erkannt, aber es wurden noch keine Daten geladen. Fordere die Erlaubnis erst an, wenn du das Dossier aus der Cloud laden möchtest.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            LabeledContent("Eingeladene Konto-E-Mail", value: zugriff.eingeladeneEmail)
                .padding(16)
                .background(akzent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            Button {
                sendeAnfrage()
            } label: {
                Label(
                    zugriff.status == DossierZugriffStatus.abgelehnt
                        ? "Datenzugriff erneut anfragen"
                        : "Datenzugriff anfragen",
                    systemImage: "icloud.and.arrow.down"
                )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(akzent)
            .disabled(arbeitet || !kannAnfragen)

            if arbeitet {
                ProgressView("Zugriff wird angefragt …")
            }

            if !meldung.isEmpty {
                Text(meldung)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(fehler ? .red : akzent)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background((fehler ? Color.red : akzent).opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
        }
        .padding(24)
        .navigationTitle("Einladung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendeAnfrage() {
        guard let token = zugriff.einladungsToken,
              let userID = UUID(uuidString: aktiveUserID) else { return }
        arbeitet = true
        fehler = false
        meldung = ""
        Task {
            do {
                let cloud = try await PushEinladungsService.shared.bestaetigungAnfragen(
                    token: token,
                    requesterName: requesterName
                )
                zugriff.bestaetigungAnfragen(
                    vertrauenspersonUserID: userID,
                    registrierungsEmail: cloud.invitedEmail
                )
                try modelContext.save()
                meldung = cloud.notificationDelivered
                    ? "Die vorsorgende Person wurde benachrichtigt. Das Dossier bleibt bis zu ihrer Bestätigung gesperrt."
                    : "Die Anfrage wurde gespeichert. Die vorsorgende Person sieht sie spätestens beim nächsten Öffnen der App."
            } catch {
                fehler = true
                meldung = error.localizedDescription
            }
            arbeitet = false
        }
    }
}
