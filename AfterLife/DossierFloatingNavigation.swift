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
    static let scrollOffsetKey = "dossierFloatingNavigationScrollOffset"

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

@MainActor
private enum DossierNavigationRuntimeState {
    static var sollNachBereichswechselAusklappen = false
}

@MainActor
private enum DossierNavigationRouter {
    static func navigateHome() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController,
              let navigationController = findNavigationController(in: rootViewController) else {
            return
        }

        navigationController.popToRootViewController(animated: true)
    }

    private static func findNavigationController(in viewController: UIViewController) -> UINavigationController? {
        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }

        if let navigationController = viewController.navigationController {
            return navigationController
        }

        if let presentedViewController = viewController.presentedViewController,
           let navigationController = findNavigationController(in: presentedViewController) {
            return navigationController
        }

        for child in viewController.children {
            if let navigationController = findNavigationController(in: child) {
                return navigationController
            }
        }

        return nil
    }
}

struct DossierFloatingNavigation: View {
    let aktiverBereich: DossierBereich
    var interaktionGestartet: () -> Void = { }
    var interaktionBeendet: () -> Void = { }
    @AppStorage(DossierNavigationManager.homeReihenfolgeKey) private var homeBereicheReihenfolge = ""
    @AppStorage(DossierNavigationManager.scrollOffsetKey) private var gespeicherterScrollOffset = 0.0
    @State private var beruehrterBereich: DossierBereich?
    @State private var interaktionsPosition: CGPoint?
    @State private var zielBereich: DossierBereich?
    @State private var aktuellerScrollOffset: CGFloat = 0
    @State private var containerBreite: CGFloat = 0
    @State private var autoScrollGeschwindigkeit: CGFloat = 0
    @State private var autoScrollTask: Task<Void, Never>?
    @State private var selectionFeedback = UISelectionFeedbackGenerator()
    @State private var impactFeedback = UIImpactFeedbackGenerator(style: .light)

    private let chipSpacing: CGFloat = 8
    private let inhaltHorizontalPadding: CGFloat = 10
    private let aktiverChipBreite: CGFloat = 72
    private let inaktiverChipBreite: CGFloat = 62

    private var bereiche: [DossierBereich] {
        DossierNavigationManager.bereiche(homeReihenfolge: homeBereicheReihenfolge)
    }

    private var scrollOffset: CGFloat {
        aktuellerScrollOffset
    }

    private var minimalerScrollOffset: CGFloat {
        min(0, containerBreite - inhaltBreite)
    }

