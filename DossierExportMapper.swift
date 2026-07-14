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
            profilbildDaten: profil?.profilbildDaten,
            sections: makeProfilSections(profil: profil, options: options)
        )
    }

    func makeDossierDocument(
        profil: ProfilModell?,
        wuensche: [WuenscheModell],
        gesundheitsdaten: [GesundheitModell] = [],
        bankkonten: [BankkontoModell] = [],
        schulden: [SchuldenModell] = [],
        versicherungen: [VersicherungModell] = [],
        liegenschaften: [LiegenschaftModell] = [],
        wertsachen: [WertsacheModell] = [],
        dokumente: [DokumenteModell] = [],
        fotoalbumBilder: [FotoalbumBildModell] = [],
        aboModelle: [AboModell] = [],
        options: DossierPDFExportOptions = .standard,
        attachments: [DossierPDFAttachment] = []
    ) -> DossierPDFDocument {
        let chapters = [
            makeProfilChapter(profil: profil, options: options),
            makeWuenscheChapter(wuensche: wuensche, options: options),
            makeGesundheitChapter(gesundheitsdaten: gesundheitsdaten, options: options),
            makeFinanzenChapter(
                bankkonten: bankkonten,
                schulden: schulden,
                versicherungen: versicherungen,
                liegenschaften: liegenschaften,
                wertsachen: wertsachen,
                options: options
            ),
            makeDokumenteChapter(
                dokumente: dokumente,
                fotoalbumBilder: fotoalbumBilder,
                options: options
            ),
            makeAbosChapter(
                aboModelle: aboModelle,
                options: options
            )
        ]

        let finanzDaten = bankkonten.map(\.aktualisiertAm) + schulden.map(\.aktualisiertAm) + versicherungen.map(\.aktualisiertAm) + liegenschaften.map(\.aktualisiertAm) + wertsachen.map(\.aktualisiertAm)
        let dokumentDaten = dokumente.map(\.hochgeladenAm) + fotoalbumBilder.map(\.hinzugefuegtAm)
        let aboDaten = aboModelle.map(\.aktualisiertAm) + aboModelle.flatMap { $0.abos.map(\.aktualisiertAm) }

        return makeDocument(
            erstelltAm: Date(),
            aktualisiertAm: latestDate(profil?.aktualisiertAm, gesundheitsdaten.map(\.geaendertAm) + finanzDaten + dokumentDaten + aboDaten),
            chapters: chapters,
            attachments: attachments,
            options: options
        )
    }

    func makeWuenscheChapter(
        wuensche: [WuenscheModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFChapter {
        DossierPDFChapter(
            typ: .wuensche,
            titel: "Meine Wünsche",
            beschreibung: "Persönliche Vorstellungen zu Abschied, Beisetzung, wichtigen Botschaften und vorhandenen Vorsorgedokumenten.",
            farbe: PDFThemeColor(red: 0.46, green: 0.34, blue: 0.58),
            sections: makeWuenscheSections(wuensche: wuensche, options: options)
        )
    }

    func makeGesundheitChapter(
        gesundheitsdaten: [GesundheitModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFChapter {
        DossierPDFChapter(
            typ: .gesundheit,
            titel: "Gesundheit",
            beschreibung: "Medizinische Kerninformationen, Hausarzt und wichtige Hinweise für den Notfall.",
            farbe: PDFThemeColor(red: 0.18, green: 0.46, blue: 0.42),
            sections: makeGesundheitSections(gesundheitsdaten: gesundheitsdaten, options: options)
        )
    }

    func makeFinanzenChapter(
        bankkonten: [BankkontoModell],
        schulden: [SchuldenModell],
        versicherungen: [VersicherungModell],
        liegenschaften: [LiegenschaftModell],
        wertsachen: [WertsacheModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFChapter {
        DossierPDFChapter(
            typ: .finanzen,
            titel: "Finanzen",
            beschreibung: "Konten, Vermögenswerte, Verpflichtungen, Versicherungen und wichtige Sachwerte übersichtlich zusammengefasst.",
            farbe: PDFThemeColor(red: 0.34, green: 0.43, blue: 0.30),
            sections: makeFinanzenSections(
                bankkonten: bankkonten,
                schulden: schulden,
                versicherungen: versicherungen,
                liegenschaften: liegenschaften,
                wertsachen: wertsachen,
                options: options
            )
        )
    }

    func makeDokumenteChapter(
        dokumente: [DokumenteModell],
        fotoalbumBilder: [FotoalbumBildModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFChapter {
        DossierPDFChapter(
            typ: .dokumente,
            titel: "Dokumente",
            beschreibung: "Hochgeladene Unterlagen, Nachweise und Fotoalbum-Hinweise für die Anhänge des Dossiers.",
            farbe: PDFThemeColor(red: 0.32, green: 0.40, blue: 0.56),
            sections: makeDokumenteSections(
                dokumente: dokumente,
                fotoalbumBilder: fotoalbumBilder,
                options: options
            )
        )
    }

    func makeAbosChapter(
        aboModelle: [AboModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFChapter {
        DossierPDFChapter(
            typ: .abos,
            titel: "Abos & digitale Zugänge",
            beschreibung: "Abonnemente, Profile, Geräte, Mitgliedschaften und Zugangsinformationen strukturiert für den Ernstfall.",
            farbe: PDFThemeColor(red: 0.42, green: 0.34, blue: 0.27),
            sections: makeAboSections(aboModelle: aboModelle, options: options)
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

    func makeWuenscheSections(
        wuensche: [WuenscheModell],
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        guard !wuensche.isEmpty else {
            return [
                DossierPDFSection(
                    titel: "Meine Wünsche",
                    untertitel: "Es wurden noch keine Wünsche erfasst.",
                    items: [DossierPDFItem(label: "Status", wert: "Nicht erfasst", status: .nichtErfasst)],
                    darstellung: .statusListe
                )
            ]
        }

        return wuensche.enumerated().flatMap { index, wunsch in
            makeWuenscheSections(
                wunsch: wunsch,
                titelPraefix: wuensche.count == 1 ? nil : "Wünsche \(index + 1)",
                options: options
            )
        }
    }

    func makeWuenscheSections(
        wunsch: WuenscheModell,
        titelPraefix: String?,
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        [
            makeWuenscheOverviewSection(wunsch: wunsch, titelPraefix: titelPraefix),
            makeBeisetzungSection(wunsch: wunsch, options: options),
            makeMusikSection(wunsch: wunsch, options: options),
            makeZeremonieSection(wunsch: wunsch, options: options),
            makeLetzteWorteSection(wunsch: wunsch, options: options),
            makeNachrufSection(wunsch: wunsch, options: options),
            makeVorsorgedokumenteSection(wunsch: wunsch, options: options),
            makeLebensqualitaetSection(wunsch: wunsch, options: options),
            makeHaustiereSection(wunsch: wunsch, options: options)
        ].compactMap { section in
            guard !section.items.isEmpty || options.leereFelderAnzeigen else { return nil }
            return section
        }
    }

    func makeWuenscheOverviewSection(
        wunsch: WuenscheModell,
        titelPraefix: String?
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: titelPraefix ?? "Übersicht",
            items: [
                makeStatusItem(label: "Besondere Wünsche", isPresent: hasWuenscheDetails(wunsch)),
                makeStatusItem(label: "Keine Blumengeschenke", isPresent: wunsch.keineBlumengeschenkeBitte),
                makeStatusItem(label: "Haustiere", isPresent: hasHaustierDetails(wunsch))
            ],
            darstellung: .statusListe
        )
    }

    func makeBeisetzungSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Beisetzung",
            items: [
                makeItem(label: "Art", value: wunsch.beisetzungsArt, options: options),
                makeItem(label: "Hinweis", value: wunsch.beisetzungHinweis, options: options),
                makeItem(label: "Sonstige Bemerkungen", value: wunsch.sonstigeBemerkungen, options: options)
            ].compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeMusikSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        var items: [DossierPDFItem] = [makeStatusItem(label: "Besondere Musik", isPresent: hasContent(wunsch.musikWunsch))]
        if let musikWunsch = makeItem(label: "Musikwunsch", value: wunsch.musikWunsch, options: options) {
            items.append(musikWunsch)
        }

        return DossierPDFSection(
            titel: "Musik",
            items: items,
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeZeremonieSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Zeremonie",
            items: [
                makeStatusItem(label: "Zeremonie gewünscht", isPresent: hasContent(wunsch.zeremonieDetails)),
                makeStatusItem(label: "Organisiert", isPresent: wunsch.zeremonieOrganisiert && hasContent(wunsch.zeremonieDetails)),
                makeStatusItem(label: "Finanziell abgesichert", isPresent: wunsch.zeremonieFinanziellAbgesichert && hasContent(wunsch.zeremonieDetails)),
                makeItem(label: "Details", value: wunsch.zeremonieDetails, options: options)
            ].compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeLetzteWorteSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        var items: [DossierPDFItem] = [makeStatusItem(label: "Text eingegeben", isPresent: hasContent(wunsch.letzteBotschaft))]
        if let botschaft = makeItem(label: "Botschaft", value: wunsch.letzteBotschaft, options: options) {
            items.append(botschaft)
        }

        return DossierPDFSection(
            titel: "Letzte Worte",
            untertitel: "Persönliche Botschaft für Angehörige.",
            items: items,
            darstellung: .persoenlicherText
        )
    }

    func makeNachrufSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        var items: [DossierPDFItem] = [makeStatusItem(label: "Text eingegeben", isPresent: hasContent(wunsch.nachrufText))]
        if let nachruf = makeItem(label: "Text", value: wunsch.nachrufText, options: options) {
            items.append(nachruf)
        }

        return DossierPDFSection(
            titel: "Nachruf",
            untertitel: "Text und Hinweise für einen möglichen Nachruf.",
            items: items,
            darstellung: .persoenlicherText
        )
    }

    func makeVorsorgedokumenteSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = [
            makeDocumentStatusItem(
                label: "Testament",
                isPresent: hasContent(wunsch.testamentDateiName) || hasData(wunsch.testamentDateiData),
                fileName: wunsch.testamentDateiName,
                uploadedAt: wunsch.testamentHochgeladenAm,
                options: options
            ),
            makeDocumentStatusItem(
                label: "Patientenverfügung",
                isPresent: hasContent(wunsch.patientenverfuegungDateiName) || hasData(wunsch.patientenverfuegungDateiData),
                fileName: wunsch.patientenverfuegungDateiName,
                uploadedAt: wunsch.patientenverfuegungHochgeladenAm,
                options: options
            ),
            makeDocumentStatusItem(
                label: "Vorsorgeauftrag",
                isPresent: hasContent(wunsch.vorsorgeauftragDateiName) || hasData(wunsch.vorsorgeauftragDateiData),
                fileName: wunsch.vorsorgeauftragDateiName,
                uploadedAt: wunsch.vorsorgeauftragHochgeladenAm,
                options: options
            ),
            makeDocumentStatusItem(
                label: "Sterbebegleitung",
                isPresent: hasContent(wunsch.sterbebegleitungDateiName) || hasData(wunsch.sterbebegleitungDateiData),
                fileName: wunsch.sterbebegleitungDateiName,
                uploadedAt: wunsch.sterbebegleitungHochgeladenAm,
                options: options
            )
        ].compactMap { $0 }

        return DossierPDFSection(
            titel: "Vorsorgedokumente",
            untertitel: "Vorhandene Dokumente und Hinweise zu den Anhängen.",
            items: items,
            darstellung: .statusListe
        )
    }

    func makeLebensqualitaetSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Schwere Erkrankung / Lebensqualität",
            items: [
                makeStatusItem(label: "Schwere Erkrankung", isPresent: hasContent(wunsch.schwereErkrankungArt) || hasContent(wunsch.mirIstWichtig)),
                makeItem(label: "Art der Erkrankung", value: wunsch.schwereErkrankungArt, options: options),
                makeItem(label: "Mir ist wichtig", value: wunsch.mirIstWichtig, options: options),
                makeStatusItem(label: "Regelmässig beurteilen", isPresent: wunsch.regelmaessigBeurteilen && (hasContent(wunsch.schwereErkrankungArt) || hasContent(wunsch.mirIstWichtig)))
            ].compactMap { $0 },
            darstellung: .persoenlicherText
        )
    }

    func makeHaustiereSection(
        wunsch: WuenscheModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        var items: [DossierPDFItem] = [makeStatusItem(label: "Haustiere", isPresent: hasHaustierDetails(wunsch))]

        if wunsch.hatHaustiere,
           let haustiereData = wunsch.haustiereData,
           let haustiere = try? JSONDecoder().decode([DossierHaustierExportEintrag].self, from: haustiereData) {
            for (index, haustier) in haustiere.enumerated() {
                let title = haustier.anzeigename.isEmpty ? "Haustier \(index + 1)" : haustier.anzeigename
                let details = [
                    haustier.art,
                    haustier.tierarzt.isEmpty ? nil : "Tierarzt: \(haustier.tierarzt)",
                    haustier.bemerkungen.isEmpty ? nil : haustier.bemerkungen
                ].compactMap { $0 }.joined(separator: "\n")
                if let item = makeItem(label: title, value: details, options: options) {
                    items.append(item)
                }
            }
        }

        return DossierPDFSection(
            titel: "Haustiere",
            items: items,
            darstellung: .karte
        )
    }

    func makeGesundheitSections(
        gesundheitsdaten: [GesundheitModell],
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        guard !gesundheitsdaten.isEmpty else {
            return [
                DossierPDFSection(
                    titel: "Gesundheit",
                    untertitel: "Es wurden noch keine Gesundheitsdaten erfasst.",
                    items: [DossierPDFItem(label: "Status", wert: "Nicht erfasst", status: .nichtErfasst)],
                    darstellung: .statusListe
                )
            ]
        }

        return gesundheitsdaten.enumerated().flatMap { index, gesundheit in
            makeGesundheitSections(
                gesundheit: gesundheit,
                titelPraefix: gesundheitsdaten.count == 1 ? nil : "Gesundheit \(index + 1)",
                options: options
            )
        }
    }

    func makeGesundheitSections(
        gesundheit: GesundheitModell,
        titelPraefix: String?,
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        [
            makeGesundheitOverviewSection(gesundheit: gesundheit, titelPraefix: titelPraefix),
            makeHausarztSection(gesundheit: gesundheit, options: options),
            makeMedizinischeInformationenSection(gesundheit: gesundheit, options: options),
            makeGesundheitlicheHinweiseSection(gesundheit: gesundheit, options: options)
        ].compactMap { section in
            guard !section.items.isEmpty || options.leereFelderAnzeigen else { return nil }
            return section
        }
    }

    func makeGesundheitOverviewSection(
        gesundheit: GesundheitModell,
        titelPraefix: String?
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: titelPraefix ?? "Übersicht",
            items: [
                makeStatusItem(label: "Hausarzt", isPresent: hasHausarztDetails(gesundheit)),
                makeStatusItem(label: "Medizinische Angaben", isPresent: hasMedizinischeDetails(gesundheit)),
                makeStatusItem(label: "Wichtige Notfallinformationen", isPresent: hasHausarztDetails(gesundheit) || hasMedizinischeDetails(gesundheit))
            ],
            darstellung: .statusListe
        )
    }

    func makeHausarztSection(
        gesundheit: GesundheitModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Hausarzt",
            untertitel: hasHausarztDetails(gesundheit) ? nil : "Keine Angabe erfasst.",
            items: [
                makeStatusItem(label: "Hausarzt vorhanden", isPresent: hasHausarztDetails(gesundheit)),
                makeItem(label: "Name", value: gesundheit.hausarztName, options: options),
                makeItem(label: "Telefon", value: gesundheit.hausarztTelefon, options: options),
                makeItem(label: "E-Mail", value: gesundheit.hausarztEmail, options: options),
                makeItem(label: "Adresse", value: hausarztAdresse(gesundheit), options: options)
            ].compactMap { $0 },
            darstellung: .kontaktkarte
        )
    }

    func makeMedizinischeInformationenSection(
        gesundheit: GesundheitModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Medizinische Informationen",
            items: [
                makeMedicalItem(label: "Blutgruppe", value: gesundheit.blutgruppe, emptyValue: GesundheitBlutgruppe.unbekannt, options: options),
                makeMedicalItem(label: "Organspende", value: gesundheit.organspende, emptyValue: GesundheitOrganspendeStatus.nichtAngegeben, options: options),
                makeStatusItem(label: "Allergien", isPresent: hasContent(gesundheit.allergien)),
                makeItem(label: "Allergien", value: gesundheit.allergien, options: options),
                makeStatusItem(label: "Medikamente", isPresent: hasContent(gesundheit.medikamente)),
                makeItem(label: "Medikamente", value: gesundheit.medikamente, options: options)
            ].compactMap { $0 },
            darstellung: .zweispaltigeTabelle
        )
    }

    func makeGesundheitlicheHinweiseSection(
        gesundheit: GesundheitModell,
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Gesundheitliche Hinweise",
            untertitel: "Informationen, die Angehörige oder medizinische Fachpersonen im Ernstfall kennen sollten.",
            items: [
                makeItem(label: "Hinweis", value: gesundheit.gesundheitlicheHinweise, options: options)
            ].compactMap { $0 },
            darstellung: .persoenlicherText
        )
    }

    func makeFinanzenSections(
        bankkonten: [BankkontoModell],
        schulden: [SchuldenModell],
        versicherungen: [VersicherungModell],
        liegenschaften: [LiegenschaftModell],
        wertsachen: [WertsacheModell],
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        guard !bankkonten.isEmpty || !schulden.isEmpty || !versicherungen.isEmpty || !liegenschaften.isEmpty || !wertsachen.isEmpty else {
            return [
                DossierPDFSection(
                    titel: "Finanzen",
                    untertitel: "Es wurden noch keine Finanzdaten erfasst.",
                    items: [DossierPDFItem(label: "Status", wert: "Nicht erfasst", status: .nichtErfasst)],
                    darstellung: .statusListe
                )
            ]
        }

        return [
            makeBankkontenSection(bankkonten: bankkonten, options: options),
            makeSchuldenSection(schulden: schulden, options: options),
            makeVersicherungenSection(versicherungen: versicherungen, options: options),
            makeLiegenschaftenSection(liegenschaften: liegenschaften, options: options),
            makeWertsachenSection(wertsachen: wertsachen, options: options)
        ].compactMap { section in
            guard !section.items.isEmpty || options.leereFelderAnzeigen else { return nil }
            return section
        }
    }

    func makeBankkontenSection(
        bankkonten: [BankkontoModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = bankkonten.sorted { $0.erstelltAm < $1.erstelltAm }.enumerated().compactMap { index, bankkonto in
            makeGroupedItem(
                label: bankkonto.bankname.isEmpty ? "Konto \(index + 1)" : bankkonto.bankname,
                values: [
                    makeSelectableLine(label: "Art", value: bankkonto.kontoArt),
                    makeLine(label: "IBAN / Konto-Nr.", value: bankkonto.iban),
                    makeLine(label: "Adresse der Bank", value: bankkonto.bankAdresse),
                    makeLine(label: "Berater", value: bankkonto.berater),
                    makeAmountLine(label: "Vermögenswert", amount: bankkonto.vermoegenswert, currency: bankkonto.waehrung)
                ],
                options: options
            )
        }

        return DossierPDFSection(
            titel: "Konten & Vermögen",
            items: items,
            darstellung: .karte
        )
    }

    func makeSchuldenSection(
        schulden: [SchuldenModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = schulden.sorted { $0.erstelltAm < $1.erstelltAm }.enumerated().compactMap { index, schuld in
            makeGroupedItem(
                label: schuld.glaeubiger.isEmpty ? "Schuld \(index + 1)" : schuld.glaeubiger,
                values: [
                    makeSelectableLine(label: "Art", value: schuld.art),
                    makeAmountLine(label: "Betrag", amount: schuld.betrag, currency: schuld.waehrung),
                    makeLine(label: "Bemerkungen", value: schuld.bemerkungen)
                ],
                options: options
            )
        }

        return DossierPDFSection(
            titel: "Schulden",
            items: items,
            darstellung: .karte
        )
    }

    func makeVersicherungenSection(
        versicherungen: [VersicherungModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = versicherungen.sorted { $0.erstelltAm < $1.erstelltAm }.enumerated().compactMap { index, versicherung in
            makeGroupedItem(
                label: versicherung.anbieter.isEmpty ? "Versicherung \(index + 1)" : versicherung.anbieter,
                values: [
                    makeSelectableLine(label: "Art", value: versicherung.art),
                    makeLine(label: "Police-Nr. / Vertrags-Nr.", value: versicherung.policenNummer),
                    makeAmountLine(label: "Betrag / Versicherungssumme", amount: versicherung.praemie, currency: versicherung.waehrung),
                    makeLine(label: "Bemerkungen", value: versicherung.bemerkungen)
                ],
                options: options
            )
        }

        return DossierPDFSection(
            titel: "Versicherungen",
            items: items,
            darstellung: .karte
        )
    }

    func makeLiegenschaftenSection(
        liegenschaften: [LiegenschaftModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = liegenschaften.sorted { $0.erstelltAm < $1.erstelltAm }.enumerated().compactMap { index, liegenschaft in
            let adresse = [liegenschaft.adresse, liegenschaft.plz, liegenschaft.stadt, liegenschaft.land]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            return makeGroupedItem(
                label: liegenschaft.art == "Bitte wählen" ? "Liegenschaft \(index + 1)" : liegenschaft.art,
                values: [
                    makeLine(label: "Adresse", value: adresse),
                    makeAmountLine(label: "Verkehrswert", amount: liegenschaft.verkehrswert, currency: liegenschaft.waehrung),
                    makeAmountLine(label: "Eigenmietwert", amount: liegenschaft.eigenmietwert, currency: liegenschaft.eigenmietwertWaehrung),
                    makeLine(label: "Bemerkungen", value: liegenschaft.bemerkungen)
                ],
                options: options
            )
        }

        return DossierPDFSection(
            titel: "Liegenschaften",
            items: items,
            darstellung: .karte
        )
    }

    func makeWertsachenSection(
        wertsachen: [WertsacheModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = wertsachen.sorted { $0.erstelltAm < $1.erstelltAm }.enumerated().compactMap { index, wertsache in
            makeGroupedItem(
                label: wertsache.beschreibung.isEmpty ? "Wertsache \(index + 1)" : wertsache.beschreibung,
                values: [
                    makeSelectableLine(label: "Art", value: wertsache.art),
                    makeAmountLine(label: "Betrag", amount: wertsache.betrag, currency: wertsache.waehrung),
                    makeLine(label: "Aufbewahrungsort", value: wertsache.aufbewahrungsort),
                    makeLine(label: "Bemerkungen", value: wertsache.bemerkungen)
                ],
                options: options
            )
        }

        return DossierPDFSection(
            titel: "Wertsachen",
            items: items,
            darstellung: .karte
        )
    }

    func makeDokumenteSections(
        dokumente: [DokumenteModell],
        fotoalbumBilder: [FotoalbumBildModell],
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        guard !dokumente.isEmpty || !fotoalbumBilder.isEmpty else {
            return [
                DossierPDFSection(
                    titel: "Dokumente",
                    untertitel: "Es wurden noch keine Dokumente erfasst.",
                    items: [DossierPDFItem(label: "Status", wert: "Nicht erfasst", status: .nichtErfasst)],
                    darstellung: .statusListe
                )
            ]
        }

        return [
            makeDokumenteOverviewSection(dokumente: dokumente, fotoalbumBilder: fotoalbumBilder),
            makeHochgeladeneDokumenteSection(dokumente: dokumente, options: options),
            makeFotoalbumSection(fotoalbumBilder: fotoalbumBilder, options: options)
        ].compactMap { section in
            guard !section.items.isEmpty || options.leereFelderAnzeigen else { return nil }
            return section
        }
    }

    func makeDokumenteOverviewSection(
        dokumente: [DokumenteModell],
        fotoalbumBilder: [FotoalbumBildModell]
    ) -> DossierPDFSection {
        DossierPDFSection(
            titel: "Übersicht",
            items: [
                DossierPDFItem(label: "Hochgeladene Dokumente", wert: "\(dokumente.count)", status: dokumente.isEmpty ? .nichtVorhanden : .vorhanden),
                DossierPDFItem(label: "Fotoalbum", wert: fotoalbumBilder.isEmpty ? "○ keine Angabe" : "✓ \(fotoalbumBilder.count) Foto(s) vorhanden", status: fotoalbumBilder.isEmpty ? .nichtVorhanden : .vorhanden)
            ],
            darstellung: .statusListe
        )
    }

    func makeHochgeladeneDokumenteSection(
        dokumente: [DokumenteModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        let items = dokumente.sorted { $0.hochgeladenAm < $1.hochgeladenAm }.enumerated().compactMap { index, dokument in
            makeGroupedItem(
                label: dokument.dateiName.isEmpty ? "Dokument \(index + 1)" : dokument.dateiName,
                values: [
                    makeLine(label: "Kategorie", value: dokument.kategorie),
                    "Hochgeladen am: \(dateFormatter.string(from: dokument.hochgeladenAm))",
                    dokument.dateiDaten.isEmpty ? nil : "Anhang: Wird im Dokumentenregister berücksichtigt"
                ],
                options: options
            )
        }

        return DossierPDFSection(
            titel: "Hochgeladene Dokumente",
            untertitel: "Diese Dokumente können als Anhang im Dossier erscheinen.",
            items: items,
            darstellung: .karte
        )
    }

    func makeFotoalbumSection(
        fotoalbumBilder: [FotoalbumBildModell],
        options: DossierPDFExportOptions
    ) -> DossierPDFSection {
        guard !fotoalbumBilder.isEmpty || options.leereFelderAnzeigen else {
            return DossierPDFSection(titel: "Fotoalbum", items: [], darstellung: .statusListe)
        }

        let sortierteBilder = fotoalbumBilder.sorted {
            if $0.reihenfolge == $1.reihenfolge {
                return $0.hinzugefuegtAm < $1.hinzugefuegtAm
            }
            return $0.reihenfolge < $1.reihenfolge
        }

        return DossierPDFSection(
            titel: "Fotoalbum",
            untertitel: "Foto(s) im Anhang. Kann aber auch separat gespeichert werden.",
            items: [
                DossierPDFItem(label: "Anzahl Fotos", wert: "\(sortierteBilder.count)", status: sortierteBilder.isEmpty ? .nichtVorhanden : .vorhanden)
            ],
            darstellung: .statusListe
        )
    }

    func makeAboSections(
        aboModelle: [AboModell],
        options: DossierPDFExportOptions
    ) -> [DossierPDFSection] {
        let abos = aboModelle.flatMap(\.abos)

        guard !abos.isEmpty else {
            return [
                DossierPDFSection(
                    titel: "Abos & digitale Zugänge",
                    untertitel: "Es wurden noch keine Abos oder digitalen Zugänge erfasst.",
                    items: [DossierPDFItem(label: "Status", wert: "Nicht erfasst", status: .nichtErfasst)],
                    darstellung: .statusListe
                )
            ]
        }

        return gruppierteAbos(abos).compactMap { gruppe in
            let items = gruppe.abos.enumerated().compactMap { index, abo in
                makeAboItem(abo, fallbackIndex: index + 1, options: options)
            }

            guard !items.isEmpty || options.leereFelderAnzeigen else { return nil }

            return DossierPDFSection(
                titel: gruppe.typ,
                items: items,
                darstellung: .karte
            )
        }
    }

    func gruppierteAbos(_ abos: [AboEintrag]) -> [(typ: String, abos: [AboEintrag])] {
        let gruppiert = Dictionary(grouping: abos) { abo in
            let typ = abo.aboTyp.trimmingCharacters(in: .whitespacesAndNewlines)
            return typ.isEmpty || typ == "Bitte wählen" ? "Ohne Typ" : typ
        }

        let reihenfolge = AboType.allCases.map(\.rawValue)

        return gruppiert
            .map { typ, abos in
                (typ: typ, abos: abos.sorted { $0.erstelltAm < $1.erstelltAm })
            }
            .sorted { links, rechts in
                let linkerIndex = reihenfolge.firstIndex(of: links.typ) ?? Int.max
                let rechterIndex = reihenfolge.firstIndex(of: rechts.typ) ?? Int.max

                if linkerIndex == rechterIndex {
                    return links.typ < rechts.typ
                }

                return linkerIndex < rechterIndex
            }
    }

    func makeAboItem(
        _ abo: AboEintrag,
        fallbackIndex: Int,
        options: DossierPDFExportOptions
    ) -> DossierPDFItem? {
        makeGroupedItem(
            label: aboTitel(abo, fallbackIndex: fallbackIndex),
            values: aboLines(abo, options: options),
            options: options
        )
    }

    func aboLines(_ abo: AboEintrag, options: DossierPDFExportOptions) -> [String?] {
        var lines: [String?]

        switch abo.aboTyp {
        case "Streamingdienst":
            lines = []

        case "Social Media":
            lines = []

        case "Digitale Identitäten":
            lines = [
                makeLine(label: "Benutzername / E-Mail", value: abo.benutzername)
            ]

        case "E-Mail-Konten":
            lines = [
                makeLine(label: "E-Mail-Adresse", value: abo.benutzername)
            ]

        case "Meine Geräte", "Mein Mobile Telefon":
            let geraeteArt = abo.geraeteArt.isEmpty ? abo.aboArt : abo.geraeteArt
            lines = [
                makeSelectableLine(label: "Geräteart", value: geraeteArt),
                makeLine(label: "Gerät", value: abo.geraeteBezeichnung),
                geraeteArt == "Mobile Telefon" ? nil : makeLine(label: "Benutzername / Anmeldung", value: abo.benutzername)
            ]
            if options.sensibleDatenEinschliessen {
                lines.append(makeLine(label: "PIN / Code", value: abo.geraetePIN.isEmpty ? abo.passwort : abo.geraetePIN))
            }

        case "Zeitschriften":
            lines = [makeLine(label: "Name der Zeitschrift", value: abo.bezeichnung)]

        case "Öffentlicher Verkehr":
            lines = [
                makeSelectableLine(label: "ÖV-Unternehmen", value: abo.oevUnternehmen),
                makeSelectableLine(label: "ÖV-Abo-Typ", value: abo.oevAboTyp),
                makeLine(label: "Abo-Nr.", value: abo.aboNummer)
            ]

        case "Software / Apps", "Software / App":
            lines = [
                makeLine(label: "Name", value: abo.bezeichnung),
                abo.istSystemEintrag ? makeLine(label: "Benutzername", value: abo.benutzername) : nil,
                abo.istSystemEintrag ? "Hinweis: Automatisch aus der Registrierung" : nil
            ]

        case "Fitness / Sport":
            lines = [
                makeLine(label: "Um was handelt es sich?", value: abo.bezeichnung),
                makeLine(label: "Aboart", value: abo.aboArt),
                makeLine(label: "Unternehmen", value: abo.unternehmen)
            ]

        case "Online Zeitschriften", "Online-Zeitschrift":
            lines = [
                makeLine(label: "Um was handelt es sich?", value: abo.bezeichnung),
                makeLine(label: "Aboart", value: abo.aboArt),
                makeLine(label: "Unternehmen", value: abo.unternehmen)
            ]

        case "Mitgliedschaft":
            lines = [
                makeLine(label: "Aboart", value: abo.aboArt),
                makeLine(label: "Abo-Nr.", value: abo.aboNummer)
            ]

        case "Mobile & Internet":
            lines = [
                makeLine(label: "Vertragsdetails", value: abo.mobileInternetVertragsdetails)
            ]

        default:
            lines = [
                makeSelectableLine(label: "Anbieter", value: abo.anbieter),
                makeLine(label: "Unternehmen", value: abo.unternehmen),
                makeLine(label: "Aboart", value: abo.aboArt),
                makeLine(label: "Abo-Nr.", value: abo.aboNummer)
            ]
        }

        if options.sensibleDatenEinschliessen && shouldAppendLoginFields(abo) {
            lines.append(makeLine(label: "Benutzername", value: abo.benutzername))
            lines.append(makeLine(label: "Passwort", value: abo.passwort))
        } else if options.sensibleDatenEinschliessen && shouldAppendPasswordOnly(abo) {
            lines.append(makeLine(label: "Passwort", value: abo.passwort))
        }

        lines.append(makeLine(label: "Bankkonto", value: abo.bankkontoName))
        lines.append(makeLine(label: "Bankkonto-Art", value: abo.bankkontoArt))
        lines.append(makeLine(label: "Notizen", value: abo.notizen))

        if !abo.istAktiv {
            lines.append("Aktiv: Nein")
        }

        return lines
    }

    func aboTitel(_ abo: AboEintrag, fallbackIndex: Int) -> String {
        [
            abo.anbieter,
            abo.streamingAnbieter,
            abo.socialMediaPlattform,
            abo.emailAnbieter,
            abo.digitaleIdentitaetAnbieter,
            abo.mobileInternetAnbieter,
            abo.unternehmen,
            abo.geraeteBezeichnung
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty && $0 != "Bitte wählen" } ?? "Eintrag \(fallbackIndex)"
    }

    func shouldAppendLoginFields(_ abo: AboEintrag) -> Bool {
        abo.aboTyp != "Meine Geräte" &&
        abo.aboTyp != "Mein Mobile Telefon" &&
        abo.aboTyp != "Digitale Identitäten" &&
        abo.aboTyp != "E-Mail-Konten" &&
        !(abo.istSystemEintrag && (abo.aboTyp == "Software / Apps" || abo.aboTyp == "Software / App"))
    }

    func shouldAppendPasswordOnly(_ abo: AboEintrag) -> Bool {
        abo.aboTyp == "Digitale Identitäten" ||
        abo.aboTyp == "E-Mail-Konten" ||
        ((abo.aboTyp == "Software / Apps" || abo.aboTyp == "Software / App") && abo.istSystemEintrag)
    }

    func makeMedicalItem(
        label: String,
        value: String,
        emptyValue: String,
        options: DossierPDFExportOptions
    ) -> DossierPDFItem? {
        if value == emptyValue && !options.leereFelderAnzeigen {
            return nil
        }

        return makeItem(label: label, value: value, options: options)
    }

    func hausarztAdresse(_ gesundheit: GesundheitModell) -> String {
        [gesundheit.hausarztAdresse, gesundheit.hausarztPLZ, gesundheit.hausarztOrt]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    func makeStatusItem(label: String, isPresent: Bool) -> DossierPDFItem {
        DossierPDFItem(
            label: label,
            wert: isPresent ? "✓ vorhanden" : "○ keine Angabe",
            status: isPresent ? .vorhanden : .nichtVorhanden
        )
    }

    func makeGroupedItem(
        label: String,
        values: [String?],
        options: DossierPDFExportOptions
    ) -> DossierPDFItem? {
        let value = values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return makeItem(label: label, value: value, options: options)
    }

    func makeLine(label: String, value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        return "\(label): \(trimmedValue)"
    }

    func makeSelectableLine(label: String, value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty && trimmedValue != "Bitte wählen" else { return nil }
        return "\(label): \(trimmedValue)"
    }

    func makeAmountLine(label: String, amount: Double, currency: String) -> String? {
        guard amount != 0 else { return nil }
        return "\(label): \(formattedAmount(amount, currency: currency))"
    }

    func formattedAmount(_ amount: Double, currency: String) -> String {
        let formattedNumber = amount.formatted(.number.precision(.fractionLength(0...2)))
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrency.isEmpty ? formattedNumber : "\(formattedNumber) \(trimmedCurrency)"
    }

    func makeDocumentStatusItem(
        label: String,
        isPresent: Bool,
        fileName: String,
        uploadedAt: Date?,
        options: DossierPDFExportOptions
    ) -> DossierPDFItem? {
        if !isPresent && !options.leereFelderAnzeigen {
            return nil
        }

        var details = isPresent ? "✓ vorhanden" : "○ keine Angabe"
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFileName.isEmpty {
            details += "\nDatei: \(trimmedFileName)"
        }
        if let uploadedAt {
            details += "\nHochgeladen am: \(dateFormatter.string(from: uploadedAt))"
        }

        return DossierPDFItem(
            label: label,
            wert: details,
            status: isPresent ? .vorhanden : .nichtVorhanden
        )
    }

    func hasContent(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func hasData(_ data: Data?) -> Bool {
        guard let data else { return false }
        return !data.isEmpty
    }

    func hasWuenscheDetails(_ wunsch: WuenscheModell) -> Bool {
        hasContent(wunsch.beisetzungsArt) ||
        hasContent(wunsch.beisetzungHinweis) ||
        hasContent(wunsch.sonstigeBemerkungen) ||
        hasContent(wunsch.musikWunsch) ||
        hasContent(wunsch.zeremonieDetails) ||
        hasContent(wunsch.letzteBotschaft) ||
        hasContent(wunsch.nachrufText) ||
        hasContent(wunsch.mirIstWichtig)
    }

    func hasHaustierDetails(_ wunsch: WuenscheModell) -> Bool {
        guard let haustiereData = wunsch.haustiereData,
              let haustiere = try? JSONDecoder().decode([DossierHaustierExportEintrag].self, from: haustiereData) else {
            return false
        }

        return haustiere.contains { haustier in
            hasContent(haustier.art) ||
            hasContent(haustier.name) ||
            hasContent(haustier.tierarzt) ||
            hasContent(haustier.bemerkungen)
        }
    }

    func hasHausarztDetails(_ gesundheit: GesundheitModell) -> Bool {
        hasContent(gesundheit.hausarztName) ||
        hasContent(gesundheit.hausarztTelefon) ||
        hasContent(gesundheit.hausarztEmail) ||
        hasContent(gesundheit.hausarztAdresse) ||
        hasContent(gesundheit.hausarztPLZ) ||
        hasContent(gesundheit.hausarztOrt)
    }

    func hasMedizinischeDetails(_ gesundheit: GesundheitModell) -> Bool {
        gesundheit.blutgruppe != GesundheitBlutgruppe.unbekannt ||
        gesundheit.organspende != GesundheitOrganspendeStatus.nichtAngegeben ||
        hasContent(gesundheit.allergien) ||
        hasContent(gesundheit.medikamente) ||
        hasContent(gesundheit.gesundheitlicheHinweise)
    }

    func latestDate(_ primaryDate: Date?, _ additionalDates: [Date]) -> Date? {
        ([primaryDate].compactMap { $0 } + additionalDates).max()
    }
}

private struct DossierHaustierExportEintrag: Decodable {
    let art: String
    let name: String
    let tierarzt: String
    let bemerkungen: String

    var anzeigename: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
