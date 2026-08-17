import CryptoKit
import Foundation
import Security
import UIKit

nonisolated struct DossierRecoveryPaket: Codable, Sendable, Equatable {
    let version: Int
    let algorithmus: String
    let verschluesselterSchluessel: String
}

enum DossierRecoveryFehler: LocalizedError {
    case ungueltigerCode
    case keinRecoveryPaket
    case falscherCode
    case ungueltigesPaket

    var errorDescription: String? {
        switch self {
        case .ungueltigerCode:
            "Der Wiederherstellungscode muss aus genau 12 gültigen Wörtern bestehen."
        case .keinRecoveryPaket:
            "Für dieses Dossier ist noch kein Wiederherstellungspaket vorhanden."
        case .falscherCode:
            "Der Wiederherstellungscode ist nicht korrekt."
        case .ungueltigesPaket:
            "Das Wiederherstellungspaket konnte nicht verarbeitet werden."
        }
    }
}

nonisolated enum DossierRecoveryCode {
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
}

@MainActor
enum DossierRecoveryPDF {
    static func erstellen(code: String) throws -> URL {
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
            let hinweis = "Mit diesen 12 Wörtern können die verschlüsselten Zugangsdaten wiederhergestellt werden. Wer diese Wörter kennt, kann auf diese Daten zugreifen. Bewahre das Dokument offline und sicher auf. Teile es niemals per ungeschützter E-Mail oder Chat."
            hinweis.draw(in: CGRect(x: 48, y: 108, width: 499, height: 100), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ])
            let woerter = code.split(separator: " ").map(String.init)
            for (index, wort) in woerter.enumerated() {
                let spalte = index % 2
                let zeile = index / 2
                let text = "\(index + 1).  \(wort)"
                text.draw(at: CGPoint(x: 66 + CGFloat(spalte) * 250, y: 230 + CGFloat(zeile) * 58), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: UIColor.black
                ])
            }
            "Erstellt am \(Date().formatted(date: .long, time: .shortened))"
                .draw(at: CGPoint(x: 48, y: 775), withAttributes: [
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
}
