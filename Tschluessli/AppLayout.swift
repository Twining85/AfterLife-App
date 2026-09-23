import SwiftUI
import UIKit

enum AppErscheinungsbild: String, CaseIterable, Identifiable {
    case system
    case hell
    case dunkel

    var id: Self { self }

    var titel: String {
        switch self {
        case .system: "System"
        case .hell: "Hell"
        case .dunkel: "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .hell: .light
        case .dunkel: .dark
        }
    }
}

extension Color {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let appCanvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.045, green: 0.055, blue: 0.060, alpha: 1)
            : UIColor(red: 0.985, green: 0.98, blue: 0.965, alpha: 1)
    })

    static let appCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.085, green: 0.100, blue: 0.105, alpha: 1)
            : UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1)
    })

    static let appRaisedCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.115, green: 0.130, blue: 0.135, alpha: 1)
            : UIColor.white.withAlphaComponent(0.88)
    })

    static let appField = adaptive(
        light: UIColor.white.withAlphaComponent(0.82),
        dark: UIColor(red: 0.145, green: 0.160, blue: 0.165, alpha: 1)
    )
    static let appPrimaryText = adaptive(
        light: UIColor(red: 0.12, green: 0.12, blue: 0.11, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1)
    )
    static let appSecondaryText = adaptive(
        light: UIColor(red: 0.37, green: 0.37, blue: 0.35, alpha: 1),
        dark: UIColor(red: 0.69, green: 0.70, blue: 0.68, alpha: 1)
    )
    static let appBorder = adaptive(
        light: UIColor.white.withAlphaComponent(0.76),
        dark: UIColor.white.withAlphaComponent(0.13)
    )
    static let appShadow = adaptive(
        light: UIColor.black.withAlphaComponent(0.09),
        dark: UIColor.black.withAlphaComponent(0.38)
    )
    static let appAccent = adaptive(
        light: UIColor(red: 0.16, green: 0.36, blue: 0.42, alpha: 1),
        dark: UIColor(red: 0.39, green: 0.70, blue: 0.73, alpha: 1)
    )
    static let appOnAccent = adaptive(light: .white, dark: UIColor(red: 0.035, green: 0.06, blue: 0.065, alpha: 1))

    static let areaHealth = adaptive(
        light: UIColor(red: 0.76, green: 0.24, blue: 0.30, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.45, blue: 0.51, alpha: 1)
    )
    static let areaWishes = adaptive(
        light: UIColor(red: 0.72, green: 0.42, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.61, blue: 0.43, alpha: 1)
    )
    static let areaFinance = adaptive(
        light: UIColor(red: 0.62, green: 0.47, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.84, green: 0.68, blue: 0.32, alpha: 1)
    )
    static let areaContacts = adaptive(
        light: UIColor(red: 0.24, green: 0.50, blue: 0.34, alpha: 1),
        dark: UIColor(red: 0.42, green: 0.75, blue: 0.52, alpha: 1)
    )
    static let areaDocuments = adaptive(
        light: UIColor(red: 0.22, green: 0.43, blue: 0.68, alpha: 1),
        dark: UIColor(red: 0.43, green: 0.66, blue: 0.92, alpha: 1)
    )
    static let areaSubscriptions = adaptive(
        light: UIColor(red: 0.46, green: 0.36, blue: 0.62, alpha: 1),
        dark: UIColor(red: 0.67, green: 0.56, blue: 0.87, alpha: 1)
    )
    static let areaKeepsakes = adaptive(
        light: UIColor(red: 0.78, green: 0.34, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.52, blue: 0.31, alpha: 1)
    )
}

