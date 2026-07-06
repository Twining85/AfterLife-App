import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLook
import PhotosUI
import UIKit
import PDFKit
import VisionKit

struct DokumenteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FotoalbumBildModell.reihenfolge) private var gespeicherteFotos: [FotoalbumBildModell]
    @Query private var gespeicherteWuensche: [WuenscheModell]
    @Query private var steuerdokumente: [SteuerdokumentModell]
    @Query(sort: \DokumenteModell.hochgeladenAm, order: .reverse) private var gespeicherteWeitereDokumente: [DokumenteModell]
    @State private var wuenscheDokumenteEingeklappt = true
    @State private var finanzenDokumenteEingeklappt = true
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoID: UUID?
    @State private var photoBundleURL: URL?
    @State private var showDocumentPicker = false
    @State private var selectedDocument: UploadedDocument?
    @State private var exportURL: URL?
    @State private var showDocumentScanner = false
    @State private var pendingScanData: Data?
    @State private var pendingScanDateiName = ""
    @State private var showDownloadSpeichernAbfrage = false

    private let dokumenteHintergrundFarbe = Color(red: 0.985, green: 0.975, blue: 0.955)
    private let dokumenteKartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let dokumenteAkzentFarbe = Color(red: 0.16, green: 0.36, blue: 0.42)

    var body: some View {
        NavigationStack {
            Form {
                wuenscheDokumenteSection
                finanzenDokumenteSection
                fotoalbumSection
                weitereDokumenteSection
            }
            .scrollContentBackground(.hidden)
            .background(dokumenteHintergrundFarbe)
            .tint(dokumenteAkzentFarbe)
            .navigationTitle("Dokumente")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportiereDokumenteUndOeffneVorschau()
                    } label: {
                        Image(systemName: "doc.richtext")
                            .foregroundStyle(dokumenteAkzentFarbe)
                    }
                    .disabled(alleExportierbarenDokumente.isEmpty)
                    .accessibilityLabel("Dokumente als PDF exportieren")
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { urls in
                    for url in urls {
                        let hatZugriffErhalten = url.startAccessingSecurityScopedResource()
                        defer {
                            if hatZugriffErhalten {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        if let dateiDaten = try? Data(contentsOf: url) {
                            let dokument = DokumenteModell(
                                dateiName: url.lastPathComponent,
                                kategorie: "Weitere Dokumente",
                                hochgeladenAm: Date(),
                                dateiDaten: dateiDaten
                            )
                            modelContext.insert(dokument)
                        }
                    }
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showDocumentScanner) {
                DocumentScanner { pdfData in
                    pendingScanDateiName = "Scan_\(Date().formatted(.dateTime.year().month().day().hour().minute())).pdf"
                    pendingScanData = pdfData
                    showDownloadSpeichernAbfrage = true
                }
            }
            .alert("Scan zusätzlich speichern?", isPresented: $showDownloadSpeichernAbfrage) {
                Button("Nein") {
                    speichereGescanntesDokument(sollInDownloadsSpeichern: false)
                }

                Button("Ja") {
                    speichereGescanntesDokument(sollInDownloadsSpeichern: true)
                }
            } message: {
                Text("Möchtest du den Scan zusätzlich ausserhalb der App speichern? In der App wird das Dokument in jedem Fall gespeichert. Bei Ja öffnet sich anschliessend das Speichern-Menü.")
            }
            .sheet(item: $selectedDocument) { document in
                DocumentPreview(url: document.fileURL)
            }
            .sheet(isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            )) {
                if let exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    await fotosAusMediathekLaden(newItems)
                }
            }
        }
    }

    private var wuenscheDokumenteSection: some View {
        Section {
            if !wuenscheDokumenteEingeklappt {
                dokumenteListe(wuenscheDokumente)
            }
        } header: {
            einklappHeader(
                titel: "Dokumente - Meine Wünsche",
                anzahl: wuenscheDokumente.count,
                eingeklappt: wuenscheDokumenteEingeklappt
            ) {
                withAnimation {
                    wuenscheDokumenteEingeklappt.toggle()
                }
            }
        }
        .listRowBackground(dokumenteKartenFarbe)
    }

    private var finanzenDokumenteSection: some View {
        Section {
            if !finanzenDokumenteEingeklappt {
                dokumenteListe(finanzDokumente)
            }
        } header: {
            einklappHeader(
                titel: "Dokumente - Finanzen",
                anzahl: finanzDokumente.count,
                eingeklappt: finanzenDokumenteEingeklappt
            ) {
                withAnimation {
                    finanzenDokumenteEingeklappt.toggle()
                }
            }
        }
        .listRowBackground(dokumenteKartenFarbe)
    }

    private var fotoalbumSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mein persönliches Fotoalbum")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Lade hier Fotos hoch, die für deine Vertrauenspersonen wichtig oder besonders wertvoll sind.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)

                if !gespeicherteFotos.isEmpty {
                    fotoalbumInhalt
                }

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Bild für Fotoalbum hochladen", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(dokumenteAkzentFarbe)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(dokumenteAkzentFarbe.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(dokumenteAkzentFarbe.opacity(0.12), lineWidth: 1)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .listRowBackground(Color.clear)
    }

    private var weitereDokumenteSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weitere Dokumente hochladen")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ergänze wichtige Unterlagen, die nicht direkt zu Wünsche oder Finanzen gehören.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Beispiele")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dokumenteAkzentFarbe)

                        beispielZeile("Aktueller Mietvertrag")
                        beispielZeile("Wohnsitzbestätigung")
                        beispielZeile("Familienbuch")
                        beispielZeile("Handyverträge")
                        beispielZeile("Fahrzeugpapiere")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Hinzufügen", systemImage: "doc.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(dokumenteAkzentFarbe)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDocumentScanner = true
                    } label: {
                        Label("Scannen", systemImage: "doc.viewfinder")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(dokumenteAkzentFarbe)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(dokumenteAkzentFarbe.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(dokumenteAkzentFarbe.opacity(0.12), lineWidth: 1)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)

            let weitereDokumenteModelle = gespeicherteWeitereDokumente.filter { $0.kategorie == "Weitere Dokumente" }

            if !weitereDokumenteModelle.isEmpty {
                ForEach(weitereDokumenteModelle) { dokument in
                    let document = ReadOnlyDocument(
                        title: dokumentTitel(for: dokument.dateiName),
                        fileName: dokument.dateiName,
                        uploadDate: dokument.hochgeladenAm,
                        fileURL: nil,
                        fileData: dokument.dateiDaten,
                        preferredFileExtension: nil
                    )

                    readOnlyDocumentRow(document) {
                        if let previewURL = previewURL(for: document) {
                            selectedDocument = UploadedDocument(
                                fileName: document.fileName,
                                uploadDate: document.uploadDate ?? Date(),
                                fileURL: previewURL
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(dokument)
                            try? modelContext.save()
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    private var fotoalbumInhalt: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                TabView(selection: $selectedPhotoID) {
                    ForEach(Array(gespeicherteFotos.enumerated()), id: \.element.id) { _, photo in
                        ZStack(alignment: .topTrailing) {
                            if let image = UIImage(data: photo.bildDaten) {
                                imageCarouselItem(image: image, photo: photo)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.gray.opacity(0.15))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .overlay {
                                        Label("Foto kann nicht geladen werden", systemImage: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        deletePhotoButton(for: photo)
                                            .padding(8)
                                    }
                                    .padding(.horizontal, 4)
                            }
                        }
                        .tag(photo.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 260)

                if gespeicherteFotos.count > 1 {
                    carouselDots
                }
            }
            .frame(height: gespeicherteFotos.count > 1 ? 294 : 260)
            .onAppear {
                if selectedPhotoID == nil {
                    selectedPhotoID = gespeicherteFotos.first?.id
                }
            }
            .onChange(of: gespeicherteFotos.map(\.id)) { _, neueIDs in
                if selectedPhotoID == nil || !neueIDs.contains(where: { $0 == selectedPhotoID }) {
                    selectedPhotoID = neueIDs.first
                }
            }

            HStack {
                Text("\(gespeicherteFotos.count) Foto\(gespeicherteFotos.count == 1 ? "" : "s") ausgewählt")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let photoBundleURL {
                    ShareLink(item: photoBundleURL) {
                        Label("Album teilen", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dokumenteAkzentFarbe)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        photoBundleURL = erstelleFotoBundle()
                    } label: {
                        Label("Album bereitstellen", systemImage: "tray.and.arrow.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dokumenteAkzentFarbe)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button(role: .destructive) {
                for photo in gespeicherteFotos {
                    modelContext.delete(photo)
                }
                photoBundleURL = nil
                try? modelContext.save()
            } label: {
                Label("Fotoalbum leeren", systemImage: "trash")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func dokumenteListe(_ dokumente: [ReadOnlyDocument]) -> some View {
        if dokumente.isEmpty {
            Text("Noch keine Dokumente vorhanden.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(dokumente) { document in
                readOnlyDocumentRow(document) {
                    if let previewURL = previewURL(for: document) {
                        selectedDocument = UploadedDocument(
                            fileName: document.fileName,
                            uploadDate: document.uploadDate ?? Date(),
                            fileURL: previewURL
                        )
                    }
                }
            }
        }
    }

    private func einklappHeader(
        titel: String,
        anzahl: Int,
        eingeklappt: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(anzahl)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dokumenteAkzentFarbe)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dokumenteAkzentFarbe.opacity(0.12), in: Capsule())

                Image(systemName: eingeklappt ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dokumenteAkzentFarbe)
            }
        }
        .buttonStyle(.borderless)
    }

    private func beispielZeile(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .font(.caption.weight(.bold))
                .foregroundStyle(dokumenteAkzentFarbe)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }


    private var alleExportierbarenDokumente: [ReadOnlyDocument] {
        wuenscheDokumente + finanzDokumente + weitereDokumente
    }

    private var weitereDokumente: [ReadOnlyDocument] {
        gespeicherteWeitereDokumente
            .filter { $0.kategorie == "Weitere Dokumente" }
            .map { dokument in
                ReadOnlyDocument(
                    title: dokumentTitel(for: dokument.dateiName),
                    fileName: dokument.dateiName,
                    uploadDate: dokument.hochgeladenAm,
                    fileURL: nil,
                    fileData: dokument.dateiDaten,
                    preferredFileExtension: nil
                )
            }
    }

    private var wuenscheDokumente: [ReadOnlyDocument] {
        guard let wuensche = gespeicherteWuensche.first else { return [] }

        var dokumente: [ReadOnlyDocument] = []

        if !wuensche.testamentDateiName.isEmpty {
            dokumente.append(
                ReadOnlyDocument(
                    title: "Testament",
                    fileName: wuensche.testamentDateiName,
                    uploadDate: wuensche.testamentHochgeladenAm,
                    fileURL: nil,
                    fileData: wuensche.testamentDateiData
                )
            )
        }

        if !wuensche.patientenverfuegungDateiName.isEmpty {
            dokumente.append(
                ReadOnlyDocument(
                    title: "Patientenverfügung",
                    fileName: wuensche.patientenverfuegungDateiName,
                    uploadDate: wuensche.patientenverfuegungHochgeladenAm,
                    fileURL: nil,
                    fileData: wuensche.patientenverfuegungDateiData
                )
            )
        }

        if !wuensche.vorsorgeauftragDateiName.isEmpty {
            dokumente.append(
                ReadOnlyDocument(
                    title: "Vorsorgeauftrag",
                    fileName: wuensche.vorsorgeauftragDateiName,
                    uploadDate: wuensche.vorsorgeauftragHochgeladenAm,
                    fileURL: nil,
                    fileData: wuensche.vorsorgeauftragDateiData
                )
            )
        }

        if !wuensche.sterbebegleitungDateiName.isEmpty {
            dokumente.append(
                ReadOnlyDocument(
                    title: "Sterbebegleitung",
                    fileName: wuensche.sterbebegleitungDateiName,
                    uploadDate: wuensche.sterbebegleitungHochgeladenAm,
                    fileURL: nil,
                    fileData: wuensche.sterbebegleitungDateiData
                )
            )
        }

        if let nachrufBildData = wuensche.nachrufBildData {
            dokumente.append(
                ReadOnlyDocument(
                    title: "Nachruf-Foto",
                    fileName: "Nachruf-Foto.jpg",
                    uploadDate: nil,
                    fileURL: nil,
                    fileData: nachrufBildData,
                    preferredFileExtension: "jpg"
                )
            )
        }

        return dokumente
    }

    private var finanzDokumente: [ReadOnlyDocument] {
        steuerdokumente.map { dokument in
            ReadOnlyDocument(
                title: "Steuerdokument",
                fileName: dokument.dateiName,
                uploadDate: dokument.hochgeladenAm,
                fileURL: nil,
                fileData: dokument.dateiDaten,
                preferredFileExtension: nil
            )
        }
    }

    private func dokumentTitel(for fileName: String) -> String {
        let lowercasedFileName = fileName.lowercased()

        if lowercasedFileName.hasSuffix(".pdf") {
            return "PDF-Dokument"
        }

        if lowercasedFileName.hasSuffix(".jpg")
            || lowercasedFileName.hasSuffix(".jpeg")
            || lowercasedFileName.hasSuffix(".png")
            || lowercasedFileName.hasSuffix(".heic") {
            return "Bild"
        }

        if lowercasedFileName.hasSuffix(".txt")
            || lowercasedFileName.hasSuffix(".rtf")
            || lowercasedFileName.hasSuffix(".doc")
            || lowercasedFileName.hasSuffix(".docx") {
            return "Textdokument"
        }

        return "Dokument"
    }

    private func readOnlyDocumentRow(_ document: ReadOnlyDocument, previewAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: dokumentIcon(for: document.fileName))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(dokumenteAkzentFarbe)
                .frame(width: 44, height: 44)
                .background(dokumenteAkzentFarbe.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(document.fileName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let uploadDate = document.uploadDate {
                    Text(uploadDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !document.hasPreview {
                    Text("Vorschau nicht verfügbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button(action: previewAction) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(document.hasPreview ? dokumenteAkzentFarbe : Color.secondary.opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(
                        document.hasPreview
                        ? dokumenteAkzentFarbe.opacity(0.10)
                        : Color.secondary.opacity(0.08),
                        in: Circle()
                    )
            }
                .buttonStyle(.borderless)
            .disabled(!document.hasPreview)
            .accessibilityLabel("Dokument ansehen")
        }
        .padding(14)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(dokumenteAkzentFarbe.opacity(0.10), lineWidth: 1)
        }
        .padding(.vertical, 3)
    }

    private func dokumentIcon(for fileName: String) -> String {
        let lowercasedFileName = fileName.lowercased()

        if lowercasedFileName.hasSuffix(".pdf") {
            return "doc.richtext.fill"
        }

        if lowercasedFileName.hasSuffix(".jpg")
            || lowercasedFileName.hasSuffix(".jpeg")
            || lowercasedFileName.hasSuffix(".png")
            || lowercasedFileName.hasSuffix(".heic") {
            return "photo.fill"
        }

        if lowercasedFileName.hasSuffix(".txt")
            || lowercasedFileName.hasSuffix(".rtf")
            || lowercasedFileName.hasSuffix(".doc")
            || lowercasedFileName.hasSuffix(".docx") {
            return "doc.text.fill"
        }

        return "doc.fill"
    }

    private func speichereGescanntesDokument(sollInDownloadsSpeichern: Bool) {
        guard let pdfData = pendingScanData, !pendingScanDateiName.isEmpty else {
            pendingScanData = nil
            pendingScanDateiName = ""
            return
        }

        if sollInDownloadsSpeichern,
           let scanDateiURL = speichereScanFuerDateienApp(pdfData, dateiName: pendingScanDateiName) {
            exportURL = scanDateiURL
        }

        let dokument = DokumenteModell(
            dateiName: pendingScanDateiName,
            kategorie: "Weitere Dokumente",
            hochgeladenAm: Date(),
            dateiDaten: pdfData
        )

        modelContext.insert(dokument)
        try? modelContext.save()

        pendingScanData = nil
        pendingScanDateiName = ""
    }

    private func speichereScanFuerDateienApp(_ pdfData: Data, dateiName: String) -> URL? {
        let dateiURL = FileManager.default.temporaryDirectory.appendingPathComponent(dateiName)

        do {
            try pdfData.write(to: dateiURL, options: .atomic)
            return dateiURL
        } catch {
            print("Scan konnte nicht für die Dateien-App bereitgestellt werden: \(error.localizedDescription)")
            return nil
        }
    }

    private func previewURL(for document: ReadOnlyDocument) -> URL? {
        if let fileURL = document.fileURL {
            return fileURL
        }

        if let existingFileURL = document.existingFileURL {
            return existingFileURL
        }

        guard let fileData = document.fileData else { return nil }

        let sanitizedFileName = document.fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitizedFileName)

        do {
            try fileData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private var carouselDots: some View {
        HStack(spacing: 6) {
            ForEach(gespeicherteFotos) { photo in
                Circle()
                    .fill(photo.id == selectedPhotoID ? .white : .white.opacity(0.45))
                    .frame(width: photo.id == selectedPhotoID ? 8 : 6, height: photo.id == selectedPhotoID ? 8 : 6)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func imageCarouselItem(image: UIImage, photo: FotoalbumBildModell) -> some View {
        GeometryReader { geometry in
            let aspectRatio = image.size.width / max(image.size.height, 1)
            let maxHeight: CGFloat = 260
            let calculatedWidth = min(maxHeight * aspectRatio, geometry.size.width - 32)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: calculatedWidth, height: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    deletePhotoButton(for: photo)
                        .padding(8)
                }
                .frame(maxWidth: .infinity)
        }
        .frame(height: 260)
    }

    private func deletePhotoButton(for photo: FotoalbumBildModell) -> some View {
        Button {
            modelContext.delete(photo)
            photoBundleURL = nil
            try? modelContext.save()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, dokumenteAkzentFarbe.opacity(0.85))
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Foto löschen")
    }

    private func fotosAusMediathekLaden(_ items: [PhotosPickerItem]) async {
        var neueFotos: [FotoalbumBildModell] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               UIImage(data: data) != nil {
                let photo = FotoalbumBildModell(
                    dateiName: "Foto_\(gespeicherteFotos.count + neueFotos.count + 1).jpg",
                    hinzugefuegtAm: Date(),
                    bildDaten: data,
                    reihenfolge: gespeicherteFotos.count + neueFotos.count
                )
                neueFotos.append(photo)
            }
        }

        await MainActor.run {
            for photo in neueFotos {
                modelContext.insert(photo)
            }
            photoBundleURL = nil
            selectedPhotoItems.removeAll()
            try? modelContext.save()
        }
    }

    private func exportiereDokumenteUndOeffneVorschau() {
        guard let pdfURL = erstelleDokumenteExportPDF() else {
            print("PDF Export fehlgeschlagen")
            return
        }

        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            print("PDF Datei wurde nicht erstellt: \(pdfURL.path)")
            return
        }

        print("PDF erstellt: \(pdfURL.path)")

        exportURL = pdfURL
    }

    private func erstelleDokumenteExportPDF() -> URL? {
        let dokumente = alleExportierbarenDokumente
        guard !dokumente.isEmpty else { return nil }

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AfterLife_Dokumente_Export_\(UUID().uuidString).pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: exportURL) { context in
                var yPosition: CGFloat = 48
                let leftMargin: CGFloat = 44
                let contentWidth: CGFloat = pageRect.width - 88

                context.beginPage()
                yPosition = drawPDFText(
                    "AfterLife Dokumentenexport",
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: contentWidth,
                    font: .boldSystemFont(ofSize: 22),
                    color: .label
                ) + 16

                yPosition = drawPDFText(
                    "Erstellt am \(Date().formatted(date: .abbreviated, time: .shortened))",
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: contentWidth,
                    font: .systemFont(ofSize: 11),
                    color: .secondaryLabel
                ) + 28

                for dokument in dokumente {
                    if yPosition > pageRect.height - 150 {
                        context.beginPage()
                        yPosition = 48
                    }

                    yPosition = drawPDFText(
                        dokument.title,
                        at: CGPoint(x: leftMargin, y: yPosition),
                        width: contentWidth,
                        font: .boldSystemFont(ofSize: 16),
                        color: .label
                    ) + 4

                    yPosition = drawPDFText(
                        dokument.fileName,
                        at: CGPoint(x: leftMargin, y: yPosition),
                        width: contentWidth,
                        font: .systemFont(ofSize: 11),
                        color: .secondaryLabel
                    ) + 10

                    yPosition = drawDocumentPreview(
                        dokument,
                        pageRect: pageRect,
                        startY: yPosition,
                        leftMargin: leftMargin,
                        contentWidth: contentWidth
                    ) + 24
                }
            }

            return exportURL
        } catch {
            print("PDF Fehler: \(error.localizedDescription)")
            return nil
        }
    }

    private func drawDocumentPreview(
        _ dokument: ReadOnlyDocument,
        pageRect: CGRect,
        startY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        guard let data = dokument.fileData ?? dokument.existingFileURL.flatMap({ try? Data(contentsOf: $0) }) else {
            return drawPDFText(
                "Inhalt konnte nicht eingebettet werden.",
                at: CGPoint(x: leftMargin, y: startY),
                width: contentWidth,
                font: .systemFont(ofSize: 10),
                color: .secondaryLabel
            )
        }

        let maxHeight = pageRect.height - startY - 60

        if let image = UIImage(data: data) {
            let scale = min(contentWidth / image.size.width, maxHeight / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let rect = CGRect(x: leftMargin + (contentWidth - size.width) / 2, y: startY, width: size.width, height: size.height)
            image.draw(in: rect)
            return rect.maxY
        }

        if dokument.fileName.lowercased().hasSuffix(".pdf"),
           let pdf = PDFDocument(data: data),
           let page = pdf.page(at: 0),
           let cgContext = UIGraphicsGetCurrentContext() {
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(contentWidth / bounds.width, maxHeight / bounds.height)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let rect = CGRect(x: leftMargin + (contentWidth - size.width) / 2, y: startY, width: size.width, height: size.height)

            cgContext.saveGState()
            cgContext.translateBy(x: rect.minX, y: rect.maxY)
            cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()

            return rect.maxY
        }

        return drawPDFText(
            "Datei ist im Export aufgeführt, kann aber nicht direkt dargestellt werden.",
            at: CGPoint(x: leftMargin, y: startY),
            width: contentWidth,
            font: .systemFont(ofSize: 10),
            color: .secondaryLabel
        )
    }

    private func drawPDFText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let rect = text.boundingRect(
            with: CGSize(width: width, height: 500),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        let drawRect = CGRect(x: point.x, y: point.y, width: width, height: ceil(rect.height))
        text.draw(in: drawRect, withAttributes: attributes)
        return drawRect.maxY
    }

    // Erstellt einen temporären Ordner mit allen Fotos.
    // FileManager besitzt keine native zipItem-Funktion.
    // Für echtes ZIP-Exportieren müsste zusätzlich ZIPFoundation eingebunden werden.
    private func erstelleFotoBundle() -> URL? {
        guard !gespeicherteFotos.isEmpty else { return nil }

        let fileManager = FileManager.default
        let folderURL = fileManager.temporaryDirectory
            .appendingPathComponent("Mein_persoenliches_Fotoalbum_\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            for (index, photo) in gespeicherteFotos.enumerated() {
                let fileURL = folderURL.appendingPathComponent("Foto_\(index + 1).jpg")
                try photo.bildDaten.write(to: fileURL)
            }
            return folderURL
        } catch {
            return nil
        }
    }
}

struct UploadedDocument: Identifiable {
    let id = UUID()
    var fileName: String
    var uploadDate: Date
    var fileURL: URL
}




struct ReadOnlyDocument: Identifiable {
    let id = UUID()
    var title: String
    var fileName: String
    var uploadDate: Date?
    var fileURL: URL?
    var fileData: Data? = nil
    var preferredFileExtension: String? = nil

    var hasPreview: Bool {
        fileURL != nil || fileData != nil || existingFileURL != nil
    }

    var existingFileURL: URL? {
        let fileManager = FileManager.default
        let searchFolders = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            fileManager.temporaryDirectory
        ].compactMap { $0 }

        for folder in searchFolders {
            let directURL = folder.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: directURL.path) {
                return directURL
            }

            if let enumerator = fileManager.enumerator(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator where fileURL.lastPathComponent == fileName {
                    return fileURL
                }
            }
        }

        return nil
    }
}


struct DocumentPicker: UIViewControllerRepresentable {
    var onDocumentsPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .text, .plainText, .item])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsPicked: onDocumentsPicked)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onDocumentsPicked: ([URL]) -> Void

        init(onDocumentsPicked: @escaping ([URL]) -> Void) {
            self.onDocumentsPicked = onDocumentsPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDocumentsPicked(urls)
        }
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    var onScanCompleted: (Data) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanCompleted: onScanCompleted)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScanCompleted: (Data) -> Void

        init(onScanCompleted: @escaping (Data) -> Void) {
            self.onScanCompleted = onScanCompleted
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pdfDocument = PDFDocument()

            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                if let pdfPage = PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: index)
                }
            }

            if let pdfData = pdfDocument.dataRepresentation() {
                onScanCompleted(pdfData)
            }

            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    DokumenteView()
}

// This struct previews a document using QuickLook

struct DocumentPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.currentPreviewItemIndex = 0
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.dataSource = context.coordinator
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}



