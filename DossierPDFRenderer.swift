import UIKit

final class DossierPDFRenderer {
    private let theme: PDFTheme
    private let sectionRenderer: PDFSectionRenderer
    private let attachmentRenderer: PDFAttachmentRenderer

    init(
        theme: PDFTheme = .tschluessli,
        sectionRenderer: PDFSectionRenderer? = nil,
        attachmentRenderer: PDFAttachmentRenderer? = nil
    ) {
        self.theme = theme
        self.sectionRenderer = sectionRenderer ?? PDFSectionRenderer(theme: theme)
        self.attachmentRenderer = attachmentRenderer ?? PDFAttachmentRenderer(theme: theme)
    }

    func render(_ document: DossierPDFDocument, to url: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Tschlüssli",
            kCGPDFContextAuthor as String: "Tschlüssli App",
            kCGPDFContextTitle as String: document.titel
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        try renderer.writePDF(to: url) { context in
            let layout = PDFLayoutEngine(context: context, pageRect: pageRect, theme: theme)

            drawTitlePage(document, in: layout)
            drawTableOfContents(document, in: layout)

            for chapter in document.kapitel {
                sectionRenderer.drawChapter(chapter, in: layout)
            }

            drawClosingPage(document, in: layout)
            attachmentRenderer.drawAttachments(document.anhaenge, in: layout)
        }
    }

    private func drawTitlePage(_ document: DossierPDFDocument, in layout: PDFLayoutEngine) {
        layout.beginPage()
        layout.advance(80)
        layout.drawText("Tschlüssli", font: theme.typography.bodyEmphasis, color: theme.accent, spacing: 26)
        layout.drawText(document.titel, font: theme.typography.title, color: theme.primaryText, spacing: 12)
        layout.drawText(document.untertitel, font: theme.typography.sectionTitle, color: theme.secondaryText, spacing: 36)
        layout.drawText("Erstellt am \(document.erstelltAm.formatted(date: .long, time: .omitted))", font: theme.typography.body, color: theme.primaryText, spacing: 8)

        if let aktualisiertAm = document.aktualisiertAm {
            layout.drawText("Zuletzt aktualisiert am \(aktualisiertAm.formatted(date: .long, time: .omitted))", font: theme.typography.body, color: theme.primaryText, spacing: 24)
        }

        layout.drawText(document.vertraulichkeitshinweis, font: theme.typography.body, color: theme.secondaryText)
    }

    private func drawTableOfContents(_ document: DossierPDFDocument, in layout: PDFLayoutEngine) {
        layout.beginPage()
        layout.drawText("Inhaltsverzeichnis", font: theme.typography.chapterTitle, color: theme.primaryText, spacing: 24)

        for chapter in document.kapitel {
            layout.drawText(chapter.titel, font: theme.typography.bodyEmphasis, color: UIColor(chapter.farbe), spacing: 8)
        }

        if !document.anhaenge.isEmpty {
            layout.drawText("Dokumentenverzeichnis und Anhänge", font: theme.typography.bodyEmphasis, color: theme.accent, spacing: 8)
        }
    }

    private func drawClosingPage(_ document: DossierPDFDocument, in layout: PDFLayoutEngine) {
        layout.beginPage()
        layout.drawText("Hinweis zur Aktualität", font: theme.typography.chapterTitle, color: theme.primaryText, spacing: 18)
        layout.drawText(
            "Dieses Dossier bildet den Stand der in Tschlüssli erfassten Informationen zum Exportzeitpunkt ab. Bitte prüfe regelmässig, ob die Angaben noch aktuell sind.",
            font: theme.typography.body,
            color: theme.secondaryText,
            spacing: 18
        )
        layout.drawText("Exportdatum: \(Date().formatted(date: .long, time: .shortened))", font: theme.typography.body, color: theme.primaryText, spacing: 8)
        layout.drawText("Version: MVP 1", font: theme.typography.body, color: theme.primaryText, spacing: 18)
        layout.drawText("Dieses Dokument enthält persönliche und potenziell sensible Daten. Teile es nur mit Personen, denen du vertraust.", font: theme.typography.body, color: theme.secondaryText)
    }
}