    private var inhaltBreite: CGFloat {
        let chipBreiten = bereiche.reduce(CGFloat(0)) { ergebnis, bereich in
            ergebnis + chipBreite(fuer: bereich)
        }
        let spacing = CGFloat(max(0, bereiche.count - 1)) * chipSpacing
        return inhaltHorizontalPadding * 2 + chipBreiten + spacing
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: chipSpacing) {
                ForEach(bereiche) { bereich in
                    chip(fuer: bereich, istAktiv: bereich == aktiverBereich)
                }
            }
            .padding(.horizontal, inhaltHorizontalPadding)
            .padding(.vertical, 8)
            .offset(x: scrollOffset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                containerBreite = proxy.size.width
                aktuellerScrollOffset = begrenzterScrollOffset(CGFloat(gespeicherterScrollOffset))
                scrollOffsetBegrenzen()
            }
            .onChange(of: proxy.size.width) { _, neueBreite in
                containerBreite = neueBreite
                scrollOffsetBegrenzen()
            }
        }
        .coordinateSpace(name: "dossierFloatingNavigation")
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("dossierFloatingNavigation"))
                .onChanged { value in
                    interaktionGestartet()
                    aktualisiereInteraktion(an: value.location)
                }
                .onEnded { _ in
                    if let ziel = beruehrterBereich,
                       ziel != aktiverBereich,
                       frameFuerBereich(ziel)?.intersects(CGRect(x: 0, y: 0, width: containerBreite, height: 76)) == true {
                        navigiereZuBereich(ziel)
                    }
                    interaktionZuruecksetzen()
                    interaktionBeendet()
                }
        )
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.11), radius: 16, x: 0, y: 7)
        .padding(.horizontal, 20)
        .padding(.bottom, -4)
        .navigationDestination(item: $zielBereich) { bereich in
            bereich.zielView
        }
        .onAppear {
            aktuellerScrollOffset = begrenzterScrollOffset(CGFloat(gespeicherterScrollOffset))
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
    }

    private func chip(fuer bereich: DossierBereich, istAktiv: Bool) -> some View {
        let glasIntensitaet = glasIntensitaet(fuer: bereich)
        let skalierung = skalierung(fuer: bereich, istAktiv: istAktiv)
        let istHervorgehoben = beruehrterBereich == bereich

        return VStack(spacing: 4) {
            Image(systemName: bereich.systemImage)
                .font(.system(size: istAktiv ? 17 : 15, weight: .semibold))
            Text(bereich.titel)
                .font(.system(size: 10, weight: istAktiv ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(istAktiv ? .white : bereich.akzentFarbe)
        .frame(width: istAktiv ? 72 : 62, height: 56)
        .background(
            chipBackground(
                fuer: bereich,
                istAktiv: istAktiv,
                istHervorgehoben: istHervorgehoben,
                glasIntensitaet: glasIntensitaet
            )
        )
        .scaleEffect(skalierung)
        .offset(y: -6 * glasIntensitaet)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: istAktiv)
        .animation(.linear(duration: 0.035), value: interaktionsPosition)
        .animation(.linear(duration: 0.035), value: istHervorgehoben)
        .accessibilityLabel(bereich.titel)
    }

    @ViewBuilder
    private func chipBackground(
        fuer bereich: DossierBereich,
        istAktiv: Bool,
        istHervorgehoben: Bool,
        glasIntensitaet: CGFloat
    ) -> some View {
        if istAktiv {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(bereich.akzentFarbe)
                .shadow(color: bereich.akzentFarbe.opacity(0.24), radius: 8, x: 0, y: 4)
        } else if glasIntensitaet > 0.01 {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.34 * glasIntensitaet),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.30 + 0.34 * glasIntensitaet), lineWidth: istHervorgehoben ? 1.2 : 0.8)
                )
                .shadow(
                    color: bereich.akzentFarbe.opacity(0.10 + 0.16 * glasIntensitaet),
                    radius: 7 + 7 * glasIntensitaet,
                    x: 0,
                    y: 3 + 3 * glasIntensitaet
                )
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.clear)
        }
    }

    private func skalierung(fuer bereich: DossierBereich, istAktiv: Bool) -> CGFloat {
        guard interaktionsPosition != nil else {
            return istAktiv ? 1.04 : 1
        }

        return 1 + 0.24 * glasIntensitaet(fuer: bereich)
    }

    private func glasIntensitaet(fuer bereich: DossierBereich) -> CGFloat {
        guard let interaktionsPosition,
              let frame = frameFuerBereich(bereich) else {
            return 0
        }

        let distanz = abs(interaktionsPosition.x - frame.midX)
        let radius: CGFloat = 92
        let linear = max(0, 1 - distanz / radius)
        return pow(linear, 1.7)
    }

    private func aktualisiereInteraktion(an position: CGPoint) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            interaktionsPosition = position
            aktualisiereBeruehrtenBereich(an: position)
            aktualisiereAutoScroll(an: position)
        }
    }

    private func aktualisiereBeruehrtenBereich(an position: CGPoint) {
        let naechsterBereich = bereiche
            .compactMap { bereich -> (bereich: DossierBereich, frame: CGRect)? in
                guard let frame = frameFuerBereich(bereich) else { return nil }
                return (bereich, frame)
            }
            .min { lhs, rhs in
                abs(position.x - lhs.frame.midX) < abs(position.x - rhs.frame.midX)
            }?
            .bereich

        guard let naechsterBereich else {
            beruehrterBereich = nil
            return
        }

        if beruehrterBereich != naechsterBereich {
            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
        }

        beruehrterBereich = naechsterBereich
    }

    private func interaktionZuruecksetzen() {
        beruehrterBereich = nil
        interaktionsPosition = nil
        stoppeAutoScroll()
        speichereScrollOffset()
    }

    private func navigiereZuBereich(_ bereich: DossierBereich) {
        guard bereich != aktiverBereich else { return }
        speichereScrollOffset()
        DossierNavigationRuntimeState.sollNachBereichswechselAusklappen = true
        impactFeedback.impactOccurred()
        impactFeedback.prepare()
        zielBereich = bereich
    }

    private func aktualisiereAutoScroll(an position: CGPoint) {
        guard inhaltBreite > containerBreite else {
            stoppeAutoScroll()
            return
        }

        let randZone: CGFloat = 108
        let maximaleGeschwindigkeit: CGFloat = 10.5
        let geschwindigkeit: CGFloat

        if position.x < randZone {
            let intensitaet = min(1, max(0, (randZone - position.x) / randZone))
            geschwindigkeit = maximaleGeschwindigkeit * pow(intensitaet, 1.08)
        } else if position.x > containerBreite - randZone {
            let intensitaet = min(1, max(0, (position.x - (containerBreite - randZone)) / randZone))
            geschwindigkeit = -maximaleGeschwindigkeit * pow(intensitaet, 1.08)
        } else {
            stoppeAutoScroll()
            return
        }

        aktualisiereAutoScrollGeschwindigkeit(geschwindigkeit)
    }

    private func aktualisiereAutoScrollGeschwindigkeit(_ geschwindigkeit: CGFloat) {
        autoScrollGeschwindigkeit = geschwindigkeit

        guard autoScrollTask == nil else { return }

        autoScrollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)

                await MainActor.run {
                    guard interaktionsPosition != nil else {
                        stoppeAutoScroll()
                        return
                    }

                    setzeScrollOffset(scrollOffset + autoScrollGeschwindigkeit)

                    if let interaktionsPosition {
                        aktualisiereBeruehrtenBereich(an: interaktionsPosition)
                    }
                }
            }
        }
    }

    private func stoppeAutoScroll() {
        autoScrollGeschwindigkeit = 0
        autoScrollTask?.cancel()
        autoScrollTask = nil
    }

    private func scrollOffsetBegrenzen() {
        setzeScrollOffset(scrollOffset)
    }

    private func setzeScrollOffset(_ neuerWert: CGFloat) {
        let begrenzterWert = begrenzterScrollOffset(neuerWert)
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            aktuellerScrollOffset = begrenzterWert
        }
    }

    private func begrenzterScrollOffset(_ wert: CGFloat) -> CGFloat {
        min(0, max(minimalerScrollOffset, wert))
    }

    private func speichereScrollOffset() {
        let wert = Double(begrenzterScrollOffset(aktuellerScrollOffset))
        guard gespeicherterScrollOffset != wert else { return }
        gespeicherterScrollOffset = wert
    }

    private func chipBreite(fuer bereich: DossierBereich) -> CGFloat {
        bereich == aktiverBereich ? aktiverChipBreite : inaktiverChipBreite
    }

    private func frameFuerBereich(_ bereich: DossierBereich) -> CGRect? {
        var aktuelleXPosition = scrollOffset + inhaltHorizontalPadding

        for aktuellerBereich in bereiche {
            let breite = chipBreite(fuer: aktuellerBereich)
            let frame = CGRect(x: aktuelleXPosition, y: 8, width: breite, height: 56)

            if aktuellerBereich == bereich {
                return frame
            }

            aktuelleXPosition += breite + chipSpacing
        }

        return nil
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
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        }
    }
}

