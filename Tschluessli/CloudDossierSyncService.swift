import Foundation

struct CloudDossierBereich: Sendable {
    let schemaVersion: Int
    let revision: Int
    let payload: Data
    let aktualisiertAm: Date
}

enum CloudDossierSyncFehler: LocalizedError {
    case ungueltigeDossierID
    case ungueltigeDaten
    case konflikt
    case server(String)

    var errorDescription: String? {
        switch self {
        case .ungueltigeDossierID:
            return "Das aktive Dossier ist ungültig."
        case .ungueltigeDaten:
            return "Die Cloud-Daten konnten nicht verarbeitet werden."
        case .konflikt:
            return "Die Daten wurden zwischenzeitlich auf einem anderen Gerät geändert."
        case .server(let meldung):
            return meldung
        }
    }
}

actor CloudDossierSyncService {
    static let shared = CloudDossierSyncService()

    private let revisionenKey = "Tschluessli.CloudRevisionen"

    func speichern<Payload: Encodable & Sendable>(
        _ payload: Payload,
        dossierID: UUID,
        bereich: String,
        schemaVersion: Int = 1
    ) async throws -> CloudDossierBereich {
        let token = try await CloudKontoService.shared.sitzungsToken()
        let erwarteteRevision = await gespeicherteRevision(dossierID: dossierID, bereich: bereich)
        let anfrage = SpeicherAnfrage(
            schemaVersion: schemaVersion,
            expectedRevision: erwarteteRevision,
            payload: payload
        )
        var request = URLRequest(url: try url(dossierID: dossierID, bereich: bereich))
        request.httpMethod = "PUT"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.cloudEncoder.encode(anfrage)

        let (daten, response) = try await URLSession.shared.data(for: request)
        let bereichAntwort = try pruefeAntwort(daten: daten, response: response)
        await speichereRevision(bereichAntwort.revision, dossierID: dossierID, bereich: bereich)
        return try bereichAntwort.alsBereich()
    }

    func laden(dossierID: UUID, bereich: String) async throws -> CloudDossierBereich? {
        let token = try await CloudKontoService.shared.sitzungsToken()
        var request = URLRequest(url: try url(dossierID: dossierID, bereich: bereich))
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (daten, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudDossierSyncFehler.ungueltigeDaten
        }
        if http.statusCode == 404 { return nil }
        let bereichAntwort = try pruefeAntwort(daten: daten, response: response)
        await speichereRevision(bereichAntwort.revision, dossierID: dossierID, bereich: bereich)
        return try bereichAntwort.alsBereich()
    }

    private func url(dossierID: UUID, bereich: String) throws -> URL {
        guard bereich.range(of: "^[a-z][a-z0-9_-]{0,63}$", options: .regularExpression) != nil else {
            throw CloudDossierSyncFehler.ungueltigeDaten
        }
        var komponenten = URLComponents(
            url: CloudAPIKonfiguration.basisURL.appending(path: "api/dossiers/sections"),
            resolvingAgainstBaseURL: false
        )
        komponenten?.queryItems = [
            URLQueryItem(name: "dossierID", value: dossierID.uuidString.lowercased()),
            URLQueryItem(name: "sectionType", value: bereich)
        ]
        guard let url = komponenten?.url else {
            throw CloudDossierSyncFehler.ungueltigeDossierID
        }
        return url
    }

    private func pruefeAntwort(daten: Data, response: URLResponse) throws -> BereichAntwort {
        guard let http = response as? HTTPURLResponse else {
            throw CloudDossierSyncFehler.ungueltigeDaten
        }
        if http.statusCode == 409 { throw CloudDossierSyncFehler.konflikt }
        guard (200..<300).contains(http.statusCode) else {
            let fehler = try? JSONDecoder().decode(SyncServerFehler.self, from: daten)
            throw CloudDossierSyncFehler.server(fehler?.error ?? "Die Cloud-Synchronisation ist fehlgeschlagen.")
        }
        guard let antwort = try? JSONDecoder.cloudDecoder.decode(BereichAntwort.self, from: daten) else {
            throw CloudDossierSyncFehler.ungueltigeDaten
        }
        return antwort
    }

    private func gespeicherteRevision(dossierID: UUID, bereich: String) async -> Int {
        await MainActor.run {
            let key = "\(dossierID.uuidString.lowercased()):\(bereich)"
            let werte = UserDefaults.standard.dictionary(forKey: revisionenKey) as? [String: Int] ?? [:]
            return werte[key] ?? 0
        }
    }

    private func speichereRevision(_ revision: Int, dossierID: UUID, bereich: String) async {
        await MainActor.run {
            let key = "\(dossierID.uuidString.lowercased()):\(bereich)"
            var werte = UserDefaults.standard.dictionary(forKey: revisionenKey) as? [String: Int] ?? [:]
            werte[key] = revision
            UserDefaults.standard.set(werte, forKey: revisionenKey)
        }
    }
}

