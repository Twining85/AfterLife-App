import Foundation
import Testing
@testable import Tschluessli

struct DossierE2EVerschluesselungTests {
    private let dossierID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private var context: DossierE2EKontext {
        DossierE2EKontext(dossierID: dossierID, sectionType: "gesundheit", schemaVersion: 1, keyVersion: 1, resourceID: "section")
    }

    @Test func interoperabilitaetMitNodeUndWebCrypto() throws {
        let key = try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: Data(repeating: 7, count: 32), kontext: context)
        #expect(key.map { String(format: "%02x", $0) }.joined() == "644f1449eb5ffc35fb59fa57325fb61d8645d50744908f8d58a358c78b0a95be")
        let envelope = DossierE2EPayload(formatVersion: 2, algorithm: "AES-256-GCM", context: context,
                                        ciphertext: "AwMDAwMDAwMDAwMDU1HO4loIEx1x27mSGC0ZXsh55rhmrho=")
        #expect(try DossierE2EVerschluesselung.entschluesseln(envelope, schluessel: key, erwarteterKontext: context) == Data("V2-Test".utf8))
    }

    @Test func alleBereicheUndDokumenteSindGetrennt() throws {
        let root = DossierE2EVerschluesselung.zufaelligerSchluessel()
        let message = Data("Testinhalt".utf8)
        var keys = Set<Data>()
        for section in DossierE2EKontext.bereiche.sorted() {
            for resource in ["section", "22222222-2222-4222-8222-222222222222"] {
                let c = DossierE2EKontext(dossierID: dossierID, sectionType: section, schemaVersion: 1, keyVersion: 1, resourceID: resource)
                let key = try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: root, kontext: c)
                #expect(keys.insert(key).inserted)
                let box = try DossierE2EVerschluesselung.verschluesseln(message, schluessel: key, kontext: c)
                #expect(try DossierE2EVerschluesselung.entschluesseln(box, schluessel: key, erwarteterKontext: c) == message)
            }
        }
    }

    @Test func manipuliertePaketeUndFremdeKontexteWerdenAbgewiesen() throws {
        let key = DossierE2EVerschluesselung.zufaelligerSchluessel()
        let box = try DossierE2EVerschluesselung.verschluesseln(Data("privat".utf8), schluessel: key, kontext: context)
        var altered = try #require(Data(base64Encoded: box.ciphertext))
        altered[14] ^= 1
        let tampered = DossierE2EPayload(formatVersion: 2, algorithm: "AES-256-GCM", context: context, ciphertext: altered.base64EncodedString())
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.entschluesseln(tampered, schluessel: key, erwarteterKontext: context) }
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.entschluesseln(box, schluessel: Data(repeating: 0, count: 32), erwarteterKontext: context) }
        let other = DossierE2EKontext(dossierID: dossierID, sectionType: "finanzen", schemaVersion: 1, keyVersion: 1, resourceID: "section")
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.entschluesseln(box, schluessel: key, erwarteterKontext: other) }
        let rewritten = DossierE2EPayload(formatVersion: 2, algorithm: "AES-256-GCM", context: other, ciphertext: box.ciphertext)
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.entschluesseln(rewritten, schluessel: key, erwarteterKontext: other) }
    }

    @Test func freigabeEnthaeltNurAusgewaehlteSchluessel() throws {
        let root = DossierE2EVerschluesselung.zufaelligerSchluessel()
        let secret = DossierE2EVerschluesselung.zufaelligerSchluessel()
        let selectedKey = try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: root, kontext: context)
        let selected = DossierE2ERessourcenSchluessel(context: context, key: selectedKey.base64EncodedString())
        let grantContext = DossierE2EFreigabeKontext(dossierID: dossierID, invitationID: UUID(), recipientEmail: "tester@example.ch", grantVersion: 1, scope: .partial)
        let grant = try DossierE2EVerschluesselung.freigabeVerpacken([selected], geheimnis: secret, kontext: grantContext)
        let opened = try DossierE2EVerschluesselung.freigabeOeffnen(grant, geheimnis: secret, erwarteterKontext: grantContext)
        #expect(opened.count == 1)
        #expect(opened[0].key == selected.key)
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.freigabeOeffnen(grant, geheimnis: Data(repeating: 0, count: 32), erwarteterKontext: grantContext) }
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.freigabeVerpacken([selected, selected], geheimnis: secret, kontext: grantContext) }
        let otherContext = DossierE2EKontext(dossierID: dossierID, sectionType: "finanzen", schemaVersion: 1, keyVersion: 1, resourceID: "section")
        let otherKey = try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: root, kontext: otherContext)
        let otherBox = try DossierE2EVerschluesselung.verschluesseln(Data("Bankdaten".utf8), schluessel: otherKey, kontext: otherContext)
        #expect(throws: (any Error).self) { try DossierE2EVerschluesselung.entschluesseln(otherBox, schluessel: selectedKey, erwarteterKontext: otherContext) }
    }

    @Test func rotationUndDossierwechselErzeugenAndereSchluessel() throws {
        let root = DossierE2EVerschluesselung.zufaelligerSchluessel()
        let key = try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: root, kontext: context)
        let rotated = DossierE2EKontext(dossierID: dossierID, sectionType: "gesundheit", schemaVersion: 1, keyVersion: 2, resourceID: "section")
        let foreign = DossierE2EKontext(dossierID: UUID(), sectionType: "gesundheit", schemaVersion: 1, keyVersion: 1, resourceID: "section")
        #expect(try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: root, kontext: rotated) != key)
        #expect(try DossierE2EVerschluesselung.ressourcenSchluessel(stammSchluessel: root, kontext: foreign) != key)
    }
}
