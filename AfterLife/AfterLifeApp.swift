//
//  AfterLifeApp.swift
//  AfterLife
//
//  Created by René Engeler on 17.06.2026.
//

import SwiftUI
import SwiftData

@main
struct AfterLifeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ProfilModell.self,
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
            DokumenteModell.self
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
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AppStartView: View {
    @Query private var gespeicherteProfile: [ProfilModell]

    private var istBereitsRegistriert: Bool {
        guard let profil = gespeicherteProfile.first else { return false }

        let registrierungsEmail = profil.registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let profilEmail = profil.email.trimmingCharacters(in: .whitespacesAndNewlines)

        return !registrierungsEmail.isEmpty || !profilEmail.isEmpty
    }

    var body: some View {
        if istBereitsRegistriert {
            ReloginView()
        } else {
            Registrierung()
        }
    }
}
