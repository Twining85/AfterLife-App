import SwiftUI

import PhotosUI
import UIKit

struct ProfilView: View {

    @AppStorage("gespeicherteEmail") private var gespeicherteEmail = ""
    @AppStorage("gespeichertesPasswort") private var gespeichertesPasswort = ""
    @AppStorage("registrierungsArt") private var registrierungsArt = "E-Mail"

    @State private var vorname = ""

    @State private var name = ""

    @State private var geburtsdatum = Calendar.current.date(from: DateComponents(year: 1978, month: 6, day: 1)) ?? Date()

    @State private var adresse = ""

    @State private var land = "Schweiz"

    private let laender = [
        "Schweiz",
        "Deutschland",
        "Österreich",
        "Liechtenstein",
        "Frankreich",
        "Italien",
        "Spanien",
        "Portugal",
        "Niederlande",
        "Belgien",
        "Luxemburg",
        "Vereinigtes Königreich",
        "Irland",
        "USA",
        "Kanada",
        "Australien",
        "Neuseeland",
        "Andere"
    ]

    @State private var telefon = ""

    @State private var email = ""

    @State private var profilbildAuswahl: PhotosPickerItem?

    @AppStorage("profilbildData") private var profilbildData: Data?

    @State private var showLogout = false

    @State private var showDeleted = false

    @State private var profilLoeschenBestaetigen = false

    @State private var dossierPDF: ExportiertesDossier?



    private var istEmailGueltig: Bool {

        if email.isEmpty { return true }

        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        return email.range(of: emailRegex, options: .regularExpression) != nil

    }