private nonisolated struct SpeicherAnfrage<Payload: Encodable & Sendable>: Encodable, Sendable {
    let schemaVersion: Int
    let expectedRevision: Int
    let payload: Payload
}

private nonisolated struct BereichAntwort: Decodable, Sendable {
    let schemaVersion: Int
    let revision: Int
    let payload: JSONWert
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case schemaVersionSQL = "schema_version"
        case revision
        case payload
        case updatedAt
        case updatedAtSQL = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try Self.ganzeZahl(
            aus: container,
            primaer: .schemaVersion,
            alternativ: .schemaVersionSQL
        )
        revision = try Self.ganzeZahl(aus: container, primaer: .revision)
        payload = try container.decode(JSONWert.self, forKey: .payload)

        if let datum = try container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = datum
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAtSQL)
        }
    }

    private static func ganzeZahl(
        aus container: KeyedDecodingContainer<CodingKeys>,
        primaer: CodingKeys,
        alternativ: CodingKeys? = nil
    ) throws -> Int {
        let schluessel = container.contains(primaer) ? primaer : (alternativ ?? primaer)
        if let zahl = try? container.decode(Int.self, forKey: schluessel) {
            return zahl
        }
        let text = try container.decode(String.self, forKey: schluessel)
        guard let zahl = Int(text) else {
            throw DecodingError.dataCorruptedError(
                forKey: schluessel,
                in: container,
                debugDescription: "Erwartete eine Ganzzahl."
            )
        }
        return zahl
    }

    func alsBereich() throws -> CloudDossierBereich {
        CloudDossierBereich(
            schemaVersion: schemaVersion,
            revision: revision,
            payload: try JSONEncoder.cloudEncoder.encode(payload),
            aktualisiertAm: updatedAt
        )
    }
}

private nonisolated struct SyncServerFehler: Decodable { let error: String }

private nonisolated enum JSONWert: Codable, Sendable {
    case objekt([String: JSONWert])
    case liste([JSONWert])
    case text(String)
    case zahl(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let wert = try? container.decode(Bool.self) { self = .bool(wert) }
        else if let wert = try? container.decode(Double.self) { self = .zahl(wert) }
        else if let wert = try? container.decode(String.self) { self = .text(wert) }
        else if let wert = try? container.decode([JSONWert].self) { self = .liste(wert) }
        else { self = .objekt(try container.decode([String: JSONWert].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .objekt(let wert): try container.encode(wert)
        case .liste(let wert): try container.encode(wert)
        case .text(let wert): try container.encode(wert)
        case .zahl(let wert): try container.encode(wert)
        case .bool(let wert): try container.encode(wert)
        case .null: try container.encodeNil()
        }
    }
}

private nonisolated extension JSONEncoder {
    static var cloudEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private nonisolated extension JSONDecoder {
    static var cloudDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
