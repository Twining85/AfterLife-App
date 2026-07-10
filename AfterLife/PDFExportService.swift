import Foundation

struct PDFExportService {
    private let dossierService: DossierPDFExportService
    private let mapper: DossierExportMapper

    init(
        dossierService: DossierPDFExportService = DossierPDFExportService(),
        mapper: DossierExportMapper = DossierExportMapper()
    ) {
        self.dossierService = dossierService
        self.mapper = mapper
    }

    func exportDossier(_ document: DossierPDFDocument, fileName: String? = nil) throws -> URL {
        try dossierService.export(document: document, fileName: fileName)
    }

    func exportProfilDossier(
        profil: ProfilModell?,
        options: DossierPDFExportOptions = .standard,
        attachments: [DossierPDFAttachment] = [],
        fileName: String? = nil
    ) throws -> URL {
        let document = mapper.makeProfilDocument(
            profil: profil,
            options: options,
            attachments: attachments
        )

        return try dossierService.export(document: document, fileName: fileName)
    }
}
