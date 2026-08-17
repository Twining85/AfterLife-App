import Foundation

enum LokaleSicherheitsMigration {
    private static let migrationsVersionKey = "Tschluessli.LokaleSicherheitsMigrationVersion"
    private static let aktuelleVersion = 1

    static func ausfuehren(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        legacyLoginLoeschen: () -> Void = {
            try? KeychainHelper.shared.deleteAll(service: "Tschluessli.Login")
        },
        dateischutzAnwenden: Bool = true
    ) {
        guard userDefaults.integer(forKey: migrationsVersionKey) < aktuelleVersion else {
            return
        }

        // Fruehere App-Versionen legten das Kontopasswort in UserDefaults und im
        // Keychain-Service Tschluessli.Login ab. Kontopasswoerter werden nicht
        // migriert, sondern bewusst geloescht. Nur Cloud-Sitzungstoken bleiben im
        // separaten Keychain-Service Tschluessli.CloudSession erhalten.
        userDefaults.removeObject(forKey: "gespeichertesPasswort")
        legacyLoginLoeschen()

        if dateischutzAnwenden {
            schuetztBestehendeAppDateien(fileManager: fileManager)
        }
        userDefaults.set(aktuelleVersion, forKey: migrationsVersionKey)
    }

    private static func schuetztBestehendeAppDateien(fileManager: FileManager) {
        let verzeichnisse = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        for verzeichnis in verzeichnisse {
            setzeVollstaendigenDateischutz(verzeichnis, fileManager: fileManager)

            guard let enumerator = fileManager.enumerator(
                at: verzeichnis,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                setzeVollstaendigenDateischutz(url, fileManager: fileManager)
            }
        }
    }

    private static func setzeVollstaendigenDateischutz(
        _ url: URL,
        fileManager: FileManager
    ) {
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}
