import UIKit

struct PDFTheme {
    struct Typography {
        var title = UIFont.systemFont(ofSize: 32, weight: .bold)
        var chapterTitle = UIFont.systemFont(ofSize: 24, weight: .bold)
        var sectionTitle = UIFont.systemFont(ofSize: 17, weight: .semibold)
        var body = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        var bodyEmphasis = UIFont.systemFont(ofSize: 13, weight: .semibold)
        var secondary = UIFont.systemFont(ofSize: 10.5, weight: .regular)
        var footer = UIFont.systemFont(ofSize: 9, weight: .regular)
    }

    struct Spacing {
        var pageMargin: CGFloat = 48
        var sectionSpacing: CGFloat = 22
        var cardPadding: CGFloat = 16
        var cardSpacing: CGFloat = 12
        var lineSpacing: CGFloat = 5
    }

    var typography = Typography()
    var spacing = Spacing()

    var pageBackground = UIColor.white
    var primaryText = UIColor.label
    var secondaryText = UIColor.secondaryLabel
    var divider = UIColor.systemGray4
    var cardBackground = UIColor(red: 0.985, green: 0.98, blue: 0.965, alpha: 1)
    var subtleBackground = UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1)
    var accent = UIColor(red: 0.16, green: 0.36, blue: 0.42, alpha: 1)

    static let tschluessli = PDFTheme()
}

extension UIColor {
    convenience init(_ color: PDFThemeColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
