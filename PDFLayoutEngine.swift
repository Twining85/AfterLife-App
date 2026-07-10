import UIKit

final class PDFLayoutEngine {
    let context: UIGraphicsPDFRendererContext
    let pageRect: CGRect
    let theme: PDFTheme

    private(set) var yPosition: CGFloat
    private(set) var pageNumber = 0

    var contentWidth: CGFloat {
        pageRect.width - theme.spacing.pageMargin * 2
    }

    init(context: UIGraphicsPDFRendererContext, pageRect: CGRect, theme: PDFTheme) {
        self.context = context
        self.pageRect = pageRect
        self.theme = theme
        self.yPosition = theme.spacing.pageMargin
    }

    func beginPage() {
        context.beginPage()
        pageNumber += 1
        yPosition = theme.spacing.pageMargin
    }

    func ensureSpace(_ requiredHeight: CGFloat) {
        if yPosition + requiredHeight > pageRect.height - theme.spacing.pageMargin {
            beginPage()
        }
    }

    func advance(_ distance: CGFloat) {
        yPosition += distance
    }

    @discardableResult
    func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor? = nil,
        width: CGFloat? = nil,
        spacing: CGFloat = 0
    ) -> CGRect {
        let availableWidth = width ?? contentWidth
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color ?? theme.primaryText
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let measured = attributed.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let height = ceil(measured.height)
        ensureSpace(height + spacing)

        let rect = CGRect(
            x: theme.spacing.pageMargin,
            y: yPosition,
            width: availableWidth,
            height: height
        )
        attributed.draw(in: rect)
        yPosition = rect.maxY + spacing
        return rect
    }

    func drawDivider(spacing: CGFloat = 18) {
        ensureSpace(spacing + 1)
        let y = yPosition
        context.cgContext.setStrokeColor(theme.divider.cgColor)
        context.cgContext.setLineWidth(0.8)
        context.cgContext.move(to: CGPoint(x: theme.spacing.pageMargin, y: y))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width - theme.spacing.pageMargin, y: y))
        context.cgContext.strokePath()
        yPosition += spacing
    }

    func drawRoundedCard(rect: CGRect, fill: UIColor? = nil) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
        (fill ?? theme.cardBackground).setFill()
        path.fill()
    }
}
