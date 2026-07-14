import Foundation

struct DocumentBundlePDFDocument {
    var titel: String
    var untertitel: String
    var erstelltAm: Date
    var vertraulichkeitshinweis: String
    var attachments: [DossierPDFAttachment]
}
