import Foundation

enum CloudAPIKonfiguration {
    nonisolated static let basisURL = URL(string: "https://afterlife-address-proxy.vercel.app")!
}

struct CloudKontoSitzung: Sendable {
    let userID: UUID
    let dossierID: UUID?
    let token: String
    let gueltigBis: Date
}

enum CloudKontoFehler: LocalizedError {
    case ungueltigeAntwort
    case server(String)

    var errorDescription: String? {
        switch self {
        case .ungueltigeAntwort:
            return "Der Server hat unerwartet geantwortet."
        case .server(let meldung):
            return meldung
        }
    }
}

actor CloudKontoService {
    static let shared = CloudKontoService()

    private let keychainService = "Tschluessli.CloudSession"
    private let keychainAccount = "current"

    func registrieren(email: String, passwort: String, registrierungsGrant: String) async throws -> CloudKontoSitzung {
        let antwort: KontoAntwort = try await sende(
            pfad: "api/accounts/register",
            inhalt: RegistrierungsAnfrage(
                email: email,
                password: passwort,
                registrationGrant: registrierungsGrant
            )
        )
        return try await speichereSitzung(antwort)
    }

    func anmelden(email: String, passwort: String) async throws -> CloudKontoSitzung {
        let antwort: KontoAntwort = try await sende(
            pfad: "api/accounts/login",
            inhalt: LoginAnfrage(email: email, password: passwort)
        )
        return try await speichereSitzung(antwort)
    }

    private func sende<Anfrage: Encodable, Antwort: Decodable>(pfad: String, inhalt: Anfrage) async throws -> Antwort {
        var request = URLRequest(url: CloudAPIKonfiguration.basisURL.appending(path: pfad))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(inhalt)

        let (daten, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudKontoFehler.ungueltigeAntwort
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverFehler = try? JSONDecoder().decode(ServerFehler.self, from: daten)
            throw CloudKontoFehler.server(serverFehler?.error ?? "Die Cloud-Anfrage ist fehlgeschlagen.")
        }
        guard let antwort = try? JSONDecoder().decode(Antwort.self, from: daten) else {
            throw CloudKontoFehler.ungueltigeAntwort
        }
        return antwort
    }

    private func speichereSitzung(_ antwort: KontoAntwort) async throws -> CloudKontoSitzung {
        guard let userID = UUID(uuidString: antwort.userID),
              let gueltigBis = Self.iso8601Datum(antwort.expiresAt) else {
            throw CloudKontoFehler.ungueltigeAntwort
        }
        try await MainActor.run {
            try KeychainHelper.shared.save(
                antwort.sessionToken,
                service: keychainService,
                account: keychainAccount
            )
        }
        return CloudKontoSitzung(
            userID: userID,
            dossierID: antwort.dossierID.flatMap(UUID.init(uuidString:)),
            token: antwort.sessionToken,
            gueltigBis: gueltigBis
        )
    }

    private static func iso8601Datum(_ wert: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: wert) ?? ISO8601DateFormatter().date(from: wert)
    }
}

private nonisolated struct RegistrierungsAnfrage: Encodable {
    let email: String
    let password: String
    let registrationGrant: String
}

private nonisolated struct LoginAnfrage: Encodable {
    let email: String
    let password: String
}

private nonisolated struct KontoAntwort: Decodable {
    let userID: String
    let dossierID: String?
    let sessionToken: String
    let expiresAt: String
}

private nonisolated struct ServerFehler: Decodable {
    let error: String
}
