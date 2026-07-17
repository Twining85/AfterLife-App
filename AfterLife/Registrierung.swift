import SwiftUI
import SwiftData
import UIKit
import SafariServices

private struct RegistrierungsSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

struct Registrierung: View {
    private enum VorsorgeEmpfaenger: String, CaseIterable, Identifiable {
        case familie = "Für meine Familie"
        case partner = "Für meinen Partner oder meine Partnerin"
        case eltern = "Für meine Eltern"
        case anderePerson = "Für eine andere wichtige Person"
        case ich = "Für mich"

        var id: String { rawValue }
    }

    private enum Eingabefeld {
        case email
        case passwort
        case passwortWiederholung
        case captcha
    }


    private let registrierungHintergrund = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let registrierungAkzent = Color(red: 0.16, green: 0.36, blue: 0.42)
    private let registrierungKarte = Color.white.opacity(0.88)
    private let registrierungTextPrimaer = Color(red: 0.12, green: 0.12, blue: 0.11)
    private let onboardingBildHoehe: CGFloat = 550
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteProfile: [ProfilModell]
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false
    @AppStorage("istEingeloggt") private var istEingeloggt = false
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""
    @State private var registrierungsformularAnzeigen = false
    @State private var registrierungsformularIstSichtbar = false
    @State private var onboardingSeite = 0
    @State private var ausgewaehlterEmpfaenger: VorsorgeEmpfaenger?
    @State private var email = ""
    @State private var passwort = ""
    @State private var passwortWiederholung = ""
    @State private var passwortIstSichtbar = false
    @State private var fehlermeldung = ""
    @State private var homeVollbildAnzeigen = false
    @State private var akzeptiertDisclaimer = false
    @State private var akzeptiertNutzungsbedingungen = false
    @State private var rechtlichesAnzeigen = false
    @State private var captchaAntwort = ""
    @State private var captchaZahl1 = Int.random(in: 2...9)
    @State private var captchaZahl2 = Int.random(in: 2...9)
    
    @FocusState private var aktivesEingabefeld: Eingabefeld?

    var body: some View {
        ZStack {
            registrierungHintergrund
                .ignoresSafeArea()

            if onboardingSeite < 3 {
                onboardingInhalt
                    .transition(.opacity)
            } else {
                registrierungsInhalt
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: onboardingSeite)
        .sheet(isPresented: $rechtlichesAnzeigen) {
            RegistrierungsSafariView(url: URL(string: "https://tschluessli.ch")!)
                .ignoresSafeArea()
        }
    }

    private var registrierungsInhalt: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                headerBereich

                if registrierungsformularAnzeigen {
                    registrierungsformular
                        .opacity(registrierungsformularIstSichtbar ? 1 : 0)
                        .offset(y: registrierungsformularIstSichtbar ? 0 : 14)
                } else {
                    empfaengerAuswahl
                }

                logoFooter
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let istWischNachRechts = value.translation.width > 80
                    let istUeberwiegendHorizontal = abs(value.translation.width) > abs(value.translation.height)

                    if istWischNachRechts && istUeberwiegendHorizontal {
                        onboardingSeite = 2
                    }
                }
        )
    }
