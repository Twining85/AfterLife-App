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

    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let kartenFarbe = Color.white.opacity(0.88)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let textFarbe = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let sekundaerTextFarbe = Color.black.opacity(0.58)

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

    private var bereinigteEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bereinigterEmpfaengerName: String {
        [vorname, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var dossierZugriffService: DossierZugriffService {
        DossierZugriffService()
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

    private var dossierZugriffeFuerAktivesDossier: [DossierZugriffModell] {
        guard let aktivesDossierUUID else { return [] }

        let gefilterteZugriffe: [DossierZugriffModell] = gespeicherteDossierZugriffe.filter { zugriff in
            zugriff.dossierID == aktivesDossierUUID
        }

        return gefilterteZugriffe.sorted { ersterZugriff, zweiterZugriff in
            ersterZugriff.erstelltAm > zweiterZugriff.erstelltAm
        }
    }

    private func statusFarbe(fuer zugriff: DossierZugriffModell) -> Color {
        if zugriff.istEinladungAbgelaufen && zugriff.status == DossierZugriffStatus.erstellt {
            return .orange
        }

        switch zugriff.status {
        case DossierZugriffStatus.angenommen,
             DossierZugriffStatus.freigegeben:
            return .green
        case DossierZugriffStatus.abgelehnt,
             DossierZugriffStatus.widerrufen:
            return .red
        default:
            return .blue
        }
    }

    private var vorsorgendePersonName: String {
        if let aktiveUserUUID,
           let profil = gespeicherteProfile.first(where: { $0.userID == aktiveUserUUID }) {
            let name = [profil.vorname, profil.name]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !name.isEmpty {
                return name
            }
        }

        return gespeicherteEmail.isEmpty ? "Vorsorgende Person" : gespeicherteEmail
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
        if !bereinigterEmpfaengerName.isEmpty {
            return bereinigterEmpfaengerName
        }

        if !bereinigteEmail.isEmpty {
            return bereinigteEmail
        }

        return "Keine Vertrauensperson ausgewählt"
    }

    private var einladungIstErstellt: Bool {
        einladungsToken != nil
    }

    private var einladungIstAngenommen: Bool {
        aktuellerDossierZugriff?.status == DossierZugriffStatus.angenommen
    }

    private var einladungIstAbgelehnt: Bool {
        aktuellerDossierZugriff?.status == DossierZugriffStatus.abgelehnt
    }

    private var einladungKannManuellAngenommenWerden: Bool {
        aktuellerDossierZugriff?.kannRegistrierungFortsetzen == true
    }

    private var zugriffKannFreigegebenWerden: Bool {
        guard let zugriff = aktuellerDossierZugriff else { return false }

        return zugriff.status == DossierZugriffStatus.angenommen &&
        zugriff.istAktiv &&
        zugriff.freigegebenAm == nil &&
        zugriff.widerrufenAm == nil
    }

    private var naechsterSchrittText: String {
        if !kontaktIstAusgewaehlt {
            return "Wähle zuerst eine Vertrauensperson aus deinen Kontakten aus."
        }

        if !einladungIstErstellt {
            return "Bereite danach die Einladung per E-Mail vor. Dabei wird automatisch ein persönlicher Einladungslink erzeugt."
        }

        if einladungIstAngenommen {
            return "Die Einladung wurde angenommen. Der Link kann nicht erneut verwendet werden."
        }

        if einladungIstAbgelehnt {
            return "Die Einladung wurde abgelehnt. Erstelle bei Bedarf eine neue Einladung."
        }

        return "Die Einladung ist bereit. Sende die E-Mail oder teste den Link im Testbereich."
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vertrauensperson einladen")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(textFarbe)

                    Text("Führe den Prozess Schritt für Schritt durch. Die App zeigt dir jeweils, was als Nächstes zu tun ist.")
                        .font(.footnote)
                        .foregroundStyle(sekundaerTextFarbe)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(kontaktIstAusgewaehlt ? "1. Kontakt ausgewählt" : "1. Kontakt auswählen", systemImage: kontaktIstAusgewaehlt ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(kontaktIstAusgewaehlt ? .green : .primary)

                        Label(einladungIstErstellt ? "2. Einladung vorbereitet" : "2. Einladung vorbereiten", systemImage: einladungIstErstellt ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(einladungIstErstellt ? .green : .primary)

                        Label(einladungIstAngenommen ? "3. Einladung angenommen" : einladungIstAbgelehnt ? "3. Einladung abgelehnt" : "3. Rückmeldung abwarten", systemImage: einladungIstAngenommen ? "checkmark.circle.fill" : einladungIstAbgelehnt ? "xmark.circle.fill" : "circle")
                            .foregroundStyle(einladungIstAngenommen ? .green : einladungIstAbgelehnt ? .red : .primary)
                    }
                    .font(.footnote)

                    Text(naechsterSchrittText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(akzentFarbe)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(akzentFarbe.opacity(0.08))
                        )
                        .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardHintergrund)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            if !dossierZugriffeFuerAktivesDossier.isEmpty {
                Section("Aktuelle Zugriffe") {
                    ForEach(dossierZugriffeFuerAktivesDossier, id: \.einladungsToken) { zugriff in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.title2)
                                    .foregroundStyle(statusFarbe(fuer: zugriff))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(zugriff.anzeigename)
                                        .font(.headline)

                                    Text(zugriff.eingeladeneEmail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 6) {
                                        Text(zugriff.statusAnzeige)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(statusFarbe(fuer: zugriff))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(statusFarbe(fuer: zugriff).opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }

                            if let gueltigBis = zugriff.einladungGueltigBis,
                               zugriff.status == DossierZugriffStatus.erstellt {
                                Text("Einladung gültig bis \(gueltigBis.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if zugriff.hatAbweichendeRegistrierungsEmail,
                               let registrierungsEmail = zugriff.registrierungsEmail {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Registrierung erfolgte mit abweichender E-Mail", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)

                                    Text(registrierungsEmail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }

            Section {
                sectionTitel("Vertrauensperson", icon: "person.crop.circle.badge.plus")
                if kontaktIstAusgewaehlt {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kontaktAnzeigename)
                            .font(.headline)

                        if !bereinigteEmail.isEmpty {
                            Text(bereinigteEmail)
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

            Section {
                sectionTitel("Einladung", icon: "envelope.fill")
                Button {
                    einladungPerMailVorbereiten()
                } label: {
                    Label(einladungIstErstellt ? "Einladung erneut in Mail öffnen" : "Einladung per E-Mail vorbereiten", systemImage: "envelope.fill")
                }
                .disabled(bereinigteEmail.isEmpty)

                if !kontaktIstAusgewaehlt {
                    Text("Wähle zuerst eine Vertrauensperson aus. Danach kannst du die Einladung vorbereiten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !einladungIstErstellt {
                    Text("Beim Vorbereiten wird ein persönlicher Link erzeugt, der 30 Tage gültig ist und nur einmal verwendet werden kann.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Die Einladung wurde vorbereitet. Du kannst die E-Mail in deiner Mail-App prüfen und senden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if einladungWurdeVorbereitet {
                    HStack(spacing: 10) {
                        if einladungIstAngenommen {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Einladung angenommen")
                        } else if einladungIstAbgelehnt {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Einladung abgelehnt")
                        } else {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text("Einladung offen")
                        }
                    }

                    #if DEBUG
                    Button {
                        markiereEinladungImTestAlsAngenommen()
                    } label: {
                        Label("Test: Einladung als angenommen markieren", systemImage: "checkmark.circle")
                    }
                    .disabled(!einladungKannManuellAngenommenWerden)
                    #endif
                }
            }

            if einladungWurdeVorbereitet {
                Section {
                    sectionTitel("Rückmeldung", icon: "lock.open.fill")
                    HStack(spacing: 10) {
                        if aktuellerDossierZugriff?.istFreigegeben == true {
                            Image(systemName: "lock.open.fill")
                                .foregroundStyle(.green)
                            Text("Zugriff freigegeben")
                        } else if einladungIstAngenommen {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Einladung angenommen, Freigabe offen")
                        } else {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text("Noch keine Freigabe möglich")
                        }
                    }

                    #if DEBUG
                    Button {
                        gebeZugriffImTestFrei()
                    } label: {
                        Label("Test: Zugriff freigeben", systemImage: "lock.open")
                    }
                    .disabled(!zugriffKannFreigegebenWerden)
                    #endif
                }
            }

            if !fehlermeldung.isEmpty || !erfolgsmeldung.isEmpty {
                Section {
                    sectionTitel("Hinweis", icon: "info.circle.fill")
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

            Section {
                sectionTitel("Protokoll", icon: "list.bullet.clipboard.fill")
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
                        .foregroundStyle((aktuellerDossierZugriff?.status == DossierZugriffStatus.erstellt) ? Color.green : Color.secondary)

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
        .scrollContentBackground(.hidden)
        .background(hintergrundFarbe.ignoresSafeArea())
        .navigationTitle("Zugriff im Notfall")
        .tint(akzentFarbe)
        .fullScreenCover(isPresented: $einladungsSimulationStarten) {
            EinladungAngenommen(
                einladenderName: vorsorgendePersonName,
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
        .formStyle(.grouped)
    }

    private var cardHintergrund: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(kartenFarbe)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private func sectionTitel(_ titel: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(akzentFarbe)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(akzentFarbe.opacity(0.10))
                )

            Text(titel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(textFarbe)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private func markiereEinladungImTestAlsAngenommen() {
        guard let zugriff = aktuellerDossierZugriff else {
            fehlermeldung = "Es wurde kein passender Dossierzugriff gefunden."
            erfolgsmeldung = ""
            return
        }

        let testUserID = UUID()
        zugriff.einladungAnnehmen(
            vertrauenspersonUserID: testUserID,
            registrierungsEmail: zugriff.eingeladeneEmail
        )

        einladungsStatus = .angenommen
        fehlermeldung = ""
        erfolgsmeldung = "Einladung wurde im Test als angenommen markiert."

        do {
            try modelContext.save()
        } catch {
            fehlermeldung = "Die angenommene Einladung konnte nicht gespeichert werden."
            erfolgsmeldung = ""
        }
    }

    private func gebeZugriffImTestFrei() {
        guard let zugriff = aktuellerDossierZugriff else {
            fehlermeldung = "Es wurde kein passender Dossierzugriff gefunden."
            erfolgsmeldung = ""
            return
        }

        zugriff.zugriffFreigeben()
        vorsorgeprozessStatus = .gestartet
        fehlermeldung = ""
        erfolgsmeldung = "Zugriff wurde im Test freigegeben."

        do {
            try modelContext.save()
        } catch {
            fehlermeldung = "Die Freigabe konnte nicht gespeichert werden."
            erfolgsmeldung = ""
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

        let zugriff = dossierZugriffService.erstelleEinladung(
            dossierID: dossierID,
            vorsorgendeUserID: vorsorgendeUserID,
            eingeladeneEmail: empfaengerEmail,
            eingeladenePersonName: bereinigterEmpfaengerName
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
        simulierterEinladungsLink = dossierZugriffService.registrierungsLink(fuer: zugriff)

        speichereVertrauensperson()
    }

    private func einladungPerMailVorbereiten() {
        fehlermeldung = ""
        erfolgsmeldung = ""

        let empfaengerEmail = bereinigteEmail

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

        let anredeName = bereinigterEmpfaengerName.isEmpty ? "" : " \(bereinigterEmpfaengerName)"

        let betreff = "Einladung als Vertrauensperson"
        let nachricht = """
        Hallo\(anredeName)

        Ich möchte dich als Vertrauensperson in meiner Vorsorge-App hinterlegen.

        Diese Einladung wurde von \(vorsorgendePersonName) erstellt.

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

        vertrauensperson.kontaktangabenAktualisieren(
            vorname: vorname,
            name: name,
            email: email,
            telefon: telefon,
            beziehung: beziehung
        )
        vertrauensperson.einladungsStatus = einladungsStatus.rawValue
        vertrauensperson.vorsorgeprozessStatus = vorsorgeprozessStatus.rawValue
        vertrauensperson.einladungsToken = einladungsToken
        vertrauensperson.einladungsEmail = einladungsEmail
        vertrauensperson.einladungsLinkErstelltAm = einladungsLinkErstelltAm

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



#Preview("Vertrauensperson – Layout") {
    NavigationStack {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vertrauensperson einladen")
                        .font(.headline)

                    Text("Führe den Prozess Schritt für Schritt durch. Die App zeigt dir jeweils, was als Nächstes zu tun ist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("1. Kontakt ausgewählt", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        Label("2. Einladung vorbereitet", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        Label("3. Rückmeldung abwarten", systemImage: "circle")
                            .foregroundStyle(.primary)
                    }
                    .font(.footnote)

                    Text("Die Einladung ist bereit. Sende die E-Mail oder teste den Link im Testbereich.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Aktuelle Zugriffe") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.title3)
                            .foregroundStyle(Color.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max Muster")
                                .font(.headline)

                            Text("max.muster@example.com")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Eingeladen")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Einladung gültig bis 31.07.2026, 10:00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Schritt 1: Vertrauensperson auswählen") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Max Muster")
                        .font(.headline)

                    Text("max.muster@example.com")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("+41 79 000 00 00")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Label("Kontakt ändern", systemImage: "person.crop.circle.badge.plus")
            }

            Section("Schritt 2: Einladung vorbereiten") {
                Label("Einladung erneut in Mail öffnen", systemImage: "envelope.fill")

                Text("Die Einladung wurde vorbereitet. Du kannst die E-Mail in deiner Mail-App prüfen und senden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Vertrauensperson")
    }
}


