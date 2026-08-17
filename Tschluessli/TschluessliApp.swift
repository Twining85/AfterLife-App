//
//  TschluessliApp.swift
//  Tschluessli
//
//  Created by René Engeler on 17.06.2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct TschluessliApp: App {
    var sharedModelContainer: ModelContainer = {
        LokaleSicherheitsMigration.ausfuehren()

        let schema = Schema([
            ProfilModell.self,
            GesundheitModell.self,
            WuenscheModell.self,
            HinterbliebeneModell.self,
            BankkontoModell.self,
            SchuldenModell.self,
            VersicherungModell.self,
            LiegenschaftModell.self,
            WertsacheModell.self,
            SteuerdokumentModell.self,
            AboModell.self,
            AboEintrag.self,
            FotoalbumBildModell.self,
            DokumenteModell.self,
            HerzensstueckModell.self,
            HerzensstueckBildModell.self,
            HerzensstueckDokumentModell.self,
            HerzensstueckAudioModell.self,
            VertrauenspersonModell.self,
            VertrauenspersonEinladungsHistorieModell.self,
            DossierModell.self,
            DossierZugriffModell.self,
            SyncAuftrag.self,
            SyncKonflikt.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError(
                "Could not create ModelContainer: \(error)"
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppStartView()
                .modelContainer(sharedModelContainer)
        }
    }
}

struct AppStartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]

    @AppStorage("istEingeloggt")
    private var istEingeloggt = false

    @AppStorage("direktNachRegistrierungEingeloggt")
    private var direktNachRegistrierungEingeloggt = false

    @AppStorage("profilIstVorhanden")
    private var profilIstVorhanden = false

    @AppStorage("gespeicherteEmail")
    private var gespeicherteEmail = ""

    @AppStorage("biometriePruefungImProfilLaeuft")
    private var biometriePruefungImProfilLaeuft = false

    @AppStorage("systemdialogImProfilLaeuft")
    private var systemdialogImProfilLaeuft = false

    @AppStorage("eingehenderEinladungsToken")
    private var eingehenderEinladungsToken = ""

    @AppStorage("eingehendeEinladungsURL")
    private var eingehendeEinladungsURL = ""

    @AppStorage("profilWurdeGeradeGeloescht")
    private var profilWurdeGeradeGeloescht = false

    @AppStorage("wurdeGeradeAusgeloggt")
    private var wurdeGeradeAusgeloggt = false

    @AppStorage("wiederherstellungNeuesGeraetLaeuft")
    private var wiederherstellungNeuesGeraetLaeuft = false

    @State private var deepLinkFehlermeldung = ""
    @State private var deepLinkFehlerAnzeigen = false
    @State private var dossierSyncDienst: DossierSyncDienst?
    @State private var cloudDatenVersion = UUID()
    @State private var syncAnzeigeStatus: SyncAnzeigeStatus?
    @State private var syncAnzeigeTask: Task<Void, Never>?

    // Vor einem Release wieder auf false setzen.
    private let homeDirektStarten = false

    // Testschalter für den Einladungsprozess.
    private let einladungsSimulationAktiv = false

    private var istBereitsRegistriert: Bool {
        // Während des Recovery-Downloads wird bereits ein Profil importiert.
        // Die Startansicht darf deshalb erst nach der vollständigen Animation
        // auf Login/Home umschalten.
        if wiederherstellungNeuesGeraetLaeuft {
            return false
        }
        if profilIstVorhanden {
            return true
        }

        if !gespeicherteEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            return true
        }

        guard let profil = gespeicherteProfile.first else {
            return false
        }

        let registrierungsEmail =
            profil.registrierungsEmail.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let profilEmail =
            profil.email.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return !registrierungsEmail.isEmpty ||
            !profilEmail.isEmpty
    }

    private var vorsorgendePersonName: String {
        guard let profil = gespeicherteProfile.first else {
            return "eine vorsorgende Person"
        }

        let vorname =
            profil.vorname.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let nachname =
            profil.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let vollerName =
            "\(vorname) \(nachname)"
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        return vollerName.isEmpty
            ? "eine vorsorgende Person"
            : vollerName
    }

    private var hatOffeneEinladung: Bool {
        !eingehenderEinladungsToken
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    var body: some View {
        Group {
            if profilWurdeGeradeGeloescht {
                Deleted {
                    profilWurdeGeradeGeloescht = false
                }
            } else if wurdeGeradeAusgeloggt {
                Logout {
                    wurdeGeradeAusgeloggt = false
                }
            } else if hatOffeneEinladung {
                EinladungAngenommen(
                    einladenderName: vorsorgendePersonName,
                    eingeladeneEmail: "",
                    einladungsToken:
                        eingehenderEinladungsToken
                )
                .id(eingehenderEinladungsToken)

            } else if homeDirektStarten {
                Home()

            } else if einladungsSimulationAktiv {
                EinladungAngenommen(
                    einladenderName: "René Engeler",
                    eingeladeneEmail:
                        "vertrauensperson@mail.ch",
                    einladungsToken:
                        "test-token-123"
                )

            } else if istBereitsRegistriert {
                if istEingeloggt ||
                    direktNachRegistrierungEingeloggt {
                    Home()
                } else {
                    ReloginView()
                }

            } else {
                Registrierung()
            }
        }
        .id(cloudDatenVersion)
        .overlay(alignment: .top) {
            if let syncAnzeigeStatus {
                SyncStatusHinweis(status: syncAnzeigeStatus)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                UIApplication.shared
                    .aktiviereTastaturAusblendenBeiInteraktion()
            }

            verarbeiteGespeicherteEinladungsURLFallsNoetig()
            if istEingeloggt || direktNachRegistrierungEingeloggt || homeDirektStarten {
                starteDossierSyncFallsNoetig()
            }
        }
        .onOpenURL { url in
            verarbeiteEinladungsURL(url)
        }
        .onContinueUserActivity(
            NSUserActivityTypeBrowsingWeb
        ) { userActivity in
            guard let url = userActivity.webpageURL else {
                return
            }

            verarbeiteEinladungsURL(url)
        }
        .alert(
            "Einladung konnte nicht geöffnet werden",
            isPresented: $deepLinkFehlerAnzeigen
        ) {
            Button("OK", role: .cancel) {
                deepLinkFehlermeldung = ""
            }
        } message: {
            Text(deepLinkFehlermeldung)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication
                    .didEnterBackgroundNotification
            )
        ) { _ in
            if (istEingeloggt || direktNachRegistrierungEingeloggt || homeDirektStarten),
               let dossierSyncDienst {
                var hintergrundTask = UIBackgroundTaskIdentifier.invalid
                hintergrundTask = UIApplication.shared.beginBackgroundTask(
                    withName: "Tschluessli.CloudSync"
                ) {
                    if hintergrundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(hintergrundTask)
                        hintergrundTask = .invalid
                    }
                }
                dossierSyncDienst.synchronisierenImHintergrund {
                    if hintergrundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(hintergrundTask)
                        hintergrundTask = .invalid
                    }
                }
            }

            guard !biometriePruefungImProfilLaeuft,
                  !systemdialogImProfilLaeuft else {
                return
            }

            guard istBereitsRegistriert else {
                return
            }

            guard !homeDirektStarten else {
                return
            }

            guard !hatOffeneEinladung else {
                return
            }

            istEingeloggt = false
            direktNachRegistrierungEingeloggt = false
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )
        ) { _ in
            UIApplication.shared
                .aktiviereTastaturAusblendenBeiInteraktion()
            guard istEingeloggt || direktNachRegistrierungEingeloggt || homeDirektStarten else {
                return
            }
            starteDossierSyncFallsNoetig()
            dossierSyncDienst?.synchronisieren()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .dossierCloudDatenAktualisiert
            )
        ) { _ in
            // Ein erzwungener Neuaufbau würde den Fullscreen-Recovery-Ablauf
            // samt Fortschrittsanimation zerstören. Die importierten Daten
            // werden dort bereits direkt beobachtet und nach Abschluss mit
            // dem Wechsel zu Home angezeigt.
            guard !wiederherstellungNeuesGeraetLaeuft else { return }
            cloudDatenVersion = UUID()
            zeigeErfolgreicheCloudAktualisierung()
        }
        .onChange(of: istEingeloggt) { _, istJetztEingeloggt in
            guard istJetztEingeloggt else { return }
            // `didBecomeActive` kann vor dem abgeschlossenen Face-ID- oder
            // E-Mail-Login eintreffen. Nach erfolgreicher Anmeldung wird der
            // Cloud-Abgleich deshalb nochmals garantiert ausgelöst.
            starteDossierSyncFallsNoetig()
            dossierSyncDienst?.synchronisieren()
        }
        .onChange(of: direktNachRegistrierungEingeloggt) { _, istJetztEingeloggt in
            guard istJetztEingeloggt else { return }
            starteDossierSyncFallsNoetig()
            dossierSyncDienst?.synchronisieren()
        }
    }

    private func starteDossierSyncFallsNoetig() {
        guard dossierSyncDienst == nil,
              let dienst = try? DossierSyncDienst(modelContext: modelContext) else {
            return
        }
        dossierSyncDienst = dienst
        dienst.starten()
    }

    private func zeigeErfolgreicheCloudAktualisierung() {
        syncAnzeigeTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            syncAnzeigeStatus = .aktualisiert
        }
        syncAnzeigeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                syncAnzeigeStatus = .abgeschlossen
            }
            try? await Task.sleep(for: .milliseconds(1_250))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) {
                syncAnzeigeStatus = nil
            }
            syncAnzeigeTask = nil
        }
    }

    // MARK: - Eingehender Link

    private func verarbeiteEinladungsURL(_ url: URL) {
        print(
            "Eingehende URL: \(url.absoluteString)"
        )

        guard istGueltigerEinladungsLink(url) else {
            print(
                "URL wurde nicht als Einladungslink erkannt."
            )

            deepLinkFehlermeldung =
                "Der Link gehört nicht zu einer gültigen Tschlüssli-Einladung."

            deepLinkFehlerAnzeigen = true
            return
        }

        guard let token = einladungsToken(aus: url) else {
            print(
                "Einladungslink enthält keinen Token."
            )

            deepLinkFehlermeldung =
                "Der Einladungslink enthält keinen gültigen Einladungscode."

            deepLinkFehlerAnzeigen = true
            return
        }

        eingehendeEinladungsURL =
            url.absoluteString

        eingehenderEinladungsToken =
            token

        istEingeloggt = false
        direktNachRegistrierungEingeloggt = false

        print(
            "Einladungstoken gespeichert: \(token)"
        )
    }

    private func istGueltigerEinladungsLink(
        _ url: URL
    ) -> Bool {
        let scheme =
            url.scheme?
                .lowercased() ?? ""

        let host =
            url.host?
                .lowercased() ?? ""

        let normalisierterPfad =
            url.path
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )
                .lowercased()

        let istUniversalLink =
            scheme == "https" &&
            (
                host == "tschluessli.ch" ||
                host == "www.tschluessli.ch"
            ) &&
            normalisierterPfad == "einladung"

        let istTschluessliScheme =
            scheme == "tschluessli" &&
            (
                host == "einladung" ||
                host == "registrierung" ||
                normalisierterPfad == "einladung" ||
                normalisierterPfad == "registrierung"
            )

        return istUniversalLink ||
            istTschluessliScheme
    }

    private func einladungsToken(
        aus url: URL
    ) -> String? {
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }

        guard let roherToken =
                components.queryItems?
                    .first(where: {
                        $0.name.lowercased() == "token"
                    })?
                    .value else {
            return nil
        }

        let dekodierterToken =
            roherToken.removingPercentEncoding ??
            roherToken

        let bereinigterToken =
            dekodierterToken.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !bereinigterToken.isEmpty else {
            return nil
        }

        return bereinigterToken
    }

    private func verarbeiteGespeicherteEinladungsURLFallsNoetig() {
        guard !hatOffeneEinladung else {
            return
        }

        let gespeicherteURL =
            eingehendeEinladungsURL
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !gespeicherteURL.isEmpty,
              let url = URL(
                string: gespeicherteURL
              ) else {
            return
        }

        verarbeiteEinladungsURL(url)
    }
}

