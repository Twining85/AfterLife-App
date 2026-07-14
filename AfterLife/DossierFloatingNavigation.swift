import SwiftUI
import UIKit

enum DossierBereich: String, CaseIterable, Identifiable, Hashable {
    case profil
    case gesundheit
    case wuensche
    case finanzen
    case hinterbliebene
    case dokumente
    case abos

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .profil: return "Profil"
        case .gesundheit: return "Gesundheit"
        case .wuensche: return "Wünsche"
        case .finanzen: return "Finanzen"
        case .hinterbliebene: return "Vertrauen"
        case .dokumente: return "Dokumente"
        case .abos: return "Abos"
        }
    }

    var systemImage: String {
        switch self {
        case .profil: return "person.text.rectangle.fill"
        case .gesundheit: return "heart.text.square.fill"
        case .wuensche: return "sparkles"
        case .finanzen: return "dollarsign.circle.fill"
        case .hinterbliebene: return "person.3.fill"
        case .dokumente: return "folder.fill"
        case .abos: return "rectangle.stack.badge.person.crop.fill"
        }
    }

    var akzentFarbe: Color {
        switch self {
        case .profil: return Color(red: 0.16, green: 0.36, blue: 0.42)
        case .gesundheit: return Color(red: 0.76, green: 0.24, blue: 0.30)
        case .wuensche: return Color(red: 0.72, green: 0.42, blue: 0.28)
        case .finanzen: return Color(red: 0.62, green: 0.47, blue: 0.18)
        case .hinterbliebene: return Color(red: 0.24, green: 0.50, blue: 0.34)
        case .dokumente: return Color(red: 0.22, green: 0.43, blue: 0.68)
        case .abos: return Color(red: 0.46, green: 0.36, blue: 0.62)
        }
    }

    @ViewBuilder
    var zielView: some View {
        switch self {
        case .profil:
            ProfilView()
        case .gesundheit:
            GesundheitView()
        case .wuensche:
            WuenscheView()
        case .finanzen:
            FinanzenView()
        case .hinterbliebene:
            HinterbliebeneView()
        case .dokumente:
            DokumenteView()
        case .abos:
            AbosView()
        }
    }
}

struct DossierNavigationManager {
    static let homeReihenfolgeKey = "homeBereicheReihenfolge"

    static func bereiche(homeReihenfolge: String) -> [DossierBereich] {
        let gespeicherteBereiche = homeReihenfolge
            .split(separator: ",")
            .compactMap { DossierBereich(rawValue: String($0)) }
        let fehlendeBereiche = DossierBereich.allCases.filter { !gespeicherteBereiche.contains($0) }

        if gespeicherteBereiche.isEmpty {
            return DossierBereich.allCases
        }

        return gespeicherteBereiche + fehlendeBereiche
    }
}

struct DossierFloatingNavigation: View {
    let aktiverBereich: DossierBereich
    @AppStorage(DossierNavigationManager.homeReihenfolgeKey) private var homeBereicheReihenfolge = ""

    private var bereiche: [DossierBereich] {
        DossierNavigationManager.bereiche(homeReihenfolge: homeBereicheReihenfolge)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(bereiche) { bereich in
                    if bereich == aktiverBereich {
                        chip(fuer: bereich, istAktiv: true)
                    } else {
                        NavigationLink {
                            bereich.zielView
                        } label: {
                            chip(fuer: bereich, istAktiv: false)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 9)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func chip(fuer bereich: DossierBereich, istAktiv: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: bereich.systemImage)
                .font(.system(size: istAktiv ? 17 : 15, weight: .semibold))
            Text(bereich.titel)
                .font(.system(size: 10, weight: istAktiv ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(istAktiv ? .white : bereich.akzentFarbe)
        .frame(width: istAktiv ? 72 : 62, height: 56)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(istAktiv ? bereich.akzentFarbe : Color.clear)
                .shadow(color: istAktiv ? bereich.akzentFarbe.opacity(0.24) : .clear, radius: 8, x: 0, y: 4)
        }
        .scaleEffect(istAktiv ? 1.04 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: istAktiv)
        .accessibilityLabel(bereich.titel)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 30))
        } else {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                )
        }
    }
}

private struct DossierFloatingNavigationModifier: ViewModifier {
    let aktiverBereich: DossierBereich

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                DossierFloatingNavigation(aktiverBereich: aktiverBereich)
            }
    }
}

extension View {
    func dossierFloatingNavigation(_ aktiverBereich: DossierBereich) -> some View {
        modifier(DossierFloatingNavigationModifier(aktiverBereich: aktiverBereich))
    }
}
