import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct DokumenteView: View {
    @State private var wishDocuments: [UploadedDocument] = []
    @State private var financeDocuments: [UploadedDocument] = []
    @State private var additionalDocuments: [UploadedDocument] = []
    @State private var showDocumentPicker = false
    @State private var selectedDocument: UploadedDocument?

    var body: some View {
        NavigationStack {
            Form {
                Section("Dokumente - Meine Wünsche") {
                    if wishDocuments.isEmpty {
                        Text("Noch keine Dokumente vorhanden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(wishDocuments) { document in
                            Button {
                                selectedDocument = document
                            } label: {
                                documentRow(document)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Dokumente - Finanzen") {
                    if financeDocuments.isEmpty {
                        Text("Noch keine Dokumente vorhanden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(financeDocuments) { document in
                            Button {
                                selectedDocument = document
                            } label: {
                                documentRow(document)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    if additionalDocuments.isEmpty {
                        Text("Noch keine weiteren Dokumente hochgeladen.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(additionalDocuments) { document in
                            Button {
                                selectedDocument = document
                            } label: {
                                documentRow(document)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            additionalDocuments.remove(atOffsets: indexSet)
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
                        let document = UploadedDocument(
                            fileName: url.lastPathComponent,
                            uploadDate: Date(),
                            fileURL: url
                        )
                        additionalDocuments.append(document)
                    }
                }
            }
            .sheet(item: $selectedDocument) { document in
                DocumentPreview(url: document.fileURL)
            }
        }
    }

    private func documentRow(_ document: UploadedDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.fileName)
                .font(.headline)

            Text("Hochgeladen am \(document.uploadDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct UploadedDocument: Identifiable {
    let id = UUID()
    var fileName: String
    var uploadDate: Date
    var fileURL: URL
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
