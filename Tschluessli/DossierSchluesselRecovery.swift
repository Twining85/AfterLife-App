import CryptoKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Security
import UIKit

nonisolated struct DossierRecoveryPaket: Codable, Sendable, Equatable {
    enum Status: String, Codable, Sendable {
        case aktiv
        case obsolet
    }

    let version: Int
    let algorithmus: String
    let verschluesselterSchluessel: String
    let id: UUID
    let status: Status
    let erstelltAm: Date
    let codeFingerabdruck: String?
    let obsoleteCodeFingerabdruecke: [String]

    init(
        version: Int,
        algorithmus: String,
        verschluesselterSchluessel: String,
        id: UUID = UUID(),
        status: Status = .aktiv,
        erstelltAm: Date = Date(),
        codeFingerabdruck: String? = nil,
        obsoleteCodeFingerabdruecke: [String] = []
    ) {
        self.version = version
        self.algorithmus = algorithmus
        self.verschluesselterSchluessel = verschluesselterSchluessel
        self.id = id
        self.status = status
        self.erstelltAm = erstelltAm
        self.codeFingerabdruck = codeFingerabdruck
        self.obsoleteCodeFingerabdruecke = obsoleteCodeFingerabdruecke
    }

    private enum CodingKeys: String, CodingKey {
        case version, algorithmus, verschluesselterSchluessel, id, status, erstelltAm
        case codeFingerabdruck, obsoleteCodeFingerabdruecke
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        algorithmus = try container.decode(String.self, forKey: .algorithmus)
        verschluesselterSchluessel = try container.decode(String.self, forKey: .verschluesselterSchluessel)
        // Bereits ausgelieferte Pakete bleiben migrierbar. Sobald ein neuer
        // Code erstellt wird, erhält er zwingend eine eindeutige ID und Status.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .aktiv
        erstelltAm = try container.decodeIfPresent(Date.self, forKey: .erstelltAm) ?? .distantPast
        codeFingerabdruck = try container.decodeIfPresent(String.self, forKey: .codeFingerabdruck)
        obsoleteCodeFingerabdruecke = try container.decodeIfPresent(
            [String].self,
            forKey: .obsoleteCodeFingerabdruecke
        ) ?? []
    }
}

enum DossierRecoveryFehler: LocalizedError {
    case ungueltigerCode
    case keinRecoveryPaket
    case falscherCode
    case ungueltigesPaket
    case recoveryNichtSynchronisiert
    case recoveryNichtSynchronisiertMitUrsache(String)
    case cloudWiederherstellungFehlgeschlagen
    case cloudWiederherstellungMitUrsache(String)
    case codeObsolet

    var errorDescription: String? {
        switch self {
        case .ungueltigerCode:
            "Der Wiederherstellungscode muss aus genau 12 gültigen Wörtern bestehen."
        case .keinRecoveryPaket:
            "Für dieses Dossier ist noch kein Wiederherstellungspaket vorhanden."
        case .falscherCode:
            "Der Wiederherstellungscode ist nicht korrekt oder gehört zu einem anderen Profil."
        case .ungueltigesPaket:
            "Das Wiederherstellungspaket konnte nicht verarbeitet werden."
        case .recoveryNichtSynchronisiert:
            "Der Wiederherstellungscode konnte noch nicht sicher in der Cloud gespeichert werden. Bitte versuche es erneut."
        case .recoveryNichtSynchronisiertMitUrsache(let ursache):
            "Der Wiederherstellungscode konnte noch nicht sicher in der Cloud gespeichert werden: \(ursache)"
        case .cloudWiederherstellungFehlgeschlagen:
            "Der Schlüssel wurde bestätigt, aber das Dossier konnte noch nicht vollständig aus der Cloud geladen werden. Bitte versuche es erneut."
        case .cloudWiederherstellungMitUrsache(let ursache):
            "Der Wiederherstellungscode wurde bestätigt, aber der Cloud-Download ist fehlgeschlagen: \(ursache)"
        case .codeObsolet:
            "Dieser Wiederherstellungscode ist nicht mehr gültig. Verwende den zuletzt erstellten Wiederherstellungscode."
        }
    }
}

