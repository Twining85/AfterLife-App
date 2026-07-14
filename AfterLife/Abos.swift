import SwiftUI
import SwiftData

struct AbosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteAboModelle: [AboModell]

    private let abosHintergrundFarbe = Color(red: 0.985, green: 0.975, blue: 0.955)
    private let abosKartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let abosAkzentFarbe = Color(red: 0.46, green: 0.36, blue: 0.62)

    @State private var showAddAboSheet = false
    @State private var aktiverAboSheetKontext: AboSheetKontext?
    @State private var sheetID = UUID()
    @State private var selectedAboID: UUID?
    @State private var selectedAbo: AboEintrag?
    @State private var wurdeInitialisiert = false
    @State private var ausgeklappteAboSektionen: Set<String> = []
    @State private var ausgewaehlteAboTypen: Set<AboType> = []
    @State private var scrollZuAboEintragID: UUID?
    @State private var aboTypDurchSectionVorgegeben = false
    @State private var sectionAboType: AboType?
  

    @State private var selectedAboType: AboType = .pleaseSelect
    @State private var selectedStreamingProvider: StreamingProvider = .pleaseSelect
    @State private var selectedSocialMediaProvider: SocialMediaProvider = .pleaseSelect
    @State private var selectedDigitalIdentityProvider: DigitalIdentityProvider = .pleaseSelect
    @State private var selectedEmailProvider: EmailProvider = .pleaseSelect
    @State private var username = ""
    @State private var password = ""
    @State private var magazineName = ""
    @State private var publicTransportType: PublicTransportAboType = .pleaseSelect
    @State private var publicTransportCompany: PublicTransportCompany = .pleaseSelect
    @State private var customPublicTransportCompany = ""
    @State private var publicTransportAboNumber = ""
    @State private var selectedDeviceType: DeviceType = .pleaseSelect
    @State private var devicePIN = ""
    @State private var softwareName = ""
    @State private var fitnessAboType = ""
    @State private var fitnessCompany = ""
    @State private var onlineMagazineAboType = ""
    @State private var onlineMagazineCompany = ""
    @State private var membershipAboType = ""
    @State private var membershipNumber = ""
    @State private var selectedMobileInternetProvider: MobileInternetProvider = .pleaseSelect
    @State private var customMobileInternetProvider = ""
    @State private var mobileInternetContractDetails = ""
    @State private var customAboName = ""
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 24) {
                        abosHero
                            .padding(.horizontal, 16)
                            .padding(.top, 20)

                        abosTypChips
                            .padding(.horizontal, 16)

                        if (aktuellesAboModell?.abos.isEmpty ?? true) && ausgewaehlteAboTypen.isEmpty {
                            Text("Hier kannst du digitale Abonnemente, Online-Profile, Streamingdienste, ÖV-Abos o.ä erfassen.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(gefilterteGruppierteAbos, id: \.typ) { gruppe in
                                    aboSection(gruppe)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(abosHintergrundFarbe)
                .onChange(of: scrollZuAboEintragID) { _, zielID in
                    guard let zielID else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            scrollProxy.scrollTo(zielID, anchor: .center)
                        }
                        scrollZuAboEintragID = nil
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(abosHintergrundFarbe)
            .tint(abosAkzentFarbe)
            .navigationTitle("Abos & Profile")
            .task {
                ladeOderErstelleAboModellFallsNoetig()
            }
            .sheet(item: $aktiverAboSheetKontext) { sheetKontext in
                NavigationStack {
                    Form {
                        if sheetKontext.typ == .streaming {
                            Section("Streamingdienst") {
                                styledPicker("Anbieter", selection: $selectedStreamingProvider) {
                                    ForEach(StreamingProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if sheetKontext.typ == .socialMedia {
                            Section("Social Media") {
                                styledPicker("Plattform", selection: $selectedSocialMediaProvider) {
                                    ForEach(SocialMediaProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if sheetKontext.typ == .digitalIdentity {
                            Section("Digitale Identität") {
                                styledPicker("Anbieter", selection: $selectedDigitalIdentityProvider) {
                                    ForEach(DigitalIdentityProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("Benutzername / E-Mail", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if sheetKontext.typ == .emailAccount {
                            Section("E-Mail-Konto") {
                                styledPicker("Anbieter", selection: $selectedEmailProvider) {
                                    ForEach(EmailProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("E-Mail-Adresse", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if sheetKontext.typ == .magazine {
                            Section("Zeitschrift") {
                                labelledTextField("Name der Zeitschrift", text: $magazineName)
                            }
                        }
                        if sheetKontext.typ == .publicTransport {
                            Section("Öffentlicher Verkehr") {
                                styledPicker("Art des Abos", selection: $publicTransportType) {
                                    ForEach(PublicTransportAboType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }

                                styledPicker("Unternehmen", selection: $publicTransportCompany) {
                                    ForEach(PublicTransportCompany.allCases) { company in
                                        Text(company.rawValue).tag(company)
                                    }
                                }

                                if publicTransportCompany == .other {
                                    labelledTextField("Unternehmensname", text: $customPublicTransportCompany)
                                }

                                labelledTextField("Abo-Nummer", text: $publicTransportAboNumber)
                            }
                        }
                        if sheetKontext.typ == .devices {
                            Section("Meine Geräte") {
                                styledPicker("Geräteart", selection: $selectedDeviceType) {
                                    ForEach(DeviceType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }

                                labelledTextField("Bezeichnung / Gerät", text: $customAboName)

                                if selectedDeviceType != .mobilePhone {
                                    labelledTextField("Benutzername / Login", text: $username)
                                }

                                labelledTextField("PIN / Code", text: $devicePIN, keyboardType: .numberPad)
                            }
                            }
                        if sheetKontext.typ == .software {
                            Section("Um was handelt es sich?") {
                                labelledTextField("Name App / Software", text: $softwareName)
                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if sheetKontext.typ == .fitness {
                            Section("Um was handelt es sich?") {
                                labelledTextField("Aboart", text: $fitnessAboType)
                                labelledTextField("Unternehmen", text: $fitnessCompany)
                            }
                        }
                        if sheetKontext.typ == .news {
                            Section("Um was handelt es sich?") {
                                labelledTextField("Aboart", text: $onlineMagazineAboType)
                                labelledTextField("Unternehmen", text: $onlineMagazineCompany)
                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if sheetKontext.typ == .membership {
                            Section("Mitgliedschaft") {
                                labelledTextField("Mitglied bei", text: $membershipAboType)
                                labelledTextField("Kontakt", text: $membershipNumber)
                            }
                        }
                        if sheetKontext.typ == .mobileInternet {
                            Section("Mobile & Internet") {
                                styledPicker("Anbieter", selection: $selectedMobileInternetProvider) {
                                    ForEach(MobileInternetProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                if selectedMobileInternetProvider == .other {
                                    labelledTextField("Anbietername", text: $customMobileInternetProvider)
                                }

                                labelledTextField("Vertragsdetails", text: $mobileInternetContractDetails)
                            }
                        }
                        if sheetKontext.typ == .cloudStorage {
                            Section("Cloud-Speicher") {
                                labelledTextField("Dienst / Anbieter", text: $customAboName)
                                labelledTextField("Benutzername / E-Mail", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        
                        if sheetKontext.typ == .other {
                            Section("Anderes Abo") {
                                labelledTextField("Name oder Beschreibung", text: $customAboName)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(abosHintergrundFarbe)
                    .tint(abosAkzentFarbe)
                    .navigationTitle(erfassungsTitel(fuer: sheetKontext.typ))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                showAddAboSheet = false
                                selectedAbo = nil
                                selectedAboID = nil
                                aboTypDurchSectionVorgegeben = false
                                sectionAboType = nil
                                aktiverAboSheetKontext = nil
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                saveAbo()
                                showAddAboSheet = false
                                selectedAbo = nil
                                selectedAboID = nil
                                aboTypDurchSectionVorgegeben = false
                                sectionAboType = nil
                                aktiverAboSheetKontext = nil
                            }
                            .disabled(!canSaveAbo)
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        ladeSelectedAboDetailsFallsVorhanden()
                    }
                }
                .onChange(of: selectedAboID) { _, _ in
                    DispatchQueue.main.async {
                        ladeSelectedAboDetailsFallsVorhanden()
                    }
                }
            }
        }
        .dossierFloatingNavigation(.abos)
    }

    private var abosHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.badge.person.crop.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(abosAkzentFarbe)
                    .frame(width: 40, height: 40)
                    .background(abosAkzentFarbe.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Abos & Profile")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Halte fest, welche digitalen Profile, Geräte, Zugänge und Abonnemente zu deinem digitalen Leben gehören.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(abosKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(abosAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    struct AboSheetKontext: Identifiable {
        let id = UUID()
        let typ: AboType
    }
    
    private var abosTypChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bereiche")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(abosAkzentFarbe)

            AboChipFlowLayout(spacing: 10, rowSpacing: 10) {
                aboChip(
                    title: "Alle",
                    systemImage: "square.grid.2x2.fill",
                    count: anzahlFuerAlleAboTypen,
                    isSelected: ausgewaehlteAboTypen.isEmpty
                ) {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        ausgewaehlteAboTypen.removeAll()
                    }
                }

                ForEach(aboChipTypen) { typ in
                    aboChip(
                        title: typ.chipTitel,
                        systemImage: typ.systemImage,
                        count: anzahlFuerAboTyp(typ),
                        isSelected: ausgewaehlteAboTypen.contains(typ)
                    ) {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                            aboTypAntippen(typ)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboChip(
        title: String,
        systemImage: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? abosAkzentFarbe : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            isSelected ? Color.white.opacity(0.95) : abosAkzentFarbe,
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isSelected ? .white : abosAkzentFarbe)
            .background(
                isSelected ? abosAkzentFarbe : abosKartenFarbe,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(abosAkzentFarbe.opacity(isSelected ? 0 : 0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var aboChipTypen: [AboType] {
        AboType.allCases.filter { $0 != .pleaseSelect }
    }

    private var anzahlFuerAlleAboTypen: Int {
        aktuellesAboModell?.abos.count ?? 0
    }

    private func anzahlFuerAboTyp(_ typ: AboType) -> Int {
        aktuellesAboModell?.abos.filter { $0.aboTyp == typ.rawValue }.count ?? 0
    }

    private func aboTypAntippen(_ typ: AboType) {
        if ausgewaehlteAboTypen.contains(typ) {
            ausgewaehlteAboTypen.remove(typ)
        } else {
            ausgewaehlteAboTypen.insert(typ)
        }

        let alleEinzelTypen = Set(aboChipTypen)

        if ausgewaehlteAboTypen == alleEinzelTypen || ausgewaehlteAboTypen.isEmpty {
            ausgewaehlteAboTypen.removeAll()
        }
    }

    private var gefilterteGruppierteAbos: [(typ: AboType, abos: [AboEintrag])] {
        if ausgewaehlteAboTypen.isEmpty {
            return gruppierteAbos
        }

        return aboChipTypen
            .filter { ausgewaehlteAboTypen.contains($0) }
            .map { typ in
                (
                    typ: typ,
                    abos: gruppierteAbos.first(where: { $0.typ == typ })?.abos ?? []
                )
            }
    }

    private var aktiverAboType: AboType {
        aktiverAboSheetKontext?.typ ?? sectionAboType ?? selectedAboType
    }

    private func erfassungsTitel(fuer typ: AboType) -> String {
        if aboTypDurchSectionVorgegeben, typ != .pleaseSelect {
            return "\(typ.chipTitel) erfassen"
        }

        return selectedAboID == nil ? "Abo oder Profil erfassen" : "Eintrag bearbeiten"
    }

    private var gruppierteAbos: [(typ: AboType, abos: [AboEintrag])] {
        guard let aboModell = aktuellesAboModell else { return [] }

        let gruppiert = Dictionary(grouping: aboModell.abos) { abo in
            aboTypeAusSectionTitel(abo.aboTyp.isEmpty ? AboType.other.rawValue : abo.aboTyp)
        }

        let reihenfolge = AboType.allCases

        return gruppiert
            .map { typ, abos in
                (
                    typ: typ,
                    abos: abos.sorted { $0.erstelltAm < $1.erstelltAm }
                )
            }
            .sorted { links, rechts in
                let linkerIndex = reihenfolge.firstIndex(of: links.typ) ?? Int.max
                let rechterIndex = reihenfolge.firstIndex(of: rechts.typ) ?? Int.max

                if linkerIndex == rechterIndex {
                    return links.typ.rawValue < rechts.typ.rawValue
                }

                return linkerIndex < rechterIndex
            }
    }

    private func istSektionAusgeklappt(_ gruppe: (typ: AboType, abos: [AboEintrag])) -> Bool {
        if gruppe.abos.count <= 1 { return true }
        return ausgeklappteAboSektionen.contains(gruppe.typ.rawValue)
    }

    private func aboSection(_ gruppe: (typ: AboType, abos: [AboEintrag])) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text(gruppe.typ.rawValue)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            if gruppe.abos.isEmpty {
                Text("Noch keine Einträge erfasst.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if gruppe.abos.count > 1 {
                DisclosureGroup("Erfasste Einträge (\(gruppe.abos.count))", isExpanded: Binding(
                    get: { istSektionAusgeklappt(gruppe) },
                    set: { istOffen in
                        if istOffen {
                            ausgeklappteAboSektionen.insert(gruppe.typ.rawValue)
                        } else {
                            ausgeklappteAboSektionen.remove(gruppe.typ.rawValue)
                        }
                    }
                )) {
                    VStack(spacing: 12) {
                        ForEach(gruppe.abos) { abo in
                            AboSwipeToDeleteRow(
                                deleteAction: {
                                    loescheAbo(abo)
                                }
                            ) {
                                aboKarte(abo)
                            }
                            .id(abo.id)
                        }
                    }
                    .padding(.top, 10)
                }
                .tint(abosAkzentFarbe)
            } else {
                VStack(spacing: 12) {
                    ForEach(gruppe.abos) { abo in
                        AboSwipeToDeleteRow(
                            deleteAction: {
                                loescheAbo(abo)
                            }
                        ) {
                            aboKarte(abo)
                        }
                        .id(abo.id)
                    }
                }
            }

            HStack {
                Spacer()

                Button {
                    starteAboErfassung(fuer: gruppe.typ)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(abosAkzentFarbe))
                        .shadow(color: abosAkzentFarbe.opacity(0.22), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eintrag hinzufügen")

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(abosKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(abosAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    private func starteAboErfassung(fuer typ: AboType) {
        aktiverAboSheetKontext = nil
        showAddAboSheet = false
        selectedAboID = nil
        selectedAbo = nil
        resetInputFields(typBeibehalten: true)

        selectedAboType = typ
        sectionAboType = typ
        aboTypDurchSectionVorgegeben = typ != .pleaseSelect
        sheetID = UUID()

        DispatchQueue.main.async {
            aktiverAboSheetKontext = AboSheetKontext(typ: typ)
            showAddAboSheet = true
        }
    }

    private func aboTypeAusSectionTitel(_ titel: String) -> AboType {
        let bereinigterTitel = titel.trimmingCharacters(in: .whitespacesAndNewlines)

        if let typ = AboType(rawValue: bereinigterTitel) {
            return typ
        }

        if let typ = aboChipTypen.first(where: { $0.chipTitel == bereinigterTitel }) {
            return typ
        }

        if bereinigterTitel == "Öffentlicher Verkehr" || bereinigterTitel == "ÖV" {
            return .publicTransport
        }

        return .pleaseSelect
    }


    private func aboKarte(_ abo: AboEintrag) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(aboTitel(abo))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            let unternehmenText = abo.aboTyp == AboType.mobileInternet.rawValue
                ? abo.mobileInternetAnbieter
                : abo.unternehmen

            let detailText = abo.aboTyp == AboType.mobileInternet.rawValue
                ? abo.mobileInternetVertragsdetails
                : abo.aboArt

            if !unternehmenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unternehmenText != "Bitte wählen" {
                Text(unternehmenText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !detailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(abosAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            oeffneAboZumBearbeiten(abo)
        }
    }

    private func ladeSelectedAboDetailsFallsVorhanden() {
        guard let selectedAboID else { return }

        let alleAbos = gespeicherteAboModelle.flatMap { $0.abos }
        guard let aktuellesAbo = alleAbos.first(where: { $0.id == selectedAboID }) ?? selectedAbo else { return }

        selectedAbo = aktuellesAbo
        loadAbo(aktuellesAbo)
    }

    private func oeffneAboZumBearbeiten(_ abo: AboEintrag) {
        aktiverAboSheetKontext = nil
        showAddAboSheet = false
        selectedAboID = abo.id
        selectedAbo = abo
        resetInputFields()
        aboTypDurchSectionVorgegeben = false
        sectionAboType = nil
        sheetID = UUID()

        loadAbo(abo)

        DispatchQueue.main.async {
            aktiverAboSheetKontext = AboSheetKontext(typ: selectedAboType)
            showAddAboSheet = true
        }
    }

    private var canSaveAbo: Bool {
        switch aktiverAboType {
        case .pleaseSelect:
            return false
        case .streaming:
            return selectedStreamingProvider != .pleaseSelect
        case .socialMedia:
            return selectedSocialMediaProvider != .pleaseSelect
        case .digitalIdentity:
            return selectedDigitalIdentityProvider != .pleaseSelect
        case .emailAccount:
            return selectedEmailProvider != .pleaseSelect
        case .magazine:
            return !magazineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .publicTransport:
            if publicTransportType == .pleaseSelect || publicTransportCompany == .pleaseSelect {
                return false
            }

            if publicTransportCompany == .other {
                return !customPublicTransportCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            return true
        case .software:
            return !softwareName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fitness:
            return !fitnessAboType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !fitnessCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .news:
            return !onlineMagazineAboType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !onlineMagazineCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .membership:
            return !membershipAboType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .mobileInternet:
            if selectedMobileInternetProvider == .pleaseSelect {
                return false
            }

            if selectedMobileInternetProvider == .other,
               customMobileInternetProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            return !mobileInternetContractDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .devices:
            return selectedDeviceType != .pleaseSelect
                && !devicePIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cloudStorage:
            return !customAboName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .other:
            return !customAboName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveAbo() {
        guard let aboModell = aktuellesAboModell else { return }

        let alleAbos = gespeicherteAboModelle.flatMap { $0.abos }
        let istNeuerEintrag = selectedAboID == nil && selectedAbo == nil

        if let sectionAboType {
            selectedAboType = sectionAboType
        }

        let abo = selectedAboID.flatMap { id in
            alleAbos.first(where: { $0.id == id })
        } ?? selectedAbo ?? AboEintrag()

        if istNeuerEintrag {
            modelContext.insert(abo)

            if !aboModell.abos.contains(where: { $0.id == abo.id }) {
                aboModell.abos.append(abo)
            }
        }

        if istNeuerEintrag {
            ausgeklappteAboSektionen.insert(selectedAboType.rawValue)
            scrollZuAboEintragID = abo.id
        }

        abo.aboTyp = selectedAboType.rawValue
        abo.anbieter = anbieterWert
        abo.unternehmen = unternehmenWert
        abo.bezeichnung = bezeichnungWert
        abo.aboArt = aboArtWert
        abo.aboNummer = aboNummerWert
        abo.benutzername = username
        abo.passwort = password
        abo.streamingAnbieter = aktiverAboType == .streaming ? selectedStreamingProvider.rawValue : "Bitte wählen"
        abo.socialMediaPlattform = aktiverAboType == .socialMedia ? selectedSocialMediaProvider.rawValue : "Bitte wählen"
        abo.digitaleIdentitaetAnbieter = aktiverAboType == .digitalIdentity ? selectedDigitalIdentityProvider.rawValue : "Bitte wählen"
        abo.emailAnbieter = aktiverAboType == .emailAccount ? selectedEmailProvider.rawValue : "Bitte wählen"
        if aktiverAboType == .devices && selectedDeviceType == .mobilePhone {
            abo.benutzername = ""
        }
        if aktiverAboType == .devices {
            abo.passwort = ""
            abo.geraeteArt = selectedDeviceType.rawValue
            abo.geraeteBezeichnung = bezeichnungWert
            abo.geraetePIN = devicePIN
        } else {
            abo.geraeteArt = "Bitte wählen"
            abo.geraeteBezeichnung = ""
            abo.geraetePIN = ""
        }
        if aktiverAboType == .publicTransport {
            abo.oevUnternehmen = publicTransportCompany.rawValue
            abo.oevAboTyp = publicTransportType.rawValue
            abo.andereBezeichnung = customPublicTransportCompany
        } else {
            abo.oevUnternehmen = "Bitte wählen"
            abo.oevAboTyp = "Bitte wählen"
            abo.andereBezeichnung = ""
        }

        if aktiverAboType == .mobileInternet {
            abo.mobileInternetAnbieter = mobileInternetProviderWert
            abo.mobileInternetVertragsdetails = mobileInternetContractDetails
        } else {
            abo.mobileInternetAnbieter = "Bitte wählen"
            abo.mobileInternetVertragsdetails = ""
        }

        abo.bankkontoName = ""
        abo.bankkontoArt = ""
        abo.aktualisiertAm = Date()

        aboModell.aktualisiertAm = Date()
        selectedAboID = nil
        selectedAbo = nil
        speichereAenderung()
    }

    private func loadAbo(_ abo: AboEintrag) {
        let bereinigterTyp = abo.aboTyp.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedAboType = AboType(rawValue: bereinigterTyp) ?? (bereinigterTyp == "Mein Mobile Telefon" ? .devices : .pleaseSelect)

        if selectedAboType == .pleaseSelect,
           let typAusBezeichnung = AboType.allCases.first(where: { $0.rawValue == bereinigterTyp }) {
            selectedAboType = typAusBezeichnung
        }

        if selectedAboType == .pleaseSelect {
            if !abo.streamingAnbieter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && abo.streamingAnbieter != "Bitte wählen" {
                selectedAboType = .streaming
            } else if !abo.socialMediaPlattform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && abo.socialMediaPlattform != "Bitte wählen" {
                selectedAboType = .socialMedia
            } else if !abo.digitaleIdentitaetAnbieter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && abo.digitaleIdentitaetAnbieter != "Bitte wählen" {
                selectedAboType = .digitalIdentity
            } else if !abo.emailAnbieter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && abo.emailAnbieter != "Bitte wählen" {
                selectedAboType = .emailAccount
            } else if !abo.geraeteArt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && abo.geraeteArt != "Bitte wählen" {
                selectedAboType = .devices
            }
        }

        selectedStreamingProvider = .pleaseSelect
        selectedSocialMediaProvider = .pleaseSelect
        selectedDigitalIdentityProvider = .pleaseSelect
        selectedEmailProvider = .pleaseSelect

        switch aktiverAboType {
        case .streaming:
            selectedStreamingProvider = StreamingProvider(rawValue: abo.streamingAnbieter.isEmpty || abo.streamingAnbieter == "Bitte wählen" ? abo.anbieter : abo.streamingAnbieter) ?? .pleaseSelect
        case .socialMedia:
            selectedSocialMediaProvider = SocialMediaProvider(rawValue: abo.socialMediaPlattform.isEmpty || abo.socialMediaPlattform == "Bitte wählen" ? abo.anbieter : abo.socialMediaPlattform) ?? .pleaseSelect
        case .digitalIdentity:
            selectedDigitalIdentityProvider = DigitalIdentityProvider(rawValue: abo.digitaleIdentitaetAnbieter.isEmpty || abo.digitaleIdentitaetAnbieter == "Bitte wählen" ? abo.anbieter : abo.digitaleIdentitaetAnbieter) ?? .pleaseSelect
        case .emailAccount:
            selectedEmailProvider = EmailProvider(rawValue: abo.emailAnbieter.isEmpty || abo.emailAnbieter == "Bitte wählen" ? abo.anbieter : abo.emailAnbieter) ?? .pleaseSelect
        default:
            break
        }

        username = abo.benutzername
        password = abo.passwort

        if selectedAboType == .devices {
            username = abo.geraeteArt == "Mobile Telefon" ? "" : abo.benutzername
        }

        magazineName = selectedAboType == .magazine ? abo.bezeichnung : ""
        publicTransportType = selectedAboType == .publicTransport ? (PublicTransportAboType(rawValue: abo.oevAboTyp.isEmpty ? abo.aboArt : abo.oevAboTyp) ?? .pleaseSelect) : .pleaseSelect
        publicTransportCompany = selectedAboType == .publicTransport ? (PublicTransportCompany(rawValue: abo.oevUnternehmen.isEmpty ? abo.unternehmen : abo.oevUnternehmen) ?? .pleaseSelect) : .pleaseSelect
        customPublicTransportCompany = selectedAboType == .publicTransport ? abo.andereBezeichnung : ""
        publicTransportAboNumber = selectedAboType == .publicTransport ? abo.aboNummer : ""
        selectedDeviceType = selectedAboType == .devices ? (DeviceType(rawValue: abo.geraeteArt.isEmpty ? abo.aboArt : abo.geraeteArt) ?? .pleaseSelect) : .pleaseSelect
        devicePIN = selectedAboType == .devices ? (abo.geraetePIN.isEmpty ? abo.passwort : abo.geraetePIN) : ""
        softwareName = selectedAboType == .software ? abo.bezeichnung : ""
        fitnessAboType = selectedAboType == .fitness ? abo.aboArt : ""
        fitnessCompany = selectedAboType == .fitness ? abo.unternehmen : ""
        onlineMagazineAboType = selectedAboType == .news ? abo.aboArt : ""
        onlineMagazineCompany = selectedAboType == .news ? abo.unternehmen : ""
        membershipAboType = selectedAboType == .membership ? abo.aboArt : ""
        membershipNumber = selectedAboType == .membership ? abo.aboNummer : ""
        selectedMobileInternetProvider = .pleaseSelect
        customMobileInternetProvider = ""
        if selectedAboType == .mobileInternet {
            let gespeicherterAnbieter = !abo.mobileInternetAnbieter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && abo.mobileInternetAnbieter != "Bitte wählen"
                ? abo.mobileInternetAnbieter
                : (abo.unternehmen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? abo.bezeichnung : abo.unternehmen)

            if let provider = MobileInternetProvider(rawValue: gespeicherterAnbieter) {
                selectedMobileInternetProvider = provider
            } else if !gespeicherterAnbieter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedMobileInternetProvider = .other
                customMobileInternetProvider = gespeicherterAnbieter
            }
        }
        mobileInternetContractDetails = selectedAboType == .mobileInternet
            ? (abo.mobileInternetVertragsdetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? abo.aboArt : abo.mobileInternetVertragsdetails)
            : ""
        customAboName = selectedAboType == .other || selectedAboType == .cloudStorage ? abo.bezeichnung : (selectedAboType == .devices ? (abo.geraeteBezeichnung.isEmpty ? abo.bezeichnung : abo.geraeteBezeichnung) : "")

        if selectedAboType == .digitalIdentity && selectedDigitalIdentityProvider == .pleaseSelect,
           let fallbackProvider = DigitalIdentityProvider(rawValue: abo.bezeichnung) {
            selectedDigitalIdentityProvider = fallbackProvider
        }

        if selectedAboType == .emailAccount && selectedEmailProvider == .pleaseSelect,
           let fallbackProvider = EmailProvider(rawValue: abo.bezeichnung) {
            selectedEmailProvider = fallbackProvider
        }
    }

    private func resetInputFields(typBeibehalten: Bool = false) {
        if !typBeibehalten {
            selectedAboType = .pleaseSelect
        }
        selectedStreamingProvider = .pleaseSelect
        selectedSocialMediaProvider = .pleaseSelect
        selectedDigitalIdentityProvider = .pleaseSelect
        selectedEmailProvider = .pleaseSelect
        username = ""
        password = ""
        magazineName = ""
        publicTransportType = .pleaseSelect
        publicTransportCompany = .pleaseSelect
        customPublicTransportCompany = ""
        publicTransportAboNumber = ""
        selectedDeviceType = .pleaseSelect
        devicePIN = ""
        softwareName = ""
        fitnessAboType = ""
        fitnessCompany = ""
        onlineMagazineAboType = ""
        onlineMagazineCompany = ""
        membershipAboType = ""
        membershipNumber = ""
        selectedMobileInternetProvider = .pleaseSelect
        customMobileInternetProvider = ""
        mobileInternetContractDetails = ""
        customAboName = ""
        showPassword = false
    }

    private func passwordField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(abosAkzentFarbe)

            HStack {
                if showPassword {
                    TextField(title, text: text)
                } else {
                    SecureField(title, text: text)
                }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(abosKartenFarbe.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func labelledTextField(_ title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(abosAkzentFarbe)

            TextField(title, text: text)
                .keyboardType(keyboardType)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(abosKartenFarbe.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func styledPicker<SelectionValue: Hashable, Content: View>(
        _ title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Picker(title, selection: selection) {
            content()
        }
        .pickerStyle(.menu)
        .tint(abosAkzentFarbe)
    }

    private var alleAboEintraege: [AboEintrag] {
        gespeicherteAboModelle.flatMap { $0.abos }
    }

    private var aktuellesAboModell: AboModell? {
        gespeicherteAboModelle.first
    }

    private var mobileInternetProviderWert: String {
        if selectedMobileInternetProvider == .other {
            return customMobileInternetProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return selectedMobileInternetProvider.rawValue
    }

    private var unternehmenWert: String {
        switch aktiverAboType {
        case .fitness:
            return fitnessCompany
        case .news:
            return onlineMagazineCompany
        case .mobileInternet:
            return ""
        case .publicTransport:
            return publicTransportCompany == .other ? customPublicTransportCompany : publicTransportCompany.rawValue
        default:
            return ""
        }
    }

    private var bezeichnungWert: String {
        switch aktiverAboType {
        case .streaming:
            return selectedStreamingProvider.rawValue
        case .socialMedia:
            return selectedSocialMediaProvider.rawValue
        case .digitalIdentity:
            return selectedDigitalIdentityProvider.rawValue
        case .emailAccount:
            return selectedEmailProvider.rawValue
        case .devices:
            return customAboName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedDeviceType.rawValue : customAboName
        case .magazine:
            return magazineName
        case .software:
            return softwareName
        case .mobileInternet:
            return mobileInternetProviderWert
        case .cloudStorage:
            return customAboName
        case .other:
            return customAboName
        default:
            return ""
        }
    }

    private var anbieterWert: String {
        switch aktiverAboType {
        case .streaming:
            return selectedStreamingProvider.rawValue
        case .socialMedia:
            return selectedSocialMediaProvider.rawValue
        case .digitalIdentity:
            return selectedDigitalIdentityProvider.rawValue
        case .emailAccount:
            return selectedEmailProvider.rawValue
        default:
            return ""
        }
    }

    private var aboArtWert: String {
        switch aktiverAboType {
        case .fitness:
            return fitnessAboType
        case .news:
            return onlineMagazineAboType
        case .membership:
            return membershipAboType
        case .mobileInternet:
            return ""
        case .publicTransport:
            return publicTransportType.rawValue
        case .devices:
            return selectedDeviceType.rawValue
        default:
            return ""
        }
    }

    private var aboNummerWert: String {
        switch aktiverAboType {
        case .publicTransport:
            return publicTransportAboNumber
        case .membership:
            return membershipNumber
        case .devices:
            return ""
        default:
            return ""
        }
    }

    private func ladeOderErstelleAboModellFallsNoetig() {
        guard !wurdeInitialisiert else { return }
        wurdeInitialisiert = true

        guard gespeicherteAboModelle.isEmpty else { return }

        let neuesModell = AboModell()
        modelContext.insert(neuesModell)
        speichereAenderung()
    }

    private func speichereAenderung() {
        do {
            try modelContext.save()
        } catch {
            print("Abos konnten nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    private func loescheAbo(_ abo: AboEintrag) {
        guard let aboModell = aktuellesAboModell else { return }

        if let index = aboModell.abos.firstIndex(where: { $0.id == abo.id }) {
            aboModell.abos.remove(at: index)
        }

        modelContext.delete(abo)
        aboModell.aktualisiertAm = Date()
        speichereAenderung()
    }

    private func aboTitel(_ abo: AboEintrag) -> String {
        if abo.aboTyp == "Meine Geräte" || abo.aboTyp == "Mein Mobile Telefon" {
            let bezeichnung = (abo.geraeteBezeichnung.isEmpty ? abo.bezeichnung : abo.geraeteBezeichnung).trimmingCharacters(in: .whitespacesAndNewlines)
            let art = (abo.geraeteArt.isEmpty ? abo.aboArt : abo.geraeteArt).trimmingCharacters(in: .whitespacesAndNewlines)

            if !bezeichnung.isEmpty && !art.isEmpty {
                return "\(bezeichnung) – \(art)"
            }

            if !bezeichnung.isEmpty {
                return bezeichnung
            }

            if !art.isEmpty {
                return art
            }
        }

        if abo.aboTyp == AboType.mobileInternet.rawValue {
            let anbieter = abo.mobileInternetAnbieter.trimmingCharacters(in: .whitespacesAndNewlines)
            let details = abo.mobileInternetVertragsdetails.trimmingCharacters(in: .whitespacesAndNewlines)

            if !anbieter.isEmpty && anbieter != "Bitte wählen" && !details.isEmpty {
                return "\(anbieter) – \(details)"
            }

            if !anbieter.isEmpty && anbieter != "Bitte wählen" {
                return anbieter
            }

            if !details.isEmpty {
                return details
            }
        }

        if !abo.bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return abo.bezeichnung
        }

        if !abo.unternehmen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !abo.aboArt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(abo.unternehmen) – \(abo.aboArt)"
            }
            return abo.unternehmen
        }

        if !abo.aboArt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return abo.aboArt
        }

        return abo.aboTyp
    }
}

struct AboChipFlowLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = max(1, proposal.width ?? 320)
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = currentX == 0 ? size.width : currentX + spacing + size.width

            if currentX > 0 && proposedX > maxWidth {
                currentY += currentRowHeight + rowSpacing
                currentX = 0
                currentRowHeight = 0
            }

            if currentX > 0 {
                currentX += spacing
            }

            currentX += size.width
            currentRowHeight = max(currentRowHeight, size.height)
            usedWidth = max(usedWidth, currentX)
        }

        return CGSize(width: min(usedWidth, maxWidth), height: currentY + currentRowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = max(1, bounds.width)
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = currentX == bounds.minX ? size.width : currentX - bounds.minX + spacing + size.width

            if currentX > bounds.minX && proposedX > maxWidth {
                currentY += currentRowHeight + rowSpacing
                currentX = bounds.minX
                currentRowHeight = 0
            }

            if currentX > bounds.minX {
                currentX += spacing
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

struct AboSwipeToDeleteRow<Content: View>: View {
    let deleteAction: () -> Void
    let content: Content

    @State private var offsetX: CGFloat = 0
    @State private var istGeloescht = false

    private let revealOffset: CGFloat = -92
    private let fullDeleteThreshold: CGFloat = -148
    private let maxOffset: CGFloat = -164

    init(
        deleteAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.deleteAction = deleteAction
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Button {
                    loeschen()
                } label: {
                    ZStack {
                        Rectangle()
                            .fill(Color.red.opacity(0.92))

                        Image(systemName: "trash.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: deleteAreaWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(offsetX < -8 ? 1 : 0)
                .allowsHitTesting(offsetX < -40)
            }
            .frame(maxWidth: .infinity)
            .zIndex(0)

            content
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.001))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .compositingGroup()
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .zIndex(1)
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }

                            let startOffset = offsetX == revealOffset ? revealOffset : 0
                            let neuePosition = min(0, max(maxOffset, value.translation.width + startOffset))

                            if neuePosition <= 0 {
                                offsetX = neuePosition
                            }
                        }
                        .onEnded { value in
                            guard !istGeloescht else { return }

                            if value.translation.width < fullDeleteThreshold {
                                loeschen()
                            } else if offsetX < -42 {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    offsetX = revealOffset
                                }
                            } else {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    offsetX = 0
                                }
                            }
                        }
                )
        }
        .opacity(istGeloescht ? 0 : 1)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .clipped()
    }

    private var deleteAreaWidth: CGFloat {
        min(max(0, abs(offsetX)), abs(maxOffset))
    }

    private func loeschen() {
        guard !istGeloescht else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            istGeloescht = true
            offsetX = maxOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            deleteAction()
        }
    }
}

enum AboType: String, CaseIterable, Identifiable, Hashable {
    case pleaseSelect = "Bitte wählen"
    case digitalIdentity = "Digitale Identitäten"
    case devices = "Meine Geräte"
    case emailAccount = "E-Mail-Konten"
    case fitness = "Fitness / Sport"
    case membership = "Mitgliedschaft"
    case mobileInternet = "Mobile & Internet"
    case news = "Online Zeitschriften"
    case publicTransport = "Öffentlicher Verkehr"
    case socialMedia = "Social Media"
    case software = "Software / Apps"
    case streaming = "Streamingdienst"
    case magazine = "Zeitschriften"
    case cloudStorage = "Cloud-Speicher"
    case other = "Andere"

    var id: String { rawValue }

    var chipTitel: String {
        switch self {
        case .pleaseSelect: return "Bitte wählen"
        case .digitalIdentity: return "Identitäten"
        case .devices: return "Geräte"
        case .emailAccount: return "E-Mail"
        case .fitness: return "Fitness"
        case .membership: return "Mitgliedschaft"
        case .mobileInternet: return "Mobile & Internet"
        case .news: return "Online-Magazine"
        case .publicTransport: return "ÖV"
        case .socialMedia: return "Social Media"
        case .software: return "Software"
        case .streaming: return "Streaming"
        case .magazine: return "Zeitschriften"
        case .cloudStorage: return "Cloud"
        case .other: return "Andere"
        }
    }

    var systemImage: String {
        switch self {
        case .pleaseSelect: return "questionmark.circle.fill"
        case .digitalIdentity: return "person.badge.key.fill"
        case .devices: return "iphone.gen3"
        case .emailAccount: return "envelope.fill"
        case .fitness: return "figure.run"
        case .membership: return "person.2.fill"
        case .mobileInternet: return "antenna.radiowaves.left.and.right"
        case .news: return "newspaper.fill"
        case .publicTransport: return "tram.fill"
        case .socialMedia: return "bubble.left.and.bubble.right.fill"
        case .software: return "app.fill"
        case .streaming: return "play.rectangle.fill"
        case .magazine: return "book.pages.fill"
        case .cloudStorage: return "icloud.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum StreamingProvider: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case amazonPrime = "Amazon Prime Video"
    case appleTV = "Apple TV+"
    case disneyPlus = "Disney+"
    case hbo = "HBO / Max"
    case netflix = "Netflix"
    case paramount = "Paramount+"
    case sky = "Sky"
    case spotify = "Spotify"
    case youtube = "YouTube Premium"
    case other = "Andere"

    var id: String { rawValue }
}


enum SocialMediaProvider: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case bluesky = "Bluesky"
    case facebook = "Facebook"
    case instagram = "Instagram"
    case linkedin = "LinkedIn"
    case mastodon = "Mastodon"
    case pinterest = "Pinterest"
    case reddit = "Reddit"
    case snapchat = "Snapchat"
    case threads = "Threads"
    case tiktok = "TikTok"
    case twitch = "Twitch"
    case x = "X / Twitter"
    case youtube = "YouTube"
    case other = "Andere"

    var id: String { rawValue }
}

enum DigitalIdentityProvider: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case adobe = "Adobe"
    case apple = "Apple ID"
    case bitwarden = "Bitwarden"
    case dropbox = "Dropbox"
    case google = "Google"
    case meta = "Meta"
    case microsoft = "Microsoft"
    case onePassword = "1Password"
    case samsung = "Samsung"
    case other = "Andere"

    var id: String { rawValue }
}

enum EmailProvider: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case bluewin = "Bluewin"
    case ownDomain = "Eigene Domain"
    case gmail = "Gmail"
    case gmx = "GMX"
    case icloud = "iCloud Mail"
    case outlook = "Outlook / Hotmail"
    case proton = "Proton Mail"
    case yahoo = "Yahoo Mail"
    case other = "Andere"

    var id: String { rawValue }
}

enum PublicTransportAboType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case ga = "Generalabonnement"
    case halfFare = "Halbtax"
    case regional = "Regionalabo / Verbundabo"
    case swissPass = "SwissPass"
    case city = "Stadtabo"
    case pointToPoint = "Streckenabo"
    case other = "Andere"

    var id: String { rawValue }
}

enum PublicTransportCompany: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case aWelle = "A-Welle"
    case bls = "BLS"
    case libero = "Libero Tarifverbund"
    case mobilis = "Mobilis"
    case ostwind = "Ost-Wind"
    case passepartout = "Passepartout"
    case postAuto = "PostAuto"
    case rhb = "Rhätische Bahn"
    case sbb = "SBB"
    case sob = "Südostbahn"
    case tl = "TL Lausanne"
    case tpf = "TPF Fribourg"
    case tpg = "TPG"
    case unireso = "Unireso"
    case vbz = "VBZ"
    case zug = "Kanton Zug / Tarifverbund Zug"
    case zvv = "ZVV"
    case zvvBonusPass = "ZVV BonusPass"
    case other = "Andere"

    var id: String { rawValue }
}

#Preview {
    AbosView()
        .modelContainer(for: [AboModell.self, AboEintrag.self], inMemory: true)
}

enum DeviceType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case eReader = "eReader"
    case externalHardDrive = "Externe Festplatte"
    case camera = "Kamera"
    case computerNotebook = "Computer / Notebook"
    case mobilePhone = "Mobile Telefon"
    case nas = "NAS / Heimserver"
    case router = "Router / WLAN"
    case smartSpeaker = "Smart Speaker"
    case smartTV = "Smart TV"
    case smartwatch = "Smartwatch"
    case gamingConsole = "Spielkonsole"
    case tablet = "Tablet"
    case other = "Andere"

    var id: String { rawValue }
}

enum MobileInternetProvider: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case other = "Andere"
    case swisscom = "Swisscom"
    case sunrise = "Sunrise"
    case salt = "Salt"
    case wingo = "Wingo"
    case yallo = "yallo"
    case mbudget = "M-Budget Mobile"
    case migrosMobile = "Migros Mobile"
    case coopMobile = "Coop Mobile"
    case galaxusMobile = "Galaxus Mobile"
    case lebara = "Lebara"
    case digitalRepublic = "Digital Republic"
    case quickline = "Quickline"
    case teleboy = "Teleboy"
    case green = "Green"
    case iway = "iWay"
    case init7 = "Init7"
    case spusu = "spusu"
    case talkTalk = "TalkTalk"

    var id: String { rawValue }
}