//SCREEN 1
    private var onboardingInhalt: some View {
        VStack(spacing: 0) {
            TabView(selection: $onboardingSeite) {
                onboardingSeiteView(
                    bild: "daniel-j-schwarz-YtY724tdl7Y-unsplash",
                    titel: "Alles Wichtige. An einem sicheren Ort.",
                    text: "Ob Wünsche, Dokumente, Online-Profile oder andere wichtige Informationen.\nMit Tschlüssli sorgst du dafür, dass Hinterbliebene im entscheidenden Moment wissen, was zu tun ist."
                )
                .tag(0)
//SCREEN 2
                onboardingSeiteView(
                    bild: "juan-cruz-mountford-AMFWArSckYM-unsplash_neu",
                    titel: "Vorsorge ist ein Geschenk für Alle.",
                    text: "Es geht um mehr als Geld. Wenn etwas passiert, müssen deine Angehörigen nicht suchen oder rätseln was zu tun ist.\nSie finden genau die Informationen, die du für sie hinterlassen möchtest."
                )
                .tag(1)

                auswahlSeite
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 18) {
                HStack(spacing: 9) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == onboardingSeite ? registrierungAkzent : registrierungAkzent.opacity(0.2))
                            .frame(width: index == onboardingSeite ? 9 : 7, height: index == onboardingSeite ? 9 : 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Fortschritt: Schritt \(onboardingSeite + 1) von 3")

                if onboardingSeite < 2 {
                    onboardingButton(titel: "Weiter") {
                        onboardingSeite += 1
                    }
                } else {
                    onboardingButton(titel: "Jetzt kostenlos starten") {
                        onboardingSeite = 3
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
    }

    private func onboardingSeiteView(bild: String, titel: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image("Icon1_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 58)
                .accessibilityLabel("Tschlüssli")

            onboardingBildMitText(
                bild: bild,
                titel: titel,
                text: text,
                titelgroesse: 30,
                hoehe: onboardingBildHoehe
            )
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
//SCREEN 3
    private var auswahlSeite: some View {
        onboardingSeiteView(
            bild: "bruno-van-der-kraan-ESvhyYKEafE-unsplash",
            //bild: "marvin-meyer-1d8bqq_Obls-unsplash",
            titel: "In Ruhe erstellt. Ein Leben lang wertvoll.",
            text: "Erstelle dein persönliches Vorsorgedossier.\nOder unterstütze deine Eltern dabei.\nHeute vorbereitet. Für morgen."
        )
    }

    private func onboardingBildMitText(
        bild: String,
        titel: String,
        text: String,
        titelgroesse: CGFloat,
        hoehe: CGFloat
    ) -> some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                Image(bild)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: hoehe)
                    .clipped()
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Text(titel)
                    .font(.system(size: titelgroesse, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .lineSpacing(3)
                        .foregroundStyle(.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                minHeight: text.isEmpty ? nil : 180,
                maxHeight: text.isEmpty ? nil : 180,
                alignment: .top
            )
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: hoehe)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
        .padding(.horizontal, 18)
    }

    private func onboardingButton(titel: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 9) {
                Text(titel)
                    .font(.body.weight(.semibold))

                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(registrierungAkzent)
            )
        }
        .buttonStyle(.plain)
    }

    private var headerBereich: some View {
        VStack(spacing: 12) {
            Image("Icon1_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 58)
                .accessibilityLabel("Tschlüssli")

            onboardingBildMitText(
                bild: "priscilla-du-preez-v_tSfR5M4As-unsplash",
                titel: "Für dich. Und für die Menschen, die dir wichtig sind.",
                text: "",
                titelgroesse: registrierungsformularAnzeigen ? 24 : 30,
                hoehe: registrierungsformularAnzeigen ? 230 : onboardingBildHoehe
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.horizontal, -22)
        .animation(.smooth(duration: 0.52), value: registrierungsformularAnzeigen)
    }

    private var registrierungsformular: some View {
        VStack(spacing: 18) {
            zugangKarte

            if !fehlermeldung.isEmpty {
                fehlermeldungBox
            }

            captchaKarte
            hinweisKarte
            registrierungsButtonBereich
            weitereAnmeldungHinweis
        }
    }

    private var empfaengerAuswahl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Für wen erstellst du in erster Linie dein Vorsorgedossier?")
                .font(.headline)
                .foregroundStyle(registrierungTextPrimaer)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(VorsorgeEmpfaenger.allCases) { empfaenger in
                Button {
                    ausgewaehlterEmpfaenger = empfaenger
                    aktivesEingabefeld = nil

                    withAnimation(.smooth(duration: 0.52)) {
                        registrierungsformularAnzeigen = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(.easeOut(duration: 0.30)) {
                            registrierungsformularIstSichtbar = true
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: ausgewaehlterEmpfaenger == empfaenger ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(registrierungAkzent)

                        Text(empfaenger.rawValue)
                            .foregroundStyle(registrierungTextPrimaer)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(registrierungKarte)
        )
        .transition(.opacity)
    }

    private var zugangKarte: some View {
        registrierungKarteView(titel: "Zugang erstellen", systemImage: "lock.shield.fill") {
            VStack(spacing: 14) {
                registrierungTextfeld(
                    titel: "E-Mail-Adresse",
                    systemImage: "envelope.fill",
                    platzhalter: "name@example.ch",
                    text: $email,
                    tastatur: .emailAddress,
                    fokus: .email
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit {
                    aktivesEingabefeld = .passwort
                }

                passwortFeld(
                    titel: "Passwort",
                    platzhalter: "Mindestens 8 Zeichen",
                    text: $passwort,
                    fokus: .passwort,
                    naechsterFokus: .passwortWiederholung,
                    augeAnzeigen: true
                )

                passwortFeld(
                    titel: "Passwort wiederholen",
                    platzhalter: "Passwort erneut eingeben",
                    text: $passwortWiederholung,
                    fokus: .passwortWiederholung,
                    naechsterFokus: .captcha,
                    augeAnzeigen: false
                )

                if passwortWiederholungIstUngueltig {
                    Text("Die Passwörter stimmen nicht überein.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Dein Passwort wird in deinem Profil gespeichert.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func passwortFeld(
        titel: String,
        platzhalter: String,
        text: Binding<String>,
        fokus: Eingabefeld,
        naechsterFokus: Eingabefeld,
        augeAnzeigen: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(registrierungTextPrimaer)

            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(registrierungAkzent)
                    .frame(width: 22)

                Group {
                    if passwortIstSichtbar {
                        TextField(platzhalter, text: text)
                    } else {
                        SecureField(platzhalter, text: text)
                    }
                }
                .focused($aktivesEingabefeld, equals: fokus)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit {
                    aktivesEingabefeld = naechsterFokus
                }

                if augeAnzeigen {
                    Button {
                        passwortIstSichtbar.toggle()
                    } label: {
                        Image(systemName: passwortIstSichtbar ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(registrierungAkzent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(passwortIstSichtbar ? "Passwort ausblenden" : "Passwort anzeigen")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(registrierungAkzent.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var fehlermeldungBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(fehlermeldung)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }



    private var hinweisKarte: some View {
        registrierungKarteView(titel: "Wichtiger Hinweis", systemImage: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 13) {
                Text("Tschlüssli dient ausschliesslich der Organisation persönlicher Informationen und ersetzt keine Rechts-, Steuer-, Finanz- oder Vorsorgeberatung sowie keine rechtsgültigen Dokumente wie Testamente, Erbverträge, Vorsorgeaufträge oder Patientenverfügungen. Die Nutzung erfolgt in eigener Verantwortung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $akzeptiertDisclaimer) {
                    Text("Ich habe den Hinweis gelesen und verstanden.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(registrierungTextPrimaer)
                }
                .tint(registrierungAkzent)

                Divider()

                HStack(spacing: 8) {
                    Button("Nutzungsbedingungen") {
                        rechtlichesAnzeigen = true
                    }
                    .buttonStyle(.plain)
                    .underline()
                    Text("und")
                        .foregroundStyle(.secondary)
                    Text("Datenschutz")
                        .underline()
                }
                .font(.caption)
                .foregroundStyle(registrierungAkzent)
                .accessibilityLabel("Nutzungsbedingungen öffnen und Datenschutz")

                Toggle(isOn: $akzeptiertNutzungsbedingungen) {
                    Text("Ich akzeptiere die Nutzungsbedingungen.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(registrierungTextPrimaer)
                }
                .tint(registrierungAkzent)
            }
        }
    }

    private var captchaKarte: some View {
        registrierungKarteView(titel: "Kurze Sicherheitsfrage", systemImage: "person.crop.circle.badge.checkmark") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Damit stellen wir sicher, dass die Registrierung bewusst erfolgt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text("Was ist \(captchaZahl1) + \(captchaZahl2)?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(registrierungTextPrimaer)

                    Spacer(minLength: 0)

                    TextField("Antwort", text: $captchaAntwort)
                        .keyboardType(.numberPad)
                        .focused($aktivesEingabefeld, equals: .captcha)
                        .multilineTextAlignment(.center)
                        .frame(width: 92)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(registrierungAkzent.opacity(0.12), lineWidth: 1)
                        )
                }

                if !captchaAntwort.isEmpty && !captchaIstGueltig {
                    Text("Die Antwort ist nicht korrekt.")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var registrierungsButtonBereich: some View {
        VStack(spacing: 8) {
            Button {
                registrierenMitEmail()
            } label: {
                Text("Persönliches Vorsorge-Dossier erstellen")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(registrierungErlaubt ? registrierungAkzent : Color.gray.opacity(0.42))
            )
            .buttonStyle(.plain)
            .disabled(!registrierungErlaubt)

            Text("Du kannst deine Angaben danach jederzeit ergänzen oder ändern.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !fehlermeldung.isEmpty {
                Text(fehlermeldung)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fullScreenCover(isPresented: $homeVollbildAnzeigen) {
            Home()
                .interactiveDismissDisabled()
        }
        .padding(.top, 2)
    }

    private var weitereAnmeldungHinweis: some View {
        Text("Apple- und Google-Anmeldung folgen in einer späteren Version.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private var logoFooter: some View {
        Group {
            if registrierungsformularAnzeigen {
                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                    .opacity(0.34)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private func registrierungKarteView<Content: View>(titel: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(registrierungAkzent)
                    .frame(width: 24)

                Text(titel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(registrierungTextPrimaer)

                Spacer(minLength: 0)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(registrierungKarte)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 7)
    }

    private func registrierungTextfeld(
        titel: String,
        systemImage: String,
        platzhalter: String,
        text: Binding<String>,
        tastatur: UIKeyboardType,
        fokus: Eingabefeld
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(registrierungTextPrimaer)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(registrierungAkzent)
                    .frame(width: 22)

                TextField(platzhalter, text: text)
                    .keyboardType(tastatur)
                    .focused($aktivesEingabefeld, equals: fokus)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(registrierungAkzent.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var registrierungErlaubt: Bool {
        akzeptiertDisclaimer &&
        akzeptiertNutzungsbedingungen &&
        captchaIstGueltig &&
        registrierungsEmailIstFormalGueltig &&
        bereinigtesPasswort.count >= 8 &&
        passwoerterStimmenUeberein
    }

    private var captchaIstGueltig: Bool {
        Int(captchaAntwort.trimmingCharacters(in: .whitespacesAndNewlines)) == captchaZahl1 + captchaZahl2
    }


    private var bereinigteRegistrierungsEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var bereinigteEmailOriginalschreibweise: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bereinigtesPasswort: String {
        passwort.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bereinigtePasswortWiederholung: String {
        passwortWiederholung.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var passwoerterStimmenUeberein: Bool {
        !bereinigtePasswortWiederholung.isEmpty &&
        bereinigtesPasswort == bereinigtePasswortWiederholung
    }

    private var passwortWiederholungIstUngueltig: Bool {
        !passwortWiederholung.isEmpty && !passwoerterStimmenUeberein
    }

    private var dossierZugriffService: DossierZugriffService {
        DossierZugriffService()
    }

    private var registrierungsEmailIstFormalGueltig: Bool {
        bereinigteRegistrierungsEmail.contains("@") && bereinigteRegistrierungsEmail.contains(".")
    }



    

    private func registrierenMitEmail() {
        fehlermeldung = ""

        guard akzeptiertDisclaimer else {
            fehlermeldung = "Bitte akzeptiere zuerst den Haftungsausschluss."
            return
        }

        guard akzeptiertNutzungsbedingungen else {
            fehlermeldung = "Bitte akzeptiere die Nutzungsbedingungen."
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

        guard bereinigtesPasswort.count >= 8 else {
            fehlermeldung = "Das Passwort muss mindestens 8 Zeichen lang sein."
            return
        }

        guard passwoerterStimmenUeberein else {
            fehlermeldung = "Die Passwörter stimmen nicht überein."
            return
        }


        let bereinigteEmail = bereinigteEmailOriginalschreibweise

        do {
            try KeychainHelper.shared.save(
                bereinigtesPasswort,
                service: "AfterLife.Login",
                account: bereinigteEmail
            )

            gespeicherteEmail = bereinigteEmail
            gespeichertesPasswort = bereinigtesPasswort
            registrierungsArt = "E-Mail"

            speichereRegistrierungsdaten(art: "E-Mail", email: bereinigteEmail)
            try modelContext.save()

            profilIstVorhanden = true
            direktNachRegistrierungEingeloggt = true
            istEingeloggt = true
            homeVollbildAnzeigen = true
        } catch {
            fehlermeldung = "Die Registrierung konnte nicht gespeichert werden: \(error.localizedDescription)"
            print("Registrierung fehlgeschlagen: \(error)")
        }
    }



    private func speichereRegistrierungsdaten(art: String, email: String) {
        let bereinigteEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let profil = ProfilModell()
        modelContext.insert(profil)

        profil.registrierungsart = art
        profil.registrierungsEmail = bereinigteEmail

        erstelleDossierFallsNoetig(fuer: profil, email: bereinigteEmail)
        aktiveUserID = profil.userID.uuidString
        direktNachRegistrierungEingeloggt = true
        gespeicherteEmail = bereinigteEmail
        registrierungsArt = art

        if profil.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profil.email = bereinigteEmail
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
}

#Preview {
    Registrierung()
        .modelContainer(for: [ProfilModell.self, DossierModell.self], inMemory: true)
}