nonisolated enum DossierRecoveryCode {
    private static let qrPraefix = "TSCHLUESSLI-RECOVERY:1:"

    // 8 x 16 x 16 eindeutig lesbare Wortkombinationen ergeben 2'048 Wörter.
    // Zwölf unabhaengige 11-Bit-Wörter liefern 132 Bit Recovery-Entropie.
    private static let vorsilben = [
        "klar", "leise", "sanft", "still", "frei", "weit", "hell", "treu"
    ]
    private static let anfaenge = [
        "abend", "alpen", "birken", "blumen", "brunnen", "farben", "felsen", "fenster",
        "garten", "gold", "hafen", "herbst", "himmel", "insel", "kiesel", "morgen"
    ]
    private static let enden = [
        "anker", "bogen", "brise", "feder", "funke", "glocke", "hain", "karte",
        "kranz", "laterne", "perle", "quelle", "segel", "stern", "ufer", "wolke"
    ]

    static let woerter: [String] = vorsilben.flatMap { vorsilbe in
        anfaenge.flatMap { anfang in
            enden.map { vorsilbe + anfang + $0 }
        }
    }

    static func erstellen() throws -> [String] {
        var bytes = [UInt8](repeating: 0, count: 24)
        let status = bytes.withUnsafeMutableBytes { puffer in
            guard let basisadresse = puffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, puffer.count, basisadresse)
        }
        guard status == errSecSuccess else {
            throw DossierRecoveryFehler.ungueltigerCode
        }
        return stride(from: 0, to: bytes.count, by: 2).map { index in
            let wert = (UInt16(bytes[index]) << 8) | UInt16(bytes[index + 1])
            return woerter[Int(wert & 0x07ff)]
        }
    }

    static func normalisieren(_ eingabe: String) throws -> String {
        let teile = eingabe
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)
        guard teile.count == 12, teile.allSatisfy(woerter.contains) else {
            throw DossierRecoveryFehler.ungueltigerCode
        }
        return teile.joined(separator: " ")
    }

    static func schluessel(aus code: String) throws -> SymmetricKey {
        let normalisiert = try normalisieren(code)
        let material = Data("Tschluessli-Dossier-Recovery-v1\u{0}\(normalisiert)".utf8)
        return SymmetricKey(data: Data(SHA256.hash(data: material)))
    }

    static func fingerabdruck(aus code: String) throws -> String {
        let normalisiert = try normalisieren(code)
        let material = Data("Tschluessli-Dossier-Recovery-Fingerprint-v1\u{0}\(normalisiert)".utf8)
        return Data(SHA256.hash(data: material)).base64EncodedString()
    }

    static func qrCodeInhalt(aus code: String) throws -> String {
        qrPraefix + (try normalisieren(code))
    }

    static func ausQRCode(_ inhalt: String) throws -> String {
        guard inhalt.hasPrefix(qrPraefix) else {
            throw DossierRecoveryFehler.ungueltigerCode
        }
        return try normalisieren(String(inhalt.dropFirst(qrPraefix.count)))
    }
}

@MainActor
enum DossierRecoveryPDF {
    static func erstellen(code: String) throws -> URL {
        let normalisierterCode = try DossierRecoveryCode.normalisieren(code)
        let qrCode = try qrCodeBild(code: normalisierterCode)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Tschlüssli Wiederherstellungscode",
            kCGPDFContextAuthor as String: "Tschlüssli"
        ]
        let seite = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: seite, format: format)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tschluessli-Wiederherstellungscode.pdf")

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let titel = "Tschlüssli Wiederherstellungscode"
            titel.draw(at: CGPoint(x: 48, y: 58), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 25),
                .foregroundColor: UIColor(red: 0.16, green: 0.36, blue: 0.42, alpha: 1)
            ])
            let hinweis = "Neues Gerät? Wähle bei der Registrierung „Mit bestehendem Konto anmelden“ und gib deine E-Mail-Adresse und dein Passwort ein. Danach kannst du entweder die 12 Wörter manuell eingeben oder den QR-Code scannen, um deine verschlüsselten Daten wiederherzustellen. Wer diese Wörter kennt, kann auf deine Daten zugreifen. Bewahre dieses Dokument deshalb sicher auf und teile es niemals."
            hinweis.draw(in: CGRect(x: 48, y: 108, width: 499, height: 108), withAttributes: [
                .font: UIFont.systemFont(ofSize: 13.5),
                .foregroundColor: UIColor.darkGray
            ])
            let woerter = normalisierterCode.split(separator: " ").map(String.init)
            for (index, wort) in woerter.enumerated() {
                let spalte = index / 6
                let zeile = index % 6
                let text = "\(index + 1).  \(wort)"
                text.draw(at: CGPoint(x: 66 + CGFloat(spalte) * 250, y: 230 + CGFloat(zeile) * 58), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: UIColor.black
                ])
            }

            let qrRahmen = CGRect(x: 204, y: 552, width: 187, height: 187)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: qrRahmen, cornerRadius: 8).fill()
            qrCode.draw(in: qrRahmen.insetBy(dx: 10, dy: 10))

            let qrHinweis = "Auf einem neuen iPhone direkt in Tschlüssli scannen. Der QR-Code enthält den vollständigen Wiederherstellungscode."
            let absatz = NSMutableParagraphStyle()
            absatz.alignment = .center
            qrHinweis.draw(in: CGRect(x: 100, y: 742, width: 395, height: 34), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: absatz
            ])
            "Erstellt am \(Date().formatted(date: .long, time: .shortened))"
                .draw(at: CGPoint(x: 48, y: 802), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ])
        }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var geschuetzteURL = url
        try geschuetzteURL.setResourceValues(resourceValues)
        return url
    }

    static func qrCodeInhalt(code: String) throws -> String {
        try DossierRecoveryCode.qrCodeInhalt(aus: code)
    }

    private static func qrCodeBild(code: String) throws -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(try qrCodeInhalt(code: code).utf8)
        filter.correctionLevel = "Q"
        guard let ausgabe = filter.outputImage else {
            throw DossierRecoveryFehler.ungueltigerCode
        }

        let skaliert = ausgabe.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgBild = context.createCGImage(skaliert, from: skaliert.extent) else {
            throw DossierRecoveryFehler.ungueltigerCode
        }
        return UIImage(cgImage: cgBild)
    }
}
