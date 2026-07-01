import SwiftUI
import SwiftData

struct Home: View {
    private let kachelFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let schluessliAkzent = Color(red: 0.16, green: 0.36, blue: 0.42)
    // TEST: später durch echte Beziehungen aus dem Einladungs-/VertrauenspersonModell ersetzen
    private let verknuepfteVorsorgedossiers = ["René Engeler"]
    @State private var kachelnSindSichtbar = false
    @State private var vorsorgedossierAuswahlAnzeigen = false
    @State private var direktesVorsorgedossierOeffnen = false
    @State private var ausgewaehltesVorsorgedossier = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    Text("Willkommen")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 8)


                    NavigationLink {
                        ProfilView()
                    } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(schluessliAkzent.opacity(0.14))
                                        .frame(width: 56, height: 56)

                                    Image(systemName: "heart.text.square.fill")
                                        .font(.system(size: 27, weight: .semibold))
                                        .foregroundStyle(schluessliAkzent)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Schön, dass du vorsorgst.")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                                    Text("Deine wichtigsten Bereiche sind hier gesammelt. Du kannst dein Dossier jederzeit ergänzen und Schritt für Schritt vervollständigen.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            HStack(spacing: 8) {
                                Text("Weiter am Dossier")
                                    .font(.headline.weight(.semibold))

                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(schluessliAkzent)
                            .clipShape(Capsule())
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color(red: 0.98, green: 0.97, blue: 0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.78), lineWidth: 1)
                        )
                        .shadow(color: schluessliAkzent.opacity(0.13), radius: 18, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            HomeInfoChip(
                                icon: "shield.checkered",
                                titel: "Sicher gespeichert"
                            )

                            HomeInfoChip(
                                icon: "lock.fill",
                                titel: "Privat"
                            )

                            HomeInfoChip(
                                icon: "icloud.fill",
                                titel: "Jederzeit verfügbar"
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 16)


                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bereiche")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))

                        Text("Wähle einen Bereich aus, um deine Angaben zu ergänzen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                    alleKacheln
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                                kachelnSindSichtbar = true
                            }
                        }
                        .offset(y: kachelnSindSichtbar ? 0 : 20)
                        .opacity(kachelnSindSichtbar ? 1 : 0)

                    if !verknuepfteVorsorgedossiers.isEmpty {
                        vorsorgedossierWechselAktion
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                            .offset(y: kachelnSindSichtbar ? 0 : 20)
                            .opacity(kachelnSindSichtbar ? 1 : 0)
                    }

#if DEBUG
                    HomeDebugTestPanel()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
#endif
                }
            }
            .background(Color(.systemBackground))
            .navigationDestination(isPresented: $direktesVorsorgedossierOeffnen) {
                VorsorgedossierPlatzhalter(name: ausgewaehltesVorsorgedossier)
            }
            .confirmationDialog(
                "Vorsorgedossier auswählen",
                isPresented: $vorsorgedossierAuswahlAnzeigen,
                titleVisibility: .visible
            ) {
                ForEach(verknuepfteVorsorgedossiers, id: \.self) { name in
                    Button(name) {
                        ausgewaehltesVorsorgedossier = name
                        direktesVorsorgedossierOeffnen = true
                    }
                }

                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Wähle aus, welches Vorsorgedossier du öffnen möchtest.")
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    private var vorsorgedossierWechselAktion: some View {
        HStack {
            Spacer()

            Button {
                vorsorgedossierWechseln()
            } label: {
                HStack(spacing: 8) {
                    Text("Zum Vorsorgedossier wechseln")
                        .font(.footnote.weight(.semibold))

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
    }

    private func vorsorgedossierWechseln() {
        guard !verknuepfteVorsorgedossiers.isEmpty else { return }

        if verknuepfteVorsorgedossiers.count == 1 {
            ausgewaehltesVorsorgedossier = verknuepfteVorsorgedossiers[0]
            direktesVorsorgedossierOeffnen = true
        } else {
            vorsorgedossierAuswahlAnzeigen = true
        }
    }

    private var alleKacheln: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ],
            spacing: 20
        ) {
            NavigationLink {
                ProfilView()
            } label: {
                HomeKachel(
                    icon: "person.fill",
                    titel: "Mein Profil",
                    untertitel: "Persönliche Angaben",
                    details: "Kontaktdaten und Einstellungen, Vertrauensperson verwalten",
                    farbe: kachelFarbe,
                    akzentFarbe: schluessliAkzent
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WuenscheView()
            } label: {
                HomeKachel(
                    icon: "sparkles",
                    titel: "Meine Wünsche",
                    untertitel: "Was dir wichtig ist",
                    details: "Testament und persönliche Wünsche festhalten",
                    farbe: kachelFarbe,
                    akzentFarbe: Color(red: 0.72, green: 0.42, blue: 0.28)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FinanzenView()
            } label: {
                HomeKachel(
                    icon: "dollarsign.circle.fill",
                    titel: "Finanzen",
                    untertitel: "Deine finanzielle Übersicht",
                    details: "Konten, Schulden und Wertsachen auflisten",
                    farbe: kachelFarbe,
                    akzentFarbe: Color(red: 0.62, green: 0.47, blue: 0.18)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                HinterbliebeneView()
            } label: {
                HomeKachel(
                    icon: "person.3.fill",
                    titel: "Hinterbliebene",
                    untertitel: "Menschen, die dir wichtig sind",
                    details: "Familie & Freunde als Kontakte hinterlegen",
                    farbe: kachelFarbe,
                    akzentFarbe: Color(red: 0.24, green: 0.50, blue: 0.34)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DokumenteView()
            } label: {
                HomeKachel(
                    icon: "folder.fill",
                    titel: "Dokumente & Fotoalbum",
                    untertitel: "Alles sicher abgelegt",
                    details: "Dokumente hochladen und Fotoalbum erstellen",
                    farbe: kachelFarbe,
                    akzentFarbe: Color(red: 0.22, green: 0.43, blue: 0.68)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AbosView()
            } label: {
                HomeKachel(
                    icon: "rectangle.stack.badge.person.crop.fill",
                    titel: "Abos & Profile",
                    untertitel: "Digitales Leben",
                    details: "Digitale Profile, Zugänge und Abos",
                    farbe: kachelFarbe,
                    akzentFarbe: Color(red: 0.46, green: 0.36, blue: 0.62)
                )
            }
            .buttonStyle(.plain)
        }
    }

    struct HomeKachel: View {
        let icon: String
        let titel: String
        let untertitel: String
        let details: String
        let farbe: Color
        let akzentFarbe: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(akzentFarbe.opacity(0.14))
                        .frame(width: 54, height: 54)

                    Image(systemName: icon)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(akzentFarbe)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(titel)
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.11))
                        .lineLimit(2)

                    Text(untertitel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 202)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(farbe.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: akzentFarbe.opacity(0.12), radius: 16, x: 0, y: 8)
        }
    }
}

struct HomeInfoChip: View {
    let icon: String
    let titel: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))

            Text(titel)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    Home()
}