    var body: some View {

        NavigationStack {

            Form {

                Section {

                    VStack(spacing: 16) {

                        if let profilbildData,

                           let uiImage = UIImage(data: profilbildData) {

                            Image(uiImage: uiImage)

                                .resizable()

                                .scaledToFill()

                                .frame(width: 90, height: 90)

                                .clipShape(Circle())

                        } else {

                            Image(systemName: "person.crop.circle.fill")

                                .resizable()

                                .scaledToFit()

                                .frame(width: 90, height: 90)

                                .foregroundStyle(Color.gray.opacity(0.45))

                        }

                        PhotosPicker(

                            selection: $profilbildAuswahl,

                            matching: .images,

                            photoLibrary: .shared()

                        ) {

                            Text(profilbildData == nil ? "Profilbild auswählen" : "Profilbild ändern")

                                .font(.headline)

                        }

                    }

                    .frame(maxWidth: .infinity)

                    .padding(.vertical, 12)

                    .listRowInsets(EdgeInsets())

                    .listRowBackground(Color.clear)

                }

                Section("Persönliche Angaben") {

                    TextField("Vorname", text: $vorname)

                        .textContentType(.name)
                    
                    TextField("Name", text: $name)

                        .textContentType(.name)

                    DatePicker(

                        "Geburtsdatum",

                        selection: $geburtsdatum,

                        displayedComponents: .date

                    )

                    .environment(\.locale, Locale(identifier: "de_CH"))

                    TextField("Adresse", text: $adresse, axis: .vertical)

                        .textContentType(.fullStreetAddress)

                        .lineLimit(2...4)

                    Picker("Land", selection: $land) {
                        ForEach(laender, id: \.self) { land in
                            Text(land).tag(land)
                        }
                    }

                    TextField("Telefon", text: $telefon)

                        .keyboardType(.phonePad)

                        .textContentType(.telephoneNumber)

                    VStack(alignment: .leading, spacing: 6) {

                        TextField("E-Mail", text: $email)

                            .keyboardType(.emailAddress)

                            .textInputAutocapitalization(.never)

                            .autocorrectionDisabled()

                            .textContentType(.emailAddress)

                        if !istEmailGueltig {

                            Text("Bitte gib eine gültige E-Mail-Adresse ein.")

                                .font(.footnote)

                                .foregroundStyle(.red)

                        }

                    }

                }

                Section("Zugriff im Notfall") {

                    Button {

                        // Platzhalter: Funktion wird später ergänzt

                    } label: {

                        Label("Vertrauensperson Zugriff geben", systemImage: "person.badge.key.fill")

                    }

                    Text("Hier kannst du später einer Vertrauensperson Zugriff auf deine Daten geben, damit sie im Notfall abrufbar sind.")

                        .font(.footnote)

                        .foregroundStyle(.secondary)

                }
                Section("Dossier exportieren") {

                    Button {

                        if let url = erstelleDossierPDF() {

                            dossierPDF = ExportiertesDossier(url: url)

                        }

                    } label: {

                        Label("Dossier als PDF exportieren", systemImage: "doc.richtext.fill")

                    }

                    Text("Erzeugt ein PDF-Dossier mit den aktuell erfassten Informationen. Weitere Bereiche wie Wünsche, Finanzen, Dokumente sowie Abos & Profile können später ergänzt werden, sobald deren Daten zentral gespeichert sind.")

                        .font(.footnote)

                        .foregroundStyle(.secondary)

                }

                Section("Zugangsdaten") {

                    if registrierungsArt == "Google" {

                        LabeledContent("Registrierungsart", value: "Mit Google registriert")
                        LabeledContent("E-Mail-Adresse", value: gespeicherteEmail.isEmpty ? "Nicht erfasst" : gespeicherteEmail)

                    } else if registrierungsArt == "Apple" {

                        LabeledContent("Registrierungsart", value: "Mit Apple ID registriert")
                        LabeledContent("E-Mail-Adresse", value: gespeicherteEmail.isEmpty ? "Nicht erfasst" : gespeicherteEmail)

                    } else {

                        LabeledContent("Benutzername", value: gespeicherteEmail.isEmpty ? "Nicht erfasst" : gespeicherteEmail)
                        LabeledContent("Passwort", value: gespeichertesPasswort.isEmpty ? "Nicht erfasst" : gespeichertesPasswort)

                    }

                    Text("Diese Angaben stammen aus der Registrierung. Für eine produktive App sollten Passwörter nicht im Klartext gespeichert oder angezeigt werden, sondern sicher über die Keychain verwaltet werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                }
                Section {

                    Button {

                        showLogout = true

                    } label: {

                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")

                    }

                    Button(role: .destructive) {

                        profilLoeschenBestaetigen = true

                    } label: {

                        Label("Profil löschen", systemImage: "trash.fill")

                    }

                }

            }

            .navigationTitle("Mein Profil")

            .navigationDestination(isPresented: $showLogout) {

                Logout()

            }

            .navigationDestination(isPresented: $showDeleted) {

                Deleted()

            }

            .alert("Profil wirklich löschen?", isPresented: $profilLoeschenBestaetigen) {

                Button("Abbrechen", role: .cancel) { }

                Button("Ja, löschen", role: .destructive) {

                    profilLoeschen()

                    showDeleted = true

                }

            } message: {

                Text("Alle Daten werden unwiderruflich gelöscht.")

            }
            .sheet(item: $dossierPDF) { dossier in

                ShareSheet(activityItems: [dossier.url])

            }

            .onChange(of: profilbildAuswahl) { _, neueAuswahl in

                Task {

                    if let data = try? await neueAuswahl?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpegData = image.jpegData(compressionQuality: 0.85) {

                        profilbildData = jpegData

                    }

                }

            }

        }

    }

    private func profilLoeschen() {

        vorname = ""

        name = ""

        adresse = ""

        land = "Schweiz"

        telefon = ""

        email = ""

        profilbildData = nil

        profilbildAuswahl = nil

        geburtsdatum = Calendar.current.date(from: DateComponents(year: 1978, month: 6, day: 1)) ?? Date()

    }

    private func erstelleDossierPDF() -> URL? {

        let pdfMetaData = [

            kCGPDFContextCreator: "AfterLife",

            kCGPDFContextAuthor: "AfterLife App",

            kCGPDFContextTitle: "Persönliches Dossier"

        ]

        let format = UIGraphicsPDFRendererFormat()

        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 595.2

        let pageHeight = 841.8

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = "AfterLife_Dossier_\(Int(Date().timeIntervalSince1970)).pdf"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let dateFormatter = DateFormatter()

        dateFormatter.locale = Locale(identifier: "de_CH")

        dateFormatter.dateStyle = .long

        dateFormatter.timeStyle = .none

        do {

            try renderer.writePDF(to: url) { context in

                context.beginPage()

                var yPosition: CGFloat = 48

                func drawProfileImageIfAvailable() {

                    guard let profilbildData,
                          let uiImage = UIImage(data: profilbildData) else {
                        return
                    }

                    let imageSize: CGFloat = 82
                    let imageRect = CGRect(x: pageWidth - imageSize - 48, y: 48, width: imageSize, height: imageSize)

                    context.cgContext.saveGState()

                    let circlePath = UIBezierPath(ovalIn: imageRect)
                    circlePath.addClip()

                    let imageAspect = uiImage.size.width / uiImage.size.height
                    let rectAspect = imageRect.width / imageRect.height

                    var drawRect = imageRect

                    if imageAspect > rectAspect {
                        let scaledWidth = imageRect.height * imageAspect
                        drawRect = CGRect(
                            x: imageRect.midX - scaledWidth / 2,
                            y: imageRect.minY,
                            width: scaledWidth,
                            height: imageRect.height
                        )
                    } else {
                        let scaledHeight = imageRect.width / imageAspect
                        drawRect = CGRect(
                            x: imageRect.minX,
                            y: imageRect.midY - scaledHeight / 2,
                            width: imageRect.width,
                            height: scaledHeight
                        )
                    }

                    uiImage.draw(in: drawRect)

                    context.cgContext.restoreGState()

                    context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
                    context.cgContext.setLineWidth(1)
                    context.cgContext.strokeEllipse(in: imageRect)
                }

                func drawText(_ text: String, font: UIFont = .systemFont(ofSize: 13), color: UIColor = .label, spacing: CGFloat = 24) {

                    let paragraphStyle = NSMutableParagraphStyle()

                    paragraphStyle.lineBreakMode = .byWordWrapping

                    let attributes: [NSAttributedString.Key: Any] = [

                        .font: font,

                        .foregroundColor: color,

                        .paragraphStyle: paragraphStyle

                    ]

                    let textRect = CGRect(x: 48, y: yPosition, width: pageWidth - 96, height: pageHeight - yPosition - 48)

                    let attributedText = NSAttributedString(string: text, attributes: attributes)

                    let boundingRect = attributedText.boundingRect(

                        with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),

                        options: [.usesLineFragmentOrigin, .usesFontLeading],

                        context: nil

                    )

                    attributedText.draw(in: CGRect(x: textRect.minX, y: textRect.minY, width: textRect.width, height: ceil(boundingRect.height)))

                    yPosition += ceil(boundingRect.height) + spacing

                }

                func drawSectionTitle(_ title: String) {

                    drawText(title, font: .boldSystemFont(ofSize: 18), spacing: 14)

                }

                func drawField(_ label: String, _ value: String) {

                    let cleanValue = value.isEmpty ? "Nicht erfasst" : value

                    drawText("\(label): \(cleanValue)", font: .systemFont(ofSize: 13), spacing: 10)

                }

                drawProfileImageIfAvailable()

                drawText("Persönliches AfterLife Dossier", font: .boldSystemFont(ofSize: 24), spacing: 12)

                drawText("Erstellt am \(dateFormatter.string(from: Date()))", font: .systemFont(ofSize: 12), color: .secondaryLabel, spacing: 28)

                drawSectionTitle("Persönliche Angaben")

                drawField("Vorname", vorname)

                drawField("Name", name)

                drawField("Geburtsdatum", dateFormatter.string(from: geburtsdatum))

                drawField("Adresse", adresse)

                drawField("Land", land)

                drawField("Telefon", telefon)

                drawField("E-Mail", email)

                yPosition += 14

                drawSectionTitle("Zugangsdaten")

                if registrierungsArt == "Google" {
                    drawField("Registrierungsart", "Mit Google registriert")
                    drawField("E-Mail-Adresse", gespeicherteEmail)
                } else if registrierungsArt == "Apple" {
                    drawField("Registrierungsart", "Mit Apple ID registriert")
                    drawField("E-Mail-Adresse", gespeicherteEmail)
                } else {
                    drawField("Benutzername", gespeicherteEmail)
                    drawField("Passwort", gespeichertesPasswort)
                }

                yPosition += 14

                drawSectionTitle("Weitere Bereiche")

                drawText("Wünsche, Finanzen, Dokumente sowie Abos & Profile werden hier ergänzt, sobald diese Daten zentral gespeichert und für den Export verfügbar sind.", font: .systemFont(ofSize: 13), color: .secondaryLabel, spacing: 10)

            }

            return url

        } catch {

            print("PDF konnte nicht erstellt werden: \(error.localizedDescription)")

            return nil

        }

    }

}

struct ExportiertesDossier: Identifiable {

    let id = UUID()

    let url: URL

}

struct ShareSheet: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {

        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)

    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }

}

#Preview {

    ProfilView()

}
