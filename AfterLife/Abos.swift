import SwiftUI

struct AbosView: View {
    @State private var showAddAboSheet = false
    @State private var abos: [AboEntry] = []
    @State private var selectedAboIndex: Int?

    @State private var selectedAboType: AboType = .pleaseSelect
    @State private var selectedStreamingProvider: StreamingProvider = .pleaseSelect
    @State private var username = ""
    @State private var password = ""
    @State private var magazineName = ""
    @State private var publicTransportType: PublicTransportAboType = .pleaseSelect
    @State private var publicTransportCompany: PublicTransportCompany = .pleaseSelect
    @State private var customPublicTransportCompany = ""
    @State private var publicTransportAboNumber = ""
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
                    resetInputFields()
                    showAddAboSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 82))
                        .foregroundStyle(.black)
                        .accessibilityLabel("Abo hinzufügen")
                }

                Text("Abo oder Profil hinzufügen")
                    .font(.title3)
                    .fontWeight(.semibold)

                if abos.isEmpty {
                    Text("Hier kannst du Abonnemente, Profile,  Streamingdienste, ÖV-Abos o.ä erfassen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    List {
                        ForEach(Array(abos.enumerated()), id: \.element.id) { index, abo in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(abo.title)
                                    .fontWeight(.semibold)

                                Text(abo.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                loadAbo(abos[index])
                                selectedAboIndex = index
                                showAddAboSheet = true
                            }
                        }
                        .onDelete { indexSet in
                            abos.remove(atOffsets: indexSet)
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer()
            }
            .navigationTitle("Abos & Profile")
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
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                saveAbo()
                                showAddAboSheet = false
                            }
                            .disabled(!canSaveAbo)
                        }
                    }
                }
            }
        }
    }

    private var canSaveAbo: Bool {
        switch selectedAboType {
        case .pleaseSelect:
            return false
        case .streaming:
            return selectedStreamingProvider != .pleaseSelect
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
        case .cloudStorage:
            return true
        case .other:
            return !customAboName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveAbo() {
        let title: String

        switch selectedAboType {
        case .streaming:
            title = selectedStreamingProvider.rawValue
        case .magazine:
            title = magazineName
        case .publicTransport:
            let companyName = publicTransportCompany == .other
                ? customPublicTransportCompany.trimmingCharacters(in: .whitespacesAndNewlines)
                : publicTransportCompany.rawValue
            title = "\(companyName) – \(publicTransportType.rawValue)"
        case .software:
            title = softwareName
        case .fitness:
            title = "\(fitnessCompany) – \(fitnessAboType)"
        case .news:
            title = "\(onlineMagazineCompany) – \(onlineMagazineAboType)"
        case .membership:
            title = membershipAboType
        case .other:
            title = customAboName
        default:
            title = selectedAboType.rawValue
        }

        let abo = AboEntry(
            type: selectedAboType,
            title: title,
            streamingProvider: selectedStreamingProvider,
            username: username,
            password: password,
            magazineName: magazineName,
            publicTransportType: publicTransportType,
            publicTransportCompany: publicTransportCompany,
            customPublicTransportCompany: customPublicTransportCompany,
            publicTransportAboNumber: publicTransportAboNumber,
            softwareName: softwareName,
            fitnessAboType: fitnessAboType,
            fitnessCompany: fitnessCompany,
            onlineMagazineAboType: onlineMagazineAboType,
            onlineMagazineCompany: onlineMagazineCompany,
            membershipAboType: membershipAboType,
            membershipNumber: membershipNumber,
            customAboName: customAboName
        )

        if let selectedAboIndex {
            abos[selectedAboIndex] = abo
            self.selectedAboIndex = nil
        } else {
            abos.append(abo)
        }
    }

    private func loadAbo(_ abo: AboEntry) {
        selectedAboType = abo.type
        selectedStreamingProvider = abo.streamingProvider
        username = abo.username
        password = abo.password
        magazineName = abo.magazineName
        publicTransportType = abo.publicTransportType
        publicTransportCompany = abo.publicTransportCompany
        customPublicTransportCompany = abo.customPublicTransportCompany
        publicTransportAboNumber = abo.publicTransportAboNumber
        softwareName = abo.softwareName
        fitnessAboType = abo.fitnessAboType
        fitnessCompany = abo.fitnessCompany
        onlineMagazineAboType = abo.onlineMagazineAboType
        onlineMagazineCompany = abo.onlineMagazineCompany
        membershipAboType = abo.membershipAboType
        membershipNumber = abo.membershipNumber
        customAboName = abo.customAboName
    }

    private func resetInputFields() {
        selectedAboType = .pleaseSelect
        selectedStreamingProvider = .pleaseSelect
        username = ""
        password = ""
        magazineName = ""
        publicTransportType = .pleaseSelect
        publicTransportCompany = .pleaseSelect
        customPublicTransportCompany = ""
        publicTransportAboNumber = ""
        softwareName = ""
        fitnessAboType = ""
        fitnessCompany = ""
        onlineMagazineAboType = ""
        onlineMagazineCompany = ""
        membershipAboType = ""
        membershipNumber = ""
        customAboName = ""
        selectedAboIndex = nil
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
}

struct AboEntry: Identifiable {
    let id = UUID()
    var type: AboType
    var title: String
    var streamingProvider: StreamingProvider
    var username: String
    var password: String
    var magazineName: String
    var publicTransportType: PublicTransportAboType
    var publicTransportCompany: PublicTransportCompany
    var customPublicTransportCompany: String
    var publicTransportAboNumber: String
    var softwareName: String
    var fitnessAboType: String
    var fitnessCompany: String
    var onlineMagazineAboType: String
    var onlineMagazineCompany: String
    var membershipAboType: String
    var membershipNumber: String
    var customAboName: String
}

enum AboType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case streaming = "Streamingdienst"
    case magazine = "Zeitschriften"
    case publicTransport = "Öffentlicher Verkehr"
    case software = "Software / Apps"
    case fitness = "Fitness / Sport"
    case cloudStorage = "Cloud-Speicher"
    case news = "Online Zeitschriften"
    case membership = "Mitgliedschaft"
    case other = "Andere"

    var id: String { rawValue }
}

enum StreamingProvider: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case netflix = "Netflix"
    case disneyPlus = "Disney+"
    case amazonPrime = "Amazon Prime Video"
    case appleTV = "Apple TV+"
    case sky = "Sky"
    case hbo = "HBO / Max"
    case youtube = "YouTube Premium"
    case spotify = "Spotify"
    case instagram = "Instagram"
    case snapchat = "Snapchat"
    case paramount = "Paramount+"
    case other = "Andere"

    var id: String { rawValue }
}

enum PublicTransportAboType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case swissPass = "SwissPass"
    case ga = "Generalabonnement"
    case halfFare = "Halbtax"
    case regional = "Regionalabo / Verbundabo"
    case pointToPoint = "Streckenabo"
    case city = "Stadtabo"
    case other = "Andere"

    var id: String { rawValue }
}

enum PublicTransportCompany: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case sbb = "SBB"
    case zb = "Zentralbahn"
    case postAuto = "PostAuto"
    case zvv = "ZVV"
    case vbz = "VBZ"
    case zvvBonusPass = "ZVV BonusPass"
    case tpg = "TPG"
    case tl = "TL Lausanne"
    case bls = "BLS"
    case rhb = "Rhätische Bahn"
    case sob = "Südostbahn"
    case tpf = "TPF Fribourg"
    case libero = "Libero Tarifverbund"
    case ostwind = "Ost-Wind"
    case aWelle = "A-Welle"
    case zug = "Kanton Zug / Tarifverbund Zug"
    case passepartout = "Passepartout"
    case mobilis = "Mobilis"
    case unireso = "Unireso"
    case other = "Andere"

    var id: String { rawValue }
}

#Preview {
    AbosView()
}
