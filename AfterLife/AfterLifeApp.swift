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
            fatalError("Could not create ModelContainer: \(error)")
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
    @AppStorage("istEingeloggt") private var istEingeloggt = false
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false

    // MARK: - Eingehende Einladung
    // Der Token wird über Deep Links gesetzt, z. B.:
    // tschluessli://einladung?token=...
    // https://tschluessli.ch/einladung?token=...
    @AppStorage("eingehenderEinladungsToken") private var eingehenderEinladungsToken = ""

    // MARK: - Entwicklungsmodus
    // Für die Entwicklung kann direkt die HomeView geöffnet werden.
    // Vor einem Release wieder auf false setzen.
    private let homeDirektStarten = false

    // Testschalter für den Einladungs-Use-Case
    private let einladungsSimulationAktiv = false

    private var istBereitsRegistriert: Bool {
        guard let profil = gespeicherteProfile.first else { return false }

        let registrierungsEmail = profil.registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let profilEmail = profil.email.trimmingCharacters(in: .whitespacesAndNewlines)

        return !registrierungsEmail.isEmpty || !profilEmail.isEmpty
    }

    private var vorsorgendePersonName: String {
        guard let profil = gespeicherteProfile.first else { return "eine vorsorgende Person" }

        let vorname = profil.vorname.trimmingCharacters(in: .whitespacesAndNewlines)
        let nachname = profil.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let vollerName = "\(vorname) \(nachname)".trimmingCharacters(in: .whitespacesAndNewlines)

        return vollerName.isEmpty ? "eine vorsorgende Person" : vollerName
    }

    var body: some View {
        Group {
            if !eingehenderEinladungsToken.isEmpty {
                EinladungAngenommen(
                    einladenderName: vorsorgendePersonName,
                    eingeladeneEmail: "",
                    einladungsToken: eingehenderEinladungsToken
                )
            } else if homeDirektStarten {
                Home()
            } else if einladungsSimulationAktiv {
                EinladungAngenommen(
                    einladenderName: "René Engeler",
                    eingeladeneEmail: "vertrauensperson@mail.ch",
                    einladungsToken: "test-token-123"
                )
            } else if istBereitsRegistriert {
                if istEingeloggt || direktNachRegistrierungEingeloggt {
                    Home()
                } else {
                    ReloginView()
                }
            } else {
                Registrierung()
            }
        }
        .onAppear {
            UIApplication.shared.aktiviereTastaturAusblendenBeiTap()
            NotificationService.shared.berechtigungAnfragen()
        }
        .onOpenURL { url in
            verarbeiteEinladungsURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            guard istBereitsRegistriert else { return }
            guard !homeDirektStarten else { return }
            guard eingehenderEinladungsToken.isEmpty else { return }
            istEingeloggt = false
            direktNachRegistrierungEingeloggt = false
        }
    }

    private func verarbeiteEinladungsURL(_ url: URL) {
        guard istGueltigerEinladungsLink(url) else { return }
        guard let token = einladungsToken(aus: url) else { return }

        eingehenderEinladungsToken = token
        istEingeloggt = false
        direktNachRegistrierungEingeloggt = false
    }

    private func istGueltigerEinladungsLink(_ url: URL) -> Bool {
        let istUniversalLink = url.scheme == "https"
            && url.host == "tschluessli.ch"
            && url.path == "/einladung"

        let istTschluessliSchemeMitHost = url.scheme == "tschluessli"
            && url.host == "einladung"

        let istTschluessliSchemeMitPfad = url.scheme == "tschluessli"
            && url.path == "/einladung"

        let istAfterLifeSchemeMitHost = url.scheme == "afterlife"
            && url.host == "einladung"

        let istAfterLifeSchemeMitPfad = url.scheme == "afterlife"
            && url.path == "/einladung"

        let istAlterRegistrierungsLink = url.scheme == "afterlife"
            && url.host == "registrierung"

        return istUniversalLink
            || istTschluessliSchemeMitHost
            || istTschluessliSchemeMitPfad
            || istAfterLifeSchemeMitHost
            || istAfterLifeSchemeMitPfad
            || istAlterRegistrierungsLink
    }

    private func einladungsToken(aus url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let token = components.queryItems?
            .first { $0.name == "token" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token, !token.isEmpty else { return nil }
        return token
    }
}

final class TastaturAusblendenGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = TastaturAusblendenGestureDelegate()
    
    private override init() {}
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var aktuelleView: UIView? = touch.view
        
        while let view = aktuelleView {
            if view is UIControl || view is UITextView {
                return false
            }
            
            aktuelleView = view.superview
        }
        
        return true
    }
}

extension UIApplication {
    func aktiviereTastaturAusblendenBeiTap() {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                let gestureName = "GlobaleTastaturAusblendenGesture"
                let gestureExistiertBereits = window.gestureRecognizers?.contains { $0.name == gestureName } ?? false
                
                guard !gestureExistiertBereits else { return }
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tastaturAusblenden))
                tapGesture.name = gestureName
                tapGesture.cancelsTouchesInView = false
                tapGesture.delegate = TastaturAusblendenGestureDelegate.shared
                window.addGestureRecognizer(tapGesture)
            }
    }
    
    @objc private func tastaturAusblenden() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
