import Foundation

struct EmailVerifizierungsChallenge: Sendable {
    let token: String
    let gueltigBis: Date
}

struct EmailVerifizierungsErgebnis: Sendable {
    let registrierungsGrant: String
}

enum EmailVerifizierungsFehler: LocalizedError {
    case ungueltigeAntwort
    case versandFehlgeschlagen
    case codeUngueltig

    var errorDescription: String? {
        switch self {
        case .ungueltigeAntwort:
            return "Der Server hat unerwartet geantwortet."
        case .versandFehlgeschlagen:
            return "Der Code konnte nicht gesendet werden. Bitte versuche es erneut."
        case .codeUngueltig:
            return "Der Code ist nicht korrekt oder bereits abgelaufen."
        }
    }
}

actor EmailVerifizierungsService {
    static let shared = EmailVerifizierungsService()

    func codeSenden(an email: String) async throws -> EmailVerifizierungsChallenge {
        let url = CloudAPIKonfiguration.basisURL.appending(path: "api/email-verification/request")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(VersandAnfrage(email: email))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EmailVerifizierungsFehler.versandFehlgeschlagen
        }
        let antwort = try JSONDecoder().decode(VersandAntwort.self, from: data)
        guard let gueltigBis = Self.iso8601Datum(from: antwort.expiresAt) else {
            throw EmailVerifizierungsFehler.ungueltigeAntwort
        }
        return EmailVerifizierungsChallenge(token: antwort.challengeToken, gueltigBis: gueltigBis)
    }

    func codePruefen(_ code: String, challenge: EmailVerifizierungsChallenge) async throws -> EmailVerifizierungsErgebnis {
        let url = CloudAPIKonfiguration.basisURL.appending(path: "api/email-verification/confirm")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PruefAnfrage(code: code, challengeToken: challenge.token)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EmailVerifizierungsFehler.codeUngueltig
        }
        guard let antwort = try? JSONDecoder().decode(PruefAntwort.self, from: data) else {
            throw EmailVerifizierungsFehler.ungueltigeAntwort
        }
        return EmailVerifizierungsErgebnis(registrierungsGrant: antwort.registrationGrant)
    }

    private static func iso8601Datum(from wert: String) -> Date? {
        let formatterMitMillisekunden = ISO8601DateFormatter()
        formatterMitMillisekunden.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let datum = formatterMitMillisekunden.date(from: wert) {
            return datum
        }

        return ISO8601DateFormatter().date(from: wert)
    }
}

private nonisolated struct VersandAnfrage: Encodable { let email: String }
private nonisolated struct VersandAntwort: Decodable {
    let challengeToken: String
    let expiresAt: String
}
private nonisolated struct PruefAnfrage: Encodable {
    let code: String
    let challengeToken: String
}
private nonisolated struct PruefAntwort: Decodable {
    let registrationGrant: String
}
