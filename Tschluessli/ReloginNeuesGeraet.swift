//
//  ReloginNeuesGeraet.swift
//  Tschluessli
//

import SwiftUI
import SwiftData

/// Anmeldung eines bestehenden Kontos auf einer neuen Installation.
/// Der vollständige Cloud-Inhalt wird erst nach dem Wiederherstellungsschlüssel freigegeben.
struct ReloginNeuesGeraet: View {
    let onAbbrechen: () -> Void
    let onWiederhergestellt: (CloudKontoSitzung, String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var sitzung: CloudKontoSitzung?
    @State private var angemeldeteEmail = ""
    @State private var wirdVorbereitet = false
    @State private var fehlermeldung = ""
    @State private var recoverySyncDienst: DossierSyncDienst?
    @State private var neuesDossierSitzung: CloudKontoSitzung?

    var body: some View {
        Group {
            if wirdVorbereitet {
                ZStack {
                    Color(red: 0.96, green: 0.95, blue: 0.92)
                        .ignoresSafeArea()

                    ProgressView("Sichere Wiederherstellung wird vorbereitet …")
                        .padding(24)
                }
            } else if let neueSitzung = neuesDossierSitzung {
                NavigationStack {
                    DossierRecoveryView(
                        nurErstellen: true,
                        onNeuerCodeBestaetigt: {
                            onWiederhergestellt(neueSitzung, angemeldeteEmail)
                        }
                    )
                    .toolbar { abbrechenSchaltflaeche }
                }
            } else if let sitzung {
                NavigationStack {
                    DossierRecoveryView(
                        nurWiederherstellen: true,
                        kontoEmail: angemeldeteEmail,
                        onDossierZurueckgesetzt: { neueDossierID in
                            let neueSitzung = CloudKontoSitzung(
                                userID: sitzung.userID,
                                dossierID: neueDossierID,
                                token: sitzung.token,
                                gueltigBis: sitzung.gueltigBis
                            )
                            UserDefaults.standard.set(neueDossierID.uuidString, forKey: "aktivesDossierID")
                            if recoverySyncDienst == nil {
                                recoverySyncDienst = try? DossierSyncDienst(modelContext: modelContext)
                            }
                            neuesDossierSitzung = neueSitzung
                        },
                        onDatenLaden: {
                            guard let dossierID = sitzung.dossierID else { return false }
                            do {
                                let syncDienst: DossierSyncDienst
                                if let vorhandenerDienst = DossierSyncDienst.shared {
                                    syncDienst = vorhandenerDienst
                                } else if let vorbereiteterDienst = recoverySyncDienst {
                                    syncDienst = vorbereiteterDienst
                                } else {
                                    let neuerDienst = try DossierSyncDienst(modelContext: modelContext)
                                    recoverySyncDienst = neuerDienst
                                    syncDienst = neuerDienst
                                }
                                return await syncDienst.dossierNachRecoveryNeuLaden(dossierID: dossierID)
                            } catch {
                                return false
                            }
                        },
                        onWiederhergestellt: {
                            onWiederhergestellt(sitzung, angemeldeteEmail)
                        }
                    )
                    .toolbar { abbrechenSchaltflaeche }
                }
            } else {
                ReloginView(
                    emailFuerBestehendesKonto: "",
                    onBestehendesKontoAngemeldet: loginErfolgreich
                )
                .toolbar { abbrechenSchaltflaeche }
            }
        }
        .alert("Wiederherstellung nicht möglich", isPresented: fehlermeldungIstSichtbar) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fehlermeldung)
        }
    }

    @ToolbarContentBuilder
    private var abbrechenSchaltflaeche: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Abbrechen", action: abbrechen)
        }
    }

    private var fehlermeldungIstSichtbar: Binding<Bool> {
        Binding(
            get: { !fehlermeldung.isEmpty },
            set: { if !$0 { fehlermeldung = "" } }
        )
    }

    private func loginErfolgreich(_ neueSitzung: CloudKontoSitzung, email: String) {
        guard let dossierID = neueSitzung.dossierID else {
            fehlermeldung = "Für dieses Konto konnte kein aktives Dossier geladen werden."
            return
        }

        wirdVorbereitet = true
        Task {
            do {
                guard let bereich = try await CloudDossierSyncService.shared.laden(
                    dossierID: dossierID,
                    bereich: "zugaenge"
                ) else {
                    throw DossierRecoveryFehler.keinRecoveryPaket
                }
                let verschluesselt = try JSONDecoder().decode(
                    VerschluesselterCloudBereich.self,
                    from: bereich.payload
                )
                try await CloudFeldVerschluesselung.shared.neueInstallationVorbereiten(
                    mit: verschluesselt
                )
                angemeldeteEmail = email
                sitzung = neueSitzung
                wirdVorbereitet = false
            } catch {
                await CloudKontoService.shared.lokaleSitzungLoeschen()
                wirdVorbereitet = false
                fehlermeldung = "Die sichere Wiederherstellung konnte nicht vorbereitet werden: \(error.localizedDescription)"
            }
        }
    }

    private func abbrechen() {
        Task { await CloudKontoService.shared.lokaleSitzungLoeschen() }
        sitzung = nil
        wirdVorbereitet = false
        onAbbrechen()
    }
}
