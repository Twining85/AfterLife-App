//
//  Vertrauensperson.swift
//  AfterLife
//
//  Created by René Engeler on 25.06.2026.
//

import SwiftUI
import SwiftData
import ContactsUI
import UIKit

struct VertrauenspersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteVertrauenspersonen: [VertrauenspersonModell]
    @Query private var gespeicherteProfile: [ProfilModell]
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]
    // No changes needed here for test panel in this file
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""

    @State private var einladungsSimulationStarten = false
    @State private var logoutFuerEinladungstestAnzeigen = false

    @State private var kontaktPickerAnzeigen = false
    @State private var name = ""
    @State private var vorname = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var beziehung = ""

    @State private var einladungsStatus: EinladungsStatus = .offen
    @State private var vorsorgeprozessStatus: VorsorgeprozessStatus = .nichtGestartet
    @State private var einladungsHistorie: [EinladungsHistorieEintrag] = []

    @State private var fehlermeldung = ""
    @State private var erfolgsmeldung = ""
    @State private var datenGeladen = false
    @State private var einladungsToken: String?
    @State private var einladungsEmail: String?
    @State private var einladungsLinkErstelltAm: Date?
    @State private var simulierterEinladungsLink = ""

    private var kontaktIstAusgewaehlt: Bool {
        !vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !telefon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var einladungWurdeVorbereitet: Bool {
        !einladungsHistorie.isEmpty
    }

    private var aktuellerDossierZugriff: DossierZugriffModell? {
        guard let einladungsToken else { return nil }

        return gespeicherteDossierZugriffe.first { zugriff in
            zugriff.einladungsToken == einladungsToken
        }
    }

    private var aktiveUserUUID: UUID? {
        if let uuid = UUID(uuidString: aktiveUserID) {
            return uuid
        }

        return gespeicherteProfile.first?.userID
    }

    private var aktivesDossierUUID: UUID? {
        if let uuid = UUID(uuidString: aktivesDossierID) {
            return uuid
        }

        return gespeicherteProfile.first?.dossierID
    }

    // Vorbereitung: später können hier mehrere Vertrauenspersonen pro aktivem Dossier angezeigt werden.
    private var vertrauenspersonenFuerAktivenUser: [VertrauenspersonModell] {
        guard let aktiveUserUUID else { return [] }

        return gespeicherteVertrauenspersonen
            .filter { $0.vorsorgendeUserID == aktiveUserUUID }
            .sorted {
                if $0.istPrimaereVertrauensperson != $1.istPrimaereVertrauensperson {
                    return $0.istPrimaereVertrauensperson && !$1.istPrimaereVertrauensperson
                }

                return $0.reihenfolge < $1.reihenfolge
            }
    }

    private var vertrauenspersonFuerAktivenUser: VertrauenspersonModell? {
        vertrauenspersonenFuerAktivenUser.first
    }

    private var kontaktAnzeigename: String {
        let vollerName = [vorname, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !vollerName.isEmpty {
            return vollerName
        }

        if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return email.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "Keine Vertrauensperson ausgewählt"
    }

    var body: some View {
        Form {
            Section("Vertrauensperson") {
                if kontaktIstAusgewaehlt {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kontaktAnzeigename)
                            .font(.headline)

                        if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(email)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !telefon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(telefon)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        kontaktLoeschen()
                    } label: {
                        Label("Kontakt entfernen", systemImage: "trash")
                    }
                } else {
                    Text("Es ist noch keine Vertrauensperson ausgewählt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    kontaktPickerAnzeigen = true
                } label: {
                    Label(kontaktIstAusgewaehlt ? "Kontakt ändern" : "Kontakt aus Kontakte auswählen", systemImage: "person.crop.circle.badge.plus")
                }
            }

            Section("Einladung") {
                Button {
                    einladungPerMailVorbereiten()
                } label: {
                    Label("Einladung per E-Mail vorbereiten", systemImage: "envelope.fill")
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if einladungWurdeVorbereitet {
                    HStack(spacing: 10) {
                        if einladungsStatus == .angenommen {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Einladung angenommen")
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Einladung noch nicht angenommen")
                        }
                    }

                    Button {
                        einladungsStatus = .angenommen
                        erfolgsmeldung = "Einladung wurde als angenommen markiert."
                        fehlermeldung = ""
                        speichereVertrauensperson()
                    } label: {
                        Label("Als angenommen markieren", systemImage: "checkmark.circle")
                    }
                    .disabled(einladungsStatus == .angenommen)
                }
            }

            if einladungWurdeVorbereitet {
                Section("Vorsorgeprozess") {
                    HStack(spacing: 10) {
                        if vorsorgeprozessStatus == .gestartet {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Vorsorgeprozess gestartet")
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Vorsorgeprozess noch nicht gestartet")
                        }
                    }

                    Button {
                        vorsorgeprozessStatus = .gestartet
                        erfolgsmeldung = "Vorsorgeprozess wurde als gestartet markiert."
                        fehlermeldung = ""
                        speichereVertrauensperson()
                    } label: {
                        Label("Als gestartet markieren", systemImage: "play.circle")
                    }
                    .disabled(vorsorgeprozessStatus == .gestartet)
                }
            }

            if !fehlermeldung.isEmpty || !erfolgsmeldung.isEmpty {
                Section("Hinweis") {
                    if !fehlermeldung.isEmpty {
                        Text(fehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !erfolgsmeldung.isEmpty {
                        Text(erfolgsmeldung)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Einladungshistorie") {
                if einladungsHistorie.isEmpty {
                    Text("Noch keine Einladung verschickt oder vorbereitet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(einladungsHistorie) { eintrag in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(eintrag.datum.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(eintrag.beschreibung)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            #if DEBUG
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Testbereich Einladungslink")
                        .font(.headline)

                    Text("Dieser Bereich dient nur zum Testen. Später wird er entfernt oder ausgeblendet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("UUID / Token")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(einladungsToken ?? "Noch kein Token erzeugt")
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    Text("Verknüpfte E-Mail")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(einladungsEmail ?? "Noch keine E-Mail verknüpft")
                        .font(.footnote)
                        .textSelection(.enabled)

                    Text("Erstellt am")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let einladungsLinkErstelltAm {
                        Text(einladungsLinkErstelltAm.formatted(date: .abbreviated, time: .standard))
                            .font(.footnote)
                    } else {
                        Text("Noch nicht erstellt")
                            .font(.footnote)
                    }

                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(aktuellerDossierZugriff?.status.capitalized ?? "Noch nicht erstellt")
                        .font(.footnote)
                        .foregroundStyle(aktuellerDossierZugriff?.status == DossierZugriffStatus.erstellt ? .green : .secondary)

                    Text("Gültig bis")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let gueltigBis = aktuellerDossierZugriff?.einladungGueltigBis {
                        Text(gueltigBis.formatted(date: .abbreviated, time: .standard))
                            .font(.footnote)
                    } else {
                        Text("Noch nicht gesetzt")
                            .font(.footnote)
                    }

                    Text("Link verwendet")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(aktuellerDossierZugriff?.einladungsLinkVerwendet == true ? "Ja" : "Nein")
                        .font(.footnote)
                        .foregroundStyle(aktuellerDossierZugriff?.einladungsLinkVerwendet == true ? .orange : .secondary)

                    if let verwendetAm = aktuellerDossierZugriff?.einladungsLinkVerwendetAm {
                        Text("Verwendet am")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(verwendetAm.formatted(date: .abbreviated, time: .standard))
                            .font(.footnote)
                    }

                    if einladungsToken != nil {
                        Text("Simulierter Link")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(simulierterEinladungsLink.isEmpty ? "Noch kein Link erzeugt" : simulierterEinladungsLink)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)

                        Button {
                            logoutFuerEinladungstestAnzeigen = true
                        } label: {
                            Label("Einladungslink simulieren", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)

                        Text("Hinweis: Dies ist eine Simulation. Später öffnet dieser Button den echten Einladungslink.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Test")
            }
            .listRowBackground(Color.orange.opacity(0.12))
            #endif
        }
        .navigationTitle("Vertrauensperson")
        .fullScreenCover(isPresented: $einladungsSimulationStarten) {
            EinladungAngenommen(
                einladenderName: "René Engeler",
                eingeladeneEmail: einladungsEmail ?? email,
                einladungsToken: einladungsToken ?? ""
            )
        }
        .alert("Für Test ausloggen?", isPresented: $logoutFuerEinladungstestAnzeigen) {
            Button("Abbrechen", role: .cancel) {
                logoutFuerEinladungstestAnzeigen = false
            }

            Button("Ausloggen und Test starten") {
                starteEinladungsSimulation()
            }
        } message: {
            Text("Für diesen Test wirst du aus der aktuellen Sitzung ausgeloggt. Danach öffnet sich direkt die simulierte Einladung als Vertrauensperson.")
        }
        .onAppear {
            ladeOderErstelleVertrauensperson()
        }
        .sheet(isPresented: $kontaktPickerAnzeigen) {
            VertrauenspersonKontaktPicker { kontakt in
                uebernehmeKontakt(kontakt)
            }
        }
    }

    private func starteEinladungsSimulation() {
        // Simulation: aktuelle Sitzung verlassen, damit der Einladungsprozess wie ein externer Link getestet werden kann.
        direktNachRegistrierungEingeloggt = false

        fehlermeldung = ""
        erfolgsmeldung = "Einladungslink wird simuliert. Die aktuelle Sitzung wurde für diesen Test beendet, deine Login-Daten bleiben erhalten."

        DispatchQueue.main.async {
            einladungsSimulationStarten = true
        }
    }

    private func uebernehmeKontakt(_ kontakt: CNContact) {
        vorname = kontakt.givenName
        name = kontakt.familyName

        if let ersteEmail = kontakt.emailAddresses.first?.value {
            email = String(ersteEmail)
        }

        if let ersteTelefonnummer = kontakt.phoneNumbers.first?.value.stringValue {
            telefon = ersteTelefonnummer
        }

        fehlermeldung = ""
        erfolgsmeldung = "Kontakt wurde übernommen."
        speichereVertrauensperson()
    }

    private func stelleEinladungsTokenSicher(fuer empfaengerEmail: String) {
        if let einladungsToken {
            einladungsEmail = einladungsEmail ?? empfaengerEmail
            einladungsLinkErstelltAm = einladungsLinkErstelltAm ?? Date()

            if simulierterEinladungsLink.isEmpty {
                simulierterEinladungsLink = "afterlife://registrierung?token=\(einladungsToken)"
            }

            speichereVertrauensperson()
            return
        }

        guard let dossierID = aktivesDossierUUID else {
            fehlermeldung = "Es konnte kein aktives Dossier gefunden werden. Bitte öffne zuerst dein Profil oder erstelle ein Dossier."
            return
        }

        guard let vorsorgendeUserID = aktiveUserUUID else {
            fehlermeldung = "Es konnte kein aktiver Nutzer gefunden werden. Bitte melde dich erneut an."
            return
        }

        let service = DossierZugriffService()
        let zugriff = service.erstelleEinladung(
            dossierID: dossierID,
            vorsorgendeUserID: vorsorgendeUserID,
            eingeladeneEmail: empfaengerEmail
        )

        modelContext.insert(zugriff)

        do {
            try modelContext.save()
        } catch {
            fehlermeldung = "Der Einladungslink konnte nicht gespeichert werden."
            return
        }

        einladungsToken = zugriff.einladungsToken
        einladungsEmail = zugriff.eingeladeneEmail
        einladungsLinkErstelltAm = zugriff.erstelltAm
        simulierterEinladungsLink = service.registrierungsLink(fuer: zugriff)

        speichereVertrauensperson()
    }

    private func einladungPerMailVorbereiten() {
        fehlermeldung = ""
        erfolgsmeldung = ""

        let empfaengerEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard kontaktIstAusgewaehlt else {
            fehlermeldung = "Bitte wähle zuerst eine Vertrauensperson aus."
            return
        }

        guard empfaengerEmail.contains("@"), empfaengerEmail.contains(".") else {
            fehlermeldung = "Bitte gib eine gültige E-Mail-Adresse ein."
            return
        }

        stelleEinladungsTokenSicher(fuer: empfaengerEmail)

        guard fehlermeldung.isEmpty else { return }

        let empfaengerName = [vorname, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let anredeName = empfaengerName.isEmpty ? "" : " \(empfaengerName)"

        let betreff = "Einladung als Vertrauensperson"
        let nachricht = """
        Hallo\(anredeName)

        Ich möchte dich als Vertrauensperson in meiner Vorsorge-App hinterlegen.

        In der App erfasse ich wichtige Informationen, Wünsche und Dokumente, damit im Ereignisfall alles geordnet verfügbar ist.

        Aktuell ist dies eine Vorabinformation. Bitte bewahre diese E-Mail auf und melde dich bei mir, falls sich deine Kontaktdaten ändern.

        Dein persönlicher Einladungslink lautet:
        \(simulierterEinladungsLink)

        Liebe Grüsse
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = empfaengerEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: betreff),
            URLQueryItem(name: "body", value: nachricht)
        ]

        guard let url = components.url else {
            fehlermeldung = "Die E-Mail konnte nicht vorbereitet werden."
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            fehlermeldung = "Auf diesem Gerät ist keine E-Mail-App eingerichtet."
            return
        }

        UIApplication.shared.open(url)

        einladungsStatus = .offen
        vorsorgeprozessStatus = .nichtGestartet
        einladungsHistorie.insert(
            EinladungsHistorieEintrag(
                datum: Date(),
                beschreibung: "Einladung per E-Mail vorbereitet an \(empfaengerEmail)."
            ),
            at: 0
        )

        erfolgsmeldung = "E-Mail wurde vorbereitet. Bitte in der Mail-App prüfen und senden."
        speichereVertrauensperson()
    }

    private func kontaktLoeschen() {
        vorname = ""
        name = ""
        email = ""
        telefon = ""
        beziehung = ""
        einladungsStatus = .offen
        vorsorgeprozessStatus = .nichtGestartet
        einladungsHistorie.removeAll()
        einladungsToken = nil
        einladungsEmail = nil
        einladungsLinkErstelltAm = nil
        simulierterEinladungsLink = ""
        fehlermeldung = ""
        erfolgsmeldung = "Kontakt wurde entfernt."

        if let vertrauensperson = vertrauenspersonFuerAktivenUser {
            modelContext.delete(vertrauensperson)
        }

        do {
            try modelContext.save()
        } catch {
            fehlermeldung = "Kontakt konnte nicht vollständig gelöscht werden."
            erfolgsmeldung = ""
        }
    }

    private func ladeOderErstelleVertrauensperson() {
        guard !datenGeladen else { return }

        if let gespeicherteVertrauensperson = vertrauenspersonFuerAktivenUser {
            vorname = gespeicherteVertrauensperson.vorname
            name = gespeicherteVertrauensperson.name
            email = gespeicherteVertrauensperson.email
            telefon = gespeicherteVertrauensperson.telefon
            beziehung = gespeicherteVertrauensperson.beziehung
            einladungsStatus = EinladungsStatus(rawValue: gespeicherteVertrauensperson.einladungsStatus) ?? .offen
            vorsorgeprozessStatus = VorsorgeprozessStatus(rawValue: gespeicherteVertrauensperson.vorsorgeprozessStatus) ?? .nichtGestartet
            einladungsToken = gespeicherteVertrauensperson.einladungsToken
            einladungsEmail = gespeicherteVertrauensperson.einladungsEmail
            einladungsLinkErstelltAm = gespeicherteVertrauensperson.einladungsLinkErstelltAm
            if let einladungsToken {
                simulierterEinladungsLink = "afterlife://registrierung?token=\(einladungsToken)"
                korrigiereEinladungsGueltigkeitFallsNoetig()
            }
            einladungsHistorie = gespeicherteVertrauensperson.einladungsHistorie
                .sorted { $0.datum > $1.datum }
                .map { eintrag in
                    EinladungsHistorieEintrag(
                        datum: eintrag.datum,
                        beschreibung: eintrag.beschreibung
                    )
                }
        }

        datenGeladen = true
    }

    private func korrigiereEinladungsGueltigkeitFallsNoetig() {
        guard let zugriff = aktuellerDossierZugriff else { return }

        let erstelltAm = zugriff.erstelltAm
        let erwartetesGueltigBis = Calendar.current.date(byAdding: .day, value: 30, to: erstelltAm) ?? erstelltAm.addingTimeInterval(30 * 24 * 60 * 60)

        if zugriff.einladungGueltigBis == nil || Calendar.current.isDate(zugriff.einladungGueltigBis ?? erstelltAm, inSameDayAs: erstelltAm) {
            zugriff.einladungGueltigBis = erwartetesGueltigBis
            zugriff.aktualisiertAm = Date()

            do {
                try modelContext.save()
            } catch {
                fehlermeldung = "Die Gültigkeit des Einladungslinks konnte nicht korrigiert werden."
            }
        }
    }

    private func speichereVertrauensperson() {
        guard datenGeladen else { return }

        let vertrauensperson: VertrauenspersonModell

        if let vorhandeneVertrauensperson = vertrauenspersonFuerAktivenUser {
            vertrauensperson = vorhandeneVertrauensperson
        } else {
            let neueVertrauensperson = VertrauenspersonModell()
            modelContext.insert(neueVertrauensperson)
            vertrauensperson = neueVertrauensperson
        }

        if let aktiveUserUUID {
            vertrauensperson.vorsorgendeUserID = aktiveUserUUID
        }
        // Aktuell wird nur eine Vertrauensperson erfasst. Diese wird deshalb als primär markiert.
        vertrauensperson.istPrimaereVertrauensperson = true
        vertrauensperson.reihenfolge = 0

        vertrauensperson.vorname = vorname
        vertrauensperson.name = name
        vertrauensperson.email = email
        vertrauensperson.telefon = telefon
        vertrauensperson.beziehung = beziehung
        vertrauensperson.einladungsStatus = einladungsStatus.rawValue
        vertrauensperson.vorsorgeprozessStatus = vorsorgeprozessStatus.rawValue
        vertrauensperson.einladungsToken = einladungsToken
        vertrauensperson.einladungsEmail = einladungsEmail
        vertrauensperson.einladungsLinkErstelltAm = einladungsLinkErstelltAm
        vertrauensperson.geaendertAm = Date()

        vertrauensperson.einladungsHistorie.forEach { historienEintrag in
            modelContext.delete(historienEintrag)
        }
        vertrauensperson.einladungsHistorie.removeAll()

        for eintrag in einladungsHistorie {
            let neuerEintrag = VertrauenspersonEinladungsHistorieModell(
                datum: eintrag.datum,
                beschreibung: eintrag.beschreibung
            )
            modelContext.insert(neuerEintrag)
            vertrauensperson.einladungsHistorie.append(neuerEintrag)
        }

        do {
            try modelContext.save()
        } catch {
            fehlermeldung = "Vertrauensperson konnte nicht gespeichert werden."
            erfolgsmeldung = ""
        }
    }
}

private enum EinladungsStatus: String, CaseIterable {
    case offen = "Offen"
    case angenommen = "Angenommen"
}

private enum VorsorgeprozessStatus: String, CaseIterable {
    case nichtGestartet = "Noch nicht gestartet"
    case gestartet = "Gestartet"
}

private struct EinladungsHistorieEintrag: Identifiable {
    let id: UUID
    let datum: Date
    let beschreibung: String

    init(id: UUID = UUID(), datum: Date, beschreibung: String) {
        self.id = id
        self.datum = datum
        self.beschreibung = beschreibung
    }
}

private struct VertrauenspersonKontaktPicker: UIViewControllerRepresentable {
    let kontaktAuswahl: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(kontaktAuswahl: kontaktAuswahl)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let kontaktAuswahl: (CNContact) -> Void

        init(kontaktAuswahl: @escaping (CNContact) -> Void) {
            self.kontaktAuswahl = kontaktAuswahl
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            kontaktAuswahl(contact)
        }
    }
}

#Preview {
    NavigationStack {
        VertrauenspersonView()
    }
    .modelContainer(for: [
        VertrauenspersonModell.self,
        VertrauenspersonEinladungsHistorieModell.self,
        ProfilModell.self,
        DossierModell.self,
        DossierZugriffModell.self
    ], inMemory: true)
}


