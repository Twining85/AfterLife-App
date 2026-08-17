import SwiftUI
import UIKit

actor DossierResetService {
    static let shared = DossierResetService()

    func codeSenden() async throws -> (String, Date) {
        let antwort: ChallengeAntwort = try await senden(body: LeereAnfrage(action: "dossier-reset-request"))
        let mitMillisekunden = ISO8601DateFormatter()
        mitMillisekunden.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let datum = mitMillisekunden.date(from: antwort.expiresAt)
                ?? ISO8601DateFormatter().date(from: antwort.expiresAt) else {
            throw ResetFehler.ungueltigeAntwort
        }
        return (antwort.challengeToken, datum)
    }

    func codePruefen(_ code: String, challenge: String) async throws -> String {
        let antwort: GrantAntwort = try await senden(body: CodeAnfrage(action: "dossier-reset-confirm", code: code, challengeToken: challenge))
        return antwort.resetGrant
    }

    func ausfuehren(grant: String, bestaetigung: String) async throws -> UUID {
        let antwort: ResetAntwort = try await senden(body: ResetAnfrage(action: "dossier-reset-execute", resetGrant: grant, confirmation: bestaetigung))
        guard let id = UUID(uuidString: antwort.dossierID) else { throw ResetFehler.ungueltigeAntwort }
        return id
    }

    private func senden<A: Encodable, R: Decodable>(body: A) async throws -> R {
        let token = try await CloudKontoService.shared.sitzungsToken()
        var request = URLRequest(url: CloudAPIKonfiguration.basisURL.appending(path: "api/accounts/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ResetFehler.ungueltigeAntwort }
        guard (200..<300).contains(http.statusCode) else {
            let meldung = (try? JSONDecoder().decode(ServerAntwort.self, from: data).error) ?? "Der Dossier-Reset ist fehlgeschlagen."
            throw ResetFehler.server(meldung)
        }
        guard let antwort = try? JSONDecoder().decode(R.self, from: data) else { throw ResetFehler.ungueltigeAntwort }
        return antwort
    }
}

struct DossierNotfallResetView: View {
    let email: String
    let onZurueckgesetzt: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var challenge = ""
    @State private var code = ""
    @State private var grant = ""
    @State private var bestaetigung = ""
    @State private var arbeitet = false
    @State private var fehler = ""
    @FocusState private var codeFeldIstFokussiert: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Unwiderruflicher Neustart") {
                    Text("Ohne Wiederherstellungscode können deine verschlüsselten Daten nicht entschlüsselt werden. Du kannst dein bestehendes Konto zurücksetzen und mit einem leeren Dossier neu beginnen. Dabei werden sämtliche bisherigen Dossierdaten unwiderruflich gelöscht.")
                        .foregroundStyle(.red)
                }
                Section("E-Mail bestätigen") {
                    Text("Der Sicherheitscode wird an \(email) gesendet.")
                    if challenge.isEmpty {
                        Button("Code senden", action: codeSenden)
                    } else if grant.isEmpty {
                        codeEingabe
                        Button("Code bestätigen", action: codePruefen).disabled(code.count != 6)
                    } else {
                        Label("E-Mail-Adresse bestätigt", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                    }
                }
                if !grant.isEmpty {
                    Section("Endgültige Bestätigung") {
                        Text("Gib DOSSIER LÖSCHEN ein.")
                        TextField("DOSSIER LÖSCHEN", text: $bestaetigung)
                            .textInputAutocapitalization(.characters)
                        Button("Dossier unwiderruflich löschen", role: .destructive, action: resetAusfuehren)
                            .disabled(bestaetigung != "DOSSIER LÖSCHEN")
                    }
                }
                if arbeitet { ProgressView() }
                if !fehler.isEmpty { Text(fehler).foregroundStyle(.red) }
            }
            .navigationTitle("Dossier zurücksetzen")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .interactiveDismissDisabled(arbeitet)
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
                .onChange(of: code) { _, wert in
                    let ziffern = String(wert.filter(\.isNumber).prefix(6))
                    if code != ziffern { code = ziffern }
                }

            HStack(spacing: 7) {
                ForEach(0..<6, id: \.self) { index in
                    Text(codeZiffer(at: index))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    index == min(code.count, 5) && code.count < 6
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.22),
                                    lineWidth: index == min(code.count, 5) && code.count < 6 ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { codeFeldIstFokussiert = true }
            .contextMenu {
                Button(action: codeAusZwischenablageEinsetzen) {
                    Label("Einfügen", systemImage: "doc.on.clipboard")
                }
            }
        }
        .onAppear { codeFeldIstFokussiert = true }
    }

    private func codeZiffer(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }

    private func codeAusZwischenablageEinsetzen() {
        guard let text = UIPasteboard.general.string else { return }
        code = String(text.filter(\.isNumber).prefix(6))
        codeFeldIstFokussiert = code.count < 6
    }

    private func codeSenden() { ausfuehren { let wert = try await DossierResetService.shared.codeSenden(); challenge = wert.0; codeFeldIstFokussiert = true } }
    private func codePruefen() { ausfuehren { grant = try await DossierResetService.shared.codePruefen(code, challenge: challenge) } }
    private func resetAusfuehren() {
        ausfuehren {
            let id = try await DossierResetService.shared.ausfuehren(grant: grant, bestaetigung: bestaetigung)
            await CloudFeldVerschluesselung.shared.neuesDossierVorbereiten()
            onZurueckgesetzt(id)
            dismiss()
        }
    }
    private func ausfuehren(_ operation: @escaping () async throws -> Void) {
        guard !arbeitet else { return }; arbeitet = true; fehler = ""
        Task { do { try await operation() } catch { fehler = error.localizedDescription }; arbeitet = false }
    }
}

private nonisolated struct LeereAnfrage: Encodable { let action: String }
private nonisolated struct CodeAnfrage: Encodable { let action: String; let code: String; let challengeToken: String }
private nonisolated struct ResetAnfrage: Encodable { let action: String; let resetGrant: String; let confirmation: String }
private nonisolated struct ChallengeAntwort: Decodable { let challengeToken: String; let expiresAt: String }
private nonisolated struct GrantAntwort: Decodable { let resetGrant: String }
private nonisolated struct ResetAntwort: Decodable { let dossierID: String }
private nonisolated struct ServerAntwort: Decodable { let error: String }
private enum ResetFehler: LocalizedError {
    case ungueltigeAntwort, server(String)
    var errorDescription: String? { switch self { case .ungueltigeAntwort: "Der Server hat unerwartet geantwortet."; case .server(let text): text } }
}
