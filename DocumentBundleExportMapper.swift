import Foundation

final class DocumentBundleExportMapper {
    private let kopieHinweis = "Hinweis: Dieses Dokument ist eine Kopie. Das Original sollte jederzeit auffindbar in einem physischen Ordner hinterlegt sein."

    func makeDocument(from dokumente: [ReadOnlyDocument]) -> DocumentBundlePDFDocument {
        DocumentBundlePDFDocument(
            titel: "Tschlüssli Dokumentenpaket",
            untertitel: "Dokumente aus deinem Vorsorgedossier",
            erstelltAm: Date(),
            vertraulichkeitshinweis: "Dieses Dokumentenpaket enthält persönliche Unterlagen. Bitte bewahre es vertraulich auf und prüfe regelmässig, ob die enthaltenen Kopien noch aktuell sind.",
            attachments: dokumente.compactMap(makeAttachment)
        )
    }

    private func makeAttachment(from dokument: ReadOnlyDocument) -> DossierPDFAttachment? {
        guard let daten = dokument.fileData ?? dokument.existingFileURL.flatMap({ try? Data(contentsOf: $0) }) else {
            return nil
        }

        let titel = normalisierterTitel(for: dokument)

        return DossierPDFAttachment(
            titel: titel,
            kategorie: kategorie(for: titel),
            dateiname: dokument.fileName,
            erstelltAm: dokument.uploadDate,
            hinweis: brauchtKopieHinweis(titel) ? kopieHinweis : nil,
            daten: daten
        )
    }

    private func normalisierterTitel(for dokument: ReadOnlyDocument) -> String {
        if dokument.title == "Nachruf-Foto" {
            return "Foto für den Nachruf"
        }

        return dokument.title
    }

    private func kategorie(for titel: String) -> String {
        switch titel {
        case "Foto für den Nachruf", "Testament", "Patientenverfügung", "Vorsorgeauftrag", "Sterbebegleitung":
            return "Meine Wünsche"
        case "Steuerdokument":
            return "Finanzen"
        default:
            return "Weitere Dokumente"
        }
    }

    private func brauchtKopieHinweis(_ titel: String) -> Bool {
        [
            "Testament",
            "Patientenverfügung",
            "Vorsorgeauftrag",
            "Sterbebegleitung"
        ].contains(titel)
    }
}
