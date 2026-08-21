import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let vertrauenspersonPushEmpfangen = Notification.Name("vertrauenspersonPushEmpfangen")
}

nonisolated struct CloudEinladungsAnfrage: Decodable, Sendable {
    let dossierID: UUID
    let ownerUserID: UUID
    let invitedEmail: String
    let expiresAt: Date
}

actor PushEinladungsService {
    static let shared = PushEinladungsService()
    private let tokenDefaultsKey = "apnsDeviceToken"

    func geraetetokenSpeichernUndRegistrieren(_ daten: Data) async {
        let token = daten.map { String(format: "%02x", $0) }.joined()
        await MainActor.run { UserDefaults.standard.set(token, forKey: tokenDefaultsKey) }
        try? await registriereGespeichertesGeraet()
    }

    func registriereGespeichertesGeraet() async throws {
        let token = await MainActor.run { UserDefaults.standard.string(forKey: tokenDefaultsKey) ?? "" }
        guard !token.isEmpty else { return }
        _ = try await sende(
            pfad: "api/sync/push?operation=device",
            body: GeraetAnfrage(deviceToken: token, environment: Self.umgebung),
            antwort: LeereAntwort.self
        )
    }

    func einladungRegistrieren(token: String, dossierID: UUID, email: String) async throws {
        _ = try await sende(
            pfad: "api/sync/push?operation=register-invitation",
            body: EinladungRegistrierenAnfrage(token: token, dossierID: dossierID, email: email),
            antwort: LeereAntwort.self
        )
    }

    func bestaetigungAnfragen(token: String, profilEmail: String) async throws -> CloudEinladungsAnfrage {
        try await sende(
            pfad: "api/sync/push?operation=request-invitation",
            body: TokenAnfrage(token: token, profileEmail: profilEmail),
            antwort: CloudEinladungsAnfrage.self
        )
    }

    func entscheiden(token: String, angenommen: Bool) async throws {
        _ = try await sende(
            pfad: "api/sync/push?operation=decide-invitation",
            body: EntscheidungsAnfrage(token: token, decision: angenommen ? "accepted" : "declined"),
            antwort: LeereAntwort.self
        )
    }

    private func sende<Body: Encodable, Antwort: Decodable>(pfad: String, body: Body, antwort: Antwort.Type) async throws -> Antwort {
        let sitzungsToken = try await CloudKontoService.shared.sitzungsToken()
        let teile = pfad.split(separator: "?", maxSplits: 1).map(String.init)
        var komponenten = URLComponents(
            url: CloudAPIKonfiguration.basisURL.appending(path: teile[0]),
            resolvingAgainstBaseURL: false
        )
        if teile.count == 2 {
            komponenten?.queryItems = teile[1].split(separator: "&").compactMap { paar in
                let elemente = paar.split(separator: "=", maxSplits: 1).map(String.init)
                guard elemente.count == 2 else { return nil }
                return URLQueryItem(name: elemente[0], value: elemente[1])
            }
        }
        guard let url = komponenten?.url else { throw PushFehler.ungueltigeAntwort }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sitzungsToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let (daten, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PushFehler.ungueltigeAntwort }
        guard (200..<300).contains(http.statusCode) else {
            let server = try? JSONDecoder().decode(ServerPushFehler.self, from: daten)
            throw PushFehler.server(server?.error ?? "Die Push-Anfrage ist fehlgeschlagen.")
        }
        if Antwort.self == LeereAntwort.self { return LeereAntwort() as! Antwort }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Antwort.self, from: daten)
    }

    #if DEBUG
    private static let umgebung = "sandbox"
    #else
    private static let umgebung = "production"
    #endif
}

enum PushFehler: LocalizedError {
    case ungueltigeAntwort
    case server(String)
    var errorDescription: String? {
        switch self {
        case .ungueltigeAntwort: "Der Server hat unerwartet geantwortet."
        case .server(let text): text
        }
    }
}

private nonisolated struct GeraetAnfrage: Encodable { let deviceToken: String; let environment: String }
private nonisolated struct EinladungRegistrierenAnfrage: Encodable { let token: String; let dossierID: UUID; let email: String }
private nonisolated struct TokenAnfrage: Encodable { let token: String; let profileEmail: String }
private nonisolated struct EntscheidungsAnfrage: Encodable { let token: String; let decision: String }
private nonisolated struct ServerPushFehler: Decodable { let error: String }
private nonisolated struct LeereAntwort: Codable { init() {} }

final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { erlaubt, _ in
            guard erlaubt else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushEinladungsService.shared.geraetetokenSpeichernUndRegistrieren(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs-Registrierung fehlgeschlagen: \(error.localizedDescription)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        verarbeite(notification.request.content.userInfo)
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        verarbeite(response.notification.request.content.userInfo)
    }

    private func verarbeite(_ userInfo: [AnyHashable: Any]) {
        guard let typ = userInfo["type"] as? String,
              let token = userInfo["invitationToken"] as? String else { return }
        var info: [String: String] = ["type": typ, "token": token]
        if let email = userInfo["requesterEmail"] as? String { info["requesterEmail"] = email }
        if let userID = userInfo["requesterUserID"] as? String { info["requesterUserID"] = userID }
        if let decision = userInfo["decision"] as? String { info["decision"] = decision }
        UserDefaults.standard.set(info, forKey: "letzterVertrauenspersonPush")
        NotificationCenter.default.post(name: .vertrauenspersonPushEmpfangen, object: nil, userInfo: info)
    }
}