/// Einheitliche, transparente Darstellung des Markenlogos. Im Dark Mode
/// werden nur die vorhandenen Markenfarben behutsam angehoben; das Logo
/// erhält weder eine Fremdfarbe noch eine zusätzliche Hintergrundfläche.
struct TschluessliLogo: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("Icon1_trans")
            .resizable()
            .scaledToFit()
            .brightness(colorScheme == .dark ? 0.22 : 0)
            .saturation(colorScheme == .dark ? 0.92 : 1)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.34) : .clear,
                radius: 3,
                y: 2
            )
    }
}

/// Appweite Layoutwerte, die sich am verfügbaren Container orientieren.
/// Es werden bewusst keine Gerätemodelle abgefragt. Damit funktionieren auch
/// Display-Zoom, Split View und zukünftige Formfaktoren ohne Sonderfälle.
struct AppLayout: Equatable {
    enum WidthClass {
        case compact
        case regular
        case expanded
    }

    let containerWidth: CGFloat
    let dynamicTypeSize: DynamicTypeSize

    var widthClass: WidthClass {
        switch containerWidth {
        case ..<400: .compact
        case ..<700: .regular
        default: .expanded
        }
    }

    var isCompact: Bool { widthClass == .compact }
    var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }
    var prefersCompactNavigationIcons: Bool { dynamicTypeSize >= .xLarge }
    /// Kreisförmige Navigationen haben eine feste Fläche. Ab xxLarge ist eine
    /// inhaltsgetriebene, lineare Darstellung robuster als kleinere Schrift.
    var prefersLinearNavigation: Bool { dynamicTypeSize >= .xxLarge }

    /// Bereichskarten benötigen pro Spalte mindestens 155 pt nutzbare Breite.
    /// Dadurch bleiben zwei Spalten auch auf kompakten iPhones erhalten und
    /// wechseln erst bei Platzmangel oder wirklich grosser Schrift auf eine
    /// gut lesbare einspaltige Darstellung.
    var prefersSingleColumnAreaGrid: Bool {
        let gridSpacing: CGFloat = 14
        let minimumColumnWidth: CGFloat = 155
        let availableWidth = containerWidth - (2 * pageInset)
        return availableWidth < (2 * minimumColumnWidth + gridSpacing)
            || dynamicTypeSize >= .xxLarge
    }

    var pageInset: CGFloat {
        switch widthClass {
        case .compact: 18
        case .regular: 24
        case .expanded: 32
        }
    }

    var sectionSpacing: CGFloat { isCompact ? 18 : 24 }
    var cardPadding: CGFloat { isCompact ? 14 : 16 }
    var authCardPadding: CGFloat { isCompact ? 20 : 24 }
    var cardCornerRadius: CGFloat { isCompact ? 20 : 22 }
    var profileImageSize: CGFloat { isCompact ? 70 : 86 }

    static let fallback = AppLayout(containerWidth: 393, dynamicTypeSize: .large)
}

private struct AppLayoutKey: EnvironmentKey {
    static let defaultValue = AppLayout.fallback
}

extension EnvironmentValues {
    var appLayout: AppLayout {
        get { self[AppLayoutKey.self] }
        set { self[AppLayoutKey.self] = newValue }
    }
}

private struct ResponsiveAppRootModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var containerWidth: CGFloat = AppLayout.fallback.containerWidth

    func body(content: Content) -> some View {
        content
            .environment(
                \.appLayout,
                AppLayout(containerWidth: containerWidth, dynamicTypeSize: dynamicTypeSize)
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                guard newWidth > 0 else { return }
                containerWidth = newWidth
            }
    }
}

extension View {
    /// Einmal am App-Root angewendet, stellt dies allen Screens dieselben
    /// responsiven Breakpoints zur Verfügung.
    func responsiveAppLayout() -> some View {
        modifier(ResponsiveAppRootModifier())
    }

    func appPagePadding() -> some View {
        modifier(AppPagePaddingModifier())
    }
}

private struct AppPagePaddingModifier: ViewModifier {
    @Environment(\.appLayout) private var layout

    func body(content: Content) -> some View {
        content.padding(.horizontal, layout.pageInset)
    }
}
