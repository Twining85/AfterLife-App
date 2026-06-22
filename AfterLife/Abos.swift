import SwiftUI
import SwiftData

struct AbosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteAboModelle: [AboModell]

    @State private var showAddAboSheet = false
    @State private var sheetID = UUID()
    @State private var selectedAboID: UUID?
    @State private var selectedAbo: AboEintrag?
    @State private var wurdeInitialisiert = false
    @State private var ausgeklappteAboSektionen: Set<String> = []
  

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
    @State private var customAboName = ""
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Button {
                    showAddAboSheet = false
                    selectedAboID = nil
                    selectedAbo = nil
                    resetInputFields()

                    DispatchQueue.main.async {
                        sheetID = UUID()
                        showAddAboSheet = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 82))
                        .foregroundStyle(.black)
                        .accessibilityLabel("Abo hinzufügen")
                }

                Text("Abo oder Profil hinzufügen")
                    .font(.title3)
                    .fontWeight(.semibold)

                if aktuellesAboModell?.abos.isEmpty ?? true {
                    Text("Hier kannst du digitale Abonnemente, Online-Profile, Streamingdienste, ÖV-Abos o.ä erfassen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    List {
                        ForEach(gruppierteAbos, id: \.typ) { gruppe in
                            Section {
                                if istSektionAusgeklappt(gruppe) {
                                    ForEach(gruppe.abos) { abo in
                                        aboKarte(abo)
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    loescheAbo(abo)
                                                } label: {
                                                    Label("Löschen", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            } header: {
                                sektionHeader(gruppe)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                Spacer()
            }
            .navigationTitle("Abos & Profile")
            .task {
                ladeOderErstelleAboModellFallsNoetig()
            }
            .sheet(isPresented: $showAddAboSheet) {
                NavigationStack {
                    Form {
                        Section("Typ") {
                            Picker("Art des Abos bzw. Profils", selection: $selectedAboType) {
                                ForEach(AboType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        }

                        if selectedAboType == .streaming {
                            Section("Streamingdienst") {
                                Picker("Anbieter", selection: $selectedStreamingProvider) {
                                    ForEach(StreamingProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }

                        if selectedAboType == .socialMedia {
                            Section("Social Media") {
                                Picker("Plattform", selection: $selectedSocialMediaProvider) {
                                    ForEach(SocialMediaProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }

                        if selectedAboType == .digitalIdentity {
                            Section("Digitale Identität") {
                                Picker("Anbieter", selection: $selectedDigitalIdentityProvider) {
                                    ForEach(DigitalIdentityProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("Benutzername / E-Mail", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }

                        if selectedAboType == .emailAccount {
                            Section("E-Mail-Konto") {
                                Picker("Anbieter", selection: $selectedEmailProvider) {
                                    ForEach(EmailProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }

                                labelledTextField("E-Mail-Adresse", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }

                        if selectedAboType == .magazine {
                            Section("Zeitschrift") {
                                labelledTextField("Name der Zeitschrift", text: $magazineName)
                            }
                        }

                        if selectedAboType == .publicTransport {
                            Section("Öffentlicher Verkehr") {
                                Picker("Art des Abos", selection: $publicTransportType) {
                                    ForEach(PublicTransportAboType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }

                                if publicTransportType != .pleaseSelect {
                                    Picker("Unternehmen", selection: $publicTransportCompany) {
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
                        }

                        if selectedAboType == .devices {
                            Section("Meine Geräte") {
                                Picker("Geräteart", selection: $selectedDeviceType) {
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

                        if selectedAboType == .software {
                            Section("Um was handelt es sich?") {
                                labelledTextField("Name App / Software", text: $softwareName)
                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }

                        if selectedAboType == .fitness {
                            Section("Um was handelt es sich?") {
                                labelledTextField("Aboart", text: $fitnessAboType)
                                labelledTextField("Unternehmen", text: $fitnessCompany)
                            }
                        }

                        if selectedAboType == .news {
                            Section("Um was handelt es sich?") {
                                labelledTextField("Aboart", text: $onlineMagazineAboType)
                                labelledTextField("Unternehmen", text: $onlineMagazineCompany)
                                labelledTextField("Benutzername", text: $username)

                                passwordField(title: "Passwort", text: $password)
                            }
                        }
                        if selectedAboType == .membership {
                            Section("Mitgliedschaft") {
                                labelledTextField("Mitglied bei", text: $membershipAboType)
                                labelledTextField("Kontakt", text: $membershipNumber)
                            }
                        }

                        if selectedAboType == .other {
                            Section("Anderes Abo") {
                                labelledTextField("Name oder Beschreibung", text: $customAboName)
                            }
                        }
                    }
                    .navigationTitle("Erfassen")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                showAddAboSheet = false
                                selectedAbo = nil
                                selectedAboID = nil
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                saveAbo()
                                showAddAboSheet = false
                                selectedAbo = nil
                                selectedAboID = nil
                            }
                            .disabled(!canSaveAbo)
                        }
                    }
                }
                .id(sheetID)
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
    }

    private var gruppierteAbos: [(typ: String, abos: [AboEintrag])] {
        guard let aboModell = aktuellesAboModell else { return [] }

        let gruppiert = Dictionary(grouping: aboModell.abos) { abo in
            abo.aboTyp.isEmpty ? "Ohne Typ" : abo.aboTyp
        }

        let reihenfolge = AboType.allCases.map(\.rawValue)

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
                    return links.typ < rechts.typ
                }

                return linkerIndex < rechterIndex
            }
    }

    private func istSektionAusgeklappt(_ gruppe: (typ: String, abos: [AboEintrag])) -> Bool {
        if gruppe.abos.count <= 3 { return true }
        return ausgeklappteAboSektionen.contains(gruppe.typ)
    }

    private func sektionHeader(_ gruppe: (typ: String, abos: [AboEintrag])) -> some View {
        Button {
            guard gruppe.abos.count > 3 else { return }

            if ausgeklappteAboSektionen.contains(gruppe.typ) {
                ausgeklappteAboSektionen.remove(gruppe.typ)
            } else {
                ausgeklappteAboSektionen.insert(gruppe.typ)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gruppe.typ)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(gruppe.abos.count) Eintrag\(gruppe.abos.count == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if gruppe.abos.count > 3 {
                    Image(systemName: istSektionAusgeklappt(gruppe) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func aboKarte(_ abo: AboEintrag) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(aboTitel(abo))
                .font(.headline)
                .foregroundStyle(.primary)

            if !abo.unternehmen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(abo.unternehmen)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !abo.aboArt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(abo.aboArt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
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
        showAddAboSheet = false
        selectedAboID = abo.id
        selectedAbo = abo
        resetInputFields()
        selectedAboID = abo.id
        selectedAbo = abo
        sheetID = UUID()

        DispatchQueue.main.async {
            showAddAboSheet = true
        }
    }

    private var canSaveAbo: Bool {
        switch selectedAboType {
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
        case .devices:
            return selectedDeviceType != .pleaseSelect
                && !devicePIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cloudStorage:
            return true
        case .other:
            return !customAboName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveAbo() {
        guard let aboModell = aktuellesAboModell else { return }

        let alleAbos = gespeicherteAboModelle.flatMap { $0.abos }
        let istNeuerEintrag = selectedAboID == nil && selectedAbo == nil

        let abo = selectedAboID.flatMap { id in
            alleAbos.first(where: { $0.id == id })
        } ?? selectedAbo ?? AboEintrag()

        if istNeuerEintrag {
            modelContext.insert(abo)

            if !aboModell.abos.contains(where: { $0.id == abo.id }) {
                aboModell.abos.append(abo)
            }
        }

        if istNeuerEintrag && aboModell.abos.filter({ $0.aboTyp == selectedAboType.rawValue }).count > 3 {
            ausgeklappteAboSektionen.remove(selectedAboType.rawValue)
        }

        abo.aboTyp = selectedAboType.rawValue
        abo.anbieter = anbieterWert
        abo.unternehmen = unternehmenWert
        abo.bezeichnung = bezeichnungWert
        abo.aboArt = aboArtWert
        abo.aboNummer = aboNummerWert
        abo.benutzername = username
        abo.passwort = password
        abo.streamingAnbieter = selectedAboType == .streaming ? selectedStreamingProvider.rawValue : "Bitte wählen"
        abo.socialMediaPlattform = selectedAboType == .socialMedia ? selectedSocialMediaProvider.rawValue : "Bitte wählen"
        abo.digitaleIdentitaetAnbieter = selectedAboType == .digitalIdentity ? selectedDigitalIdentityProvider.rawValue : "Bitte wählen"
        abo.emailAnbieter = selectedAboType == .emailAccount ? selectedEmailProvider.rawValue : "Bitte wählen"
        if selectedAboType == .devices && selectedDeviceType == .mobilePhone {
            abo.benutzername = ""
        }
        if selectedAboType == .devices {
            abo.passwort = ""
            abo.geraeteArt = selectedDeviceType.rawValue
            abo.geraeteBezeichnung = bezeichnungWert
            abo.geraetePIN = devicePIN
        } else {
            abo.geraeteArt = "Bitte wählen"
            abo.geraeteBezeichnung = ""
            abo.geraetePIN = ""
        }
        if selectedAboType == .publicTransport {
            abo.oevUnternehmen = publicTransportCompany.rawValue
            abo.oevAboTyp = publicTransportType.rawValue
            abo.andereBezeichnung = customPublicTransportCompany
        } else {
            abo.oevUnternehmen = "Bitte wählen"
            abo.oevAboTyp = "Bitte wählen"
            abo.andereBezeichnung = ""
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

        switch selectedAboType {
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
        customAboName = selectedAboType == .other ? abo.bezeichnung : (selectedAboType == .devices ? (abo.geraeteBezeichnung.isEmpty ? abo.bezeichnung : abo.geraeteBezeichnung) : "")

        if selectedAboType == .digitalIdentity && selectedDigitalIdentityProvider == .pleaseSelect,
           let fallbackProvider = DigitalIdentityProvider(rawValue: abo.bezeichnung) {
            selectedDigitalIdentityProvider = fallbackProvider
        }

        if selectedAboType == .emailAccount && selectedEmailProvider == .pleaseSelect,
           let fallbackProvider = EmailProvider(rawValue: abo.bezeichnung) {
            selectedEmailProvider = fallbackProvider
        }
    }

    private func resetInputFields() {
        selectedAboType = .pleaseSelect
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
        customAboName = ""
        showPassword = false
    }

    private func passwordField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

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
        }
    }

    private func labelledTextField(_ title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(title, text: text)
                .keyboardType(keyboardType)
        }
    }

    private var alleAboEintraege: [AboEintrag] {
        gespeicherteAboModelle.flatMap { $0.abos }
    }

    private var aktuellesAboModell: AboModell? {
        gespeicherteAboModelle.first
    }

    private var unternehmenWert: String {
        switch selectedAboType {
        case .fitness:
            return fitnessCompany
        case .news:
            return onlineMagazineCompany
        case .publicTransport:
            return publicTransportCompany == .other ? customPublicTransportCompany : publicTransportCompany.rawValue
        default:
            return ""
        }
    }

    private var bezeichnungWert: String {
        switch selectedAboType {
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
        case .other:
            return customAboName
        default:
            return ""
        }
    }

    private var anbieterWert: String {
        switch selectedAboType {
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
        switch selectedAboType {
        case .fitness:
            return fitnessAboType
        case .news:
            return onlineMagazineAboType
        case .membership:
            return membershipAboType
        case .publicTransport:
            return publicTransportType.rawValue
        case .devices:
            return selectedDeviceType.rawValue
        default:
            return ""
        }
    }

    private var aboNummerWert: String {
        switch selectedAboType {
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

enum AboType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case digitalIdentity = "Digitale Identitäten"
    case devices = "Meine Geräte"
    case emailAccount = "E-Mail-Konten"
    case fitness = "Fitness / Sport"
    case membership = "Mitgliedschaft"
    case news = "Online Zeitschriften"
    case publicTransport = "Öffentlicher Verkehr"
    case socialMedia = "Social Media"
    case software = "Software / Apps"
    case streaming = "Streamingdienst"
    case magazine = "Zeitschriften"
    case cloudStorage = "Cloud-Speicher"
    case other = "Andere"

    var id: String { rawValue }
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
