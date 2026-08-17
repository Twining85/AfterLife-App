import Foundation

nonisolated protocol SyncAuftragVerarbeiter: Sendable {
    func verarbeite(_ auftrag: SyncAuftragSnapshot) async throws -> Int64
}

nonisolated enum SyncVerarbeitungsFehler: Error, Sendable, Equatable {
    case temporaer(String)
    case authentifizierung(String)
    case konflikt(String)
    case permanent(String)

    var fehlerklasse: SyncFehlerklasse {
        switch self {
        case .temporaer(let meldung): .temporaer(meldung)
        case .authentifizierung(let meldung): .authentifizierung(meldung)
        case .konflikt(let meldung): .konflikt(meldung)
        case .permanent(let meldung): .permanent(meldung)
        }
    }
}

@MainActor
final class SyncCoordinator {
    private let outbox: SyncOutbox
    private let verarbeiter: any SyncAuftragVerarbeiter

    private(set) var laeuft = false
    private(set) var letzterErfolgreicherLauf: Date?
    private(set) var letzterFehler: String?

    init(outbox: SyncOutbox, verarbeiter: any SyncAuftragVerarbeiter) {
        self.outbox = outbox
        self.verarbeiter = verarbeiter
    }

    func synchronisieren(jetzt: @escaping @Sendable () -> Date = Date.init) async {
        guard !laeuft else { return }
        laeuft = true
        defer { laeuft = false }

        do {
            while let auftrag = try outbox.reserviereNaechstenAuftrag(jetzt: jetzt()) {
                do {
                    let revision = try await verarbeiter.verarbeite(auftrag)
                    try outbox.bestaetige(auftrag, serverRevision: revision, jetzt: jetzt())
                    letzterErfolgreicherLauf = jetzt()
                    letzterFehler = nil
                } catch let fehler as SyncVerarbeitungsFehler {
                    try outbox.vermerkeFehler(auftrag, fehler: fehler.fehlerklasse, jetzt: jetzt())
                    letzterFehler = fehler.fehlerklasse.meldung
                    if case .temporaer = fehler { continue }
                    break
                } catch {
                    let meldung = "Die Synchronisation ist vorübergehend fehlgeschlagen."
                    try outbox.vermerkeFehler(
                        auftrag,
                        fehler: .temporaer(meldung),
                        jetzt: jetzt()
                    )
                    letzterFehler = meldung
                }
            }
        } catch {
            letzterFehler = "Die lokale Sync-Warteschlange konnte nicht verarbeitet werden."
        }
    }
}
