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
            DossierZugriffModell.self
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
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gesundheitsdaten: [GesundheitModell]
    @Query private var wuenscheDaten: [WuenscheModell]
    @Query private var bankkonten: [BankkontoModell]
    @Query private var schulden: [SchuldenModell]
    @Query private var versicherungen: [VersicherungModell]
    @Query private var liegenschaften: [LiegenschaftModell]
    @Query private var wertsachen: [WertsacheModell]
    @Query private var steuerdokumente: [SteuerdokumentModell]
    @Query private var hinterbliebene: [HinterbliebeneModell]
    @Query private var vertrauenspersonen: [VertrauenspersonModell]
    @Query private var aboModelle: [AboModell]
    @Query private var digitaleKonten: [DigitalekontenModell]
    @Query private var herzensstuecke: [HerzensstueckModell]

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

    @State private var deepLinkFehlermeldung = ""
    @State private var deepLinkFehlerAnzeigen = false

    // Vor einem Release wieder auf false setzen.
    private let homeDirektStarten = false

    // Testschalter für den Einladungsprozess.
    private let einladungsSimulationAktiv = false

    private var istBereitsRegistriert: Bool {
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
        .onAppear {
            DispatchQueue.main.async {
                UIApplication.shared
                    .aktiviereTastaturAusblendenBeiInteraktion()
            }

            verarbeiteGespeicherteEinladungsURLFallsNoetig()
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
            synchronisiereKernDaten()

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
        }
    }

    private func synchronisiereKernDaten() {
        guard istEingeloggt,
              let dossierID = UUID(uuidString: UserDefaults.standard.string(forKey: "aktivesDossierID") ?? "") else {
            return
        }
        let profile = gespeicherteProfile
            .filter { $0.dossierID == dossierID }
            .map(CloudProfilDaten.init)
        let gesundheit = gesundheitsdaten
            .filter { $0.dossierID == dossierID }
            .map(CloudGesundheitDaten.init)
        let wuensche = wuenscheDaten
            .filter { $0.dossierID == dossierID }
            .map(CloudWuenscheDaten.init)
        let finanzen = CloudFinanzenDaten(
            bankkonten: bankkonten.filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Bankkonto.init),
            schulden: schulden.filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Schuld.init),
            versicherungen: versicherungen.filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Versicherung.init),
            liegenschaften: liegenschaften.filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Liegenschaft.init),
            wertsachen: wertsachen.filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Wertsache.init),
            steuerdokumente: steuerdokumente.filter { $0.dossierID == dossierID }.map(CloudFinanzenDaten.Steuerdokument.init)
        )
        let kontakte = CloudKontaktDaten(
            hinterbliebene: hinterbliebene.filter { $0.dossierID == dossierID }.map(CloudKontaktDaten.Hinterbliebene.init),
            vertrauenspersonen: vertrauenspersonen.filter { $0.dossierID == dossierID }.map(CloudKontaktDaten.Vertrauensperson.init)
        )
        let zugangsdaten = CloudZugangsDaten(
            abos: aboModelle.filter { $0.dossierID == dossierID }.map(CloudAboDaten.init),
            digitaleKonten: digitaleKonten.filter { $0.dossierID == dossierID }.map(CloudZugangsDaten.DigitalesKonto.init)
        )
        let herzensstueckDaten = herzensstuecke
            .filter { $0.dossierID == dossierID }
            .map(CloudHerzensstueckDaten.init)

        var hintergrundTask = UIBackgroundTaskIdentifier.invalid
        hintergrundTask = UIApplication.shared.beginBackgroundTask(
            withName: "Tschluessli-Dossier-Synchronisation"
        ) {
            if hintergrundTask != .invalid {
                UIApplication.shared.endBackgroundTask(hintergrundTask)
                hintergrundTask = .invalid
            }
        }

        Task {
            defer {
                if hintergrundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(hintergrundTask)
                    hintergrundTask = .invalid
                }
            }
            do {
                _ = try await CloudDossierSyncService.shared.speichern(
                    CloudDatenListe(items: profile), dossierID: dossierID, bereich: "profil", schemaVersion: 1
                )
                _ = try await CloudDossierSyncService.shared.speichern(
                    CloudDatenListe(items: gesundheit), dossierID: dossierID, bereich: "gesundheit", schemaVersion: 1
                )
                _ = try await CloudDossierSyncService.shared.speichern(
                    CloudDatenListe(items: wuensche), dossierID: dossierID, bereich: "wuensche", schemaVersion: 1
                )
                _ = try await CloudDossierSyncService.shared.speichern(
                    finanzen, dossierID: dossierID, bereich: "finanzen", schemaVersion: 1
                )
                _ = try await CloudDossierSyncService.shared.speichern(
                    kontakte, dossierID: dossierID, bereich: "kontakte", schemaVersion: 1
                )
                _ = try await CloudDossierSyncService.shared.speichern(
                    CloudDatenListe(items: herzensstueckDaten), dossierID: dossierID, bereich: "herzensstuecke", schemaVersion: 1
                )
                let verschluesselteZugaenge = try await CloudFeldVerschluesselung.shared.verschluesseln(zugangsdaten)
                _ = try await CloudDossierSyncService.shared.speichern(
                    verschluesselteZugaenge, dossierID: dossierID, bereich: "zugaenge", schemaVersion: 1
                )
            } catch {
                print("Cloud-Synchronisation der Kerndaten fehlgeschlagen: \(error.localizedDescription)")
            }
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