private enum SyncAnzeigeStatus {
    case aktualisiert
    case abgeschlossen
}

private struct SyncStatusHinweis: View {
    let status: SyncAnzeigeStatus
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: status == .aktualisiert
                ? "arrow.triangle.2.circlepath"
                : "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status == .aktualisiert ? Color.accentColor : Color.green)
                .rotationEffect(.degrees(status == .aktualisiert ? rotation : 0))

            Text(status == .aktualisiert ? "Daten werden aktualisiert …" : "Aktualisiert")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .onAppear {
            guard status == .aktualisiert else { return }
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Tastatur ausblenden

final class TastaturAusblendenGestureDelegate:
    NSObject,
    UIGestureRecognizerDelegate {

    static let shared =
        TastaturAusblendenGestureDelegate()

    private override init() {
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var aktuelleView: UIView? =
            touch.view

        while let view = aktuelleView {
            if view is UIControl ||
                view is UITextView {
                return false
            }

            aktuelleView =
                view.superview
        }

        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
            UIGestureRecognizer
    ) -> Bool {
        true
    }
}

extension UIApplication {
    func aktiviereTastaturAusblendenBeiInteraktion() {
        connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap {
                $0.windows
            }
            .forEach { window in
                let tapGestureName =
                    "GlobaleTastaturAusblendenGesture"

                let tapGestureExistiertBereits =
                    window.gestureRecognizers?
                        .contains {
                            $0.name == tapGestureName
                        } ?? false

                if !tapGestureExistiertBereits {
                    let tapGesture =
                        UITapGestureRecognizer(
                            target: self,
                            action:
                                #selector(
                                    tastaturAusblenden
                                )
                        )

                    tapGesture.name = tapGestureName
                    tapGesture.cancelsTouchesInView = false
                    tapGesture.delegate =
                        TastaturAusblendenGestureDelegate.shared
                    window.addGestureRecognizer(tapGesture)
                }

                let panGestureName =
                    "GlobaleTastaturAusblendenBeiScrollGesture"
                let panGestureExistiertBereits =
                    window.gestureRecognizers?
                        .contains {
                            $0.name == panGestureName
                        } ?? false

                if !panGestureExistiertBereits {
                    let panGesture =
                        UIPanGestureRecognizer(
                        target: self,
                        action:
                            #selector(
                                tastaturAusblendenBeiScroll(_:)
                            )
                    )

                    panGesture.name = panGestureName
                    panGesture.cancelsTouchesInView = false
                    panGesture.delegate =
                        TastaturAusblendenGestureDelegate.shared
                    window.addGestureRecognizer(panGesture)
                }
            }
    }

    @objc
    private func tastaturAusblendenBeiScroll(
        _ gestureRecognizer: UIPanGestureRecognizer
    ) {
        guard gestureRecognizer.state == .began else {
            return
        }

        tastaturAusblenden()
    }

    @objc
    private func tastaturAusblenden() {
        sendAction(
            #selector(
                UIResponder.resignFirstResponder
            ),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
