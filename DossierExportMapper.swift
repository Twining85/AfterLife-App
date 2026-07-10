import Foundation

struct DossierExportMapper {
    private let dateFormatter: DateFormatter

    init(dateFormatter: DateFormatter = DossierExportMapper.defaultDateFormatter) {
        self.dateFormatter = dateFormatter
    }

    func makeProfilDocument(
        profil: ProfilModell?,
        options: DossierPDFExportOptions = .standard,
        attachments: [DossierPDFAttachment] = []
    ) -> DossierPDFDocument {
        makeDocument(
            erstelltAm: Date(),
            aktualisiertAm: profil?.aktualisiertAm,
            chapters: [makeProfilChapter(profil: profil, options: options)],
            attachments: attachments,
            options: options
        )
    }

    func makeProfilChapter(
        profil: ProfilModell?,
        options: DossierPDFExportOptions
    ) -> DossierPDFChapter {
        DossierPDFChapter(
            typ: .profil,
            titel: "Profil",
            beschreibung: "Die wichtigsten persönlichen Angaben und Kontaktinformationen auf einen Blick.",
            farbe: PDFThemeColor(red: 0.16, green: 0.36, blue: 0.42),
            sections: makeProfilSections(profil: profil, options: options)
        )
    }

    func makeDocument(
        title: String = "Persönliches Tschlüssli Dossier",
        subtitle: String = "Persönliches Vorsorgedossier",
        erstelltAm: Date = Date(),
        aktualisiertAm: Date? = nil,
        chapters: [DossierPDFChapter],
        attachments: [DossierPDFAttachment],
        options: DossierPDFExportOptions = .standard
    ) -> DossierPDFDocument {
        DossierPDFDocument(
            titel: title,
            untertitel: subtitle,
            erstelltAm: erstelltAm,
            aktualisiertAm: aktualisiertAm,
            vertraulichkeitshinweis: "Vertraulich. Dieses Dokument ist nur für die von dir bestimmten Vertrauenspersonen bestimmt.",
            kapitel: chapters,
            anhaenge: options.dokumenteAlsAnhangBeruecksichtigen ? attachments : []
        )
    }

    func makeItem(label: String, value: String, options: DossierPDFExportOptions) -> DossierPDFItem? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.isEmpty && !options.leereFelderAnzeigen {
            return nil
        }

        return DossierPDFItem(
            label: label,
            wert: trimmedValue.isEmpty ? "Nicht erfasst" : trimmedValue,
            status: trimmedValue.isEmpty ? .nichtErfasst : nil
        )
    }
}

private extension DossierExportMapper {
    static let defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    func makeProfilSections(
        profil: ProfilModell?,
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        guard let profil else {
            return [
                DossierPDFSection(
                    titel: "Profil",
                    untertitel: "Es wurden noch keine Profildaten erfasst.",
                    items: [
                        DossierPDFItem(
                            label: "Status",
                            wert: "Nicht erfasst",
                            status: .nichtErfasst
                        )
                    ],
                    darstellung: .statusListe
                )
            ]
        }

        return [
            makePersonalSection(profil: profil, options: options),
            makeAddressSection(profil: profil, options: options),
            makeContactSection(profil: profil, options: options),
            makeEmergencySection(profil: profil, options: options),
            makeRegistrationSection(profil: profil, options: options)
        ].compactMap { section in
            guard !section.items.isEmpty || options.leereFelderAnzeigen else { return nil }
            return section
        }
    }

    func makePersonalSection(
        profil: ProfilModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Persönliche Angaben",
            items: [
                makeItem(label: "Vorname", value: profil.vorname, options: options),
                makeItem(label: "Name", value: profil.name, options: options),
                makeItem(label: "Geburtsdatum", value: dateFormatter.string(from: profil.geburtsdatum), options: options),
                makeItem(label: "AHV-Nr.", value: profil.ahvNummer, options: options)
            ].compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeAddressSection(
        profil: ProfilModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let strasse = [profil.strasse, profil.hausnummer]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let ort = [profil.plz, profil.stadt]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return DossierPDFSection(
            titel: "Adresse",
            items: [
                makeItem(label: "Strasse", value: strasse, options: options),
                makeItem(label: "Ort", value: ort, options: options),
                makeItem(label: "Land", value: profil.land, options: options)
            ].compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeContactSection(
        profil: ProfilModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Kontakt",
            items: [
                makeItem(label: "Telefon", value: profil.telefon, options: options),
                makeItem(label: "E-Mail", value: profil.email, options: options)
            ].compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeEmergencySection(
        profil: ProfilModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Notfallhinweis",
            untertitel: "Persönliche Information für den Ernstfall.",
            items: [
                makeItem(label: "Hinweis", value: profil.notfallHinweis, options: options)
            ].compactMap { $0 },
            darstellung: .persoenlicherText
        )
    }

    func makeRegistrationSection(
        profil: ProfilModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        var items: [DossierPDFItem?] = [
            makeItem(label: "Registrierungsart", value: profil.registrierungsart, options: options),
            makeItem(label: "Registrierungs-E-Mail", value: profil.registrierungsEmail, options: options)
        ]

        if options.sensibleDatenEinschliessen {
            items.append(makeItem(label: "Passwort", value: profil.registrierungsPasswort, options: options))
        }

        return DossierPDFSection(
            titel: "Registrierung",
            untertitel: options.sensibleDatenEinschliessen ? "Sensible Zugangsdaten sind enthalten." : "Sensible Zugangsdaten werden in diesem Export nicht mitgedruckt.",
            items: items.compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }
}
