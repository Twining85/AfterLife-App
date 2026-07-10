import Foundation

final class DossierPDFExportService {
    private let renderer: DossierPDFRenderer

    init(renderer: DossierPDFRenderer = DossierPDFRenderer()) {
        self.renderer = renderer
    }

    func export(document: DossierPDFDocument, fileName: String? = nil) throws -> URL {
        let resolvedFileName = fileName ?? "Tschlüssli_Dossier_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(resolvedFileName)
        try renderer.render(document, to: url)
        return url
    }
}
