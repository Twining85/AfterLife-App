
import SwiftUI
import UniformTypeIdentifiers

struct FinanzenView: View {
    @State private var hasDebts = false
    @State private var debts: [DebtEntry] = []
    @State private var showDebtEntries = false

    @State private var bankEntries: [BankEntry] = []
    @State private var showBankEntries = false

    @State private var hasInsurance = false
    @State private var insuranceEntries: [InsuranceEntry] = []
    @State private var showInsuranceEntries = false

    @State private var hasProperties = false
    @State private var propertyEntries: [PropertyEntry] = []
    @State private var showPropertyEntries = false

    @State private var hasValuables = false
    @State private var valuableEntries: [ValuableEntry] = []
    @State private var showValuableEntries = false

    @State private var hasOldTaxReturn = false
    @State private var showOldTaxReturnImporter = false
    @State private var oldTaxReturnFileName = ""

    private var totalAssets: Double {
        bankEntries.reduce(0) { result, entry in
            result + (Double(entry.assets.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
    }

    private var totalDebts: Double {
        debts.reduce(0) { result, entry in
            result + (Double(entry.amount.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
    }

    private var totalPropertyValue: Double {
        propertyEntries.reduce(0) { result, entry in
            result + (Double(entry.marketValue.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
    }

    private var totalValuables: Double {
        valuableEntries.reduce(0) { result, entry in
            result + (Double(entry.amount.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Konten & Vermögen") {
                    Text("Bankdaten")
                        .font(.headline)

                    if bankEntries.count > 1 {
                        DisclosureGroup("Erfasste Konten", isExpanded: $showBankEntries) {
                            bankEntryList
                        }
                    } else {
                        bankEntryList
                    }

                    Button {
                        bankEntries.append(BankEntry())
                        if bankEntries.count > 1 {
                            showBankEntries = true
                        }
                    } label: {
                        Label("Bankdaten hinzufügen", systemImage: "plus.circle")
                    }

                    if totalAssets > 0 {
                        DetailBox {
                            HStack {
                                Text("Total Vermögen")
                                    .fontWeight(.semibold)

                                Spacer()

                                Text("\(totalAssets.formatted(.number.precision(.fractionLength(0)))) CHF")
                            }
                        }
                    }
                }

                Section("Schulden") {
                    Toggle("Ich habe Schulden", isOn: $hasDebts)
                        .onChange(of: hasDebts) { _, newValue in
                            if !newValue {
                                debts.removeAll()
                            }
                        }

                    if hasDebts {
                        if debts.count > 1 {
                            DisclosureGroup("Erfasste Schulden", isExpanded: $showDebtEntries) {
                                debtEntryList
                            }
                        } else {
                            debtEntryList
                        }

                        Button {
                            debts.append(DebtEntry())
                            if debts.count > 1 {
                                showDebtEntries = true
                            }
                        } label: {
                            Label("Schulden auflisten", systemImage: "plus.circle")
                        }

                        if totalDebts > 0 {
                            DetailBox {
                                HStack {
                                    Text("Total Schulden")
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text("\(totalDebts.formatted(.number.precision(.fractionLength(0)))) CHF")
                                }
                            }
                        }
                    }
                }

                Section("Liegenschaften") {
                    Toggle("Ich habe Liegenschaften", isOn: $hasProperties)
                        .onChange(of: hasProperties) { _, newValue in
                            if !newValue {
                                propertyEntries.removeAll()
                            }
                        }

                    if hasProperties {
                        if propertyEntries.count > 1 {
                            DisclosureGroup("Erfasste Liegenschaften", isExpanded: $showPropertyEntries) {
                                propertyEntryList
                            }
                        } else {
                            propertyEntryList
                        }

                        Button {
                            propertyEntries.append(PropertyEntry())
                            if propertyEntries.count > 1 {
                                showPropertyEntries = true
                            }
                        } label: {
                            Label("Liegenschaft hinzufügen", systemImage: "plus.circle")
                        }

                        if totalPropertyValue > 0 {
                            DetailBox {
                                HStack {
                                    Text("Total Verkehrswert")
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text("\(totalPropertyValue.formatted(.number.precision(.fractionLength(0)))) CHF")
                                }
                            }
                        }
                    }
                }

                Section("Wertsachen") {
                    Toggle("Ich habe Wertsachen", isOn: $hasValuables)
                        .onChange(of: hasValuables) { _, newValue in
                            if !newValue {
                                valuableEntries.removeAll()
                            }
                        }

                    if hasValuables {
                        if valuableEntries.count > 1 {
                            DisclosureGroup("Erfasste Wertsachen", isExpanded: $showValuableEntries) {
                                valuableEntryList
                            }
                        } else {
                            valuableEntryList
                        }

                        Button {
                            valuableEntries.append(ValuableEntry())
                            if valuableEntries.count > 1 {
                                showValuableEntries = true
                            }
                        } label: {
                            Label("Wertsache hinzufügen", systemImage: "plus.circle")
                        }

                        if totalValuables > 0 {
                            DetailBox {
                                HStack {
                                    Text("Total Wertsachen")
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text("\(totalValuables.formatted(.number.precision(.fractionLength(0)))) CHF")
                                }
                            }
                        }
                    }
                }

                Section("Alte Steuern zur Orientierung") {
                    Toggle("Ich möchte eine alte Steuererklärung beilegen", isOn: $hasOldTaxReturn)
                        .onChange(of: hasOldTaxReturn) { _, newValue in
                            if !newValue {
                                oldTaxReturnFileName = ""
                            }
                        }

                    if hasOldTaxReturn {
                        DetailBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Eine alte Steuererklärung kann den Hinterbliebenen und der Nachlassregelung als Orientierung dienen.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                if !oldTaxReturnFileName.isEmpty {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                        Text(oldTaxReturnFileName)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }

                                Button {
                                    showOldTaxReturnImporter = true
                                } label: {
                                    Label(oldTaxReturnFileName.isEmpty ? "Datei hochladen" : "Datei ersetzen", systemImage: "doc.badge.plus")
                                }
                            }
                        }
                    }
                }

                Section("Versicherungen") {
                    Toggle("Ich habe Versicherungen", isOn: $hasInsurance)
                        .onChange(of: hasInsurance) { _, newValue in
                            if !newValue {
                                insuranceEntries.removeAll()
                            }
                        }

                    if hasInsurance {
                        if insuranceEntries.count > 1 {
                            DisclosureGroup("Erfasste Versicherungen", isExpanded: $showInsuranceEntries) {
                                insuranceEntryList
                            }
                        } else {
                            insuranceEntryList
                        }

                        Button {
                            insuranceEntries.append(InsuranceEntry())
                            if insuranceEntries.count > 1 {
                                showInsuranceEntries = true
                            }
                        } label: {
                            Label("Versicherung hinzufügen", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Finanzen")
            .fileImporter(
                isPresented: $showOldTaxReturnImporter,
                allowedContentTypes: [UTType.pdf, UTType.image, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedFile = urls.first {
                        oldTaxReturnFileName = selectedFile.lastPathComponent
                    }
                case .failure:
                    oldTaxReturnFileName = ""
                }
            }
        }
    }
    private var bankEntryList: some View {
        ForEach(Array($bankEntries.enumerated()), id: \.element.id) { index, $bankEntry in
            DetailBox {
                HStack {
                    Text("Konto \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(role: .destructive) {
                        bankEntries.removeAll { $0.id == bankEntry.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Name der Bank", selection: $bankEntry.bank) {
                    ForEach(SwissBank.allCases) { bank in
                        Text(bank.rawValue).tag(bank)
                    }
                }

                if bankEntry.bank != .pleaseSelect {
                    labelledTextField("IBAN / Konto-Nr.", text: $bankEntry.iban)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Picker("Art des Kontos", selection: $bankEntry.accountType) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    labelledMultilineTextField("Adresse der Bank", text: $bankEntry.bankAddress, lineLimit: 2...4)

                    labelledTextField("Berater", text: $bankEntry.advisor)

                    labelledTextField("Vermögenswerte", text: $bankEntry.assets, keyboardType: .decimalPad)
                }
            }
        }
    }

    private var debtEntryList: some View {
        ForEach(Array($debts.enumerated()), id: \.element.id) { index, $debt in
            DetailBox {
                HStack {
                    Text("Schuld \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(role: .destructive) {
                        debts.removeAll { $0.id == debt.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Art der Schuld", selection: $debt.type) {
                    ForEach(DebtType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if debt.type != .pleaseSelect {
                    labelledTextField("Bank oder Person", text: $debt.creditor)
                    labelledTextField("Betrag", text: $debt.amount, keyboardType: .decimalPad)
                }
            }
        }
    }
    private var propertyEntryList: some View {
        ForEach(Array($propertyEntries.enumerated()), id: \.element.id) { index, $propertyEntry in
            DetailBox {
                HStack {
                    Text("Liegenschaft \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(role: .destructive) {
                        propertyEntries.removeAll { $0.id == propertyEntry.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Art", selection: $propertyEntry.type) {
                    ForEach(PropertyType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if propertyEntry.type != .pleaseSelect {
                    labelledTextField("Verkehrswert", text: $propertyEntry.marketValue, keyboardType: .decimalPad)

                    labelledTextField("Eigenmietwert", text: $propertyEntry.imputedRentalValue, keyboardType: .decimalPad)
                }
            }
        }
    }

    private var valuableEntryList: some View {
        ForEach(Array($valuableEntries.enumerated()), id: \.element.id) { index, $valuableEntry in
            DetailBox {
                HStack {
                    Text("Wertsache \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(role: .destructive) {
                        valuableEntries.removeAll { $0.id == valuableEntry.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Art", selection: $valuableEntry.type) {
                    ForEach(ValuableType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if valuableEntry.type != .pleaseSelect {
                    labelledTextField("Betrag", text: $valuableEntry.amount, keyboardType: .decimalPad)
                }
            }
        }
    }

    private var insuranceEntryList: some View {
        ForEach(Array($insuranceEntries.enumerated()), id: \.element.id) { index, $insuranceEntry in
            DetailBox {
                HStack {
                    Text("Versicherung \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(role: .destructive) {
                        insuranceEntries.removeAll { $0.id == insuranceEntry.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Art der Versicherung", selection: $insuranceEntry.type) {
                    ForEach(InsuranceType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if insuranceEntry.type != .pleaseSelect {
                    labelledTextField("Name der Versicherung", text: $insuranceEntry.provider)

                    labelledTextField("Police-Nr. / Vertrags-Nr.", text: $insuranceEntry.policyNumber)
                        .autocorrectionDisabled()

                    labelledMultilineTextField("Bemerkungen", text: $insuranceEntry.notes, lineLimit: 2...5)
                }
            }
        }
    }
    // Helper Views
    private func labelledTextField(_ title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(title, text: text)
                .keyboardType(keyboardType)
        }
    }

    private func labelledMultilineTextField(_ title: String, text: Binding<String>, lineLimit: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(title, text: text, axis: .vertical)
                .lineLimit(lineLimit)
        }
    }
}

struct DebtEntry: Identifiable {
    let id = UUID()
    var type: DebtType = .pleaseSelect
    var amount = ""
    var creditor = ""
}

enum DebtType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case mortgage = "Hypothek"
    case privateDebt = "Private Schulden"
    case personalLoan = "Privatkredit"
    case creditCardDebt = "Kreditkartenschulden"
    case leasing = "Leasing"
    case taxDebt = "Steuerschulden"
    case other = "Andere"

    var id: String { rawValue }
}

struct PropertyEntry: Identifiable {
    let id = UUID()
    var type: PropertyType = .pleaseSelect
    var marketValue = ""
    var imputedRentalValue = ""
}

enum PropertyType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case house = "Haus"
    case apartment = "Wohnung"
    case agriculturalLand = "Landwirtschaft"
    case land = "Bauland / Grundstück"
    case holidayHome = "Ferienwohnung / Ferienhaus"
    case commercialProperty = "Gewerbeliegenschaft"
    case other = "Andere"

    var id: String { rawValue }
}

struct ValuableEntry: Identifiable {
    let id = UUID()
    var type: ValuableType = .pleaseSelect
    var amount = ""
}

enum ValuableType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case jewelry = "Schmuck"
    case art = "Kunst / Bilder"
    case watches = "Uhren"
    case preciousMetals = "Edelmetalle"
    case collectibles = "Sammlerstücke"
    case vehicles = "Fahrzeuge"
    case other = "Andere"

    var id: String { rawValue }
}

struct BankEntry: Identifiable {
    let id = UUID()
    var bank: SwissBank = .pleaseSelect
    var iban = ""
    var accountType: AccountType = .pleaseSelect
    var bankAddress = ""
    var advisor = ""
    var assets = ""
}

enum AccountType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case salaryAccount = "Lohnkonto"
    case savingsAccount = "Sparkonto"
    case securities = "Wertpapiere"
    case pillar3a = "Säule 3a"
    case vestedBenefits = "Freizügigkeitskonto"
    case businessAccount = "Geschäftskonto"
    case other = "Andere"

    var id: String { rawValue }
}

enum SwissBank: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case appenzellerKantonalbank = "Appenzeller Kantonalbank"
    case bcv = "Banque Cantonale Vaudoise"
    case bernerKantonalbank = "Berner Kantonalbank"
    case cler = "Bank Cler"
    case graubuendnerKantonalbank = "Graubündner Kantonalbank"
    case juliusBaer = "Julius Bär"
    case luzernerKantonalbank = "Luzerner Kantonalbank"
    case migrosBank = "Migros Bank"
    case neon = "neon"
    case nidwaldnerKantonalbank = "Nidwaldner Kantonalbank"
    case obwaldnerKantonalbank = "Obwaldner Kantonalbank"
    case postFinance = "PostFinance"
    case raiffeisen = "Raiffeisen"
    case schwyzerKantonalbank = "Schwyzer Kantonalbank"
    case stGallerKantonalbank = "St. Galler Kantonalbank"
    case thurgauerKantonalbank = "Thurgauer Kantonalbank"
    case ubs = "UBS"
    case valiant = "Valiant"
    case vontobel = "Vontobel"
    case zkb = "Zürcher Kantonalbank"
    case zugerKantonalbank = "Zuger Kantonalbank"
    case other = "Andere"

    var id: String { rawValue }
}

struct InsuranceEntry: Identifiable {
    let id = UUID()
    var type: InsuranceType = .pleaseSelect
    var provider = ""
    var policyNumber = ""
    var notes = ""
}

enum InsuranceType: String, CaseIterable, Identifiable {
    case pleaseSelect = "Bitte wählen"
    case lifeInsurance = "Lebensversicherung"
    case pensionFund = "Pensionskasse"
    case pillar3a = "Säule 3a"
    case vestedBenefits = "Freizügigkeitskonto"
    case disabilityInsurance = "Invaliditätsversicherung"
    case accidentInsurance = "Unfallversicherung"
    case healthInsurance = "Krankenkasse"
    case householdInsurance = "Hausratversicherung"
    case legalProtection = "Rechtsschutzversicherung"
    case liabilityInsurance = "Privathaftpflichtversicherung"
    case vehicleInsurance = "Fahrzeugversicherung"
    case buildingInsurance = "Gebäudeversicherung"
    case travelInsurance = "Reiseversicherung"
    case other = "Andere"

    var id: String { rawValue }
}


#Preview {
    FinanzenView()
}
