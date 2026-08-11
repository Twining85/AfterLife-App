//
//  Herzensstuecke.swift
//  Tschluessli
//
//  Created by René Engeler on 06.08.2026.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct HerzensstueckeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HerzensstueckModell.erstelltAm) private var herzensstuecke: [HerzensstueckModell]
    @AppStorage("aktivesDossierID") private var aktivesDossierID = ""

    @State private var ausgewaehltesHerzensstueck: HerzensstueckModell?
    @State private var limitHinweisAnzeigen = false

    private let akzent = Color(red: 0.78, green: 0.34, blue: 0.16)
    private let hintergrund = Color(red: 0.985, green: 0.975, blue: 0.955)
    private let karte = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let maximaleAnzahl = 7

    var body: some View {
        NavigationStack {
            List {
                hero
                    .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 9, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if herzensstuecke.isEmpty {
                    leerzustand
                        .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(herzensstuecke) { stueck in
                        Button {
                            ausgewaehltesHerzensstueck = stueck
                        } label: {
                            HerzensstueckKarte(stueck: stueck, akzent: akzent, karte: karte)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                loesche(stueck)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                loesche(stueck)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    neuesHerzensstueck()
                } label: {
                    Label("Neues Herzensstück", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(akzent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(herzensstuecke.count >= maximaleAnzahl)
                .opacity(herzensstuecke.count >= maximaleAnzahl ? 0.45 : 1)
                .listRowInsets(EdgeInsets(top: 11, leading: 16, bottom: 34, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(hintergrund.ignoresSafeArea())
            .navigationTitle("Herzensstücke")
            .tint(akzent)
            .sheet(item: $ausgewaehltesHerzensstueck) { stueck in
                HerzensstueckEditor(stueck: stueck)
            }
            .alert("Sieben Herzensstücke", isPresented: $limitHinweisAnzeigen) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Du hast bereits sieben Herzensstücke ausgewählt. Entferne eines, bevor du ein neues hinzufügst.")
            }
        }
        .dossierFloatingNavigation(.herzensstuecke)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "archivebox.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(akzent, in: Circle())
                    .shadow(color: akzent.opacity(0.25), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dinge mit Bedeutung")
                        .font(.title3.weight(.semibold))

                    Text("Bewahre die Geschichten hinter den Gegenständen, die dir besonders viel bedeuten.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("\(herzensstuecke.count) von \(maximaleAnzahl) hinzugefügt")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(akzent)
                    Spacer()
                    Text("Maximal sieben")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: Double(herzensstuecke.count), total: Double(maximaleAnzahl))
                    .tint(akzent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(karte, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(akzent.opacity(0.12)) }
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private var leerzustand: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox.and.arrow.backward")
                .font(.system(size: 34))
                .foregroundStyle(akzent)
            Text("Noch kein Herzensstück")
                .font(.headline)
            Text("Welcher Gegenstand ist dir wichtig und erzählt eine Geschichte, die deine Liebsten kennen sollten?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 24))
    }

    private func neuesHerzensstueck() {
        guard herzensstuecke.count < maximaleAnzahl else {
            limitHinweisAnzeigen = true
            return
        }
        let stueck = HerzensstueckModell(dossierID: UUID(uuidString: aktivesDossierID))
        modelContext.insert(stueck)
        try? modelContext.save()
        ausgewaehltesHerzensstueck = stueck
    }

    private func loesche(_ stueck: HerzensstueckModell) {
        modelContext.delete(stueck)
        try? modelContext.save()
        VorsorgeBereichStatusStore.markiereBearbeitet(.herzensstuecke)
    }
}

private struct HerzensstueckKarte: View {
    let stueck: HerzensstueckModell
    let akzent: Color
    let karte: Color

    var body: some View {
        HStack(spacing: 14) {
            vorschaubild

            VStack(alignment: .leading, spacing: 6) {
                Text(stueck.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbenanntes Herzensstück" : stueck.titel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Label(bestimmungsText, systemImage: "arrow.turn.down.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(akzent.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(karte, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(akzent.opacity(0.10)) }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    @ViewBuilder
    private var vorschaubild: some View {
        if let daten = stueck.bilder.sorted(by: { $0.reihenfolge < $1.reihenfolge }).first?.bildDaten,
           let bild = UIImage(data: daten) {
            Image(uiImage: bild)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(akzent)
                .frame(width: 72, height: 72)
                .background(akzent.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var bestimmungsText: String {
        if stueck.bestimmung == .verschenken, !stueck.empfaengerName.isEmpty {
            return "An \(stueck.empfaengerName) verschenken"
        }
        if stueck.bestimmung == .andere, !stueck.andereBestimmung.isEmpty {
            return stueck.andereBestimmung
        }
        return stueck.bestimmung.rawValue
    }
}

private struct HerzensstueckEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var kontakte: [HinterbliebeneModell]
    @Bindable var stueck: HerzensstueckModell

    @State private var fotoAuswahl: [PhotosPickerItem] = []
    @State private var dokumentImporterAnzeigen = false
    @State private var audioImporterAnzeigen = false
    @State private var vollbildBild: HerzensstueckBildModell?
    @State private var audioExportURL: URL?

    private let akzent = Color(red: 0.78, green: 0.34, blue: 0.16)
    private let hintergrund = Color(red: 0.985, green: 0.975, blue: 0.955)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    bilderBereich
                    textBereich
                    bestimmungsBereich
                    wertBereich
                    dokumentBereich
                    audioBereich
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(hintergrund.ignoresSafeArea())
            .navigationTitle(stueck.titel.isEmpty ? "Neues Herzensstück" : stueck.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        speichern()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onDisappear { speichern() }
            .onChange(of: fotoAuswahl) { _, items in
                Task { await fotosLaden(items) }
            }
            .sheet(isPresented: $dokumentImporterAnzeigen) {
                DocumentPicker { urls in
                    importiereDokumente(urls)
                }
            }
            .fileImporter(isPresented: $audioImporterAnzeigen, allowedContentTypes: [.audio], allowsMultipleSelection: false) { ergebnis in
                importiereAudio(ergebnis)
            }
            .sheet(item: $vollbildBild) { bild in
                NavigationStack {
                    Group {
                        if let uiBild = UIImage(data: bild.bildDaten) {
                            Image(uiImage: uiBild).resizable().scaledToFit().background(Color.black)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar { Button("Schliessen") { vollbildBild = nil } }
                }
            }
            .sheet(isPresented: Binding(
                get: { audioExportURL != nil },
                set: { wirdAngezeigt in
                    if !wirdAngezeigt {
                        entferneAudioExportdatei()
                    }
                }
            )) {
                if let audioExportURL {
                    ShareSheet(activityItems: [audioExportURL])
                }
            }
        }
        .tint(akzent)
    }

    private var bilderBereich: some View {
        HerzensstueckEditorKarte(titel: "Fotos", icon: "photo.on.rectangle.angled", akzent: akzent) {
            if !stueck.bilder.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(stueck.bilder.sorted(by: { $0.reihenfolge < $1.reihenfolge })) { bild in
                            if let uiBild = UIImage(data: bild.bildDaten) {
                                Image(uiImage: uiBild)
                                    .resizable().scaledToFill()
                                    .frame(width: 150, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onTapGesture { vollbildBild = bild }
                                    .overlay(alignment: .topTrailing) {
                                        Button { loescheBild(bild) } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3).foregroundStyle(.white, akzent)
                                        }
                                        .padding(7)
                                    }
                            }
                        }
                    }
                }
            }

            PhotosPicker(selection: $fotoAuswahl, maxSelectionCount: 10, matching: .images) {
                Label(stueck.bilder.isEmpty ? "Titelbild auswählen" : "Weitere Fotos hinzufügen", systemImage: "photo.badge.plus")
                    .editorAktionsButton(akzent: akzent)
            }
        }
    }

    private var textBereich: some View {
        HerzensstueckEditorKarte(titel: "Deine Geschichte dazu", icon: "text.book.closed.fill", akzent: akzent) {
            beschriftetesTextfeld("Titel", text: $stueck.titel, prompt: "z. B Zuckerdose meiner Oma")
            beschriftetesTextfeld("Kurze Beschreibung", text: $stueck.beschreibung, prompt: "Ein Gegenstand mit besonderer Bedeutung")
            mehrzeiligesFeld("Warum bedeutet mir dieser Gegenstand so viel?", text: $stueck.geschichte, prompt: "Erzähle die Geschichte hinter diesem Gegenstand. Welche Erinnerung verbindest du damit?")
            mehrzeiligesFeld("Welche Erinnerung verbinde ich damit?", text: $stueck.erinnerung, prompt: "Ein Erlebnis, eine Person oder ein besonderer Moment …")
        }
    }

    private var bestimmungsBereich: some View {
        HerzensstueckEditorKarte(titel: "Was soll später damit passieren?", icon: "arrow.triangle.branch", akzent: akzent) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                ForEach(HerzensstueckBestimmung.allCases) { bestimmung in
                    Button {
                        stueck.bestimmung = bestimmung
                    } label: {
                        Text(bestimmung.rawValue)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .foregroundStyle(stueck.bestimmung == bestimmung ? .white : akzent)
                            .background(stueck.bestimmung == bestimmung ? akzent : akzent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            if stueck.bestimmung == .verschenken {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Person auswählen").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Menu {
                        ForEach(kontakte) { kontakt in
                            Button(kontaktName(kontakt)) {
                                stueck.empfaengerName = kontaktName(kontakt)
                                stueck.empfaengerEmail = kontakt.email
                            }
                        }
                        if kontakte.isEmpty { Text("Noch keine Kontakte hinterlegt") }
                    } label: {
                        HStack {
                            Text(stueck.empfaengerName.isEmpty ? "Kontakt auswählen" : stueck.empfaengerName)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                mehrzeiligesFeld("Persönliche Nachricht (optional)", text: $stueck.persoenlicheNachricht, prompt: "Was soll diese Person über den Gegenstand wissen?")
            }

            if stueck.bestimmung == .andere {
                beschriftetesTextfeld("Andere Bestimmung", text: $stueck.andereBestimmung, prompt: "Dein Wunsch")
            }
        }
    }

    private var wertBereich: some View {
        HerzensstueckEditorKarte(titel: "Geschätzter Wert (optional)", icon: "tag.fill", akzent: akzent) {
            Toggle("Wert angeben", isOn: $stueck.hatGeschaetztenWert)
            if stueck.hatGeschaetztenWert {
                Toggle("Wert unbekannt", isOn: $stueck.wertUnbekannt)
                if !stueck.wertUnbekannt {
                    HStack {
                        Text("CHF").foregroundStyle(.secondary)
                        TextField("0", value: $stueck.geschaetzterWert, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var dokumentBereich: some View {
        HerzensstueckEditorKarte(titel: "Dokumente", icon: "doc.fill", akzent: akzent) {
            ForEach(stueck.dokumente) { dokument in
                HStack {
                    Image(systemName: "doc.text.fill").foregroundStyle(akzent)
                    Text(dokument.dateiName).font(.subheadline).lineLimit(1)
                    Spacer()
                    Button(role: .destructive) { loescheDokument(dokument) } label: { Image(systemName: "trash") }
                }
            }
            Button { dokumentImporterAnzeigen = true } label: {
                Label("Quittung, Zertifikat oder Brief hinzufügen", systemImage: "doc.badge.plus")
                    .editorAktionsButton(akzent: akzent)
            }
        }
    }

    private var audioBereich: some View {
        HerzensstueckEditorKarte(titel: "Ich erzähle die Geschichte", icon: "waveform", akzent: akzent) {
            Text("Eine persönliche Sprachaufnahme bewahrt deine Stimme und die Geschichte dieses Gegenstands.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let audio = stueck.audio {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill").foregroundStyle(akzent)
                    Text(audio.dateiName).font(.subheadline).lineLimit(1)
                    Spacer()
                    Button {
                        audioZumDownloadBereitstellen(audio)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Audio herunterladen")
                    Button(role: .destructive) { loescheAudio() } label: { Image(systemName: "trash") }
                }
            }
            Button { audioImporterAnzeigen = true } label: {
                Label(stueck.audio == nil ? "Audioaufnahme hinzufügen" : "Audio ersetzen", systemImage: "mic.fill")
                    .editorAktionsButton(akzent: akzent)
            }
        }
    }

    private func beschriftetesTextfeld(_ titel: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(prompt, text: text).padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func mehrzeiligesFeld(_ titel: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(prompt).font(.body).foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 8).allowsHitTesting(false)
                }
                TextEditor(text: text).frame(minHeight: 105).scrollContentBackground(.hidden)
            }
            .padding(7).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func kontaktName(_ kontakt: HinterbliebeneModell) -> String {
        let name = "\(kontakt.vorname) \(kontakt.name)".trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? kontakt.email : name
    }

    @MainActor
    private func fotosLaden(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let daten = try? await item.loadTransferable(type: Data.self), UIImage(data: daten) != nil else { continue }
            let bild = HerzensstueckBildModell(dateiName: "Herzensstueck_\(stueck.bilder.count + 1).jpg", bildDaten: daten, reihenfolge: stueck.bilder.count)
            modelContext.insert(bild)
            stueck.bilder.append(bild)
        }
        fotoAuswahl = []
        speichern()
    }

    private func importiereDokumente(_ urls: [URL]) {
        for url in urls {
            guard let daten = leseDatei(url) else { continue }
            let dokument = HerzensstueckDokumentModell(dateiName: url.lastPathComponent, dateiTyp: url.pathExtension, dateiDaten: daten)
            modelContext.insert(dokument)
            stueck.dokumente.append(dokument)
        }
        speichern()
    }

    private func importiereAudio(_ ergebnis: Result<[URL], Error>) {
        guard case .success(let url) = ergebnis, let url = url.first, let daten = leseDatei(url) else { return }
        if let bisherigesAudio = stueck.audio { modelContext.delete(bisherigesAudio) }
        let audio = HerzensstueckAudioModell(dateiName: url.lastPathComponent, dateiTyp: url.pathExtension, audioDaten: daten)
        modelContext.insert(audio)
        stueck.audio = audio
        speichern()
    }

    private func leseDatei(_ url: URL) -> Data? {
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }

    private func loescheBild(_ bild: HerzensstueckBildModell) {
        stueck.bilder.removeAll { $0.id == bild.id }
        modelContext.delete(bild)
        speichern()
    }

    private func loescheDokument(_ dokument: HerzensstueckDokumentModell) {
        stueck.dokumente.removeAll { $0.id == dokument.id }
        modelContext.delete(dokument)
        speichern()
    }

    private func loescheAudio() {
        guard let audio = stueck.audio else { return }
        stueck.audio = nil
        modelContext.delete(audio)
        speichern()
    }

    private func audioZumDownloadBereitstellen(_ audio: HerzensstueckAudioModell) {
        entferneAudioExportdatei()

        var dateiName = URL(fileURLWithPath: audio.dateiName).lastPathComponent
        if dateiName.isEmpty {
            let dateiEndung = audio.dateiTyp.trimmingCharacters(in: .whitespacesAndNewlines)
            dateiName = dateiEndung.isEmpty ? "Audioaufnahme.m4a" : "Audioaufnahme.\(dateiEndung)"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiName)
        do {
            try audio.audioDaten.write(to: url, options: .atomic)
            audioExportURL = url
        } catch {
            audioExportURL = nil
        }
    }

    private func entferneAudioExportdatei() {
        guard let audioExportURL else { return }
        try? FileManager.default.removeItem(at: audioExportURL)
        self.audioExportURL = nil
    }

    private func speichern() {
        stueck.aktualisiertAm = Date()
        try? modelContext.save()
        VorsorgeBereichStatusStore.markiereBearbeitet(.herzensstuecke)
    }
}

private struct HerzensstueckEditorKarte<Content: View>: View {
    let titel: String
    let icon: String
    let akzent: Color
    let content: Content

    init(titel: String, icon: String, akzent: Color, @ViewBuilder content: () -> Content) {
        self.titel = titel
        self.icon = icon
        self.akzent = akzent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(titel, systemImage: icon)
                .font(.headline)
                .foregroundStyle(akzent)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(akzent.opacity(0.10)) }
    }
}

private extension View {
    func editorAktionsButton(akzent: Color) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(akzent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(akzent.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
    }
}

#Preview {
    HerzensstueckeView()
        .modelContainer(for: [HerzensstueckModell.self, HerzensstueckBildModell.self, HerzensstueckDokumentModell.self, HerzensstueckAudioModell.self, HinterbliebeneModell.self], inMemory: true)
}
