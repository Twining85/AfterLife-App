import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let vertrauenspersonPushEmpfangen = Notification.Name("vertrauenspersonPushEmpfangen")
}

nonisolated struct CloudEinladungsAnfrage: Decodable, Sendable {
    let dossierID: UUID
    let ownerUserID: UUID
    let ownerName: String
    let invitedEmail: String
    let expiresAt: Date
    let notificationDelivered: Bool
}

nonisolated struct CloudEinladungsStatus: Decodable, Sendable {
    let dossierID: UUID
    let ownerUserID: UUID
    let requesterUserID: UUID?
    let invitedEmail: String
    let requesterEmail: String?
    let requesterName: String?
    let status: String
    let expiresAt: Date
    let title: String
    let ownerEmail: String
    let ownerName: String
}

nonisolated struct CloudFreigegebenesDossier: Decodable, Sendable {
    let dossierID: UUID
    let ownerUserID: UUID
    let ownerEmail: String
    let ownerName: String
    let title: String
    let sections: [CloudFreigegebenerBereich]
}

nonisolated struct CloudFreigegebenerBereich: Decodable, Sendable {
    let sectionType: String
    let schemaVersion: Int
    let revision: Int64
    let payload: SyncJSONWert?
    let deleted: Bool
    let updatedAt: Date
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

    func einladungRegistrieren(token: String, dossierID: UUID, email: String, ownerName: String) async throws {
        _ = try await sende(
            pfad: "api/sync/push?operation=register-invitation",
            body: EinladungRegistrierenAnfrage(
                token: token,
                dossierID: dossierID,
                email: email,
                ownerName: ownerName
            ),
            antwort: LeereAntwort.self
        )
    }

    func einladungPruefen(token: String) async throws -> CloudEinladungsAnfrage {
        try await sende(
            pfad: "api/sync/push?operation=validate-invitation",
            body: TokenAnfrage(token: token),
            antwort: CloudEinladungsAnfrage.self
        )
    }

    func bestaetigungAnfragen(token: String, requesterName: String) async throws -> CloudEinladungsAnfrage {
        try await sende(
            pfad: "api/sync/push?operation=request-invitation",
            body: AnfrageSendenAnfrage(token: token, requesterName: requesterName),
            antwort: CloudEinladungsAnfrage.self
        )
    }

    func status(token: String) async throws -> CloudEinladungsStatus {
        try await sende(
            pfad: "api/sync/push?operation=invitation-status",
            body: TokenAnfrage(token: token),
            antwort: CloudEinladungsStatus.self
        )
    }

    func freigegebenesDossier(token: String) async throws -> CloudFreigegebenesDossier {
        try await sende(
            pfad: "api/sync/push?operation=shared-dossier",
            body: TokenAnfrage(token: token),
            antwort: CloudFreigegebenesDossier.self
        )
    }

    func entscheiden(token: String, angenommen: Bool) async throws {
        _ = try await sende(
            pfad: "api/sync/push?operation=decide-invitation",
            body: EntscheidungsAnfrage(token: token, decision: angenommen ? "accepted" : "declined"),
            antwort: LeereAntwort.self
        )
    }

    func einladungWiderrufen(dossierID: UUID, email: String) async throws {
        _ = try await sende(
            pfad: "api/sync/push?operation=revoke-invitation",
            body: EinladungWiderrufenAnfrage(dossierID: dossierID, email: email),
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
        if http.statusCode == 401 {
            throw PushFehler.authentifizierung
        }
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
    case authentifizierung
    case server(String)
    var errorDescription: String? {
        switch self {
        case .ungueltigeAntwort: "Der Server hat unerwartet geantwortet."
        case .authentifizierung: "Deine Tschlüssli-Anmeldung ist abgelaufen. Bitte melde dich erneut an."
        case .server(let text): text
        }
    }
}

private nonisolated struct GeraetAnfrage: Encodable { let deviceToken: String; let environment: String }
private nonisolated struct EinladungRegistrierenAnfrage: Encodable {
    let token: String
    let dossierID: UUID
    let email: String
    let ownerName: String
}
private nonisolated struct TokenAnfrage: Encodable { let token: String }
private nonisolated struct AnfrageSendenAnfrage: Encodable { let token: String; let requesterName: String }
private nonisolated struct EntscheidungsAnfrage: Encodable { let token: String; let decision: String }
private nonisolated struct EinladungWiderrufenAnfrage: Encodable { let dossierID: UUID; let email: String }
private nonisolated struct ServerPushFehler: Decodable { let error: String }
private nonisolated struct LeereAntwort: Codable { init() {} }

final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let kategorie = "TRUST_INVITATION_REQUEST"
    private static let bestaetigenAktion = "TRUST_INVITATION_ACCEPT"
    private static let ablehnenAktion = "TRUST_INVITATION_DECLINE"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.kategorie,
                actions: [
                    UNNotificationAction(identifier: Self.bestaetigenAktion, title: "Bestätigen"),
                    UNNotificationAction(identifier: Self.ablehnenAktion, title: "Ablehnen", options: [.destructive])
                ],
                intentIdentifiers: []
            )
        ])
        center.requestAuthorization(options: [.alert, .badge, .sound]) { erlaubt, _ in
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
        if let token = response.notification.request.content.userInfo["invitationToken"] as? String {
            do {
                if response.actionIdentifier == Self.bestaetigenAktion {
                    try await PushEinladungsService.shared.entscheiden(token: token, angenommen: true)
                    var info = stringInfo(response.notification.request.content.userInfo)
                    info["ownerDecision"] = "accepted"
                    verarbeite(info)
                    return
                }
                if response.actionIdentifier == Self.ablehnenAktion {
                    try await PushEinladungsService.shared.entscheiden(token: token, angenommen: false)
                    var info = stringInfo(response.notification.request.content.userInfo)
                    info["ownerDecision"] = "declined"
                    verarbeite(info)
                    return
                }
            } catch {
                print("Push-Aktion fehlgeschlagen: \(error.localizedDescription)")
            }
        }
        verarbeite(response.notification.request.content.userInfo)
    }

    private func stringInfo(_ userInfo: [AnyHashable: Any]) -> [String: String] {
        var info: [String: String] = [:]
        for (key, value) in userInfo {
            if let key = key as? String, let value = value as? String { info[key] = value }
        }
        return info
    }

    private func verarbeite(_ info: [String: String]) {
        guard let typ = info["type"] else { return }
        var gespeichert = info
        gespeichert["type"] = typ
        if let token = info["invitationToken"] ?? info["token"] {
            gespeichert["token"] = token
        } else if typ != "trust_invitation_revoked" {
            return
        }
        UserDefaults.standard.set(gespeichert, forKey: "letzterVertrauenspersonPush")
        NotificationCenter.default.post(name: .vertrauenspersonPushEmpfangen, object: nil, userInfo: gespeichert)
    }

    private func verarbeite(_ userInfo: [AnyHashable: Any]) {
        guard let typ = userInfo["type"] as? String else { return }
        var info: [String: String] = ["type": typ]
        if let token = userInfo["invitationToken"] as? String { info["token"] = token }
        if let dossierID = userInfo["dossierID"] as? String { info["dossierID"] = dossierID }
        if let email = userInfo["requesterEmail"] as? String { info["requesterEmail"] = email }
        if let userID = userInfo["requesterUserID"] as? String { info["requesterUserID"] = userID }
        if let decision = userInfo["decision"] as? String { info["decision"] = decision }
        verarbeite(info)
    }
}
