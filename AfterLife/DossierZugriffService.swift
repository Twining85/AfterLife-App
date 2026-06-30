import Foundation

/// Zentrale Geschäftslogik rund um Einladungen und Dossierzugriffe.
struct DossierZugriffService {

    /// Erstellt einen neuen Dossierzugriff für eine Vertrauensperson.
    func erstelleEinladung(
        dossierID: UUID,
        vorsorgendeUserID: UUID,
        eingeladeneEmail: String
    ) -> DossierZugriffModell {

        let token = UUID().uuidString.lowercased()
        let gueltigBis = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

        return DossierZugriffModell(
            einladungsToken: token,
            eingeladeneEmail: eingeladeneEmail,
            einladungGueltigBis: gueltigBis,
            dossierID: dossierID,
            vorsorgendeUserID: vorsorgendeUserID
        )
    }

    /// Liefert den simulierten Registrierungslink.
    func registrierungsLink(fuer zugriff: DossierZugriffModell) -> String {
        guard let token = zugriff.einladungsToken else {
            return "afterlife://registrierung?token="
        }

        return "afterlife://registrierung?token=\(token)"
    }

    /// Prüft, ob eine Einladung aktuell gültig ist.
    func istEinladungGueltig(_ zugriff: DossierZugriffModell) -> Bool {
        zugriff.kannRegistrierungFortsetzen
    }
}
