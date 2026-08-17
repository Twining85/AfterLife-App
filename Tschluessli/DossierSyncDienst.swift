import Foundation
import SwiftData

nonisolated struct SyncDownloadAenderung: Decodable, Sendable {
    let cursor: String
    let dossierID: UUID
    let sectionType: String
    let schemaVersion: Int
    let revision: Int64
    let operation: SyncVorgang
    let payload: SyncJSONWert?
    let changedAt: Date
}

nonisolated struct SyncDownloadAntwort: Decodable, Sendable {
    let changes: [SyncDownloadAenderung]
    let nextCursor: String
    let hasMore: Bool
}

nonisolated enum SyncJSONWert: Codable, Sendable {
    case objekt([String: SyncJSONWert])
    case liste([SyncJSONWert])
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
        else if let wert = try? container.decode([SyncJSONWert].self) { self = .liste(wert) }
        else { self = .objekt(try container.decode([String: SyncJSONWert].self)) }
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

actor DossierSyncTransport {
    static let shared = DossierSyncTransport()

    func hochladen(_ auftrag: SyncAuftragSnapshot, payload: DossierBereichPayload?) async throws -> Int64 {
        let token = try await CloudKontoService.shared.sitzungsToken()
        var request = URLRequest(url: CloudAPIKonfiguration.basisURL.appending(path: "api/sync/push"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(auftrag.idempotencyKey, forHTTPHeaderField: "Idempotency-Key")

        var body: [String: Any] = [
            "dossierID": auftrag.dossierID.uuidString.lowercased(),
            "sectionType": auftrag.bereich,
            "operation": auftrag.vorgang.rawValue,
            "schemaVersion": auftrag.schemaVersion,
            "expectedRevision": auftrag.erwarteteRevision
        ]
        if let payload {
            body["payload"] = try JSONSerialization.jsonObject(with: payload.daten)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let (daten, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncVerarbeitungsFehler.temporaer("Der Sync-Server ist nicht erreichbar.")
        }
        if http.statusCode == 401 {
            throw SyncVerarbeitungsFehler.authentifizierung("Die Cloud-Anmeldung ist abgelaufen.")
        }
        if http.statusCode == 409 {
            throw SyncVerarbeitungsFehler.konflikt("Dieser Bereich wurde auf einem anderen Gerät geändert.")
        }
        if http.statusCode == 408 || http.statusCode == 429 || (500...599).contains(http.statusCode) {
            throw SyncVerarbeitungsFehler.temporaer("Die Cloud-Synchronisation wird später erneut versucht.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncVerarbeitungsFehler.permanent(Self.serverMeldung(aus: daten))
        }
        guard let antwort = try? JSONDecoder.syncDecoder.decode(SyncUploadAntwort.self, from: daten) else {
            throw SyncVerarbeitungsFehler.temporaer("Der Sync-Server hat unerwartet geantwortet.")
        }
        return antwort.revision
    }

    func herunterladen(cursor: String) async throws -> SyncDownloadAntwort {
        let token = try await CloudKontoService.shared.sitzungsToken()
        var komponenten = URLComponents(
            url: CloudAPIKonfiguration.basisURL.appending(path: "api/sync/pull"),
            resolvingAgainstBaseURL: false
        )
        komponenten?.queryItems = [URLQueryItem(name: "cursor", value: cursor)]
        guard let url = komponenten?.url else {
            throw SyncVerarbeitungsFehler.permanent("Ungültige Sync-Adresse.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (daten, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncVerarbeitungsFehler.temporaer("Der Sync-Server ist nicht erreichbar.")
        }
        if http.statusCode == 401 {
            throw SyncVerarbeitungsFehler.authentifizierung("Die Cloud-Anmeldung ist abgelaufen.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncVerarbeitungsFehler.temporaer(Self.serverMeldung(aus: daten))
        }
        do {
            return try JSONDecoder.syncDecoder.decode(SyncDownloadAntwort.self, from: daten)
        } catch {
            throw SyncVerarbeitungsFehler.temporaer("Die Cloud-Daten konnten nicht gelesen werden.")
        }
    }

    private static func serverMeldung(aus daten: Data) -> String {
        (try? JSONDecoder().decode(SyncTransportFehler.self, from: daten).error)
            ?? "Die Cloud-Synchronisation ist fehlgeschlagen."
    }
}

@MainActor
final class DossierSyncAuftragVerarbeiter: SyncAuftragVerarbeiter {
    private let modelContext: ModelContext
    private let registry: DossierBereichAdapterRegistry
    private let transport: DossierSyncTransport

    init(
        modelContext: ModelContext,
        registry: DossierBereichAdapterRegistry,
        transport: DossierSyncTransport = .shared
    ) {
        self.modelContext = modelContext
        self.registry = registry
        self.transport = transport
    }

    func verarbeite(_ auftrag: SyncAuftragSnapshot) async throws -> Int64 {
        let payload: DossierBereichPayload?
        switch auftrag.vorgang {
        case .upsert:
            payload = try await registry.adapter(fuer: auftrag.bereich).exportiere(
                dossierID: auftrag.dossierID,
                aus: modelContext
            )
        case .delete:
            payload = nil
        }
        let revision = try await transport.hochladen(auftrag, payload: payload)
        UserDefaults.standard.set(
            revision,
            forKey: DossierSyncDienst.revisionKey(
                dossierID: auftrag.dossierID,
                bereich: auftrag.bereich
            )
        )
        return revision
    }
}

@MainActor
final class DossierSyncDienst {
    private let modelContext: ModelContext
    private let registry: DossierBereichAdapterRegistry
    private let outbox: SyncOutbox
    private let coordinator: SyncCoordinator
    private let transport: DossierSyncTransport
    private var beobachter: [NSObjectProtocol] = []
    private var syncTask: Task<Void, Never>?
    private var ignoriertEigeneSpeicherung = false

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        let registry = try DossierBereichAdapterRegistry()
        self.registry = registry
        let outbox = SyncOutbox(modelContext: modelContext)
        self.outbox = outbox
        let transport = DossierSyncTransport.shared
        self.transport = transport
        self.coordinator = SyncCoordinator(
            outbox: outbox,
            verarbeiter: DossierSyncAuftragVerarbeiter(
                modelContext: modelContext,
                registry: registry,
                transport: transport
            )
        )
    }

    deinit {
        beobachter.forEach(NotificationCenter.default.removeObserver)
        syncTask?.cancel()
    }

    func starten() {
        guard beobachter.isEmpty else { return }
        beobachter.append(NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: modelContext,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.lokaleSpeicherungErfolgt(notification)
            }
        })
        beobachter.append(NotificationCenter.default.addObserver(
            forName: .dossierRecoveryGeaendert,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = _Concurrency.Task<Void, Never> { @MainActor in
                    await self?.verarbeiteZugangsKonfliktNachRecovery()
                    self?.planeSynchronisation(bereiche: ["zugaenge"])
                }
            }
        })
        planeSynchronisation(alleBereicheMarkieren: true)
    }

    func synchronisieren() {
        planeSynchronisation(alleBereicheMarkieren: false)
    }

    private func lokaleSpeicherungErfolgt(_ notification: Notification) {
        guard !ignoriertEigeneSpeicherung else { return }
        let bereiche = betroffeneBereiche(notification)
        guard !bereiche.isEmpty else { return }
        planeSynchronisation(bereiche: bereiche)
    }

    private func planeSynchronisation(
        alleBereicheMarkieren: Bool = false,
        bereiche: Set<String> = []
    ) {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self,
                  let dossierID = Self.aktivesDossierID else { return }
            ignoriertEigeneSpeicherung = true
            defer { ignoriertEigeneSpeicherung = false }
            if alleBereicheMarkieren {
                await ladeAenderungenHerunter()
            }
            let markierteBereiche = alleBereicheMarkieren
                ? Set(registry.bereiche.filter {
                    UserDefaults.standard.object(
                        forKey: Self.revisionKey(dossierID: dossierID, bereich: $0)
                    ) == nil && !self.hatGespeichertenKonflikt(dossierID: dossierID, bereich: $0)
                })
                : bereiche
            if !markierteBereiche.isEmpty {
                for bereich in markierteBereiche {
                    guard let adapter = try? registry.adapter(fuer: bereich) else { continue }
                    let revision = (UserDefaults.standard.object(
                        forKey: Self.revisionKey(dossierID: dossierID, bereich: bereich)
                    ) as? NSNumber)?.int64Value ?? 0
                    _ = try? outbox.markiereAenderung(
                        dossierID: dossierID,
                        bereich: bereich,
                        schemaVersion: adapter.schemaVersion,
                        erwarteteRevision: revision
                    )
                }
            }
            await coordinator.synchronisieren()
            await ladeAenderungenHerunter()
        }
    }

    private func ladeAenderungenHerunter() async {
        var cursor = UserDefaults.standard.string(forKey: Self.cursorKey) ?? "0"
        do {
            while true {
                let antwort = try await transport.herunterladen(cursor: cursor)
                try await importiere(antwort.changes)
                cursor = antwort.nextCursor
                UserDefaults.standard.set(cursor, forKey: Self.cursorKey)
                if !antwort.hasMore { break }
            }
        } catch {
            // Downloadfehler lassen den Cursor unverändert und werden beim nächsten Auslöser erneut versucht.
        }
    }

    private func importiere(_ aenderungen: [SyncDownloadAenderung]) async throws {
        guard !aenderungen.isEmpty else { return }
        ignoriertEigeneSpeicherung = true
        defer { ignoriertEigeneSpeicherung = false }
        for aenderung in aenderungen {
            let bekannteRevision = UserDefaults.standard.object(
                forKey: Self.revisionKey(
                    dossierID: aenderung.dossierID,
                    bereich: aenderung.sectionType
                )
            ) as? NSNumber
            if bekannteRevision?.int64Value ?? 0 >= aenderung.revision {
                continue
            }
            if try hatOffenenAuftrag(fuer: aenderung) {
                try speichereKonflikt(aenderung)
                continue
            }
            let adapter = try registry.adapter(fuer: aenderung.sectionType)
            do {
                if aenderung.operation == .upsert, let payload = aenderung.payload {
                    let daten = try JSONEncoder.syncEncoder.encode(payload)
                    let validierteDaten = try adapter.validiere(
                        daten,
                        schemaVersion: aenderung.schemaVersion
                    )
                    try await DossierBereichImport.importiere(
                        validierteDaten,
                        bereich: aenderung.sectionType,
                        dossierID: aenderung.dossierID,
                        in: modelContext
                    )
                } else if aenderung.operation == .delete {
                    try DossierBereichImport.loesche(
                        bereich: aenderung.sectionType,
                        dossierID: aenderung.dossierID,
                        in: modelContext
                    )
                }
            } catch {
                try speichereKonflikt(aenderung)
                continue
            }
            try aktualisiereRevision(aenderung)
            UserDefaults.standard.set(
                aenderung.revision,
                forKey: Self.revisionKey(
                    dossierID: aenderung.dossierID,
                    bereich: aenderung.sectionType
                )
            )
        }
        try modelContext.save()
    }

    private func hatOffenenAuftrag(fuer aenderung: SyncDownloadAenderung) throws -> Bool {
        let schluessel = SyncAuftrag.schluessel(
            dossierID: aenderung.dossierID,
            bereich: aenderung.sectionType
        )
        let descriptor = FetchDescriptor<SyncAuftrag>(predicate: #Predicate { $0.schluessel == schluessel })
        return try modelContext.fetch(descriptor).first != nil
    }

    private func speichereKonflikt(_ aenderung: SyncDownloadAenderung) throws {
        let schluessel = SyncAuftrag.schluessel(
            dossierID: aenderung.dossierID,
            bereich: aenderung.sectionType
        )
        let descriptor = FetchDescriptor<SyncKonflikt>(predicate: #Predicate { $0.schluessel == schluessel })
        let payload = try aenderung.payload.map { try JSONEncoder.syncEncoder.encode($0) }
        if let konflikt = try modelContext.fetch(descriptor).first {
            konflikt.vorgangRaw = aenderung.operation.rawValue
            konflikt.schemaVersion = aenderung.schemaVersion
            konflikt.serverRevision = aenderung.revision
            konflikt.serverPayload = payload
            konflikt.empfangenAm = aenderung.changedAt
        } else {
            modelContext.insert(SyncKonflikt(
                dossierID: aenderung.dossierID,
                bereich: aenderung.sectionType,
                vorgang: aenderung.operation,
                schemaVersion: aenderung.schemaVersion,
                serverRevision: aenderung.revision,
                serverPayload: payload,
                empfangenAm: aenderung.changedAt
            ))
        }
    }

    private func verarbeiteZugangsKonfliktNachRecovery() async {
        guard let dossierID = Self.aktivesDossierID else { return }
        let schluessel = SyncAuftrag.schluessel(dossierID: dossierID, bereich: "zugaenge")
        let descriptor = FetchDescriptor<SyncKonflikt>(predicate: #Predicate { $0.schluessel == schluessel })
        guard let konflikt = try? modelContext.fetch(descriptor).first,
              konflikt.vorgangRaw == SyncVorgang.upsert.rawValue,
              let payload = konflikt.serverPayload,
              (try? hatOffenenAuftrag(dossierID: dossierID, bereich: "zugaenge")) == false else { return }
        do {
            let adapter = try registry.adapter(fuer: "zugaenge")
            let validiert = try adapter.validiere(payload, schemaVersion: konflikt.schemaVersion)
            try await DossierBereichImport.importiere(validiert, bereich: "zugaenge", dossierID: dossierID, in: modelContext)
            UserDefaults.standard.set(konflikt.serverRevision, forKey: Self.revisionKey(dossierID: dossierID, bereich: "zugaenge"))
            modelContext.delete(konflikt)
            try modelContext.save()
        } catch {
            // Der Konflikt bleibt erhalten und kann nach korrigierter Eingabe erneut verarbeitet werden.
        }
    }

    private func hatOffenenAuftrag(dossierID: UUID, bereich: String) throws -> Bool {
        let schluessel = SyncAuftrag.schluessel(dossierID: dossierID, bereich: bereich)
        let descriptor = FetchDescriptor<SyncAuftrag>(predicate: #Predicate { $0.schluessel == schluessel })
        return try modelContext.fetch(descriptor).first != nil
    }

    private func hatGespeichertenKonflikt(dossierID: UUID, bereich: String) -> Bool {
        let schluessel = SyncAuftrag.schluessel(dossierID: dossierID, bereich: bereich)
        let descriptor = FetchDescriptor<SyncKonflikt>(predicate: #Predicate { $0.schluessel == schluessel })
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    private func aktualisiereRevision(_ aenderung: SyncDownloadAenderung) throws {
        let schluessel = SyncAuftrag.schluessel(
            dossierID: aenderung.dossierID,
            bereich: aenderung.sectionType
        )
        let descriptor = FetchDescriptor<SyncAuftrag>(predicate: #Predicate { $0.schluessel == schluessel })
        if let auftrag = try modelContext.fetch(descriptor).first,
           auftrag.status != .uploading {
            auftrag.erwarteteRevision = aenderung.revision
        }
        UserDefaults.standard.set(
            aenderung.revision,
            forKey: "Tschluessli.SyncRevision.\(schluessel)"
        )
    }

    private func betroffeneBereiche(_ notification: Notification) -> Set<String> {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        var bereiche: Set<String> = []
        var hatUnaufloesbareLoeschung = false
        for key in keys {
            let identifiers = notification.userInfo?[key.rawValue] as? Set<PersistentIdentifier> ?? []
            for identifier in identifiers {
                if let bereich = bereich(fuer: identifier) {
                    if bereich != Self.internerSyncBereich { bereiche.insert(bereich) }
                } else {
                    hatUnaufloesbareLoeschung = true
                }
            }
        }
        if hatUnaufloesbareLoeschung { return Set(registry.bereiche) }
        return bereiche
    }

    private func bereich(fuer id: PersistentIdentifier) -> String? {
        if let _: SyncAuftrag = modelContext.registeredModel(for: id) { return Self.internerSyncBereich }
        if let _: SyncKonflikt = modelContext.registeredModel(for: id) { return Self.internerSyncBereich }
        if let _: ProfilModell = modelContext.registeredModel(for: id) { return "profil" }
        if let _: GesundheitModell = modelContext.registeredModel(for: id) { return "gesundheit" }
        if let _: WuenscheModell = modelContext.registeredModel(for: id) { return "wuensche" }
        if let _: BankkontoModell = modelContext.registeredModel(for: id) { return "finanzen" }
        if let _: SchuldenModell = modelContext.registeredModel(for: id) { return "finanzen" }
        if let _: VersicherungModell = modelContext.registeredModel(for: id) { return "finanzen" }
        if let _: LiegenschaftModell = modelContext.registeredModel(for: id) { return "finanzen" }
        if let _: WertsacheModell = modelContext.registeredModel(for: id) { return "finanzen" }
        if let _: SteuerdokumentModell = modelContext.registeredModel(for: id) { return "finanzen" }
        if let _: HinterbliebeneModell = modelContext.registeredModel(for: id) { return "kontakte" }
        if let _: VertrauenspersonModell = modelContext.registeredModel(for: id) { return "kontakte" }
        if let _: VertrauenspersonEinladungsHistorieModell = modelContext.registeredModel(for: id) { return "kontakte" }
        if let _: HerzensstueckModell = modelContext.registeredModel(for: id) { return "herzensstuecke" }
        if let _: HerzensstueckBildModell = modelContext.registeredModel(for: id) { return "herzensstuecke" }
        if let _: HerzensstueckDokumentModell = modelContext.registeredModel(for: id) { return "herzensstuecke" }
        if let _: HerzensstueckAudioModell = modelContext.registeredModel(for: id) { return "herzensstuecke" }
        if let _: AboModell = modelContext.registeredModel(for: id) { return "zugaenge" }
        if let _: AboEintrag = modelContext.registeredModel(for: id) { return "zugaenge" }
        if let _: DigitalekontenModell = modelContext.registeredModel(for: id) { return "zugaenge" }
        return nil
    }

    private static var aktivesDossierID: UUID? {
        UUID(uuidString: UserDefaults.standard.string(forKey: "aktivesDossierID") ?? "")
    }

    private static let cursorKey = "Tschluessli.SyncCursor.v1"
    private static let internerSyncBereich = "__sync__"

    static func revisionKey(dossierID: UUID, bereich: String) -> String {
        "Tschluessli.SyncRevision.\(SyncAuftrag.schluessel(dossierID: dossierID, bereich: bereich))"
    }
}

private nonisolated struct SyncUploadAntwort: Decodable, Sendable {
    let revision: Int64
}

private nonisolated struct SyncTransportFehler: Decodable { let error: String }

private nonisolated extension JSONEncoder {
    static var syncEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private nonisolated extension JSONDecoder {
    static var syncDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
