import SwiftUI
import SwiftData
import AVFoundation

struct EinladungQRCodeAnnehmenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var zugriffe: [DossierZugriffModell]
    @AppStorage("aktiveUserID") private var aktiveUserID = ""

    @State private var scannerAnzeigen = false
    @State private var meldung = ""
    @State private var warErfolgreich = false
    @State private var arbeitet = false

    private let akzent = Color(red: 0.16, green: 0.36, blue: 0.42)

    var body: some View {
        ZStack {
            Color(red: 0.985, green: 0.98, blue: 0.965).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: warErfolgreich ? "checkmark.shield.fill" : "qrcode.viewfinder")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(akzent)

                Text("Einladung QR-Code annehmen")
                    .font(.title2.bold())

                Text("Scanne den QR-Code der vorsorgenden Person. Die im Code geschützte E-Mail-Adresse wird mit deinem Profil verglichen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    scannerAnzeigen = true
                } label: {
                    Label("QR-Code scannen", systemImage: "camera.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(akzent)

                if !meldung.isEmpty {
                    VStack(spacing: 8) {
                        if warErfolgreich {
                            Text("Einladung erkannt")
                                .font(.headline)
                        }
                        Text(meldung)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(warErfolgreich ? akzent : .red)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(
                        (warErfolgreich ? akzent : Color.red).opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                }
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Einladung annehmen")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $scannerAnzeigen) {
            QRCodeScannerView { ergebnis in
                scannerAnzeigen = false
                verarbeiteScan(ergebnis)
            } abbruch: {
                scannerAnzeigen = false
            }
            .ignoresSafeArea()
        }
    }

    private func verarbeiteScan(_ text: String) {
        warErfolgreich = false
        guard let url = URL(string: text),
              let komponenten = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = komponenten.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value,
              !token.isEmpty else {
            meldung = "Dieser QR-Code enthält keine gültige Tschlüssli-Einladung."
            return
        }

        let qrEmail: String
        do {
            guard let entschluesselteEmail = try EinladungsQRPayload.email(aus: url, token: token) else {
                meldung = "Der QR-Code enthält keine geschützte E-Mail-Adresse. Bitte erstelle einen neuen QR-Code."
                return
            }
            qrEmail = entschluesselteEmail
        } catch {
            meldung = "Die Identitätsinformation des QR-Codes ist ungültig oder wurde verändert."
            return
        }

        guard !qrEmail.isEmpty else { return }
        guard UUID(uuidString: aktiveUserID) != nil else {
            meldung = "Dein angemeldetes Profil konnte nicht eindeutig bestimmt werden."
            return
        }
        Task {
            do {
                arbeitet = true
                let cloud = try await PushEinladungsService.shared.einladungPruefen(token: token)
                let zugriff: DossierZugriffModell
                if let vorhanden = zugriffe.first(where: {
                    ($0.einladungsToken ?? "").caseInsensitiveCompare(token) == .orderedSame
                }) {
                    zugriff = vorhanden
                } else {
                    zugriff = DossierZugriffModell(
                        einladungsToken: token,
                        eingeladeneEmail: cloud.invitedEmail,
                        einladungGueltigBis: cloud.expiresAt,
                        dossierID: cloud.dossierID,
                        vorsorgendeUserID: cloud.ownerUserID,
                        vorsorgendePersonName: cloud.ownerName,
                        vertrauenspersonUserID: UUID(uuidString: aktiveUserID),
                        status: DossierZugriffStatus.erstellt
                    )
                    modelContext.insert(zugriff)
                }
                zugriff.vertrauenspersonUserID = UUID(uuidString: aktiveUserID)
                zugriff.vorsorgendePersonName = cloud.ownerName
                zugriff.registrierungsEmail = cloud.invitedEmail
                if zugriff.status != DossierZugriffStatus.bestaetigungAusstehend,
                   zugriff.status != DossierZugriffStatus.angenommen,
                   zugriff.status != DossierZugriffStatus.freigegeben {
                    zugriff.status = DossierZugriffStatus.erstellt
                }
                zugriff.istAktiv = true
                try modelContext.save()
                
                warErfolgreich = true
                meldung = "Der Zugang wurde auf deinem Home-Screen abgelegt. Es wurden noch keine Dossierdaten geladen. Erst beim gewünschten Cloud-Download kannst du die Erlaubnis anfragen."
            } catch {
                meldung = error.localizedDescription
            }
            arbeitet = false
        }
    }

}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let ergebnis: (String) -> Void
    let abbruch: () -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.ergebnis = ergebnis
        controller.abbruch = abbruch
        return controller
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}
}

private final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var ergebnis: ((String) -> Void)?
    var abbruch: (() -> Void)?
    private let sitzung = AVCaptureSession()
    private var vorschau: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        konfiguriereScanner()

        let button = UIButton(type: .system)
        button.setTitle("Abbrechen", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.addTarget(self, action: #selector(abbrechen), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        vorschau?.frame = view.bounds
    }

    private func konfiguriereScanner() {
        guard let kamera = AVCaptureDevice.default(for: .video),
              let eingabe = try? AVCaptureDeviceInput(device: kamera),
              sitzung.canAddInput(eingabe) else { return }
        sitzung.addInput(eingabe)
        let ausgabe = AVCaptureMetadataOutput()
        guard sitzung.canAddOutput(ausgabe) else { return }
        sitzung.addOutput(ausgabe)
        ausgabe.setMetadataObjectsDelegate(self, queue: .main)
        ausgabe.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: sitzung)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        vorschau = layer
        DispatchQueue.global(qos: .userInitiated).async { [sitzung] in sitzung.startRunning() }
    }

    @objc private func abbrechen() {
        sitzung.stopRunning()
        abbruch?()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let objekt = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let wert = objekt.stringValue else { return }
        sitzung.stopRunning()
        ergebnis?(wert)
    }
}
