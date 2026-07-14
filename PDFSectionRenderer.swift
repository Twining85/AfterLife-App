import UIKit

final class PDFSectionRenderer {
    private let theme: PDFTheme

    init(theme: PDFTheme = .tschluessli) {
        self.theme = theme
    }

    func drawChapter(_ chapter: DossierPDFChapter, in layout: PDFLayoutEngine) {
        layout.drawDivider(spacing: 22)

        let headerY = layout.yPosition
        let imageSize: CGFloat = 78
        let textWidth = chapter.profilbildDaten == nil ? layout.contentWidth : layout.contentWidth - imageSize - 24

        layout.drawText(chapter.titel, font: theme.typography.chapterTitle, color: .black, width: textWidth, spacing: 6)

        if !chapter.beschreibung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            layout.drawText(chapter.beschreibung, font: theme.typography.body, color: .black, width: textWidth, spacing: theme.spacing.sectionSpacing)
        }

        if chapter.typ == .profil,
           let profilbildDaten = chapter.profilbildDaten,
           let image = UIImage(data: profilbildDaten) {
            drawRoundImage(
                image,
                rect: CGRect(
                    x: layout.pageRect.width - theme.spacing.pageMargin - imageSize,
                    y: headerY,
                    width: imageSize,
                    height: imageSize
                ),
                in: layout
            )

            let minimumY = headerY + imageSize + theme.spacing.sectionSpacing
            if layout.yPosition < minimumY {
                layout.advance(minimumY - layout.yPosition)
            }
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
        let contentRect = rect.insetBy(dx: theme.spacing.cardPadding, dy: 0)
        drawText(section.titel, in: contentRect, y: &y, font: theme.typography.sectionTitle, color: .black)

        if let untertitel = section.untertitel,
           !untertitel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drawText(untertitel, in: contentRect, y: &y, font: theme.typography.secondary, color: .black)
        }

        y += 6
        for item in section.items {
            drawItem(item, in: contentRect, y: &y, style: section.darstellung)
        }

        layout.advance(cardHeight + theme.spacing.cardSpacing)
    }

    private func drawRoundImage(_ image: UIImage, rect: CGRect, in layout: PDFLayoutEngine) {
        let path = UIBezierPath(ovalIn: rect)
        layout.context.cgContext.saveGState()
        path.addClip()
        layout.context.cgContext.interpolationQuality = .high
        image.draw(in: rect)
        layout.context.cgContext.restoreGState()
    }

    private func drawItem(_ item: DossierPDFItem, in rect: CGRect, y: inout CGFloat, style: DossierPDFSectionStyle) {
        switch style {
        case .persoenlicherText:
            drawText(item.wert, in: rect, y: &y, font: theme.typography.body, color: .black)
        default:
            let labelWidth = rect.width * 0.34
            let valueRect = CGRect(x: rect.minX + labelWidth + 12, y: rect.minY, width: rect.width - labelWidth - 12, height: rect.height)
            let labelRect = CGRect(x: rect.minX, y: rect.minY, width: labelWidth, height: rect.height)
            let startY = y
            var labelY = y
            var valueY = y

            drawText(item.label, in: labelRect, y: &labelY, font: theme.typography.secondary, color: .black)
            drawText(item.wert, in: valueRect, y: &valueY, font: theme.typography.body, color: .black)
            y = max(labelY, valueY, startY + 20)
        }
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        y: inout CGFloat,
        font: UIFont,
        color: UIColor
    ) {
        let height = measuredTextHeight(text, font: font, width: rect.width)
        let textRect = CGRect(x: rect.minX, y: y, width: rect.width, height: height)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        NSAttributedString(string: text, attributes: attributes).draw(in: textRect)
        y = textRect.maxY + theme.spacing.lineSpacing
    }

    private func estimatedHeight(for section: DossierPDFSection, width: CGFloat) -> CGFloat {
        let contentWidth = width - theme.spacing.cardPadding * 2
        var height = theme.spacing.cardPadding * 2
        height += measuredTextHeight(section.titel, font: theme.typography.sectionTitle, width: contentWidth)
        height += theme.spacing.lineSpacing

        if let untertitel = section.untertitel,
           !untertitel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            height += measuredTextHeight(untertitel, font: theme.typography.secondary, width: contentWidth)
            height += theme.spacing.lineSpacing
        }

        height += 6

        for item in section.items {
            switch section.darstellung {
            case .persoenlicherText:
                height += measuredTextHeight(item.wert, font: theme.typography.body, width: contentWidth)
            default:
                let labelWidth = contentWidth * 0.34
                let valueWidth = contentWidth - labelWidth - 12
                let labelHeight = measuredTextHeight(item.label, font: theme.typography.secondary, width: labelWidth)
                let valueHeight = measuredTextHeight(item.wert, font: theme.typography.body, width: valueWidth)
                height += max(labelHeight, valueHeight, 20)
            }
            height += theme.spacing.lineSpacing
        }

        return max(82, ceil(height))
    }

    private func measuredTextHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measured = NSAttributedString(string: text, attributes: attributes).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(measured.height)
    }
}
