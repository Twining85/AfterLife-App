import SwiftUI
import SwiftData
import ContactsUI
import PhotosUI
import UniformTypeIdentifiers
import QuickLook
import AVKit

struct WuenscheView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteWuensche: [WuenscheModell]
    @Query private var gespeicherteHinterbliebeneKontakte: [HinterbliebeneModell]
    @State private var wuenscheGeladen = false
    @State private var kontakteGeladen = false
    @State private var hatBesondereWuensche = true

    @State private var bestattungsart: Bestattungsart = .kremation
    @State private var bestattungswuensche = ""
    @State private var kremationHinweise = ""
    @State private var erdbestattungHinweise = ""
    @State private var sonstigeBemerkungen = ""

    @State private var keineBlumengeschenkeBitte = false
    @State private var besondereMusik = false
    @State private var besondereMusikText = ""

    @State private var zeremonie = false
    @State private var zeremonieText = ""
    @State private var zeremonieBereitsOrganisiert = false
    @State private var zeremonieOrganisiertDetails = ""
    @State private var zeremonieFinanziellAbgesichert = false

    @State private var moechteNochWasSagen = false
    @State private var letzteWorteText = ""
    @State private var letzteWorteVideoAuswahl: PhotosPickerItem?
    @State private var letzteWorteVideoData: Data?
    @State private var letzteWorteVideoName: String?
    @State private var letzteWorteVideoURL: URL?
    @State private var letzteWorteVideoVorschauAnzeigen = false
    @State private var letzteWorteVideoPlayer: AVPlayer?

    @State private var nachrufVorstellung = false
    @State private var nachrufText = ""
    @State private var nachrufBildAuswahl: PhotosPickerItem?
    @State private var nachrufBildData: Data?

    @State private var kontakte: [BeisetzungsKontakt] = []
    @State private var ausgeklappteKontaktIDs: Set<UUID> = []
    @State private var kontaktPickerAnzeigen = false

    @State private var hatHaustiere = false
    @State private var haustiere: [WuenschePetEntry] = []
    @State private var ausgeklappteHaustierIDs: Set<UUID> = []
    @State private var haustierPopupAnzeigen = false

    @State private var hatTestament = false
    @State private var testamentAblageort = ""
    @State private var testamentDateiName: String?
    @State private var testamentDateiURL: URL?
    @State private var testamentDateiData: Data?
    @State private var testamentHochgeladenAm: Date?
    @State private var testamentErinnerungAktiv = true
    @State private var testamentErinnerungDatum = Date()

    @State private var hatPatientenverfuegung = false
    @State private var patientenverfuegungDateiName: String?
    @State private var patientenverfuegungDateiURL: URL?
    @State private var patientenverfuegungDateiData: Data?
    @State private var patientenverfuegungHochgeladenAm: Date?
    @State private var patientenverfuegungErinnerungAktiv = true
    @State private var patientenverfuegungErinnerungDatum = Date()

    @State private var hatVorsorgeauftrag = false
    @State private var vorsorgeauftragDateiName: String?
    @State private var vorsorgeauftragDateiURL: URL?
    @State private var vorsorgeauftragDateiData: Data?
    @State private var vorsorgeauftragHochgeladenAm: Date?
    @State private var vorsorgeauftragErinnerungAktiv = true
    @State private var vorsorgeauftragErinnerungDatum = Date()

    @State private var offenFuerSterbebegleitung = false
    @State private var sterbebegleitungDateiName: String?
    @State private var sterbebegleitungDateiURL: URL?
    @State private var sterbebegleitungDateiData: Data?
    @State private var sterbebegleitungHochgeladenAm: Date?
    @State private var sterbebegleitungErinnerungAktiv = true
    @State private var sterbebegleitungErinnerungDatum = Date()

    @State private var hatSchwereGesundheitlicheErkrankung = false
    @State private var schwereErkrankung: SchwereErkrankung?
    @State private var sterbebegleitungWichtig = ""
    @State private var lebensqualitaetRegelmaessigBeurteilen = true

    @State private var dokumentImporterAnzeigen = false
    @State private var aktiverDokumentTyp: DokumentTyp?
    @State private var dokumentVorschauURL: URL?

    private let wuenscheCardColor = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let wuenscheAccentColor = Color(red: 0.72, green: 0.42, blue: 0.28)
    private let wuenscheBackgroundColor = Color(red: 0.985, green: 0.975, blue: 0.955)


    private var kontakteSpeicherSignatur: String {
        kontakte.map { kontakt in
            [
                kontakt.id.uuidString,
                kontakt.vorname,
                kontakt.name,
                kontakt.strasse,
                kontakt.hausnummer,
                kontakt.plz,
                kontakt.ort,
                kontakt.telefon,
                kontakt.email,
                kontakt.art.rawValue,
                String(kontakt.informieren),
                String(kontakt.einladen)
            ].joined(separator: "|")
        }
        .joined(separator: "#")
    }

    private var wuenscheSpeicherSignatur: String {
        [
            String(hatBesondereWuensche),
            bestattungsart.rawValue,
            bestattungswuensche,
            kremationHinweise,
            erdbestattungHinweise,
            sonstigeBemerkungen,
            String(keineBlumengeschenkeBitte),
            String(besondereMusik),
            besondereMusikText,
            String(zeremonie),
            zeremonieText,
            String(zeremonieBereitsOrganisiert),
            zeremonieOrganisiertDetails,
            String(zeremonieFinanziellAbgesichert),
            String(moechteNochWasSagen),
            letzteWorteText,
            letzteWorteVideoName ?? "",
            letzteWorteVideoData?.count.description ?? "",
            String(nachrufVorstellung),
            nachrufText,
            nachrufBildData?.base64EncodedString() ?? "",
            String(hatTestament),
            testamentAblageort,
            testamentDateiName ?? "",
            testamentDateiData?.count.description ?? "",
            testamentHochgeladenAm?.timeIntervalSince1970.description ?? "",
            String(testamentErinnerungAktiv),
            testamentErinnerungDatum.timeIntervalSince1970.description,
            String(hatPatientenverfuegung),
            patientenverfuegungDateiName ?? "",
            patientenverfuegungDateiData?.count.description ?? "",
            patientenverfuegungHochgeladenAm?.timeIntervalSince1970.description ?? "",
            String(patientenverfuegungErinnerungAktiv),
            patientenverfuegungErinnerungDatum.timeIntervalSince1970.description,
            String(hatVorsorgeauftrag),
            vorsorgeauftragDateiName ?? "",
            vorsorgeauftragDateiData?.count.description ?? "",
            vorsorgeauftragHochgeladenAm?.timeIntervalSince1970.description ?? "",
            String(vorsorgeauftragErinnerungAktiv),
            vorsorgeauftragErinnerungDatum.timeIntervalSince1970.description,
            String(offenFuerSterbebegleitung),
            sterbebegleitungDateiName ?? "",
            sterbebegleitungDateiData?.count.description ?? "",
            sterbebegleitungHochgeladenAm?.timeIntervalSince1970.description ?? "",
            String(sterbebegleitungErinnerungAktiv),
            sterbebegleitungErinnerungDatum.timeIntervalSince1970.description,
            String(hatSchwereGesundheitlicheErkrankung),
            schwereErkrankung?.rawValue ?? "",
            sterbebegleitungWichtig,
            String(lebensqualitaetRegelmaessigBeurteilen),
            String(hatHaustiere),
            (try? JSONEncoder().encode(haustiere))?.base64EncodedString() ?? ""
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hauptToggleSection

                    if hatBesondereWuensche {
                        beisetzungSection
                        beisetzungsWuenscheSection
                        kontakteSection
                        haustiereSection
                        nachlassSection
                        patientenverfuegungSection
                        vorsorgeauftragSection
                        sterbebegleitungSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(wuenscheBackgroundColor.ignoresSafeArea())
            .navigationTitle("Meine Wünsche")
            .tint(wuenscheAccentColor)
            .sheet(isPresented: $kontaktPickerAnzeigen) {
                KontaktPicker { kontakt in
                    kontakte.append(kontakt)
                    synchronisiereKontakteMitHinterbliebenen()
                    kontaktPickerAnzeigen = false
                }
            }
            .sheet(isPresented: $haustierPopupAnzeigen) {
                HaustierErfassungView { haustier in
                    haustiere.append(haustier)
                    haustierPopupAnzeigen = false
                }
            }
            .fileImporter(
                isPresented: $dokumentImporterAnzeigen,
                allowedContentTypes: [.pdf, .image, .text, .plainText, .rtf, .data],
                allowsMultipleSelection: false
            ) { result in
                dokumentImportVerarbeiten(result)
            }
            .quickLookPreview($dokumentVorschauURL)
            .onChange(of: nachrufBildAuswahl) { _, neueAuswahl in
                Task {
                    if let data = try? await neueAuswahl?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            nachrufBildData = data
                            speichereWuensche()
                        }
                    }
                }
            }
            .onChange(of: letzteWorteVideoAuswahl) { _, neueAuswahl in
                Task {
                    guard let neueAuswahl else { return }

                    if let data = try? await neueAuswahl.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            letzteWorteVideoData = data
                            letzteWorteVideoName = "Persönliche Botschaft.mov"
                            bereiteLetzteWorteVideoVorschauVor(sichtbar: true)
                        }
                    }
                }
            }
            .onAppear {
                ladeOderErstelleWuensche()
                ladeKontakteAusHinterbliebenen()
            }
            .onChange(of: wuenscheSpeicherSignatur) { _, _ in
                speichereWuensche()
            }
            .onChange(of: kontakteSpeicherSignatur) { _, _ in
                synchronisiereKontakteMitHinterbliebenen()
            }
        }
    }

    private var haustiereSection: some View {
        styleGuideSection(titel: "Haustiere", systemImage: "pawprint.fill") {
            Toggle("Ich habe Haustiere", isOn: $hatHaustiere)
                .tint(wuenscheAccentColor)

            if hatHaustiere {
                if haustiere.isEmpty {
                    leerText("Noch keine Haustiere erfasst.")
                }

                ForEach($haustiere) { haustier in
                    if haustiere.count > 2 {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { ausgeklappteHaustierIDs.contains(haustier.wrappedValue.id) },
                                set: { istOffen in
                                    if istOffen {
                                        ausgeklappteHaustierIDs.insert(haustier.wrappedValue.id)
                                    } else {
                                        ausgeklappteHaustierIDs.remove(haustier.wrappedValue.id)
                                    }
                                }
                            )
                        ) {
                            haustierDetailFormular(haustier: haustier)
                        } label: {
                            listHeader(title: haustier.wrappedValue.anzeigename, subtitle: haustier.wrappedValue.art.rawValue, icon: "pawprint")
                        }
                        .tint(wuenscheAccentColor)
                    } else {
                        haustierDetailFormular(haustier: haustier)
                    }
                }
                .onDelete(perform: haustierLoeschen)

                accentButton(title: "Haustier erfassen", systemImage: "plus.circle.fill") {
                    haustierPopupAnzeigen = true
                }
            }
        }
    }

    @ViewBuilder
    private func haustierDetailFormular(haustier: Binding<WuenschePetEntry>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Art", selection: haustier.art) {
                ForEach(HaustierArt.allCases) { art in
                    Text(art.rawValue).tag(art)
                }
            }
            .tint(wuenscheAccentColor)

            styledTextField("Name", text: haustier.name)
            styledTextField("Tierarzt", text: haustier.tierarzt)
            styledTextField("Bemerkungen", text: haustier.bemerkungen, axis: .vertical, lineLimit: 2...6)
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hauptToggleSection: some View {
        styleGuideSection(titel: "Meine Wünsche", systemImage: "heart.text.square.fill") {
            Toggle("Ich habe besondere Wünsche nach meinem Tod", isOn: $hatBesondereWuensche)
                .tint(wuenscheAccentColor)
        }
    }

    private var beisetzungSection: some View {
        styleGuideSection(titel: "Meine Beisetzung", systemImage: "leaf.fill") {
            styledTextField("Bestattungswünsche", text: $bestattungswuensche, axis: .vertical, lineLimit: 3...8)

            Picker("Bestattungsart", selection: $bestattungsart) {
                ForEach(Bestattungsart.allCases) { art in
                    Text(art.rawValue).tag(art)
                }
            }
            .pickerStyle(.segmented)
            .tint(wuenscheAccentColor)

            if bestattungsart == .kremation {
                styledTextField("Was ist bei der Kremation zu beachten? z.B. Art der Urne, Urnengrab, Waldfriedhof", text: $kremationHinweise, axis: .vertical, lineLimit: 3...8)
            }

            if bestattungsart == .erdbestattung {
                styledTextField("Was ist bei der Erdbestattung zu beachten? z.B. Art des Sarges, Kleidung, Ort und Ablauf", text: $erdbestattungHinweise, axis: .vertical, lineLimit: 3...8)
            }

            styledTextField("Sonstige Bemerkungen", text: $sonstigeBemerkungen, axis: .vertical, lineLimit: 3...8)
        }
    }

    private var beisetzungsWuenscheSection: some View {
        styleGuideSection(titel: "Wünsche zur Beisetzung", systemImage: "sparkles") {
            Toggle("Keine Blumengeschenke, bitte spendet das Geld lieber", isOn: $keineBlumengeschenkeBitte)
                .tint(wuenscheAccentColor)
            Toggle("Zeremonie", isOn: $zeremonie)
                .tint(wuenscheAccentColor)

            if zeremonie {
                DetailBox(accentColor: wuenscheAccentColor) {
                    styledTextField("Wie soll die Zeremonie gestaltet sein?", text: $zeremonieText, axis: .vertical, lineLimit: 2...6)

                    Divider()

                    Toggle("Bereits organisiert", isOn: $zeremonieBereitsOrganisiert)
                        .tint(wuenscheAccentColor)

                    if zeremonieBereitsOrganisiert {
                        DetailBox(accentColor: wuenscheAccentColor) {
                            styledTextField("Details zur Organisation", text: $zeremonieOrganisiertDetails, axis: .vertical, lineLimit: 2...6)
                        }
                    }

                    Divider()

                    Button {
                        zeremonieFinanziellAbgesichert.toggle()
                    } label: {
                        HStack {
                            Image(systemName: zeremonieFinanziellAbgesichert ? "checkmark.square.fill" : "square")
                                .foregroundStyle(wuenscheAccentColor)
                            Text("Finanziell abgesichert, diese zu begleichen")
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle("Besondere Musik", isOn: $besondereMusik)
                .tint(wuenscheAccentColor)

            if besondereMusik {
                DetailBox(accentColor: wuenscheAccentColor) {
                    styledTextField("Welche Musik soll gespielt werden?", text: $besondereMusikText, axis: .vertical, lineLimit: 2...6)
                }
            }

            Toggle("Persönliche Botschaft", isOn: $moechteNochWasSagen)
                .tint(wuenscheAccentColor)

            if moechteNochWasSagen {
                DetailBox(accentColor: wuenscheAccentColor) {
                    styledTextField("Was möchtest du noch sagen?", text: $letzteWorteText, axis: .vertical, lineLimit: 3...8)

                    Divider()

                    VStack(spacing: 12) {
                        if letzteWorteVideoData != nil {
                            if letzteWorteVideoVorschauAnzeigen, let letzteWorteVideoPlayer {
                                VideoPlayer(player: letzteWorteVideoPlayer)
                                    .frame(height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        } else {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 44))
                                .foregroundStyle(wuenscheAccentColor.opacity(0.75))
                        }

                        PhotosPicker(
                            selection: $letzteWorteVideoAuswahl,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            Label(letzteWorteVideoData == nil ? "Video hochladen" : "Video ändern", systemImage: "video.badge.plus")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(wuenscheAccentColor)

                        if letzteWorteVideoData != nil {
                            Button(role: .destructive) {
                                letzteWorteVideoEntfernen()
                            } label: {
                                Label("Video entfernen", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            nachrufBlock
        }
    }

    private var nachrufBlock: some View {
        Group {
            Toggle("Ich habe eine Vorstellung, wie der Nachruf sein soll", isOn: $nachrufVorstellung)
                .tint(wuenscheAccentColor)

            if nachrufVorstellung {
                DetailBox(accentColor: wuenscheAccentColor) {
                    styledTextField("Wie soll der Nachruf sein? z.B Zeitung, Karte", text: $nachrufText, axis: .vertical, lineLimit: 3...8)

                    Divider()

                    VStack(spacing: 12) {
                        if let nachrufBildData,
                           let uiImage = UIImage(data: nachrufBildData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .clipped()
                        } else {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(wuenscheAccentColor.opacity(0.75))
                        }

                        PhotosPicker(
                            selection: $nachrufBildAuswahl,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(nachrufBildData == nil ? "Bild für Nachruf hochladen" : "Bild für Nachruf ändern", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(wuenscheAccentColor)

                        if nachrufBildData != nil {
                            Button(role: .destructive) {
                                nachrufBildEntfernen()
                            } label: {
                                Label("Bild entfernen", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var kontakteSection: some View {
        styleGuideSection(titel: "Personen informieren / einladen", systemImage: "person.2.fill") {
            if kontakte.isEmpty {
                leerText("Noch keine Kontakte erfasst.")
            }

            ForEach($kontakte) { $kontakt in
                kontaktEintragView(kontakt: $kontakt)
            }
            .onDelete(perform: kontaktLoeschen)

            accentButton(title: "Aus Adressbuch hinzufügen", systemImage: "person.crop.circle.badge.plus") {
                kontaktPickerAnzeigen = true
            }
        }
    }

    @ViewBuilder
    private func kontaktEintragView(kontakt: Binding<BeisetzungsKontakt>) -> some View {
        if kontakte.count > 3 {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { ausgeklappteKontaktIDs.contains(kontakt.wrappedValue.id) },
                    set: { istOffen in
                        if istOffen {
                            ausgeklappteKontaktIDs.insert(kontakt.wrappedValue.id)
                        } else {
                            ausgeklappteKontaktIDs.remove(kontakt.wrappedValue.id)
                        }
                    }
                )
            ) {
                kontaktDetailFormular(kontakt: kontakt)
            } label: {
                listHeader(title: kontakt.wrappedValue.anzeigename, subtitle: kontakt.wrappedValue.art.rawValue, icon: "person.fill")
            }
        } else {
            kontaktDetailFormular(kontakt: kontakt)
        }
    }

    private var nachlassSection: some View {
        styleGuideSection(titel: "Nachlass", systemImage: "doc.text.fill") {
            Toggle("Ich habe ein Testament", isOn: $hatTestament)
                .tint(wuenscheAccentColor)

            if hatTestament {
                DetailBox(accentColor: wuenscheAccentColor) {
                    Text("Ein Testament muss den gesetzlichen und formellen Anforderungen entsprechen. Du bist selbst dafür verantwortlich, dass Inhalt, Form und Aufbewahrung korrekt und rechtsgültig sind. Diese App ersetzt keine rechtliche Beratung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    styledTextField("Ablageort", text: $testamentAblageort, axis: .vertical, lineLimit: 2...4)
                        .textContentType(.location)

                    Divider()

                    DokumentUploadBox(
                        accentColor: wuenscheAccentColor,
                        dateiName: testamentDateiName,
                        hochgeladenAm: testamentHochgeladenAm,
                        timestampTitel: "Testament hochgeladen am",
                        uploadTitel: testamentDateiName == nil ? "Testament hochladen" : "Testament ändern",
                        entfernenTitel: "Testament entfernen",
                        erinnerungAktiv: $testamentErinnerungAktiv,
                        erinnerungDatum: $testamentErinnerungDatum,
                        vorschauAktion: {
                            dokumentVorschauAnzeigen(testamentDateiURL, dateiName: testamentDateiName, dateiData: testamentDateiData)
                        },
                        uploadAktion: {
                            dokumentImportStarten(.testament)
                        },
                        entfernenAktion: {
                            testamentDateiEntfernen()
                        }
                    )
                }
            }
        }
    }

    private var patientenverfuegungSection: some View {
        styleGuideSection(titel: "Patientenverfügung", systemImage: "cross.case.fill") {
            Toggle("Ich habe eine Patientenverfügung", isOn: $hatPatientenverfuegung)
                .tint(wuenscheAccentColor)

            if hatPatientenverfuegung {
                DetailBox(accentColor: wuenscheAccentColor) {
                    DokumentUploadBox(
                        accentColor: wuenscheAccentColor,
                        dateiName: patientenverfuegungDateiName,
                        hochgeladenAm: patientenverfuegungHochgeladenAm,
                        timestampTitel: "Patientenverfügung hochgeladen am",
                        uploadTitel: patientenverfuegungDateiName == nil ? "Patientenverfügung hochladen" : "Patientenverfügung ändern",
                        entfernenTitel: "Patientenverfügung entfernen",
                        erinnerungAktiv: $patientenverfuegungErinnerungAktiv,
                        erinnerungDatum: $patientenverfuegungErinnerungDatum,
                        vorschauAktion: {
                            dokumentVorschauAnzeigen(patientenverfuegungDateiURL, dateiName: patientenverfuegungDateiName, dateiData: patientenverfuegungDateiData)
                        },
                        uploadAktion: {
                            dokumentImportStarten(.patientenverfuegung)
                        },
                        entfernenAktion: {
                            patientenverfuegungDateiEntfernen()
                        }
                    )
                }
            }
        }
    }

    private var vorsorgeauftragSection: some View {
        styleGuideSection(titel: "Vorsorgeauftrag", systemImage: "checkmark.shield.fill") {
            Toggle("Ich habe einen Vorsorgeauftrag", isOn: $hatVorsorgeauftrag)
                .tint(wuenscheAccentColor)

            if hatVorsorgeauftrag {
                DetailBox(accentColor: wuenscheAccentColor) {
                    DokumentUploadBox(
                        accentColor: wuenscheAccentColor,
                        dateiName: vorsorgeauftragDateiName,
                        hochgeladenAm: vorsorgeauftragHochgeladenAm,
                        timestampTitel: "Vorsorgeauftrag hochgeladen am",
                        uploadTitel: vorsorgeauftragDateiName == nil ? "Vorsorgeauftrag hochladen" : "Vorsorgeauftrag ändern",
                        entfernenTitel: "Vorsorgeauftrag entfernen",
                        erinnerungAktiv: $vorsorgeauftragErinnerungAktiv,
                        erinnerungDatum: $vorsorgeauftragErinnerungDatum,
                        vorschauAktion: {
                            dokumentVorschauAnzeigen(vorsorgeauftragDateiURL, dateiName: vorsorgeauftragDateiName, dateiData: vorsorgeauftragDateiData)
                        },
                        uploadAktion: {
                            dokumentImportStarten(.vorsorgeauftrag)
                        },
                        entfernenAktion: {
                            vorsorgeauftragDateiEntfernen()
                        }
                    )
                }
            }
        }
    }

    private var sterbebegleitungSection: some View {
        styleGuideSection(titel: "Sterbebegleitung", systemImage: "hands.sparkles.fill") {
            Toggle("Ich bin offen für eine Sterbebegleitung", isOn: $offenFuerSterbebegleitung)
                .tint(wuenscheAccentColor)

            if offenFuerSterbebegleitung {
                DetailBox(accentColor: wuenscheAccentColor) {
                    Toggle("Ich habe eine schwerwiegende gesundheitliche Erkrankung", isOn: $hatSchwereGesundheitlicheErkrankung)
                        .tint(wuenscheAccentColor)

                    if hatSchwereGesundheitlicheErkrankung {
                        DetailBox(accentColor: wuenscheAccentColor) {
                            Picker("Erkrankung", selection: $schwereErkrankung) {
                                Text("Bitte wählen").tag(nil as SchwereErkrankung?)
                                ForEach(SchwereErkrankung.allCases) { erkrankung in
                                    Text(erkrankung.rawValue).tag(erkrankung as SchwereErkrankung?)
                                }
                            }
                            .tint(wuenscheAccentColor)

                            styledTextField("Das ist für mich wichtig", text: $sterbebegleitungWichtig, axis: .vertical, lineLimit: 3...8)

                            if schwereErkrankung != nil {
                                Toggle(
                                    "Ich möchte regelmässig bewusst beurteilen, ob mein Leben für mich noch lebenswert ist und welcher Weg sich für mich stimmig anfühlt.",
                                    isOn: $lebensqualitaetRegelmaessigBeurteilen
                                )
                                .tint(wuenscheAccentColor)
                            }
                        }
                    }

                    Divider()

                    DokumentUploadBox(
                        accentColor: wuenscheAccentColor,
                        dateiName: sterbebegleitungDateiName,
                        hochgeladenAm: sterbebegleitungHochgeladenAm,
                        timestampTitel: "Sterbebegleitung hochgeladen am",
                        uploadTitel: sterbebegleitungDateiName == nil ? "Dokument zur Sterbebegleitung hochladen" : "Dokument zur Sterbebegleitung ändern",
                        entfernenTitel: "Dokument zur Sterbebegleitung entfernen",
                        erinnerungAktiv: $sterbebegleitungErinnerungAktiv,
                        erinnerungDatum: $sterbebegleitungErinnerungDatum,
                        vorschauAktion: {
                            dokumentVorschauAnzeigen(sterbebegleitungDateiURL, dateiName: sterbebegleitungDateiName, dateiData: sterbebegleitungDateiData)
                        },
                        uploadAktion: {
                            dokumentImportStarten(.sterbebegleitung)
                        },
                        entfernenAktion: {
                            sterbebegleitungDateiEntfernen()
                        }
                    )
                }
            }
        }
    }

    private func ladeOderErstelleWuensche() {
        guard !wuenscheGeladen else { return }

        if let vorhandeneWuensche = gespeicherteWuensche.first {
            hatBesondereWuensche = vorhandeneWuensche.hatWuensche
            bestattungsart = Bestattungsart(rawValue: vorhandeneWuensche.beisetzungsArt) ?? .kremation
            bestattungswuensche = vorhandeneWuensche.beisetzungHinweis
            sonstigeBemerkungen = vorhandeneWuensche.sonstigeBemerkungen

            if bestattungsart == .kremation {
                kremationHinweise = vorhandeneWuensche.beisetzungHinweis
            } else {
                erdbestattungHinweise = vorhandeneWuensche.beisetzungHinweis
            }

            keineBlumengeschenkeBitte = vorhandeneWuensche.keineBlumengeschenkeBitte
            besondereMusik = vorhandeneWuensche.besondereMusik
            besondereMusikText = vorhandeneWuensche.musikWunsch

            zeremonie = vorhandeneWuensche.zeremonieGewuenscht
            zeremonieText = vorhandeneWuensche.zeremonieDetails
            zeremonieBereitsOrganisiert = vorhandeneWuensche.zeremonieOrganisiert
            zeremonieFinanziellAbgesichert = vorhandeneWuensche.zeremonieFinanziellAbgesichert

            moechteNochWasSagen = vorhandeneWuensche.moechteNochEtwasSagen

            letzteWorteText = vorhandeneWuensche.letzteBotschaft

            letzteWorteVideoName = vorhandeneWuensche.letzteBotschaftVideoName.isEmpty ? nil : vorhandeneWuensche.letzteBotschaftVideoName

            letzteWorteVideoData = vorhandeneWuensche.letzteBotschaftVideoData

            if letzteWorteVideoData != nil {

                bereiteLetzteWorteVideoVorschauVor(sichtbar: true)

            }
            nachrufVorstellung = vorhandeneWuensche.nachrufGewuenscht
            nachrufText = vorhandeneWuensche.nachrufText
            nachrufBildData = vorhandeneWuensche.nachrufBildData

            hatTestament = vorhandeneWuensche.testamentVorhanden
            testamentAblageort = vorhandeneWuensche.testamentAblageort
            testamentDateiName = vorhandeneWuensche.testamentDateiName.isEmpty ? nil : vorhandeneWuensche.testamentDateiName
            testamentDateiData = vorhandeneWuensche.testamentDateiData
            testamentHochgeladenAm = vorhandeneWuensche.testamentHochgeladenAm
            testamentErinnerungAktiv = vorhandeneWuensche.testamentErinnerungAktiv
            testamentErinnerungDatum = vorhandeneWuensche.testamentErinnerungAm ?? Date()

            hatPatientenverfuegung = vorhandeneWuensche.patientenverfuegungVorhanden
            patientenverfuegungDateiName = vorhandeneWuensche.patientenverfuegungDateiName.isEmpty ? nil : vorhandeneWuensche.patientenverfuegungDateiName
            patientenverfuegungDateiData = vorhandeneWuensche.patientenverfuegungDateiData
            patientenverfuegungHochgeladenAm = vorhandeneWuensche.patientenverfuegungHochgeladenAm
            patientenverfuegungErinnerungAktiv = vorhandeneWuensche.patientenverfuegungErinnerungAktiv
            patientenverfuegungErinnerungDatum = vorhandeneWuensche.patientenverfuegungErinnerungAm ?? Date()

            hatVorsorgeauftrag = vorhandeneWuensche.vorsorgeauftragVorhanden
            vorsorgeauftragDateiName = vorhandeneWuensche.vorsorgeauftragDateiName.isEmpty ? nil : vorhandeneWuensche.vorsorgeauftragDateiName
            vorsorgeauftragDateiData = vorhandeneWuensche.vorsorgeauftragDateiData
            vorsorgeauftragHochgeladenAm = vorhandeneWuensche.vorsorgeauftragHochgeladenAm
            vorsorgeauftragErinnerungAktiv = vorhandeneWuensche.vorsorgeauftragErinnerungAktiv
            vorsorgeauftragErinnerungDatum = vorhandeneWuensche.vorsorgeauftragErinnerungAm ?? Date()

            offenFuerSterbebegleitung = vorhandeneWuensche.sterbebegleitungGewuenscht
            sterbebegleitungDateiName = vorhandeneWuensche.sterbebegleitungDateiName.isEmpty ? nil : vorhandeneWuensche.sterbebegleitungDateiName
            sterbebegleitungDateiData = vorhandeneWuensche.sterbebegleitungDateiData
            sterbebegleitungHochgeladenAm = vorhandeneWuensche.sterbebegleitungHochgeladenAm
            sterbebegleitungErinnerungAktiv = vorhandeneWuensche.sterbebegleitungErinnerungAktiv
            sterbebegleitungErinnerungDatum = vorhandeneWuensche.sterbebegleitungErinnerungAm ?? Date()

            hatSchwereGesundheitlicheErkrankung = vorhandeneWuensche.schwereErkrankungVorhanden
            schwereErkrankung = SchwereErkrankung(rawValue: vorhandeneWuensche.schwereErkrankungArt)
            sterbebegleitungWichtig = vorhandeneWuensche.mirIstWichtig
            lebensqualitaetRegelmaessigBeurteilen = vorhandeneWuensche.regelmaessigBeurteilen

            hatHaustiere = vorhandeneWuensche.hatHaustiere
            if let data = vorhandeneWuensche.haustiereData {
                haustiere = (try? JSONDecoder().decode([WuenschePetEntry].self, from: data)) ?? []
            }
        } else {
            let neueWuensche = WuenscheModell()
            modelContext.insert(neueWuensche)
        }

        wuenscheGeladen = true
    }

    private func speichereWuensche() {
        guard wuenscheGeladen else { return }

        let wuensche: WuenscheModell

        if let vorhandeneWuensche = gespeicherteWuensche.first {
            wuensche = vorhandeneWuensche
        } else {
            let neueWuensche = WuenscheModell()
            modelContext.insert(neueWuensche)
            wuensche = neueWuensche
        }

        wuensche.hatWuensche = hatBesondereWuensche
        wuensche.beisetzungsArt = bestattungsart.rawValue

        switch bestattungsart {
        case .kremation:
            wuensche.beisetzungHinweis = kremationHinweise.isEmpty ? bestattungswuensche : kremationHinweise
        case .erdbestattung:
            wuensche.beisetzungHinweis = erdbestattungHinweise.isEmpty ? bestattungswuensche : erdbestattungHinweise
        }

        wuensche.sonstigeBemerkungen = sonstigeBemerkungen
        wuensche.keineBlumengeschenkeBitte = keineBlumengeschenkeBitte
        wuensche.besondereMusik = besondereMusik
        wuensche.musikWunsch = besondereMusikText
        wuensche.zeremonieGewuenscht = zeremonie
        wuensche.zeremonieDetails = zeremonieText
        wuensche.zeremonieOrganisiert = zeremonieBereitsOrganisiert
        wuensche.zeremonieFinanziellAbgesichert = zeremonieFinanziellAbgesichert
        wuensche.moechteNochEtwasSagen = moechteNochWasSagen
        wuensche.letzteBotschaft = letzteWorteText
        wuensche.letzteBotschaftVideoName = letzteWorteVideoName ?? ""
        wuensche.letzteBotschaftVideoData = letzteWorteVideoData
        wuensche.nachrufGewuenscht = nachrufVorstellung
        wuensche.nachrufText = nachrufText
        wuensche.nachrufBildData = nachrufBildData

        wuensche.testamentVorhanden = hatTestament
        wuensche.testamentAblageort = testamentAblageort
        wuensche.testamentDateiName = testamentDateiName ?? ""
        wuensche.testamentDateiData = testamentDateiData
        wuensche.testamentHochgeladenAm = testamentHochgeladenAm
        wuensche.testamentErinnerungAktiv = testamentErinnerungAktiv
        wuensche.testamentErinnerungAm = testamentErinnerungDatum

        wuensche.patientenverfuegungVorhanden = hatPatientenverfuegung
        wuensche.patientenverfuegungDateiName = patientenverfuegungDateiName ?? ""
        wuensche.patientenverfuegungDateiData = patientenverfuegungDateiData
        wuensche.patientenverfuegungHochgeladenAm = patientenverfuegungHochgeladenAm
        wuensche.patientenverfuegungErinnerungAktiv = patientenverfuegungErinnerungAktiv
        wuensche.patientenverfuegungErinnerungAm = patientenverfuegungErinnerungDatum

        wuensche.vorsorgeauftragVorhanden = hatVorsorgeauftrag
        wuensche.vorsorgeauftragDateiName = vorsorgeauftragDateiName ?? ""
        wuensche.vorsorgeauftragDateiData = vorsorgeauftragDateiData
        wuensche.vorsorgeauftragHochgeladenAm = vorsorgeauftragHochgeladenAm
        wuensche.vorsorgeauftragErinnerungAktiv = vorsorgeauftragErinnerungAktiv
        wuensche.vorsorgeauftragErinnerungAm = vorsorgeauftragErinnerungDatum

        wuensche.sterbebegleitungGewuenscht = offenFuerSterbebegleitung
        wuensche.sterbebegleitungDateiName = sterbebegleitungDateiName ?? ""
        wuensche.sterbebegleitungDateiData = sterbebegleitungDateiData
        wuensche.sterbebegleitungHochgeladenAm = sterbebegleitungHochgeladenAm
        wuensche.sterbebegleitungErinnerungAktiv = sterbebegleitungErinnerungAktiv
        wuensche.sterbebegleitungErinnerungAm = sterbebegleitungErinnerungDatum

        wuensche.schwereErkrankungVorhanden = hatSchwereGesundheitlicheErkrankung
        wuensche.schwereErkrankungArt = schwereErkrankung?.rawValue ?? ""
        wuensche.mirIstWichtig = sterbebegleitungWichtig
        wuensche.regelmaessigBeurteilen = lebensqualitaetRegelmaessigBeurteilen
        wuensche.hatHaustiere = hatHaustiere
        wuensche.haustiereData = try? JSONEncoder().encode(haustiere)
    }

    private func haustierLoeschen(at offsets: IndexSet) {
        for index in offsets {
            if haustiere.indices.contains(index) {
                ausgeklappteHaustierIDs.remove(haustiere[index].id)
            }
        }

        haustiere.remove(atOffsets: offsets)
    }


    private func kontaktLoeschen(at offsets: IndexSet) {
        for index in offsets {
            if kontakte.indices.contains(index) {
                ausgeklappteKontaktIDs.remove(kontakte[index].id)
            }
        }

        kontakte.remove(atOffsets: offsets)
        synchronisiereKontakteMitHinterbliebenen()
    }



    private func ladeKontakteAusHinterbliebenen() {
        guard !kontakteGeladen else { return }

        let gespeicherteWuenscheKontakte = gespeicherteHinterbliebeneKontakte
            .filter { $0.quelle == "WuenscheView" || $0.bemerkungen == "Quelle: WuenscheView" }
            .sorted { $0.erstelltAm < $1.erstelltAm }

        kontakte = gespeicherteWuenscheKontakte.map { gespeicherterKontakt in
            let adressTeile = getrennteAdresseAusText(gespeicherterKontakt.adresse)

            return BeisetzungsKontakt(
                id: UUID(uuidString: gespeicherterKontakt.rolle.components(separatedBy: "|").last ?? "") ?? UUID(),
                vorname: gespeicherterKontakt.vorname,
                name: gespeicherterKontakt.name,
                strasse: adressTeile.strasse,
                hausnummer: adressTeile.hausnummer,
                plz: adressTeile.plz,
                ort: adressTeile.ort,
                telefon: gespeicherterKontakt.telefon,
                email: gespeicherterKontakt.email,
                art: kontaktArtAusBeziehung(gespeicherterKontakt.beziehung),
                informieren: gespeicherterKontakt.sollInformiertWerden,
                einladen: gespeicherterKontakt.darfDokumenteErhalten
            )
        }

        kontakteGeladen = true
    }

    private func synchronisiereKontakteMitHinterbliebenen() {
        guard kontakteGeladen else { return }

        let gueltigeKontakte = kontakte.filter { kontakt in
            !kontakt.vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.strasse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.hausnummer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.plz.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.ort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.telefon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !kontakt.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let gueltigeIDs = Set(gueltigeKontakte.map { $0.id.uuidString })

        let gespeicherteWuenscheKontakte = gespeicherteHinterbliebeneKontakte.filter {
            $0.quelle == "WuenscheView" || $0.bemerkungen == "Quelle: WuenscheView"
        }

        for gespeicherterKontakt in gespeicherteWuenscheKontakte {
            let gespeicherteID = kontaktIDAusRolle(gespeicherterKontakt.rolle)

            if !gueltigeIDs.contains(gespeicherteID) {
                modelContext.delete(gespeicherterKontakt)
            }
        }

        for kontakt in gueltigeKontakte {
            let kontaktID = kontakt.id.uuidString

            let passendeKontakteNachID = gespeicherteWuenscheKontakte.filter {
                kontaktIDAusRolle($0.rolle) == kontaktID
            }

            let passendeKontakteNachInhalt = gespeicherteHinterbliebeneKontakte.filter {
                istGleicherKontakt($0, wie: kontakt)
            }

            let passendeKontakte = passendeKontakteNachID + passendeKontakteNachInhalt.filter { inhaltKontakt in
                !passendeKontakteNachID.contains { idKontakt in
                    idKontakt === inhaltKontakt
                }
            }

            let zielKontakt: HinterbliebeneModell

            if let bestehenderKontakt = passendeKontakte.first {
                zielKontakt = bestehenderKontakt

                passendeKontakte.dropFirst().forEach { doppelterKontakt in
                    modelContext.delete(doppelterKontakt)
                }
            } else {
                let neuerKontakt = HinterbliebeneModell(
                    quelle: "WuenscheView"
                )
                modelContext.insert(neuerKontakt)
                zielKontakt = neuerKontakt
            }

            zielKontakt.vorname = kontakt.vorname
            zielKontakt.name = kontakt.name
            zielKontakt.rolle = "\(kontakt.art.rawValue)|\(kontakt.id.uuidString)"
            zielKontakt.beziehung = beziehungFuerKontaktArt(kontakt.art)
            zielKontakt.telefon = kontakt.telefon
            zielKontakt.email = kontakt.email
            zielKontakt.adresse = kontakt.vollstaendigeAdresse
            zielKontakt.quelle = zielKontakt.quelle.isEmpty ? "WuenscheView" : zielKontakt.quelle
            zielKontakt.istVertrauensperson = zielKontakt.istVertrauensperson
            zielKontakt.sollInformiertWerden = kontakt.informieren
            zielKontakt.darfDokumenteErhalten = kontakt.einladen
            zielKontakt.aktualisiertAm = Date()
        }
    }

    private func kontaktIDAusRolle(_ rolle: String) -> String {
        rolle.components(separatedBy: "|").last ?? ""
    }

    private func istGleicherKontakt(_ gespeicherterKontakt: HinterbliebeneModell, wie kontakt: BeisetzungsKontakt) -> Bool {
        let gespeicherteEmail = gespeicherterKontakt.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let kontaktEmail = kontakt.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !gespeicherteEmail.isEmpty && gespeicherteEmail == kontaktEmail {
            return true
        }

        let gespeicherteTelefonnummer = normalisierteTelefonnummer(gespeicherterKontakt.telefon)
        let kontaktTelefonnummer = normalisierteTelefonnummer(kontakt.telefon)

        let gespeicherterName = normalisierterName(vorname: gespeicherterKontakt.vorname, name: gespeicherterKontakt.name)
        let kontaktName = normalisierterName(vorname: kontakt.vorname, name: kontakt.name)

        if !gespeicherterName.isEmpty,
           gespeicherterName == kontaktName,
           !gespeicherteTelefonnummer.isEmpty,
           gespeicherteTelefonnummer == kontaktTelefonnummer {
            return true
        }

        let gespeicherteAdresse = gespeicherterKontakt.adresse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let kontaktAdresse = kontakt.vollstaendigeAdresse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !gespeicherterName.isEmpty,
           gespeicherterName == kontaktName,
           !gespeicherteAdresse.isEmpty,
           gespeicherteAdresse == kontaktAdresse {
            return true
        }

        return false
    }

    private func normalisierterName(vorname: String, name: String) -> String {
        [vorname, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalisierteTelefonnummer(_ telefon: String) -> String {
        telefon.filter { $0.isNumber }
    }

    private func getrennteAdresseAusText(_ adresse: String) -> (strasse: String, hausnummer: String, plz: String, ort: String) {
        let zeilen = adresse
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let ersteZeile = zeilen.first ?? ""
        let zweiteZeile = zeilen.dropFirst().first ?? ""

        let ersteZeileKomponenten = ersteZeile.components(separatedBy: " ").filter { !$0.isEmpty }
        let hausnummer = ersteZeileKomponenten.last?.rangeOfCharacter(from: .decimalDigits) != nil ? ersteZeileKomponenten.last ?? "" : ""
        let strasse = hausnummer.isEmpty ? ersteZeile : ersteZeileKomponenten.dropLast().joined(separator: " ")

        let zweiteZeileKomponenten = zweiteZeile.components(separatedBy: " ").filter { !$0.isEmpty }
        let plz = zweiteZeileKomponenten.first?.allSatisfy(\.isNumber) == true ? zweiteZeileKomponenten.first ?? "" : ""
        let ort = plz.isEmpty ? zweiteZeile : zweiteZeileKomponenten.dropFirst().joined(separator: " ")

        return (strasse, hausnummer, plz, ort)
    }

    private func beziehungFuerKontaktArt(_ art: KontaktArt) -> String {
        switch art {
        case .partner:
            return VertrauenspersonKategorie.partner.rawValue
        case .familie:
            return VertrauenspersonKategorie.familie.rawValue
        case .freunde:
            return VertrauenspersonKategorie.freunde.rawValue
        case .anderes:
            return VertrauenspersonKategorie.beguenstigte.rawValue
        }
    }

    private func kontaktArtAusBeziehung(_ beziehung: String) -> KontaktArt {
        switch beziehung {
        case VertrauenspersonKategorie.partner.rawValue:
            return .partner
        case VertrauenspersonKategorie.familie.rawValue:
            return .familie
        case VertrauenspersonKategorie.freunde.rawValue:
            return .freunde
        default:
            return .anderes
        }
    }

    @ViewBuilder
    private func kontaktDetailFormular(kontakt: Binding<BeisetzungsKontakt>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Art", selection: kontakt.art) {
                ForEach(KontaktArt.allCases) { art in
                    Text(art.rawValue).tag(art)
                }
            }

            kontaktAnzeigeZeile(titel: "Vorname", wert: kontakt.wrappedValue.vorname)
            kontaktAnzeigeZeile(titel: "Name", wert: kontakt.wrappedValue.name)
            kontaktAnzeigeZeile(titel: "Strasse", wert: kontakt.wrappedValue.strasse)
            kontaktAnzeigeZeile(titel: "Hausnummer", wert: kontakt.wrappedValue.hausnummer)
            kontaktAnzeigeZeile(titel: "PLZ", wert: kontakt.wrappedValue.plz)
            kontaktAnzeigeZeile(titel: "Ort", wert: kontakt.wrappedValue.ort)
            kontaktAnzeigeZeile(titel: "Telefonnummer", wert: kontakt.wrappedValue.telefon)
            kontaktAnzeigeZeile(titel: "E-Mail", wert: kontakt.wrappedValue.email)

            Toggle("Informieren", isOn: kontakt.informieren)
                .tint(wuenscheAccentColor)
            Toggle("Zur Beisetzung einladen", isOn: kontakt.einladen)
                .tint(wuenscheAccentColor)
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func styleGuideSection<Content: View>(titel: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(wuenscheAccentColor))

                Text(titel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wuenscheCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private func styledTextField(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil
    ) -> some View {
        if let lineLimit {
            TextField(placeholder, text: text, axis: axis)
                .lineLimit(lineLimit)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(wuenscheAccentColor.opacity(0.18), lineWidth: 1)
                )
        } else {
            TextField(placeholder, text: text, axis: axis)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(wuenscheAccentColor.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private func accentButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(wuenscheAccentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func leerText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func listHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(wuenscheAccentColor)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.85)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func kontaktAnzeigeZeile(titel: String, wert: String) -> some View {
        let bereinigterWert = wert.trimmingCharacters(in: .whitespacesAndNewlines)

        if !bereinigterWert.isEmpty {
            HStack(alignment: .top) {
                Text(titel)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                Text(bereinigterWert)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
    }


    private func nachrufBildEntfernen() {
        nachrufBildData = nil
        nachrufBildAuswahl = nil
        speichereWuensche()
    }

    private func letzteWorteVideoEntfernen() {
        letzteWorteVideoData = nil
        letzteWorteVideoName = nil
        letzteWorteVideoAuswahl = nil
        letzteWorteVideoURL = nil
        letzteWorteVideoVorschauAnzeigen = false
        speichereWuensche()
    }

    private func oeffneLetzteWorteVideo() {
        if letzteWorteVideoVorschauAnzeigen {
            letzteWorteVideoPlayer?.pause()
            letzteWorteVideoVorschauAnzeigen = false
        } else {
            bereiteLetzteWorteVideoVorschauVor(sichtbar: true)
        }
    }

    private func bereiteLetzteWorteVideoVorschauVor(sichtbar: Bool) {
        guard let letzteWorteVideoData else { return }

        let dateiname = letzteWorteVideoName?.isEmpty == false
            ? letzteWorteVideoName!
            : "Persönliche_Botschaft.mov"

        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname)

        do {
            try letzteWorteVideoData.write(to: videoURL, options: .atomic)
            letzteWorteVideoURL = videoURL
            letzteWorteVideoPlayer = AVPlayer(url: videoURL)
            letzteWorteVideoVorschauAnzeigen = sichtbar
        } catch {
            print("Video konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
    }

    private func dokumentVorschauAnzeigen(_ url: URL?, dateiName: String?, dateiData: Data?) {
        if let url {
            dokumentVorschauURL = url
            return
        }
        guard let dateiName,
              let dateiData,
              let tempURL = temporaereDateiURL(dateiName: dateiName, dateiData: dateiData) else { return }
        dokumentVorschauURL = tempURL
    }

    private func temporaereDateiURL(dateiName: String, dateiData: Data) -> URL? {
        let bereinigterName = dateiName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(bereinigterName)

        do {
            try dateiData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func dokumentImportStarten(_ typ: DokumentTyp) {
        aktiverDokumentTyp = typ
        dokumentImporterAnzeigen = true
    }

    private func dokumentImportVerarbeiten(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let hatZugriffErhalten = url.startAccessingSecurityScopedResource()
            defer {
                if hatZugriffErhalten {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let dateiData = try? Data(contentsOf: url)

            switch aktiverDokumentTyp {
            case .testament:
                testamentDateiURL = url
                testamentDateiName = url.lastPathComponent
                testamentDateiData = dateiData
                testamentHochgeladenAm = Date()
                testamentErinnerungAktiv = true
                testamentErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .patientenverfuegung:
                patientenverfuegungDateiURL = url
                patientenverfuegungDateiName = url.lastPathComponent
                patientenverfuegungDateiData = dateiData
                patientenverfuegungHochgeladenAm = Date()
                patientenverfuegungErinnerungAktiv = true
                patientenverfuegungErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .vorsorgeauftrag:
                vorsorgeauftragDateiURL = url
                vorsorgeauftragDateiName = url.lastPathComponent
                vorsorgeauftragDateiData = dateiData
                vorsorgeauftragHochgeladenAm = Date()
                vorsorgeauftragErinnerungAktiv = true
                vorsorgeauftragErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .sterbebegleitung:
                sterbebegleitungDateiURL = url
                sterbebegleitungDateiName = url.lastPathComponent
                sterbebegleitungDateiData = dateiData
                sterbebegleitungHochgeladenAm = Date()
                sterbebegleitungErinnerungAktiv = true
                sterbebegleitungErinnerungDatum = erinnerungsDatumInEinemJahr()
            case .none:
                break
            }
            speichereWuensche()
        case .failure:
            break
        }

        aktiverDokumentTyp = nil
    }

    private func testamentDateiEntfernen() {
        testamentDateiName = nil
        testamentDateiURL = nil
        testamentDateiData = nil
        testamentHochgeladenAm = nil
        testamentErinnerungAktiv = true
        testamentErinnerungDatum = Date()
        speichereWuensche()
    }

    private func patientenverfuegungDateiEntfernen() {
        patientenverfuegungDateiName = nil
        patientenverfuegungDateiURL = nil
        patientenverfuegungDateiData = nil
        patientenverfuegungHochgeladenAm = nil
        patientenverfuegungErinnerungAktiv = true
        patientenverfuegungErinnerungDatum = Date()
        speichereWuensche()
    }

    private func vorsorgeauftragDateiEntfernen() {
        vorsorgeauftragDateiName = nil
        vorsorgeauftragDateiURL = nil
        vorsorgeauftragDateiData = nil
        vorsorgeauftragHochgeladenAm = nil
        vorsorgeauftragErinnerungAktiv = true
        vorsorgeauftragErinnerungDatum = Date()
        speichereWuensche()
    }

    private func sterbebegleitungDateiEntfernen() {
        sterbebegleitungDateiName = nil
        sterbebegleitungDateiURL = nil
        sterbebegleitungDateiData = nil
        sterbebegleitungHochgeladenAm = nil
        sterbebegleitungErinnerungAktiv = true
        sterbebegleitungErinnerungDatum = Date()
        speichereWuensche()
    }

    private func erinnerungsDatumInEinemJahr() -> Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }
}

enum Bestattungsart: String, CaseIterable, Identifiable {
    case kremation = "Kremation"
    case erdbestattung = "Erdbestattung"

    var id: String { rawValue }
}

enum KontaktArt: String, CaseIterable, Identifiable, Codable {
    case partner = "Partner"
    case familie = "Familie"
    case freunde = "Freunde"
    case anderes = "Andere"

    var id: String { rawValue }
}

enum DokumentTyp {
    case testament
    case patientenverfuegung
    case vorsorgeauftrag
    case sterbebegleitung
}

enum SchwereErkrankung: String, CaseIterable, Identifiable {
    case demenz = "Demenz"
    case alzheimer = "Alzheimer"
    case fortgeschrittenerKrebs = "Fortgeschrittener Krebs"
    case andere = "Andere"

    var id: String { rawValue }
}

struct BeisetzungsKontakt: Identifiable, Codable, Equatable {
    var id = UUID()
    var vorname = ""
    var name = ""
    var strasse = ""
    var hausnummer = ""
    var plz = ""
    var ort = ""
    var telefon = ""
    var email = ""
    var art: KontaktArt = .familie
    var informieren = true
    var einladen = true

    var anzeigename: String {
        let nameTeile = [vorname, name].filter { !$0.isEmpty }
        return nameTeile.isEmpty ? "Unbenannter Kontakt" : nameTeile.joined(separator: " ")
    }

    var vollstaendigeAdresse: String {
        let strasseUndHausnummer = [strasse, hausnummer]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let plzUndOrt = [plz, ort]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return [strasseUndHausnummer, plzUndOrt]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct KontaktPicker: UIViewControllerRepresentable {
    let kontaktAusgewaehlt: (BeisetzungsKontakt) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPostalAddressesKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(kontaktAusgewaehlt: kontaktAusgewaehlt)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let kontaktAusgewaehlt: (BeisetzungsKontakt) -> Void

        init(kontaktAusgewaehlt: @escaping (BeisetzungsKontakt) -> Void) {
            self.kontaktAusgewaehlt = kontaktAusgewaehlt
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let adressTeile = contact.postalAddresses.first.map { adresseAufteilen($0.value) } ?? (strasse: "", hausnummer: "", plz: "", ort: "")
            let telefon = contact.phoneNumbers.first?.value.stringValue ?? ""
            let email = contact.emailAddresses.first.map { String($0.value) } ?? ""

            let beisetzungsKontakt = BeisetzungsKontakt(
                vorname: contact.givenName,
                name: contact.familyName,
                strasse: adressTeile.strasse,
                hausnummer: adressTeile.hausnummer,
                plz: adressTeile.plz,
                ort: adressTeile.ort,
                telefon: telefon,
                email: email
            )

            kontaktAusgewaehlt(beisetzungsKontakt)
        }

        private func adresseAufteilen(_ adresse: CNPostalAddress) -> (strasse: String, hausnummer: String, plz: String, ort: String) {
            let strassenKomponenten = adresse.street.components(separatedBy: " ").filter { !$0.isEmpty }
            let hausnummer = strassenKomponenten.last?.rangeOfCharacter(from: .decimalDigits) != nil ? strassenKomponenten.last ?? "" : ""
            let strasse = hausnummer.isEmpty ? adresse.street : strassenKomponenten.dropLast().joined(separator: " ")

            return (
                strasse: strasse,
                hausnummer: hausnummer,
                plz: adresse.postalCode,
                ort: adresse.city
            )
        }
    }
}



struct DetailBox<Content: View>: View {
    var accentColor: Color = Color(red: 0.72, green: 0.42, blue: 0.28)
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.16), lineWidth: 1)
        )
    }
}

struct DokumentUploadBox: View {
    var accentColor: Color = Color(red: 0.72, green: 0.42, blue: 0.28)
    let dateiName: String?
    let hochgeladenAm: Date?
    let timestampTitel: String
    let uploadTitel: String
    let entfernenTitel: String
    @Binding var erinnerungAktiv: Bool
    @Binding var erinnerungDatum: Date
    let vorschauAktion: () -> Void
    let uploadAktion: () -> Void
    let entfernenAktion: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button {
                uploadAktion()
            } label: {
                Image(systemName: "doc.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(accentColor))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(uploadTitel)

            if let dateiName {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(accentColor)

                    Button {
                        vorschauAktion()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateiName)
                                .font(.footnote)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            if let hochgeladenAm {
                                Text("\(timestampTitel) \(hochgeladenAm.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dokument Vorschau öffnen")

                    Spacer()

                    Button {
                        vorschauAktion()
                    } label: {
                        Image(systemName: "eye.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Dokument anzeigen")

                    Button(role: .destructive) {
                        entfernenAktion()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(entfernenTitel)
                }
                .padding(12)
                .background(Color.white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Divider()

                Toggle("Erinnerung zur Überprüfung", isOn: $erinnerungAktiv)
                    .tint(accentColor)

                if erinnerungAktiv {
                    DatePicker(
                        "Überprüfung am",
                        selection: $erinnerungDatum,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "de_CH"))
                    .tint(accentColor)
                }
            } else {
                Text("Noch kein Dokument hochgeladen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    WuenscheView()
        .modelContainer(for: [WuenscheModell.self, HinterbliebeneModell.self], inMemory: true)
}



struct WuenschePetEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var art: HaustierArt = .hund
    var name = ""
    var tierarzt = ""
    var bemerkungen = ""

    var anzeigename: String {
        let bereinigterName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return bereinigterName.isEmpty ? "Unbenanntes Haustier" : bereinigterName
    }
}

enum HaustierArt: String, CaseIterable, Identifiable, Codable {
    case hund = "Hund"
    case katze = "Katze"
    case pferd = "Pferd"
    case vogel = "Vogel"
    case kaninchen = "Kaninchen"
    case meerschweinchen = "Meerschweinchen"
    case hamster = "Hamster"
    case reptil = "Reptil"
    case fisch = "Fisch"
    case anderes = "Anderes"

    var id: String { rawValue }
}

struct HaustierErfassungView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var art: HaustierArt = .hund
    @State private var name = ""
    @State private var tierarzt = ""
    @State private var bemerkungen = ""

    let onSave: (WuenschePetEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Art", selection: $art) {
                    ForEach(HaustierArt.allCases) { art in
                        Text(art.rawValue).tag(art)
                    }
                }

                TextField("Name", text: $name)
                TextField("Tierarzt", text: $tierarzt)
                TextField("Bemerkungen", text: $bemerkungen, axis: .vertical)
                    .lineLimit(2...6)
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.985, green: 0.975, blue: 0.955))
            .navigationTitle("Haustier erfassen")
            .tint(Color(red: 0.72, green: 0.42, blue: 0.28))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(
                            WuenschePetEntry(
                                art: art,
                                name: name,
                                tierarzt: tierarzt,
                                bemerkungen: bemerkungen
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
