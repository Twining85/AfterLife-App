import Foundation
import SwiftData

nonisolated enum SyncFehlerklasse: Sendable, Equatable {
    case temporaer(String)
    case authentifizierung(String)
    case konflikt(String)
    case permanent(String)

    var meldung: String {
        switch self {
        case .temporaer(let meldung),
             .authentifizierung(let meldung),
             .konflikt(let meldung),
             .permanent(let meldung):
            return meldung
        }
    }
}

nonisolated enum SyncRetryPolicy {
    static func verzoegerung(nachVersuch versuch: Int) -> TimeInterval {
        let exponent = min(max(versuch - 1, 0), 10)
        return min(5 * pow(2, Double(exponent)), 3_600)
    }
}

@MainActor
final class SyncOutbox {
    private let modelContext: ModelContext
    private let uploadTimeout: TimeInterval = 5 * 60

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func markiereAenderung(
        dossierID: UUID,
        bereich: String,
        vorgang: SyncVorgang = .upsert,
        schemaVersion: Int,
        erwarteteRevision: Int64 = 0,
        jetzt: Date = Date()
    ) throws -> SyncAuftrag {
        guard Self.istGueltigerBereich(bereich), schemaVersion > 0, erwarteteRevision >= 0 else {
            throw SyncOutboxFehler.ungueltigerAuftrag
        }

        let schluessel = SyncAuftrag.schluessel(dossierID: dossierID, bereich: bereich)
        let descriptor = FetchDescriptor<SyncAuftrag>(
            predicate: #Predicate { $0.schluessel == schluessel }
        )

        if let auftrag = try modelContext.fetch(descriptor).first {
            auftrag.vorgang = vorgang
            auftrag.schemaVersion = schemaVersion
            auftrag.generation += 1
            auftrag.geaendertAm = jetzt
            auftrag.naechsterVersuchAm = jetzt
            auftrag.status = .pending
            auftrag.gesperrtSeit = nil
            auftrag.letzterFehler = nil
            try modelContext.save()
            return auftrag
        }

        let auftrag = SyncAuftrag(
            dossierID: dossierID,
            bereich: bereich,
            vorgang: vorgang,
            schemaVersion: schemaVersion,
            erwarteteRevision: erwarteteRevision,
            jetzt: jetzt
        )
        modelContext.insert(auftrag)
        try modelContext.save()
        return auftrag
    }

    func reserviereNaechstenAuftrag(jetzt: Date = Date()) throws -> SyncAuftragSnapshot? {
        let descriptor = FetchDescriptor<SyncAuftrag>(
            sortBy: [SortDescriptor(\SyncAuftrag.naechsterVersuchAm), SortDescriptor(\SyncAuftrag.erstelltAm)]
        )
        let auftraege = try modelContext.fetch(descriptor)

        for auftrag in auftraege where auftrag.status == .uploading {
            if let gesperrtSeit = auftrag.gesperrtSeit,
               jetzt.timeIntervalSince(gesperrtSeit) >= uploadTimeout {
                auftrag.status = .pending
                auftrag.gesperrtSeit = nil
                auftrag.naechsterVersuchAm = jetzt
            }
        }

        guard let auftrag = auftraege.first(where: {
            $0.status == .pending && $0.naechsterVersuchAm <= jetzt
        }) else {
            if modelContext.hasChanges { try modelContext.save() }
            return nil
        }

        auftrag.status = .uploading
        auftrag.gesperrtSeit = jetzt
        try modelContext.save()
        return SyncAuftragSnapshot(auftrag)
    }

    func bestaetige(
        _ snapshot: SyncAuftragSnapshot,
        serverRevision: Int64,
        jetzt: Date = Date()
    ) throws {
        guard serverRevision >= 0, let auftrag = try finde(id: snapshot.id) else { return }

        if auftrag.generation == snapshot.generation {
            modelContext.delete(auftrag)
        } else {
            auftrag.erwarteteRevision = serverRevision
            auftrag.status = .pending
            auftrag.gesperrtSeit = nil
            auftrag.naechsterVersuchAm = jetzt
        }
        try modelContext.save()
    }

    func vermerkeFehler(
        _ snapshot: SyncAuftragSnapshot,
        fehler: SyncFehlerklasse,
        jetzt: Date = Date()
    ) throws {
        guard let auftrag = try finde(id: snapshot.id),
              auftrag.generation == snapshot.generation else { return }

        auftrag.gesperrtSeit = nil
        auftrag.letzterFehler = fehler.meldung

        switch fehler {
        case .temporaer:
            auftrag.versuche += 1
            auftrag.status = .pending
            auftrag.naechsterVersuchAm = jetzt.addingTimeInterval(
                SyncRetryPolicy.verzoegerung(nachVersuch: auftrag.versuche)
            )
        case .authentifizierung, .konflikt, .permanent:
            auftrag.status = .blocked
        }
        try modelContext.save()
    }

    func entsperreBlockierteAuftraege(jetzt: Date = Date()) throws {
        let auftraege = try modelContext.fetch(FetchDescriptor<SyncAuftrag>())
        for auftrag in auftraege where auftrag.status == .blocked {
            auftrag.status = .pending
            auftrag.naechsterVersuchAm = jetzt
            auftrag.letzterFehler = nil
        }
        if modelContext.hasChanges { try modelContext.save() }
    }

    func anzahlOffen() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<SyncAuftrag>())
    }

    private func finde(id: UUID) throws -> SyncAuftrag? {
        let descriptor = FetchDescriptor<SyncAuftrag>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private static func istGueltigerBereich(_ bereich: String) -> Bool {
        bereich.range(of: "^[a-z][a-z0-9_-]{0,63}$", options: .regularExpression) != nil
    }
}

nonisolated enum SyncOutboxFehler: Error, Equatable {
    case ungueltigerAuftrag
}
