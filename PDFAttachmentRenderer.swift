import UIKit
import PDFKit

final class PDFAttachmentRenderer {
    private let theme: PDFTheme

    init(theme: PDFTheme = .tschluessli) {
        self.theme = theme
    }

    func drawAttachments(_ attachments: [DossierPDFAttachment], in layout: PDFLayoutEngine) {
        guard !attachments.isEmpty else { return }

        drawRegister(for: attachments, in: layout)

        var fotoalbumTitelGedruckt = false

        for attachment in attachments {
            if attachment.kategorie == "Fotoalbum" {
                drawFotoalbumAttachment(
                    attachment,
                    in: layout,
                    titelDrucken: !fotoalbumTitelGedruckt
                )
                fotoalbumTitelGedruckt = true
            } else {
                drawAttachment(attachment, in: layout)
            }
        }
    }

    private func drawRegister(for attachments: [DossierPDFAttachment], in layout: PDFLayoutEngine) {
        layout.beginPage()
        layout.drawText("Dokumentenverzeichnis", font: theme.typography.chapterTitle, color: theme.primaryText, spacing: 18)

        for attachment in attachments {
            layout.drawText(
                "\(attachment.kategorie) - \(attachment.titel)",
                font: theme.typography.bodyEmphasis,
                color: theme.primaryText,
                spacing: 3
            )
            layout.drawText(
                attachment.dateiname,
                font: theme.typography.secondary,
                color: theme.secondaryText,
                spacing: 10
            )
        }
    }

    private func drawAttachment(_ attachment: DossierPDFAttachment, in layout: PDFLayoutEngine) {
        if let image = UIImage(data: attachment.daten) {
            drawImage(image, attachment: attachment, in: layout)
            return
        }

        if let pdf = PDFDocument(data: attachment.daten), pdf.pageCount > 0 {
            drawPDF(pdf, attachment: attachment, in: layout)
            return
        }

        layout.beginPage()
        drawAttachmentHeader(attachment, in: layout)
        layout.drawText(
            "Dieses Dokument kann nicht direkt im PDF dargestellt werden.",
            font: theme.typography.body,
            color: theme.secondaryText
        )
    }

    private func drawAttachmentHeader(_ attachment: DossierPDFAttachment, in layout: PDFLayoutEngine, pageInfo: String? = nil) {
        let title = pageInfo == nil ? attachment.titel : "\(attachment.titel) - \(pageInfo ?? "")"
        layout.drawText(title, font: theme.typography.chapterTitle, color: theme.primaryText, spacing: 6)
        layout.drawText(attachment.kategorie, font: theme.typography.bodyEmphasis, color: theme.secondaryText, spacing: 4)
        layout.drawText(attachment.dateiname, font: theme.typography.secondary, color: theme.secondaryText, spacing: 18)
    }

    private func drawFotoalbumAttachment(_ attachment: DossierPDFAttachment, in layout: PDFLayoutEngine, titelDrucken: Bool) {
        guard let image = UIImage(data: attachment.daten) else {
            drawAttachment(attachment, in: layout)
            return
        }

        layout.beginPage()
        if titelDrucken {
            layout.drawText("Fotoalbum", font: theme.typography.chapterTitle, color: .black, spacing: 18)
        }

        drawImageContent(image, in: layout)
    }

    private func drawImage(_ image: UIImage, attachment: DossierPDFAttachment, in layout: PDFLayoutEngine) {
        layout.beginPage()
        drawAttachmentHeader(attachment, in: layout)
        drawImageContent(image, in: layout)
    }

    private func drawImageContent(_ image: UIImage, in layout: PDFLayoutEngine) {
        let maxWidth = layout.contentWidth
        let maxHeight = layout.pageRect.height - layout.yPosition - theme.spacing.pageMargin
        let imageAspect = image.size.width / max(image.size.height, 1)
        let availableAspect = maxWidth / max(maxHeight, 1)
        let size: CGSize

        if imageAspect > availableAspect {
            size = CGSize(width: maxWidth, height: maxWidth / imageAspect)
        } else {
            size = CGSize(width: maxHeight * imageAspect, height: maxHeight)
        }

        let rect = CGRect(
            x: (layout.pageRect.width - size.width) / 2,
            y: layout.yPosition,
            width: size.width,
            height: size.height
        )

        layout.context.cgContext.saveGState()
        layout.context.cgContext.interpolationQuality = .high
        image.draw(in: rect)
        layout.context.cgContext.restoreGState()
    }

    private func drawPDF(_ pdf: PDFDocument, attachment: DossierPDFAttachment, in layout: PDFLayoutEngine) {
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }
            layout.beginPage()
            drawAttachmentHeader(
                attachment,
                in: layout,
                pageInfo: pdf.pageCount > 1 ? "Seite \(pageIndex + 1) von \(pdf.pageCount)" : nil
            )

            let bounds = page.bounds(for: .mediaBox)
            let maxWidth = layout.contentWidth
            let maxHeight = layout.pageRect.height - layout.yPosition - theme.spacing.pageMargin
            let scale = min(maxWidth / max(bounds.width, 1), maxHeight / max(bounds.height, 1))
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let rect = CGRect(
                x: (layout.pageRect.width - size.width) / 2,
                y: layout.yPosition,
                width: size.width,
                height: size.height
            )

            layout.context.cgContext.saveGState()
            layout.context.cgContext.interpolationQuality = .high
            layout.context.cgContext.translateBy(x: rect.minX, y: rect.maxY)
            layout.context.cgContext.scaleBy(x: scale, y: -scale)
            layout.context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: layout.context.cgContext)
            layout.context.cgContext.restoreGState()
        }
    }
}
