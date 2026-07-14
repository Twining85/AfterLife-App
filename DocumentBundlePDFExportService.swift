import Foundation

final class DocumentBundlePDFExportService {
    private let renderer: DocumentBundlePDFRenderer

    init(renderer: DocumentBundlePDFRenderer = DocumentBundlePDFRenderer()) {
        self.renderer = renderer
    }

    func export(document: DocumentBundlePDFDocument, fileName: String? = nil) throws -> URL {
        let resolvedFileName = fileName ?? "Tschlüssli_Dokumentenpaket_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(resolvedFileName)
        try renderer.render(document, to: url)
        return url
    }
}