struct VorsorgedossierPlatzhalter: View {
    let name: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.person.crop")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            Text("Vorsorgedossier")
                .font(.largeTitle.bold())

            Text(name)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Diese Ansicht wird später das freigegebene Dossier der vorsorgenden Person anzeigen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Vorsorgedossier")
    }
}


#if DEBUG
private struct HomeDebugTestPanel: View {
    @AppStorage("aktiveUserID") private var aktiveUserID = ""
    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("profilIstVorhanden") private var profilIstVorhanden = false
    @AppStorage("direktNachRegistrierungEingeloggt") private var direktNachRegistrierungEingeloggt = false

    @Query private var profile: [ProfilModell]
    @Query private var dossiers: [DossierModell]
    @Query private var dossierZugriffe: [DossierZugriffModell]

    private var aktivesProfil: ProfilModell? {
        guard let uuid = UUID(uuidString: aktiveUserID) else { return nil }
        return profile.first { $0.userID == uuid }
    }

    private var aktivesDossier: DossierModell? {
        if let profil = aktivesProfil {
            return dossiers.first { $0.dossierID == profil.dossierID }
        }

        return dossiers.first
    }

    var body: some View {
        GroupBox("🧪 Developer Testcenter") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktiver Benutzer")
                        .font(.headline)

                    Text("Profil vorhanden: \(profilIstVorhanden ? "Ja" : "Nein")")
                    Text("Direkt eingeloggt: \(direktNachRegistrierungEingeloggt ? "Ja" : "Nein")")
                    Text("E-Mail: \(gespeicherteEmail.isEmpty ? "-" : gespeicherteEmail)")
                    Text("User-ID: \(aktiveUserID.isEmpty ? "-" : aktiveUserID)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dossier")
                        .font(.headline)

                    if let aktivesDossier {
                        Text("Dossier-ID: \(aktivesDossier.dossierID.uuidString)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("Aktiv: \(aktivesDossier.istAktiv ? "Ja" : "Nein")")
                        Text("Freigegeben: \(aktivesDossier.istFreigegeben ? "Ja" : "Nein")")
                        Text("Schreibgeschützt: \(aktivesDossier.istSchreibgeschuetzt ? "Ja" : "Nein")")
                    } else {
                        Text("Kein Dossier gefunden.")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Einladungen")
                        .font(.headline)

                    if dossierZugriffe.isEmpty {
                        Text("Noch keine Einladungen vorhanden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dossierZugriffe) { zugriff in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(zugriff.eingeladeneEmail)
                                    .font(.subheadline.bold())

                                Text("Eingeladen an: \(zugriff.eingeladeneEmail)")

                                Text("Registriert mit: \((zugriff.registrierungsEmail?.isEmpty == false) ? (zugriff.registrierungsEmail ?? "-") : "-")")

                                if let registrierungsEmail = zugriff.registrierungsEmail,
                                   !registrierungsEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   registrierungsEmail.lowercased() != zugriff.eingeladeneEmail.lowercased() {
                                    Text("Hinweis: Registrierung erfolgte mit abweichender E-Mail-Adresse.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }

                                Text("Token: \(zugriff.einladungsToken ?? "-")")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)

                                Text("Einladungslink: \(zugriff.kannRegistrierungFortsetzen ? "Noch verwendbar" : "Bereits verwendet")")
                                    .foregroundStyle(zugriff.kannRegistrierungFortsetzen ? .green : .orange)

                                Text("Status: \(zugriff.status)")
                                Text("Aktiv: \(zugriff.istAktiv ? "Ja" : "Nein")")
                                Text("Link verwendet: \(zugriff.einladungsLinkVerwendet ? "Ja" : "Nein")")

                                if let gueltigBis = zugriff.einladungGueltigBis {
                                    Text("Gültig bis: \(gueltigBis.formatted(date: .abbreviated, time: .shortened))")
                                }

                                if let verwendetAm = zugriff.einladungsLinkVerwendetAm {
                                    Text("Verwendet am: \(verwendetAm.formatted(date: .abbreviated, time: .shortened))")
                                }

                                if let userID = zugriff.vertrauenspersonUserID {
                                    Text("Vertrauensperson-ID: \(userID.uuidString)")
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 4)

                            Divider()
                        }
                    }
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
