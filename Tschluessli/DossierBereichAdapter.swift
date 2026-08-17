import Foundation
import SwiftData

nonisolated struct DossierBereichPayload: Sendable, Equatable {
    let bereich: String
    let schemaVersion: Int
    let daten: Data
}

@MainActor
protocol DossierBereichAdapter {
    var bereich: String { get }
    var schemaVersion: Int { get }

    func exportiere(dossierID: UUID, aus modelContext: ModelContext) async throws -> DossierBereichPayload
    func validiere(_ daten: Data, schemaVersion: Int) throws -> Data
}

@MainActor
struct DossierBereichAdapterRegistry {
    private let adapterNachBereich: [String: any DossierBereichAdapter]

    init() throws {
        try self.init(adapter: Self.standardAdapter)
    }

    init(adapter: [any DossierBereichAdapter]) throws {
        var ergebnis: [String: any DossierBereichAdapter] = [:]
        for eintrag in adapter {
            guard Self.istGueltigerBereich(eintrag.bereich),
                  eintrag.schemaVersion > 0,
                  ergebnis[eintrag.bereich] == nil else {
                throw DossierBereichAdapterFehler.ungueltigeRegistry
            }
            ergebnis[eintrag.bereich] = eintrag
        }
        adapterNachBereich = ergebnis
    }

    var bereiche: [String] {
        adapterNachBereich.keys.sorted()
    }

    func adapter(fuer bereich: String) throws -> any DossierBereichAdapter {
        guard let adapter = adapterNachBereich[bereich] else {
            throw DossierBereichAdapterFehler.unbekannterBereich(bereich)
        }
        return adapter
    }

    static var standardAdapter: [any DossierBereichAdapter] {
        [
            ProfilBereichAdapter(),
            GesundheitBereichAdapter(),
            WuenscheBereichAdapter(),
            FinanzenBereichAdapter(),
            KontakteBereichAdapter(),
            HerzensstueckeBereichAdapter(),
            ZugaengeBereichAdapter()
        ]
    }

    private static func istGueltigerBereich(_ bereich: String) -> Bool {
        bereich.range(of: "^[a-z][a-z0-9_-]{0,63}$", options: .regularExpression) != nil
    }
}

nonisolated enum DossierBereichAdapterFehler: Error, Equatable {
    case ungueltigeRegistry
    case unbekannterBereich(String)
    case nichtUnterstuetzteSchemaVersion(Int)
    case ungueltigerPayload
}

@MainActor
private protocol CodableDossierBereichAdapter: DossierBereichAdapter {
    associatedtype Payload: Codable & Sendable
    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) async throws -> Payload
}

extension CodableDossierBereichAdapter {
    func exportiere(dossierID: UUID, aus modelContext: ModelContext) async throws -> DossierBereichPayload {
        let payload = try await erzeugePayload(dossierID: dossierID, aus: modelContext)
        return DossierBereichPayload(
            bereich: bereich,
            schemaVersion: schemaVersion,
            daten: try Self.encoder.encode(payload)
        )
    }

    func validiere(_ daten: Data, schemaVersion: Int) throws -> Data {
        guard schemaVersion == self.schemaVersion else {
            throw DossierBereichAdapterFehler.nichtUnterstuetzteSchemaVersion(schemaVersion)
        }
        do {
            let payload = try Self.decoder.decode(Payload.self, from: daten)
            return try Self.encoder.encode(payload)
        } catch let fehler as DossierBereichAdapterFehler {
            throw fehler
        } catch {
            throw DossierBereichAdapterFehler.ungueltigerPayload
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
struct ProfilBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "profil"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) throws -> CloudDatenListe<CloudProfilDaten> {
        let modelle = try modelContext.fetch(FetchDescriptor<ProfilModell>())
        return CloudDatenListe(items: modelle.filter { $0.dossierID == dossierID }.map(CloudProfilDaten.init))
    }
}

@MainActor
struct GesundheitBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "gesundheit"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) throws -> CloudDatenListe<CloudGesundheitDaten> {
        let modelle = try modelContext.fetch(FetchDescriptor<GesundheitModell>())
        return CloudDatenListe(items: modelle.filter { $0.dossierID == dossierID }.map(CloudGesundheitDaten.init))
    }
}

@MainActor
struct WuenscheBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "wuensche"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) throws -> CloudDatenListe<CloudWuenscheDaten> {
        let modelle = try modelContext.fetch(FetchDescriptor<WuenscheModell>())
        return CloudDatenListe(items: modelle.filter { $0.dossierID == dossierID }.map(CloudWuenscheDaten.init))
    }
}

@MainActor
struct FinanzenBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "finanzen"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) throws -> CloudFinanzenDaten {
        CloudFinanzenDaten(
            bankkonten: try modelContext.fetch(FetchDescriptor<BankkontoModell>()).filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Bankkonto.init),
            schulden: try modelContext.fetch(FetchDescriptor<SchuldenModell>()).filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Schuld.init),
            versicherungen: try modelContext.fetch(FetchDescriptor<VersicherungModell>()).filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Versicherung.init),
            liegenschaften: try modelContext.fetch(FetchDescriptor<LiegenschaftModell>()).filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Liegenschaft.init),
            wertsachen: try modelContext.fetch(FetchDescriptor<WertsacheModell>()).filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Wertsache.init),
            steuerdokumente: try modelContext.fetch(FetchDescriptor<SteuerdokumentModell>()).filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Steuerdokument.init)
        )
    }
}

@MainActor
struct KontakteBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "kontakte"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) throws -> CloudKontaktDaten {
        CloudKontaktDaten(
            hinterbliebene: try modelContext.fetch(FetchDescriptor<HinterbliebeneModell>()).filter { $0.dossierID == dossierID }.map(CloudKontaktDaten.Hinterbliebene.init),
            vertrauenspersonen: try modelContext.fetch(FetchDescriptor<VertrauenspersonModell>()).filter { $0.dossierID == dossierID }.map(CloudKontaktDaten.Vertrauensperson.init)
        )
    }
}

@MainActor
struct HerzensstueckeBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "herzensstuecke"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) throws -> CloudDatenListe<CloudHerzensstueckDaten> {
        let modelle = try modelContext.fetch(FetchDescriptor<HerzensstueckModell>())
        return CloudDatenListe(items: modelle.filter { $0.dossierID == dossierID }.map(CloudHerzensstueckDaten.init))
    }
}

@MainActor
struct ZugaengeBereichAdapter: CodableDossierBereichAdapter {
    let bereich = "zugaenge"
    let schemaVersion = 1

    func erzeugePayload(dossierID: UUID, aus modelContext: ModelContext) async throws -> VerschluesselterCloudBereich {
        let abos = try modelContext.fetch(FetchDescriptor<AboModell>())
            .filter { $0.dossierID == dossierID }
            .map(CloudAboDaten.init)
        let konten = try modelContext.fetch(FetchDescriptor<DigitalekontenModell>())
            .filter { $0.dossierID == dossierID }
            .map(CloudZugangsDaten.DigitalesKonto.init)
        return try await CloudFeldVerschluesselung.shared.verschluesseln(
            CloudZugangsDaten(abos: abos, digitaleKonten: konten)
        )
    }
}
