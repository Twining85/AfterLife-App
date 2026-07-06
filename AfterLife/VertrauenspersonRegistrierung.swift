//
//  VertrauenspersonRegistrierung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct VertrauenspersonRegistrierung: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteDossierZugriffe: [DossierZugriffModell]

    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""

    let eingeladeneEmail: String
    let einladungsToken: String

    @State private var email = ""
    @State private var passwort = ""
    @State private var fehlermeldung = ""
    @State private var showHome = false
    @State private var showEinladungEmailVerifizierung = false
    @State private var bestaetigungEmailAenderungAnzeigen = false
    @State private var pendingRegistrierungsArt = "E-Mail"
    @State private var pendingRegistrierungsEmail = ""
    @State private var pendingPasswort = ""

    @State private var akzeptiertDisclaimer = false
    @State private var captchaAntwort = ""
    @State private var captchaZahl1 = Int.random(in: 2...9)
    @State private var captchaZahl2 = Int.random(in: 2...9)
    @State private var passwortAnzeigen = false
    @State private var emailValidierungWurdeAusgeloest = false
    @State private var emailVerifiziert = false
    @State private var emailVerifizierungsCodeWurdeGesendet = false
    @State private var emailVerifizierungsCode = ""
    @State private var emailVerifizierungsAntwort = ""

    private let hintergrundFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let kartenFarbe = Color.white.opacity(0.88)
    private let akzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let akzentHell = Color(red: 0.16, green: 0.36, blue: 0.42).opacity(0.12)
    private let textFarbe = Color.black.opacity(0.86)
    private let sekundTextFarbe = Color.black.opacity(0.58)

    var body: some View {
        NavigationStack {
            ZStack {
                hintergrundFarbe
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroBild

                        VStack(spacing: 16) {
                            kopfBereich
                            zugangKarte

                            if emailWarnungSollAngezeigtWerden {
                                emailWarnungKarte
                            }

                            hinweisKarte
                            captchaKarte

                            if !fehlermeldung.isEmpty {
                                warnHinweis(text: fehlermeldung)
                            }

                            registrierungsButton
                            fussHinweis
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(kartenFarbe)
                                .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.75), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationDestination(isPresented: $showHome) {
                Home()
            }
            .navigationDestination(isPresented: $showEinladungEmailVerifizierung) {
                EinladungEmailVerifizierung(
                    eingeladeneEmail: eingeladeneEmail,
                    einladungsToken: einladungsToken
                )
            }
            .alert("E-Mail-Adresse ändern?", isPresented: $bestaetigungEmailAenderungAnzeigen) {
                Button("Abbrechen", role: .cancel) {
                    pendingRegistrierungsArt = "E-Mail"
                    pendingRegistrierungsEmail = ""
                    pendingPasswort = ""
                }

                Button("Ja, E-Mail verifizieren") {
                    registrierungAbschliessen(
                        art: pendingRegistrierungsArt,
                        email: pendingRegistrierungsEmail,
                        passwort: pendingPasswort,
                        benoetigtEinladungsVerifizierung: true
                    )
                }
            } message: {
                Text("Du wurdest über \(eingeladeneEmail) als Vertrauensperson eingeladen. Du möchtest dein Profil mit einer anderen E-Mail-Adresse registrieren. Damit wir sicherstellen können, dass die Einladung tatsächlich für dich bestimmt ist, musst du im nächsten Schritt bestätigen, dass du Zugriff auf die ursprünglich eingeladene E-Mail-Adresse hast.")
            }
            .navigationTitle("Einladung")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if email.isEmpty {
                    email = eingeladeneEmail
                }
            }
        }
    }

    private var heroBild: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(kartenFarbe)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)

            Image("Home2")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.01),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )

            Image("Icon1_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
        }
        .frame(height: 150)
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
    }

    private var kopfBereich: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(akzentHell)
                    .frame(width: 58, height: 58)

                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(akzentFarbe)
            }

            VStack(spacing: 6) {
                Text("Zugang als Vertrauensperson erstellen")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(textFarbe)
                    .multilineTextAlignment(.center)

                Text("Erstelle dein persönliches Tschlüssli-Profil. Damit erhältst du ein eigenes Dossier und kannst zusätzlich auf das freigegebene Dossier zugreifen.")
                    .font(.subheadline)
                    .foregroundStyle(sekundTextFarbe)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }


    private var zugangKarte: some View {
        VStack(spacing: 14) {
            eingabeFeld(
                titel: "E-Mail",
                systemImage: "envelope.fill",
                platzhalter: "deine.email@beispiel.ch",
                text: $email,
                tastatur: .emailAddress,
                istSicher: false
            )

            passwortFeld
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private var passwortFeld: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Passwort", systemImage: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(textFarbe)

            HStack(spacing: 10) {
                if passwortAnzeigen {
                    TextField("Mindestens 8 Zeichen", text: $passwort)
                } else {
                    SecureField("Mindestens 8 Zeichen", text: $passwort)
                }

                Button {
                    passwortAnzeigen.toggle()
                } label: {
                    Image(systemName: passwortAnzeigen ? "eye.slash" : "eye")
                        .foregroundStyle(akzentFarbe.opacity(0.85))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(eingabeHintergrund)
            .onChange(of: passwort) { _, neuerWert in
                emailValidierungWurdeAusgeloest = !neuerWert.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            Text("Mindestens 8 Zeichen.")
                .font(.caption2)
                .foregroundStyle(sekundTextFarbe)
        }
    }

    private var emailWarnungKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text("E-Mail stimmt nicht mit der Einladung überein")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)

                    Text("Die Einladung wurde ursprünglich an \(eingeladeneEmail) gesendet. Du kannst für die Registrierung eine andere E-Mail-Adresse verwenden. Aus Sicherheitsgründen musst du jedoch diese ursprünglich eingeladene E-Mail-Adresse verifizieren.")
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if emailVerifiziert {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(width: 24)

                    Text("Die eingeladene E-Mail-Adresse wurde verifiziert.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.green)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green.opacity(0.09))
                )
            } else if emailVerifizierungsCodeWurdeGesendet {
                VStack(alignment: .leading, spacing: 10) {
                    #if DEBUG
                    Text("Testcode: \(emailVerifizierungsCode)")
                        .font(.caption.monospaced())
                        .foregroundStyle(sekundTextFarbe)
                        .textSelection(.enabled)
                    #endif

                    TextField("6-stelliger Code", text: $emailVerifizierungsAntwort)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(eingabeHintergrund)

                    Button {
                        pruefeEingeladeneEmailCode()
                    } label: {
                        Text("Code bestätigen")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(akzentFarbe)
                    )
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    codeAnEingeladeneEmailSenden()
                } label: {
                    Text("Code an eingeladene E-Mail senden")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(emailVerifizierungButtonErlaubt ? akzentFarbe : Color.gray.opacity(0.42))
                )
                .buttonStyle(.plain)
                .disabled(!emailVerifizierungButtonErlaubt)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.20), lineWidth: 1)
        )
    }

    private var hinweisKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $akzeptiertDisclaimer) {
                Text("Ich habe den Hinweis gelesen und verstanden.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(textFarbe)
            }
            .tint(akzentFarbe)

            Text("Tschlüssli dient ausschliesslich der Organisation persönlicher Informationen und der Bereitstellung freigegebener Informationen. Die App ersetzt keine Rechts-, Steuer-, Finanz- oder Vorsorgeberatung und begründet keine automatische Vertretungsbefugnis. Die Nutzung erfolgt in eigener Verantwortung.")
                .font(.caption)
                .foregroundStyle(sekundTextFarbe)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private var captchaKarte: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verifizierung, ich bin ein Mensch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(textFarbe)

            HStack(spacing: 12) {
                Text("Was ist \(captchaZahl1) + \(captchaZahl2)?")
                    .font(.caption)
                    .foregroundStyle(sekundTextFarbe)

                TextField("Antwort", text: $captchaAntwort)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(eingabeHintergrund)
                    .frame(width: 110)
            }

            if !captchaAntwort.isEmpty && !captchaIstGueltig {
                Text("Die Antwort ist nicht korrekt.")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hintergrundFarbe.opacity(0.72))
        )
    }

    private var registrierungsButton: some View {
        Button {
            registrierenMitEmail()
        } label: {
            Text("Einladung annehmen und Profil erstellen")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(emailRegistrierungErlaubt ? akzentFarbe : Color.gray.opacity(0.42))
        )
        .buttonStyle(.plain)
        .disabled(!emailRegistrierungErlaubt)
    }


    private var fussHinweis: some View {
        Text("Du erstellst ein eigenes persönliches Dossier und nimmst zusätzlich die Einladung als Vertrauensperson an.")
            .font(.caption)
            .foregroundStyle(sekundTextFarbe)
            .multilineTextAlignment(.center)
            .lineSpacing(1)
    }

    private var emailWarnungSollAngezeigtWerden: Bool {
        emailValidierungWurdeAusgeloest && emailWurdeGeaendert
    }

    private var emailVerifizierungButtonErlaubt: Bool {
        registrierungsEmailIstFormalGueltig &&
        passwort.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }

    private var emailVerifizierungErfuellt: Bool {
        !emailWurdeGeaendert || emailVerifiziert
    }

    private var basisRegistrierungErlaubt: Bool {
        akzeptiertDisclaimer && captchaIstGueltig
    }

    private var emailRegistrierungErlaubt: Bool {
        basisRegistrierungErlaubt &&
        emailVerifizierungErfuellt &&
        registrierungsEmailIstFormalGueltig &&
        passwort.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }

    private var captchaIstGueltig: Bool {
        Int(captchaAntwort.trimmingCharacters(in: .whitespacesAndNewlines)) == captchaZahl1 + captchaZahl2
    }

    private var emailWurdeGeaendert: Bool {
        !bereinigteEmail.isEmpty && bereinigteEmail != eingeladeneEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var bereinigteEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var bereinigteEmailOriginalschreibweise: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var registrierungsEmailIstFormalGueltig: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return bereinigteEmailOriginalschreibweise.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func codeAnEingeladeneEmailSenden() {
        fehlermeldung = ""
        emailValidierungWurdeAusgeloest = true

        guard registrierungsEmailIstFormalGueltig else {
            fehlermeldung = "Bitte gib zuerst eine gültige E-Mail-Adresse ein."
            return
        }

        guard passwort.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else {
            fehlermeldung = "Bitte gib zuerst ein Passwort mit mindestens 8 Zeichen ein."
            return
        }

        emailVerifizierungsCode = String(Int.random(in: 100000...999999))
        emailVerifizierungsAntwort = ""
        emailVerifizierungsCodeWurdeGesendet = true
    }

    private func pruefeEingeladeneEmailCode() {
        guard emailVerifizierungsAntwort.trimmingCharacters(in: .whitespacesAndNewlines) == emailVerifizierungsCode else {
            fehlermeldung = "Der Verifizierungscode ist nicht korrekt."
            return
        }

        emailVerifiziert = true
        fehlermeldung = ""
    }

    private func registrierenMitEmail() {
        fehlermeldung = ""
        emailValidierungWurdeAusgeloest = true

        guard akzeptiertDisclaimer else {
            fehlermeldung = "Bitte akzeptiere zuerst den Hinweis."
            return
        }

        guard captchaIstGueltig else {
            fehlermeldung = "Bitte löse das Captcha korrekt."
            captchaNeuLaden()
            return
        }

        guard registrierungsEmailIstFormalGueltig else {
            fehlermeldung = "Bitte gib eine gültige E-Mail-Adresse ein."
            return
        }

        guard passwort.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else {
            fehlermeldung = "Das Passwort muss mindestens 8 Zeichen lang sein."
            return
        }

        guard emailVerifizierungErfuellt else {
            fehlermeldung = "Bitte verifiziere zuerst die ursprünglich eingeladene E-Mail-Adresse."
            return
        }

        vorbereitenUndAbschliessen(
            art: "E-Mail",
            email: bereinigteEmailOriginalschreibweise,
            passwort: passwort
        )
    }


    private func vorbereitenUndAbschliessen(art: String, email: String, passwort: String) {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !bereinigteEmail.isEmpty else {
            fehlermeldung = "Bitte gib eine gültige E-Mail-Adresse ein."
            return
        }

        if bereinigteEmail.lowercased() == eingeladeneEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() || emailVerifiziert {
            registrierungAbschliessen(
                art: art,
                email: bereinigteEmail,
                passwort: passwort,
                benoetigtEinladungsVerifizierung: false
            )
        } else {
            pendingRegistrierungsArt = art
            pendingRegistrierungsEmail = bereinigteEmail
            pendingPasswort = passwort
            bestaetigungEmailAenderungAnzeigen = true
        }
    }

    private func registrierungAbschliessen(art: String, email: String, passwort: String, benoetigtEinladungsVerifizierung: Bool) {
        do {
            if art == "E-Mail" {
                try KeychainHelper.shared.save(
                    passwort,
                    service: "AfterLife.Login",
                    account: email
                )
            }

            gespeicherteEmail = email
            gespeichertesPasswort = art == "E-Mail" ? passwort : ""
            registrierungsArt = art

            speichereRegistrierungsdaten(
                art: art,
                email: email,
                einladungDirektAnnehmen: !benoetigtEinladungsVerifizierung
            )

            try modelContext.save()

            direktNachRegistrierungEingeloggt = true
            profilIstVorhanden = true

            if benoetigtEinladungsVerifizierung {
                showEinladungEmailVerifizierung = true
            } else {
                showHome = true
            }
        } catch {
            fehlermeldung = "Das Passwort konnte nicht sicher gespeichert werden. Bitte versuche es erneut."
        }
    }

    private func speichereRegistrierungsdaten(art: String, email: String, einladungDirektAnnehmen: Bool) {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let profil = ProfilModell()
        modelContext.insert(profil)

        profil.registrierungsart = art
        profil.registrierungsEmail = bereinigteEmail
        profil.email = bereinigteEmail
        profil.istVertrauensperson = true

        if einladungDirektAnnehmen, let zugriff = gespeicherterDossierZugriff() {
            zugriff.einladungAnnehmen(
                vertrauenspersonUserID: profil.userID,
                registrierungsEmail: bereinigteEmail
            )
        }

        erstelleDossierFallsNoetig(fuer: profil, email: bereinigteEmail)
        aktiveUserID = profil.userID.uuidString
        direktNachRegistrierungEingeloggt = true
        gespeicherteEmail = bereinigteEmail
        registrierungsArt = art

    }

    private func gespeicherterDossierZugriff() -> DossierZugriffModell? {
        gespeicherteDossierZugriffe.first {
            $0.einladungsToken == einladungsToken
        }
    }

    private func erstelleDossierFallsNoetig(fuer profil: ProfilModell, email: String) {
        if let vorhandeneDossierID = profil.dossierID {
            aktivesDossierID = vorhandeneDossierID.uuidString
            return
        }

        let titelName = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let neuesDossier = DossierModell(
            besitzerUserID: profil.userID,
            vorsorgendePersonName: titelName.isEmpty ? "mir" : titelName
        )

        modelContext.insert(neuesDossier)
        profil.dossierID = neuesDossier.dossierID
        aktivesDossierID = neuesDossier.dossierID.uuidString
    }


    private func captchaNeuLaden() {
        captchaAntwort = ""
        captchaZahl1 = Int.random(in: 2...9)
        captchaZahl2 = Int.random(in: 2...9)
    }


    private func eingabeFeld(
        titel: String,
        systemImage: String,
        platzhalter: String,
        text: Binding<String>,
        tastatur: UIKeyboardType,
        istSicher: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(titel, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(textFarbe)

            if istSicher {
                SecureField(platzhalter, text: text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(eingabeHintergrund)
                    .keyboardType(tastatur)
            } else {
                TextField(platzhalter, text: text)
                    .keyboardType(tastatur)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(eingabeHintergrund)
            }
        }
    }

    private var eingabeHintergrund: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(akzentFarbe.opacity(0.18), lineWidth: 1)
            )
    }

    private func warnHinweis(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(width: 24)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.red.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.20), lineWidth: 1)
        )
    }
}

#Preview {
    VertrauenspersonRegistrierung(
        eingeladeneEmail: "vertrauensperson@mail.ch",
        einladungsToken: "test-token-123"
    )
    .modelContainer(
        for: [
            ProfilModell.self,
            DossierModell.self,
            DossierZugriffModell.self
        ],
        inMemory: true
    )
}
