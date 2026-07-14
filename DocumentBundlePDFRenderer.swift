import UIKit

final class DocumentBundlePDFRenderer {
    private let theme: PDFTheme
    private let attachmentRenderer: PDFAttachmentRenderer

    init(theme: PDFTheme = .tschluessli) {
        self.theme = theme
        self.attachmentRenderer = PDFAttachmentRenderer(theme: theme)
    }

    func render(_ document: DocumentBundlePDFDocument, to url: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: makeFormat(for: document))

        try renderer.writePDF(to: url) { context in
            let layout = PDFLayoutEngine(context: context, pageRect: pageRect, theme: theme)
            drawTitlePage(document, in: layout)
            attachmentRenderer.drawAttachments(document.attachments, in: layout)
        }
    }

    private func makeFormat(for document: DocumentBundlePDFDocument) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: document.titel,
            kCGPDFContextCreator as String: "Tschlüssli"
        ]
        return format
    }

    private func drawTitlePage(_ document: DocumentBundlePDFDocument, in layout: PDFLayoutEngine) {
        layout.beginPage()
        layout.advance(64)

        layout.drawText("Tschlüssli", font: theme.typography.bodyEmphasis, color: theme.accent, spacing: 18)
        layout.drawText(document.titel, font: theme.typography.title, color: theme.primaryText, spacing: 14)
        layout.drawText(document.untertitel, font: theme.typography.sectionTitle, color: theme.secondaryText, spacing: 34)

        drawInfoCard(document, in: layout)

        layout.advance(42)
        layout.drawText(
            document.vertraulichkeitshinweis,
            font: theme.typography.body,
            color: theme.secondaryText,
            spacing: 0
        )
    }

    private func drawInfoCard(_ document: DocumentBundlePDFDocument, in layout: PDFLayoutEngine) {
        let cardHeight: CGFloat = 106
        layout.ensureSpace(cardHeight + 24)

        let rect = CGRect(
            x: layout.theme.spacing.pageMargin,
            y: layout.yPosition,
            width: layout.contentWidth,
            height: cardHeight
        )
        layout.drawRoundedCard(rect: rect, fill: theme.subtleBackground)

        let x = rect.minX + theme.spacing.cardPadding
        var y = rect.minY + theme.spacing.cardPadding
        let width = rect.width - theme.spacing.cardPadding * 2

        drawInfoLine(label: "Erstellt am", value: formatiereDatum(document.erstelltAm), x: x, y: &y, width: width)
        drawInfoLine(label: "Enthaltene Dokumente", value: "\(document.attachments.count)", x: x, y: &y, width: width)
        drawInfoLine(label: "Typ", value: "Dokumentenpaket", x: x, y: &y, width: width)

        layout.advance(cardHeight + 24)
    }

    private func drawInfoLine(label: String, value: String, x: CGFloat, y: inout CGFloat, width: CGFloat) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.typography.secondary,
            .foregroundColor: UIColor.black
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.typography.bodyEmphasis,
            .foregroundColor: UIColor.black
        ]

        label.draw(in: CGRect(x: x, y: y, width: 150, height: 16), withAttributes: labelAttributes)
        value.draw(in: CGRect(x: x + 160, y: y, width: width - 160, height: 18), withAttributes: valueAttributes)
        y += 24
    }

    private func formatiereDatum(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
