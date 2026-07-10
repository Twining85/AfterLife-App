import UIKit

final class PDFSectionRenderer {
    private let theme: PDFTheme

    init(theme: PDFTheme = .tschluessli) {
        self.theme = theme
    }

    func drawChapter(_ chapter: DossierPDFChapter, in layout: PDFLayoutEngine) {
        layout.drawDivider(spacing: 22)
        layout.drawText(chapter.titel, font: theme.typography.chapterTitle, color: UIColor(chapter.farbe), spacing: 6)

        if !chapter.beschreibung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            layout.drawText(chapter.beschreibung, font: theme.typography.body, color: theme.secondaryText, spacing: theme.spacing.sectionSpacing)
        }

        for section in chapter.sections {
            drawSection(section, in: layout)
        }
    }

    func drawSection(_ section: DossierPDFSection, in layout: PDFLayoutEngine) {
        let cardHeight = estimatedHeight(for: section, width: layout.contentWidth)
        layout.ensureSpace(cardHeight + theme.spacing.cardSpacing)

        let rect = CGRect(
            x: theme.spacing.pageMargin,
            y: layout.yPosition,
            width: layout.contentWidth,
            height: cardHeight
        )
        layout.drawRoundedCard(rect: rect)

        var y = rect.minY + theme.spacing.cardPadding
        drawText(section.titel, in: rect.insetBy(dx: theme.spacing.cardPadding, dy: 0), y: &y, font: theme.typography.sectionTitle, color: theme.primaryText)

        if let untertitel = section.untertitel,
           !untertitel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drawText(untertitel, in: rect.insetBy(dx: theme.spacing.cardPadding, dy: 0), y: &y, font: theme.typography.secondary, color: theme.secondaryText)
        }

        y += 6
        for item in section.items {
            drawItem(item, in: rect.insetBy(dx: theme.spacing.cardPadding, dy: 0), y: &y, style: section.darstellung)
        }

        layout.advance(cardHeight + theme.spacing.cardSpacing)
    }

    private func drawItem(_ item: DossierPDFItem, in rect: CGRect, y: inout CGFloat, style: DossierPDFSectionStyle) {
        switch style {
        case .persoenlicherText:
            drawText(item.wert, in: rect, y: &y, font: theme.typography.body, color: theme.primaryText)
        default:
            let labelWidth = rect.width * 0.34
            drawText(item.label, in: CGRect(x: rect.minX, y: rect.minY, width: labelWidth, height: rect.height), y: &y, font: theme.typography.secondary, color: theme.secondaryText, advances: false)
            drawText(item.wert, in: CGRect(x: rect.minX + labelWidth + 12, y: rect.minY, width: rect.width - labelWidth - 12, height: rect.height), y: &y, font: theme.typography.body, color: theme.primaryText)
        }
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        y: inout CGFloat,
        font: UIFont,
        color: UIColor,
        advances: Bool = true
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let measured = attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let textRect = CGRect(x: rect.minX, y: y, width: rect.width, height: ceil(measured.height))
        attributed.draw(in: textRect)
        if advances {
            y = textRect.maxY + theme.spacing.lineSpacing
        }
    }

    private func estimatedHeight(for section: DossierPDFSection, width: CGFloat) -> CGFloat {
        let base: CGFloat = theme.spacing.cardPadding * 2 + 28
        let subtitle: CGFloat = section.untertitel == nil ? 0 : 18
        let itemHeight: CGFloat = section.items.reduce(0) { total, item in
            total + max(20, CGFloat(max(item.wert.count, item.label.count)) / 42 * 14 + 16)
        }
        return max(82, base + subtitle + itemHeight)
    }
}
