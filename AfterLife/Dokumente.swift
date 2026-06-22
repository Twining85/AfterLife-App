import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLook
import PhotosUI
import UIKit

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let dokumente = wuenscheDokumente

                    if !wuenscheDokumenteEingeklappt {
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
                } header: {
                    Button {
                        withAnimation {
                            wuenscheDokumenteEingeklappt.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Dokumente - Meine Wünsche")
                            Spacer()
                            Text("\(wuenscheDokumente.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: wuenscheDokumenteEingeklappt ? "chevron.right" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    let dokumente = finanzDokumente

                    if !finanzenDokumenteEingeklappt {
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
                } header: {
                    Button {
                        withAnimation {
                            finanzenDokumenteEingeklappt.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Dokumente - Finanzen")
                            Spacer()
                            Text("\(finanzDokumente.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: finanzenDokumenteEingeklappt ? "chevron.right" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    if gespeicherteFotos.isEmpty {
                        Text("Noch keine Fotos zugeordnet.")
                            .foregroundStyle(.secondary)
                    } else {
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
                                }
                                .font(.caption)
                            } else {
                                Button {
                                    photoBundleURL = erstelleFotoBundle()
                                } label: {
                                    Label("Album bereitstellen", systemImage: "tray.and.arrow.down")
                                }
                                .font(.caption)
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
                        }
                        .font(.caption)
                    }
                } header: {
                    HStack {
                        Text("Mein persönliches Fotoalbum")

                        Spacer()

                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 20,
                            matching: .images
                        ) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    let dokumente = weitereDokumente

                    if dokumente.isEmpty {
                        Text("Noch keine weiteren Dokumente hochgeladen.")
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
                        .onDelete { indexSet in
                            for index in indexSet {
                                let dokument = gespeicherteWeitereDokumente[index]
                                modelContext.delete(dokument)
                            }
                            try? modelContext.save()
                        }
                    }
                } header: {
                    HStack {
                        Text("Weitere Dokumente hochladen")

                        Spacer()

                        Button {
                            showDocumentPicker = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Dokumente")
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
            .sheet(item: $selectedDocument) { document in
                DocumentPreview(url: document.fileURL)
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    await fotosAusMediathekLaden(newItems)
                }
            }
        }
    }


    private var weitereDokumente: [ReadOnlyDocument] {
        gespeicherteWeitereDokumente
            .filter { $0.kategorie == "Weitere Dokumente" }
            .map { dokument in
                ReadOnlyDocument(
                    title: "Weiteres Dokument",
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

    private func readOnlyDocumentRow(_ document: ReadOnlyDocument, previewAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)

                Text(document.fileName)
                    .font(.subheadline)

                if let uploadDate = document.uploadDate {
                    Text("Hochgeladen am \(uploadDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !document.hasPreview {
                    Text("Vorschau nicht verfügbar, da aktuell nur der Dateiname gespeichert ist.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: previewAction) {
                Image(systemName: "eye")
                    .font(.title3)
                    .foregroundStyle(document.hasPreview ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!document.hasPreview)
            .accessibilityLabel("Dokument ansehen")
        }
        .padding(.vertical, 4)
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
                .foregroundStyle(.white, .black.opacity(0.35))
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
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

#Preview {
    DokumenteView()
}

// This struct previews a document using QuickLook

struct DocumentPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

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
