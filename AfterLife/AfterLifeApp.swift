//
//  AfterLifeApp.swift
//  AfterLife
//
//  Created by René Engeler on 17.06.2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct AfterLifeApp: App {
    var sharedModelContainer: ModelContainer = {
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

    @AppStorage("istEingeloggt")
    private var istEingeloggt = false

    @AppStorage("direktNachRegistrierungEingeloggt")
    private var direktNachRegistrierungEingeloggt = false

    @AppStorage("eingehenderEinladungsToken")
    private var eingehenderEinladungsToken = ""

    @AppStorage("eingehendeEinladungsURL")
    private var eingehendeEinladungsURL = ""

    @State private var deepLinkFehlermeldung = ""
    @State private var deepLinkFehlerAnzeigen = false

    // Vor einem Release wieder auf false setzen.
    private let homeDirektStarten = false

    // Testschalter für den Einladungsprozess.
    private let einladungsSimulationAktiv = false

    private var istBereitsRegistriert: Bool {
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
            if hatOffeneEinladung {
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
            UIApplication.shared
                .aktiviereTastaturAusblendenBeiTap()

            NotificationService.shared
                .berechtigungAnfragen()

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
                    .willResignActiveNotification
            )
        ) { _ in
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
                normalisierterPfad == "einladung"
            )

        let istAltesAfterLifeScheme =
            scheme == "afterlife" &&
            (
                host == "einladung" ||
                host == "registrierung" ||
                normalisierterPfad == "einladung" ||
                normalisierterPfad == "registrierung"
            )

        return istUniversalLink ||
            istTschluessliScheme ||
            istAltesAfterLifeScheme
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
}

extension UIApplication {
    func aktiviereTastaturAusblendenBeiTap() {
        connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap {
                $0.windows
            }
            .forEach { window in
                let gestureName =
                    "GlobaleTastaturAusblendenGesture"

                let gestureExistiertBereits =
                    window.gestureRecognizers?
                        .contains {
                            $0.name == gestureName
                        } ?? false

                guard !gestureExistiertBereits else {
                    return
                }

                let tapGesture =
                    UITapGestureRecognizer(
                        target: self,
                        action:
                            #selector(
                                tastaturAusblenden
                            )
                    )

                tapGesture.name =
                    gestureName

                tapGesture.cancelsTouchesInView =
                    false

                tapGesture.delegate =
                    TastaturAusblendenGestureDelegate
                        .shared

                window.addGestureRecognizer(
                    tapGesture
                )
            }
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
