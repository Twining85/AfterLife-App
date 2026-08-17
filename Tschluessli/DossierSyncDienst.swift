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
    private(set) static weak var shared: DossierSyncDienst?
    private let modelContext: ModelContext
    private let registry: DossierBereichAdapterRegistry
    private let outbox: SyncOutbox
    private let coordinator: SyncCoordinator
    private let transport: DossierSyncTransport
    private var beobachter: [NSObjectProtocol] = []
    private var debounceTask: Task<Void, Never>?
    private var syncLaufTask: Task<Void, Never>?
    private var ausstehendeBereiche: Set<String> = []
    private var initialerAbgleichAusstehend = false
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
        Self.shared = self
    }

    deinit {
        beobachter.forEach(NotificationCenter.default.removeObserver)
        debounceTask?.cancel()
        syncLaufTask?.cancel()
    }

    func starten() {
        guard beobachter.isEmpty else { return }
        bereinigeAuftraegeDesVeraltetenBreitbandSyncs()
        beobachter.append(NotificationCenter.default.addObserver(
            forName: .dossierRecoveryEingerichtet,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.planeSynchronisation(bereiche: ["zugaenge"])
            }
        })
        beobachter.append(NotificationCenter.default.addObserver(
            forName: .dossierRecoveryWiederhergestellt,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = _Concurrency.Task<Void, Never> { @MainActor in
                    guard let dossierID = Self.aktivesDossierID else { return }
                    _ = await self?.dossierNachRecoveryNeuLaden(dossierID: dossierID)
                }
            }
        })
        beobachter.append(NotificationCenter.default.addObserver(
            forName: .dossierSyncAngefordert,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.synchronisieren()
            }
        })
        beobachter.append(NotificationCenter.default.addObserver(
            forName: .dossierBereichGespeichert,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let bereich = notification.object as? String else { return }
                self?.planeSynchronisation(bereiche: [bereich])
            }
        })
        planeSynchronisation(alleBereicheMarkieren: true)
    }

    func synchronisieren() {
        synchronisierenSofort()
    }

    func synchronisierenSofort() {
        if modelContext.hasChanges {
            try? modelContext.save()
        }
        debounceTask?.cancel()
        debounceTask = nil
        starteNaechstenSyncLaufFallsNoetig(auchOhneAenderungen: true)
    }

    func synchronisierenImHintergrund(abgeschlossen: @escaping @MainActor () -> Void) {
        synchronisierenSofort()
        Task { @MainActor [weak self] in
            while let task = self?.syncLaufTask {
                await task.value
            }
            abgeschlossen()
        }
    }

    /// Sichert ein neu erstelltes Recovery-Paket, bevor der zugehörige
    /// 12-Wörter-Code angezeigt oder exportiert werden darf.
    func recoveryPaketSynchronisieren() async -> Bool {
        guard let dossierID = Self.aktivesDossierID else { return false }
        if let syncLaufTask { await syncLaufTask.value }
        do {
            // Die aktuelle Revision wird unmittelbar vom Server gelesen. So
            // kann ein alter, blockierter Auftrag nicht verhindern, dass das
            // neue Recovery-Paket zum gerade ausgegebenen Code gehört.
            let cloudBereich = try await CloudDossierSyncService.shared.laden(
                dossierID: dossierID,
                bereich: "zugaenge"
            )
            let serverRevision = Int64(cloudBereich?.revision ?? 0)
            let schluessel = SyncAuftrag.schluessel(dossierID: dossierID, bereich: "zugaenge")

            try loescheAuftrag(schluessel: schluessel)
            let konfliktDescriptor = FetchDescriptor<SyncKonflikt>(
                predicate: #Predicate { $0.schluessel == schluessel }
            )
            try modelContext.fetch(konfliktDescriptor).forEach(modelContext.delete)
            UserDefaults.standard.set(
                serverRevision,
                forKey: Self.revisionKey(dossierID: dossierID, bereich: "zugaenge")
            )

            let adapter = try registry.adapter(fuer: "zugaenge")
            _ = try outbox.markiereAenderung(
                dossierID: dossierID,
                bereich: "zugaenge",
                schemaVersion: adapter.schemaVersion,
                erwarteteRevision: serverRevision
            )
            await coordinator.synchronisieren()

            return try !hatOffenenAuftrag(dossierID: dossierID, bereich: "zugaenge")
                && !hatGespeichertenKonflikt(dossierID: dossierID, bereich: "zugaenge")
        } catch {
            return false
        }
    }

    /// Pull-to-Refresh lädt bewusst zuerst den Serverstand. Offene lokale
    /// Änderungen werden dabei als Konflikt festgehalten, statt den Cloud-Stand
    /// unbemerkt zu überschreiben.
    func manuellerVollabgleich() async -> Int {
        if let syncLaufTask { await syncLaufTask.value }
        if modelContext.hasChanges { try? modelContext.save() }

        // Zuerst den aktuellen Cloud-Stand abholen. Danach werden allfällige
        // bereits vorgemerkte lokale Bereichsänderungen verarbeitet und der
        // endgültige Serverstand nochmals geladen.
        await ladeAenderungenHerunter()
        synchronisierenSofort()
        while let syncLaufTask {
            await syncLaufTask.value
        }
        await ladeAenderungenHerunter()

        guard let dossierID = Self.aktivesDossierID else { return 0 }
        let descriptor = FetchDescriptor<SyncKonflikt>(
            predicate: #Predicate { $0.dossierID == dossierID }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func manuellenKonfliktMitCloudLoesen() async throws {
        guard let dossierID = Self.aktivesDossierID else { return }
        let descriptor = FetchDescriptor<SyncKonflikt>(
            predicate: #Predicate { $0.dossierID == dossierID }
        )
        let konflikte = try modelContext.fetch(descriptor)
        ignoriertEigeneSpeicherung = true
        defer { ignoriertEigeneSpeicherung = false }

        for konflikt in konflikte {
            if konflikt.vorgangRaw == SyncVorgang.delete.rawValue {
                try DossierBereichImport.loesche(
                    bereich: konflikt.bereich,
                    dossierID: dossierID,
                    in: modelContext
                )
            } else {
                guard let payload = konflikt.serverPayload else {
                    throw DossierBereichAdapterFehler.ungueltigerPayload
                }
                let adapter = try registry.adapter(fuer: konflikt.bereich)
                let validiert = try adapter.validiere(payload, schemaVersion: konflikt.schemaVersion)
                try await DossierBereichImport.importiere(
                    validiert,
                    bereich: konflikt.bereich,
                    dossierID: dossierID,
                    in: modelContext
                )
            }
            try loescheAuftrag(schluessel: konflikt.schluessel)
            UserDefaults.standard.set(
                konflikt.serverRevision,
                forKey: Self.revisionKey(dossierID: dossierID, bereich: konflikt.bereich)
            )
            modelContext.delete(konflikt)
        }
        try modelContext.save()
        if !konflikte.isEmpty {
            NotificationCenter.default.post(name: .dossierCloudDatenAktualisiert, object: Set(konflikte.map(\.bereich)))
        }
        await ladeAenderungenHerunter()
    }

    func manuellenKonfliktMitLokalemDossierLoesen() async throws {
        guard let dossierID = Self.aktivesDossierID else { return }
        let konfliktDescriptor = FetchDescriptor<SyncKonflikt>(
            predicate: #Predicate { $0.dossierID == dossierID }
        )
        let konflikte = try modelContext.fetch(konfliktDescriptor)
        let serverRevisionNachBereich = Dictionary(
            uniqueKeysWithValues: konflikte.map { ($0.bereich, $0.serverRevision) }
        )

        for konflikt in konflikte {
            UserDefaults.standard.set(
                konflikt.serverRevision,
                forKey: Self.revisionKey(dossierID: dossierID, bereich: konflikt.bereich)
            )
            try loescheAuftrag(schluessel: konflikt.schluessel)
            modelContext.delete(konflikt)
        }
        try modelContext.save()

        // Bewusste Benutzerentscheidung: Der komplette lokale Dossierstand wird
        // als neue Revision für jeden strukturierten Cloud-Bereich hochgeladen.
        for bereich in registry.bereiche {
            let adapter = try registry.adapter(fuer: bereich)
            let revision = serverRevisionNachBereich[bereich]
                ?? (UserDefaults.standard.object(
                    forKey: Self.revisionKey(dossierID: dossierID, bereich: bereich)
                ) as? NSNumber)?.int64Value
                ?? 0
            _ = try outbox.markiereAenderung(
                dossierID: dossierID,
                bereich: bereich,
                schemaVersion: adapter.schemaVersion,
                erwarteteRevision: revision
            )
        }
        await coordinator.synchronisieren()
        await ladeAenderungenHerunter()
    }

    private func loescheAuftrag(schluessel: String) throws {
        let descriptor = FetchDescriptor<SyncAuftrag>(
            predicate: #Predicate { $0.schluessel == schluessel }
        )
        try modelContext.fetch(descriptor).forEach(modelContext.delete)
    }

    private func planeSynchronisation(
        alleBereicheMarkieren: Bool = false,
        bereiche: Set<String> = []
    ) {
        ausstehendeBereiche.formUnion(bereiche)
        initialerAbgleichAusstehend = initialerAbgleichAusstehend || alleBereicheMarkieren
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self else { return }
            debounceTask = nil
            starteNaechstenSyncLaufFallsNoetig()
        }
    }

    private func starteNaechstenSyncLaufFallsNoetig(auchOhneAenderungen: Bool = false) {
        guard syncLaufTask == nil else { return }
        guard auchOhneAenderungen || initialerAbgleichAusstehend || !ausstehendeBereiche.isEmpty else { return }

        let bereiche = ausstehendeBereiche
        let initialerAbgleich = initialerAbgleichAusstehend
        ausstehendeBereiche.removeAll()
        initialerAbgleichAusstehend = false

        syncLaufTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await fuehreSynchronisationAus(
                initialerAbgleich: initialerAbgleich,
                bereiche: bereiche
            )
            syncLaufTask = nil
            if initialerAbgleichAusstehend || !ausstehendeBereiche.isEmpty {
                starteNaechstenSyncLaufFallsNoetig()
            }
        }
    }

    private func fuehreSynchronisationAus(
        initialerAbgleich: Bool,
        bereiche: Set<String>
    ) async {
        guard let dossierID = Self.aktivesDossierID else { return }
        ignoriertEigeneSpeicherung = true
        defer { ignoriertEigeneSpeicherung = false }

        do {
            try ordneVerwaisteDatensaetzeZu(dossierID: dossierID)
        } catch {
            // Ohne eindeutige Dossier-Zuordnung darf kein unvollständiger Upload entstehen.
            return
        }

        if initialerAbgleich {
            await ladeAenderungenHerunter()
        }
        let markierteBereiche = initialerAbgleich
            ? Set(registry.bereiche.filter {
                UserDefaults.standard.object(
                    forKey: Self.revisionKey(dossierID: dossierID, bereich: $0)
                ) == nil && !self.hatGespeichertenKonflikt(dossierID: dossierID, bereich: $0)
            }).union(bereiche)
            : bereiche

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
        await coordinator.synchronisieren()
        await ladeAenderungenHerunter()
    }

    /// Migriert lokale Bestandsdaten, die vor der dossierbasierten Speicherung
    /// angelegt wurden. Neue Datensätze sollen ihre Dossier-ID bereits beim
    /// Erstellen erhalten; diese Absicherung gilt zentral für alle Bereiche.
    private func ordneVerwaisteDatensaetzeZu(dossierID: UUID) throws {
        try ordneVerwaiste(ProfilModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(GesundheitModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(WuenscheModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })

        try ordneVerwaiste(BankkontoModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(SchuldenModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(VersicherungModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(LiegenschaftModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(WertsacheModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(SteuerdokumentModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })

        try ordneVerwaiste(HinterbliebeneModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(VertrauenspersonModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(HerzensstueckModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })

        try ordneVerwaiste(AboModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(AboEintrag.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(DigitalekontenModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })

        // Vorbereitung für den späteren geschützten Dokument-Upload.
        try ordneVerwaiste(DokumenteModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })
        try ordneVerwaiste(FotoalbumBildModell.self, dossierID: dossierID, lese: { $0.dossierID }, setze: { $0.dossierID = $1 })

        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private func ordneVerwaiste<T: PersistentModel>(
        _ typ: T.Type,
        dossierID: UUID,
        lese: (T) -> UUID?,
        setze: (T, UUID) -> Void
    ) throws {
        for datensatz in try modelContext.fetch(FetchDescriptor<T>()) where lese(datensatz) == nil {
            setze(datensatz, dossierID)
        }
    }

    @discardableResult
    private func ladeAenderungenHerunter(dossierID expliziteDossierID: UUID? = nil) async -> Bool {
        guard let dossierID = expliziteDossierID ?? Self.aktivesDossierID else { return false }
        let cursorKey = Self.cursorKey(dossierID: dossierID)
        var cursor = UserDefaults.standard.string(forKey: cursorKey) ?? "0"
        do {
            while true {
                let antwort = try await transport.herunterladen(cursor: cursor)
                try await importiere(antwort.changes)
                cursor = antwort.nextCursor
                UserDefaults.standard.set(cursor, forKey: cursorKey)
                if !antwort.hasMore { break }
            }
            return true
        } catch {
            // Downloadfehler lassen den Cursor unverändert und werden beim nächsten Auslöser erneut versucht.
            return false
        }
    }

    func dossierNachRecoveryNeuLaden(dossierID: UUID) async -> Bool {
        do {
            try bereiteVollstaendigeCloudWiederherstellungVor(dossierID: dossierID)
            return await ladeAenderungenHerunter(dossierID: dossierID)
        } catch {
            return false
        }
    }

    private func bereiteVollstaendigeCloudWiederherstellungVor(dossierID: UUID) throws {
        debounceTask?.cancel()

        let auftraege = FetchDescriptor<SyncAuftrag>(
            predicate: #Predicate { $0.dossierID == dossierID }
        )
        try modelContext.fetch(auftraege).forEach(modelContext.delete)

        let konflikte = FetchDescriptor<SyncKonflikt>(
            predicate: #Predicate { $0.dossierID == dossierID }
        )
        try modelContext.fetch(konflikte).forEach(modelContext.delete)

        for bereich in registry.bereiche {
            UserDefaults.standard.removeObject(
                forKey: Self.revisionKey(dossierID: dossierID, bereich: bereich)
            )
        }
        UserDefaults.standard.removeObject(forKey: Self.cursorKey(dossierID: dossierID))
        try modelContext.save()
    }

    private func importiere(_ aenderungen: [SyncDownloadAenderung]) async throws {
        guard !aenderungen.isEmpty else { return }
        ignoriertEigeneSpeicherung = true
        defer { ignoriertEigeneSpeicherung = false }
        var importierteBereiche: Set<String> = []
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
            importierteBereiche.insert(aenderung.sectionType)
        }
        try modelContext.save()
        if !importierteBereiche.isEmpty {
            NotificationCenter.default.post(
                name: .dossierCloudDatenAktualisiert,
                object: importierteBereiche
            )
        }
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

    /// Eine frühere Testversion hat bei jeder lokalen Speicherung alle Bereiche
    /// in die Outbox gelegt. Diese Aufträge können mit veralteten Revisionen
    /// dauerhaft blockieren. Sie werden einmalig entfernt; anschließend erzeugen
    /// nur noch die expliziten Bereichs-Speicherungen neue Aufträge.
    private func bereinigeAuftraegeDesVeraltetenBreitbandSyncs() {
        let key = "Tschluessli.SyncMigration.ExakterBereich.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try modelContext.fetch(FetchDescriptor<SyncAuftrag>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<SyncKonflikt>()).forEach(modelContext.delete)
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            // Ohne erfolgreiche Bereinigung wird sie beim nächsten Start wiederholt.
        }
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

    private static var aktivesDossierID: UUID? {
        UUID(uuidString: UserDefaults.standard.string(forKey: "aktivesDossierID") ?? "")
    }

    private static func cursorKey(dossierID: UUID) -> String {
        "Tschluessli.SyncCursor.v2.\(dossierID.uuidString.lowercased())"
    }
    static func revisionKey(dossierID: UUID, bereich: String) -> String {
        "Tschluessli.SyncRevision.\(SyncAuftrag.schluessel(dossierID: dossierID, bereich: bereich))"
    }
}

extension Notification.Name {
    static let dossierBereichGespeichert = Notification.Name("Tschluessli.DossierBereichGespeichert")
    static let dossierCloudDatenAktualisiert = Notification.Name("Tschluessli.DossierCloudDatenAktualisiert")
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
