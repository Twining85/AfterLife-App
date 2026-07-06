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

    var body: some View {
        Group {
            if homeDirektStarten {
                Home()
            } else if einladungsSimulationAktiv {
                EinladungAngenommen(
                    einladenderName: "René Engeler",
                    eingeladeneEmail: "vertrauensperson@mail.ch",
                    einladungsToken: "test-token-123"
                )
            } else if istBereitsRegistriert {
                Home()
            } else {
                Registrierung()
            }
        }
        .onAppear {
            UIApplication.shared.aktiviereTastaturAusblendenBeiTap()
            NotificationService.shared.berechtigungAnfragen()
        }
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