private struct DossierFloatingNavigationModifier: ViewModifier {
    let aktiverBereich: DossierBereich
    @State private var tastaturSichtbar = false
    @State private var navigationAusgeklappt = false
    @State private var navigationAnimationUnterdrueckt = false
    @State private var autoCollapseTask: Task<Void, Never>?
    @State private var navigationInteraktionAktiv = false
    @State private var letzteNavigationsAktivitaet = Date()

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard navigationAusgeklappt else { return }
                    klappeNavigationEin()
                }
            )
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        DossierNavigationRouter.navigateHome()
                    } label: {
                        Label("Home", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Zurück zur Übersicht")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !tastaturSichtbar {
                    ZStack(alignment: .bottomTrailing) {
                        Color.clear
                            .contentShape(Rectangle())
                            .allowsHitTesting(navigationAusgeklappt)
                            .onTapGesture {
                                markiereNavigationsAktivitaet()
                            }

                        DossierFloatingNavigationHandle {
                            klappeNavigationAus()
                            markiereNavigationsAktivitaet()
                            starteAutoCollapse()
                        }
                        .scaleEffect(navigationAusgeklappt ? 0.92 : 1, anchor: .trailing)
                        .offset(x: navigationAusgeklappt ? 6 : 0, y: navigationAusgeklappt ? 2 : 0)
                        .opacity(navigationAusgeklappt ? 0 : 1)
                        .allowsHitTesting(!navigationAusgeklappt)

                        DossierFloatingNavigation(
                            aktiverBereich: aktiverBereich,
                            interaktionGestartet: {
                                navigationInteraktionAktiv = true
                                markiereNavigationsAktivitaet()
                            },
                            interaktionBeendet: {
                                navigationInteraktionAktiv = false
                                markiereNavigationsAktivitaet()
                            }
                        )
                        .scaleEffect(
                            x: navigationAusgeklappt ? 1 : 0.22,
                            y: navigationAusgeklappt ? 1 : 0.72,
                            anchor: .trailing
                        )
                        .offset(x: navigationAusgeklappt ? 0 : 10, y: navigationAusgeklappt ? 0 : 6)
                        .opacity(navigationAusgeklappt ? 1 : 0)
                        .allowsHitTesting(navigationAusgeklappt)
                    }
                    .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 86, alignment: .bottomTrailing)
                    .clipped()
                }
            }
            .animation(.easeInOut(duration: 0.18), value: tastaturSichtbar)
            .animation(
                navigationAnimationUnterdrueckt ? nil : .spring(response: 0.64, dampingFraction: 0.94),
                value: navigationAusgeklappt
            )
            .onAppear {
                uebernehmeBereichswechselStatus()
            }
            .task {
                await beobachteTastatur()
            }
    }

    private func uebernehmeBereichswechselStatus() {
        guard DossierNavigationRuntimeState.sollNachBereichswechselAusklappen else {
            navigationAusgeklappt = false
            return
        }

        DossierNavigationRuntimeState.sollNachBereichswechselAusklappen = false
        markiereNavigationsAktivitaet()

        navigationAnimationUnterdrueckt = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            navigationAusgeklappt = true
        }

        DispatchQueue.main.async {
            navigationAnimationUnterdrueckt = false
        }

        starteAutoCollapse()
    }

    private func markiereNavigationsAktivitaet() {
        letzteNavigationsAktivitaet = Date()
    }

    private func klappeNavigationAus() {
        withAnimation(.spring(response: 0.64, dampingFraction: 0.94, blendDuration: 0.08)) {
            navigationAusgeklappt = true
        }
    }

    private func starteAutoCollapse() {
        guard autoCollapseTask == nil else { return }

        autoCollapseTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)

                await MainActor.run {
                    guard navigationAusgeklappt else {
                        autoCollapseTask?.cancel()
                        autoCollapseTask = nil
                        return
                    }

                    guard !navigationInteraktionAktiv else { return }

                    if Date().timeIntervalSince(letzteNavigationsAktivitaet) >= 2 {
                        klappeNavigationEin()
                    }
                }
            }
        }
    }

    private func klappeNavigationEin() {
        autoCollapseTask?.cancel()
        autoCollapseTask = nil
        navigationInteraktionAktiv = false

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.96, blendDuration: 0.10)) {
                navigationAusgeklappt = false
            }
        }
    }

    private func beobachteTastatur() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) {
                    await MainActor.run {
                        tastaturSichtbar = true
                        klappeNavigationEin()
                    }
                }
            }

            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) {
                    await MainActor.run {
                        tastaturSichtbar = false
                    }
                }
            }
        }
    }
}

private struct DossierFloatingNavigationHandle: View {
    let oeffnen: () -> Void
    @State private var feedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button {
            feedback.impactOccurred()
            feedback.prepare()
            oeffnen()
        } label: {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.16, green: 0.36, blue: 0.42).opacity(0.74))
                    .frame(width: 4, height: 30)
                    .shadow(color: Color.white.opacity(0.42), radius: 2, x: -1, y: 0)
            }
            .frame(width: 34, height: 66)
            .background(handleBackground)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            ))
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.11), radius: 13, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 0)
        .padding(.bottom, -4)
        .onAppear {
            feedback.prepare()
        }
        .accessibilityLabel("Dossier-Navigation öffnen")
    }

    @ViewBuilder
    private var handleBackground: some View {
        if #available(iOS 26.0, *) {
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
        }
    }
}

extension View {
    func dossierFloatingNavigation(_ aktiverBereich: DossierBereich) -> some View {
        modifier(DossierFloatingNavigationModifier(aktiverBereich: aktiverBereich))
    }
}
