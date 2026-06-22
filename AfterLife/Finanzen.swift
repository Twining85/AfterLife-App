
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import QuickLook

struct FinanzenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gespeicherteBankkonten: [BankkontoModell]
    @Query private var gespeicherteSchulden: [SchuldenModell]
    @Query private var gespeicherteVersicherungen: [VersicherungModell]
    @Query private var gespeicherteLiegenschaften: [LiegenschaftModell]
    @Query private var gespeicherteWertsachen: [WertsacheModell]
    @Query private var gespeicherteSteuerdokumente: [SteuerdokumentModell]
    @State private var finanzenGeladen = false
    @State private var exchangeRates: [CurrencyType: Double] = [.chf: 1.0]
    @State private var exchangeRateDate = ""
    @State private var exchangeRateErrorMessage = ""
    @State private var showExchangeRateInfo = false
    @State private var debts: [DebtEntry] = []
    @State private var showDebtEntries = false

    @State private var bankEntries: [BankEntry] = []
    @State private var showBankEntries = false

    @State private var insuranceEntries: [InsuranceEntry] = []
    @State private var showInsuranceEntries = false

    @State private var propertyEntries: [PropertyEntry] = []
    @State private var showPropertyEntries = false

    @State private var valuableEntries: [ValuableEntry] = []
    @State private var showValuableEntries = false

    @State private var hasOldTaxReturn = false
    @State private var showOldTaxReturnImporter = false
    @State private var oldTaxReturnFileName = ""
    @State private var oldTaxReturnFilePath = ""
    @State private var oldTaxReturnFileData: Data?
    @State private var oldTaxReturnPreviewURL: URL?
    @State private var zuletztGepruefteIBANs: [UUID: String] = [:]

    private var totalAssets: Double {
        bankEntries.reduce(0) { result, entry in
            result + convertToCHF(amountText: entry.assets, currency: entry.currency)
        }
    }

    private func finanzSection<Content: View>(
        title: String,
        totalTitle: String?,
        totalValue: Double?,
        showApproximation: Bool,
        entryCount: Int,
        isExpanded: Binding<Bool>,
        addAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                if entryCount == 0 {
                    Text("Noch keine Einträge erfasst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if entryCount >= 3 {
                    DisclosureGroup("Erfasste Einträge (\(entryCount))", isExpanded: isExpanded) {
                        VStack(spacing: 12) {
                            content()
                        }
                        .padding(.top, 10)
                    }
                } else {
                    VStack(spacing: 12) {
                        content()
                    }
                }

                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.black))
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .accessibilityLabel("Neuen Eintrag hinzufügen")

                if let totalTitle, let totalValue, totalValue > 0 {
                    Divider()

                    HStack {
                        Text(totalTitle)
                            .fontWeight(.semibold)

                        Spacer()

                        Text("\(showApproximation ? "ca. " : "")\(formatCHF(totalValue))")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var steuerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alte Steuern zur Orientierung")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                Button {
                    hasOldTaxReturn = true
                    showOldTaxReturnImporter = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.black))
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .accessibilityLabel("Steuerdokument hochladen")

                Text("Eine alte Steuererklärung kann den Hinterbliebenen und der Nachlassregelung als Orientierung dienen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if oldTaxReturnFileName.isEmpty {
                    Text("Noch kein Dokument hochgeladen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)

                        Button {
                            zeigeSteuerdokumentVorschau()
                        } label: {
                            Text(oldTaxReturnFileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Steuerdokument Vorschau öffnen")

                        Button {
                            zeigeSteuerdokumentVorschau()
                        } label: {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Steuerdokument anzeigen")

                        Button(role: .destructive) {
                            loescheSteuerdokument()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Steuerdokument löschen")
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var totalDebts: Double {
        debts.reduce(0) { result, entry in
            result + convertToCHF(amountText: entry.amount, currency: entry.currency)
        }
    }

    private var totalPropertyValue: Double {
        propertyEntries.reduce(0) { result, entry in
            result + convertToCHF(amountText: entry.marketValue, currency: entry.marketValueCurrency)
        }
    }

    private var totalValuables: Double {
        valuableEntries.reduce(0) { result, entry in
            result + convertToCHF(amountText: entry.amount, currency: entry.currency)
        }
    }

    private var totalInsuranceAssets: Double {
        insuranceEntries.reduce(0) { result, entry in
            guard entry.type == .pensionFund || entry.type == .pillar3a || entry.type == .lifeInsurance else {
                return result
            }

            return result + convertToCHF(amountText: entry.amount, currency: entry.currency)
        }
    }

    private func hasMixedCurrencies(_ currencies: [CurrencyType]) -> Bool {
        Set(currencies).count > 1
    }

    private var finanzenSpeicherSignatur: String {
        [
            bankEntries.map { entry in
                [entry.id.uuidString, entry.bankName, entry.iban, entry.accountType.rawValue, entry.bankAddress, entry.advisor, entry.assets, entry.currency.rawValue].joined(separator: "|")
            }.joined(separator: "#"),
            debts.map { entry in
                [entry.id.uuidString, entry.type.rawValue, entry.amount, entry.currency.rawValue, entry.creditor].joined(separator: "|")
            }.joined(separator: "#"),
            insuranceEntries.map { entry in
                [entry.id.uuidString, entry.type.rawValue, entry.provider, entry.policyNumber, entry.amount, entry.currency.rawValue, entry.notes].joined(separator: "|")
            }.joined(separator: "#"),
            propertyEntries.map { entry in
                [entry.id.uuidString, entry.type.rawValue, entry.marketValue, entry.marketValueCurrency.rawValue, entry.imputedRentalValue, entry.imputedRentalValueCurrency.rawValue].joined(separator: "|")
            }.joined(separator: "#"),
            valuableEntries.map { entry in
                [entry.id.uuidString, entry.type.rawValue, entry.amount, entry.currency.rawValue].joined(separator: "|")
            }.joined(separator: "#"),
            String(hasOldTaxReturn),
            oldTaxReturnFileName,
            oldTaxReturnFilePath,
            oldTaxReturnFileData?.count.description ?? ""
        ].joined(separator: "§")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    finanzSection(
                        title: "Konten & Vermögen",
                        totalTitle: "Total Vermögen",
                        totalValue: totalAssets,
                        showApproximation: hasMixedCurrencies(bankEntries.compactMap { entry in
                            entry.assets.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.currency
                        }),
                        entryCount: bankEntries.count,
                        isExpanded: $showBankEntries,
                        addAction: {
                            bankEntries.append(BankEntry())
                            if bankEntries.count > 2 {
                                showBankEntries = true
                            }
                            speichereFinanzenInSwiftData()
                        },
                        content: {
                            bankEntryList
                        }
                    )

                    finanzSection(
                        title: "Schulden",
                        totalTitle: "Total Schulden",
                        totalValue: totalDebts,
                        showApproximation: hasMixedCurrencies(debts.compactMap { entry in
                            entry.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.currency
                        }),
                        entryCount: debts.count,
                        isExpanded: $showDebtEntries,
                        addAction: {
                            debts.append(DebtEntry())
                            if debts.count > 2 {
                                showDebtEntries = true
                            }
                            speichereFinanzenInSwiftData()
                        },
                        content: {
                            debtEntryList
                        }
                    )

                    finanzSection(
                        title: "Liegenschaften",
                        totalTitle: "Total Verkehrswert",
                        totalValue: totalPropertyValue,
                        showApproximation: hasMixedCurrencies(propertyEntries.compactMap { entry in
                            entry.marketValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.marketValueCurrency
                        }),
                        entryCount: propertyEntries.count,
                        isExpanded: $showPropertyEntries,
                        addAction: {
                            propertyEntries.append(PropertyEntry())
                            if propertyEntries.count > 2 {
                                showPropertyEntries = true
                            }
                            speichereFinanzenInSwiftData()
                        },
                        content: {
                            propertyEntryList
                        }
                    )

                    finanzSection(
                        title: "Wertsachen",
                        totalTitle: "Total Wertsachen",
                        totalValue: totalValuables,
                        showApproximation: hasMixedCurrencies(valuableEntries.compactMap { entry in
                            entry.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.currency
                        }),
                        entryCount: valuableEntries.count,
                        isExpanded: $showValuableEntries,
                        addAction: {
                            valuableEntries.append(ValuableEntry())
                            if valuableEntries.count > 2 {
                                showValuableEntries = true
                            }
                            speichereFinanzenInSwiftData()
                        },
                        content: {
                            valuableEntryList
                        }
                    )

                    steuerSection

                    finanzSection(
                        title: "Versicherungen",
                        totalTitle: "Total Vorsorgewerte",
                        totalValue: totalInsuranceAssets,
                        showApproximation: hasMixedCurrencies(insuranceEntries.compactMap { entry in
                            guard entry.type == .pensionFund || entry.type == .pillar3a || entry.type == .lifeInsurance else { return nil }
                            return entry.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.currency
                        }),
                        entryCount: insuranceEntries.count,
                        isExpanded: $showInsuranceEntries,
                        addAction: {
                            insuranceEntries.append(InsuranceEntry())
                            if insuranceEntries.count > 2 {
                                showInsuranceEntries = true
                            }
                            speichereFinanzenInSwiftData()
                        },
                        content: {
                            insuranceEntryList
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Finanzen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExchangeRateInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .help("Hinweis zur Umrechnung: Totale werden bei unterschiedlichen Währungen anhand aktueller Referenz-Wechselkurse in CHF umgerechnet. Die angezeigten Beträge dienen lediglich der Orientierung und stellen keine verbindliche Bewertung dar. Wechselkurse können sich laufend ändern.")
                    .popover(isPresented: $showExchangeRateInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text("Hinweis zur Umrechnung")
                                    .font(.headline)

                                Spacer()

                                Button {
                                    showExchangeRateInfo = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Hinweis schliessen")
                            }

                            Text("Totale werden bei unterschiedlichen Währungen anhand aktueller Referenz-Wechselkurse in CHF umgerechnet. Die angezeigten Beträge dienen lediglich der Orientierung und stellen keine verbindliche Bewertung dar. Wechselkurse können sich laufend ändern.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: 320, alignment: .leading)
                    }
                }
            }
            .task {
                await loadExchangeRates()
            }
            .onAppear {
                ladeFinanzenAusSwiftData()
            }
            .onChange(of: finanzenSpeicherSignatur) { _, _ in
                speichereFinanzenInSwiftData()
            }
            .fileImporter(
                isPresented: $showOldTaxReturnImporter,
                allowedContentTypes: [UTType.pdf, UTType.image, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedFile = urls.first {
                        importiereSteuerdokument(selectedFile)
                    }
                case .failure:
                    oldTaxReturnFileName = ""
                    oldTaxReturnFilePath = ""
                    oldTaxReturnFileData = nil
                    speichereFinanzenInSwiftData()
                }
            }
            .quickLookPreview($oldTaxReturnPreviewURL)
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
                        speichereFinanzenInSwiftData()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Art des Kontos", selection: $bankEntry.accountType) {
                    ForEach(AccountType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if bankEntry.accountType != .pleaseSelect {
                    labelledTextField("IBAN / Konto-Nr.", text: $bankEntry.iban)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: bankEntry.iban) { _, _ in
                            pruefeIBANUndFuelleBankdatenAutomatisch(fuer: bankEntry.id)
                        }
                        .onSubmit {
                            pruefeIBANUndFuelleBankdatenAutomatisch(fuer: bankEntry.id, erzwingen: true)
                        }

                    labelledTextField("Name der Bank", text: $bankEntry.bankName)
                        .autocorrectionDisabled()

                    labelledMultilineTextField("Adresse der Bank", text: $bankEntry.bankAddress, lineLimit: 2...4)

                    labelledTextField("Berater", text: $bankEntry.advisor)

                    labelledMoneyField("Vermögenswerte", amount: $bankEntry.assets, currency: $bankEntry.currency)
                }
            }
            .padding(2)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    bankEntries.removeAll { $0.id == bankEntry.id }
                    speichereFinanzenInSwiftData()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }
    private func pruefeIBANUndFuelleBankdatenAutomatisch(fuer entryID: UUID, erzwingen: Bool = false) {
        guard let index = bankEntries.firstIndex(where: { $0.id == entryID }) else { return }

        let iban = bankEntries[index].iban
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard iban.count >= 15 else { return }

        if !erzwingen, zuletztGepruefteIBANs[entryID] == iban {
            return
        }

        zuletztGepruefteIBANs[entryID] = iban

        Task {
            await fuelleBankdatenAusIBAN(fuer: entryID)
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
                        speichereFinanzenInSwiftData()
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
                    labelledTextField("Name der Bank oder Person", text: $debt.creditor)

                    labelledMoneyField("Betrag", amount: $debt.amount, currency: $debt.currency)
                }
            }
            .padding(2)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    debts.removeAll { $0.id == debt.id }
                    speichereFinanzenInSwiftData()
                } label: {
                    Label("Löschen", systemImage: "trash")
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
                        speichereFinanzenInSwiftData()
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
                    labelledMoneyField("Verkehrswert", amount: $propertyEntry.marketValue, currency: $propertyEntry.marketValueCurrency)

                    labelledMoneyField("Eigenmietwert", amount: $propertyEntry.imputedRentalValue, currency: $propertyEntry.imputedRentalValueCurrency)
                }
            }
            .padding(2)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    propertyEntries.removeAll { $0.id == propertyEntry.id }
                    speichereFinanzenInSwiftData()
                } label: {
                    Label("Löschen", systemImage: "trash")
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
                        speichereFinanzenInSwiftData()
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
                    labelledMoneyField("Betrag", amount: $valuableEntry.amount, currency: $valuableEntry.currency)
                }
            }
            .padding(2)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    valuableEntries.removeAll { $0.id == valuableEntry.id }
                    speichereFinanzenInSwiftData()
                } label: {
                    Label("Löschen", systemImage: "trash")
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
                        speichereFinanzenInSwiftData()
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

                    if insuranceEntry.type == .pensionFund || insuranceEntry.type == .pillar3a {
                        labelledMoneyField("Betrag", amount: $insuranceEntry.amount, currency: $insuranceEntry.currency)
                    }

                    if insuranceEntry.type == .lifeInsurance {
                        labelledMoneyField("Versicherungssumme", amount: $insuranceEntry.amount, currency: $insuranceEntry.currency)
                    }

                    labelledMultilineTextField("Bemerkungen", text: $insuranceEntry.notes, lineLimit: 2...5)
                }
            }
            .padding(2)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    insuranceEntries.removeAll { $0.id == insuranceEntry.id }
                    speichereFinanzenInSwiftData()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }
    private func ladeFinanzenAusSwiftData() {
        guard !finanzenGeladen else { return }

        bankEntries = gespeicherteBankkonten
            .sorted { $0.erstelltAm < $1.erstelltAm }
            .map { konto in
                BankEntry(
                    id: UUID(uuidString: konto.eintragsID) ?? UUID(),
                    bankName: konto.bankname,
                    iban: konto.iban,
                    accountType: AccountType(rawValue: konto.kontoArt) ?? .pleaseSelect,
                    bankAddress: konto.bankAdresse,
                    advisor: konto.berater,
                    assets: konto.vermoegenswert == 0 ? "" : String(konto.vermoegenswert),
                    currency: CurrencyType(rawValue: konto.waehrung) ?? .chf
                )
            }

        debts = gespeicherteSchulden
            .sorted { $0.erstelltAm < $1.erstelltAm }
            .map { schuld in
                DebtEntry(
                    id: UUID(uuidString: schuld.eintragsID) ?? UUID(),
                    type: DebtType(rawValue: schuld.art) ?? .pleaseSelect,
                    amount: schuld.betrag == 0 ? "" : String(schuld.betrag),
                    currency: CurrencyType(rawValue: schuld.waehrung) ?? .chf,
                    creditor: schuld.glaeubiger
                )
            }

        insuranceEntries = gespeicherteVersicherungen
            .sorted { $0.erstelltAm < $1.erstelltAm }
            .map { versicherung in
                InsuranceEntry(
                    id: UUID(uuidString: versicherung.eintragsID) ?? UUID(),
                    type: InsuranceType(rawValue: versicherung.art) ?? .pleaseSelect,
                    provider: versicherung.anbieter,
                    policyNumber: versicherung.policenNummer,
                    amount: versicherung.praemie == 0 ? "" : String(versicherung.praemie),
                    currency: CurrencyType(rawValue: versicherung.waehrung) ?? .chf,
                    notes: versicherung.bemerkungen
                )
            }

        propertyEntries = gespeicherteLiegenschaften
            .sorted { $0.erstelltAm < $1.erstelltAm }
            .map { liegenschaft in
                PropertyEntry(
                    id: UUID(uuidString: liegenschaft.eintragsID) ?? UUID(),
                    type: PropertyType(rawValue: liegenschaft.art) ?? .pleaseSelect,
                    marketValue: liegenschaft.verkehrswert == 0 ? "" : String(liegenschaft.verkehrswert),
                    marketValueCurrency: CurrencyType(rawValue: liegenschaft.waehrung) ?? .chf,
                    imputedRentalValue: liegenschaft.eigenmietwert == 0 ? "" : String(liegenschaft.eigenmietwert),
                    imputedRentalValueCurrency: CurrencyType(rawValue: liegenschaft.waehrung) ?? .chf
                )
            }

        valuableEntries = gespeicherteWertsachen
            .sorted { $0.erstelltAm < $1.erstelltAm }
            .map { wertsache in
                ValuableEntry(
                    id: UUID(uuidString: wertsache.eintragsID) ?? UUID(),
                    type: ValuableType(rawValue: wertsache.art) ?? .pleaseSelect,
                    amount: wertsache.betrag == 0 ? "" : String(wertsache.betrag),
                    currency: CurrencyType(rawValue: wertsache.waehrung) ?? .chf
                )
            }

        if let steuerdokument = gespeicherteSteuerdokumente.sorted(by: { $0.hochgeladenAm < $1.hochgeladenAm }).last {
            hasOldTaxReturn = !steuerdokument.dateiName.isEmpty
            oldTaxReturnFileName = steuerdokument.dateiName
            oldTaxReturnFilePath = steuerdokument.dokumentPfad
            oldTaxReturnFileData = steuerdokument.dateiDaten
        }

        finanzenGeladen = true
    }

    private func speichereFinanzenInSwiftData() {
        guard finanzenGeladen else { return }

        speichereBankkonten()
        speichereSchulden()
        speichereVersicherungen()
        speichereLiegenschaften()
        speichereWertsachen()
        speichereSteuerdokumente()

        do {
            try modelContext.save()
        } catch {
            print("Finanzdaten konnten nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    private func speichereBankkonten() {
        let gueltigeEintraege = bankEntries.filter {
            $0.accountType != .pleaseSelect
        }

        let gueltigeIDs = Set(gueltigeEintraege.map { $0.id.uuidString })

        gespeicherteBankkonten
            .filter { !gueltigeIDs.contains($0.eintragsID) }
            .forEach { modelContext.delete($0) }

        for entry in gueltigeEintraege {
            let bestehendesModell = gespeicherteBankkonten.first { $0.eintragsID == entry.id.uuidString }
            let modell = bestehendesModell ?? BankkontoModell(eintragsID: entry.id.uuidString)

            if bestehendesModell == nil {
                modelContext.insert(modell)
            }

            modell.bankname = entry.bankName
            modell.bankAdresse = entry.bankAddress
            modell.iban = entry.iban
            modell.kontoArt = entry.accountType.rawValue
            modell.berater = entry.advisor
            modell.vermoegenswert = parsedAmount(entry.assets)
            modell.waehrung = entry.currency.rawValue
            modell.aktualisiertAm = Date()
        }
    }

    private func speichereSchulden() {
        let gueltigeEintraege = debts.filter {
            $0.type != .pleaseSelect
        }

        let gueltigeIDs = Set(gueltigeEintraege.map { $0.id.uuidString })

        gespeicherteSchulden
            .filter { !gueltigeIDs.contains($0.eintragsID) }
            .forEach { modelContext.delete($0) }

        for entry in gueltigeEintraege {
            let bestehendesModell = gespeicherteSchulden.first { $0.eintragsID == entry.id.uuidString }
            let modell = bestehendesModell ?? SchuldenModell(eintragsID: entry.id.uuidString)

            if bestehendesModell == nil {
                modelContext.insert(modell)
            }

            modell.art = entry.type.rawValue
            modell.betrag = parsedAmount(entry.amount)
            modell.waehrung = entry.currency.rawValue
            modell.glaeubiger = entry.creditor
            modell.aktualisiertAm = Date()
        }
    }

    private func speichereVersicherungen() {
        let gueltigeEintraege = insuranceEntries.filter {
            $0.type != .pleaseSelect
        }

        let gueltigeIDs = Set(gueltigeEintraege.map { $0.id.uuidString })

        gespeicherteVersicherungen
            .filter { !gueltigeIDs.contains($0.eintragsID) }
            .forEach { modelContext.delete($0) }

        for entry in gueltigeEintraege {
            let bestehendesModell = gespeicherteVersicherungen.first { $0.eintragsID == entry.id.uuidString }
            let modell = bestehendesModell ?? VersicherungModell(eintragsID: entry.id.uuidString)

            if bestehendesModell == nil {
                modelContext.insert(modell)
            }

            modell.art = entry.type.rawValue
            modell.anbieter = entry.provider
            modell.policenNummer = entry.policyNumber
            modell.praemie = parsedAmount(entry.amount)
            modell.waehrung = entry.currency.rawValue
            modell.bemerkungen = entry.notes
            modell.aktualisiertAm = Date()
        }
    }

    private func speichereLiegenschaften() {
        let gueltigeEintraege = propertyEntries.filter {
            $0.type != .pleaseSelect
        }

        let gueltigeIDs = Set(gueltigeEintraege.map { $0.id.uuidString })

        gespeicherteLiegenschaften
            .filter { !gueltigeIDs.contains($0.eintragsID) }
            .forEach { modelContext.delete($0) }

        for entry in gueltigeEintraege {
            let bestehendesModell = gespeicherteLiegenschaften.first { $0.eintragsID == entry.id.uuidString }
            let modell = bestehendesModell ?? LiegenschaftModell(eintragsID: entry.id.uuidString)

            if bestehendesModell == nil {
                modelContext.insert(modell)
            }

            modell.art = entry.type.rawValue
            modell.verkehrswert = parsedAmount(entry.marketValue)
            modell.eigenmietwert = parsedAmount(entry.imputedRentalValue)
            modell.waehrung = entry.marketValueCurrency.rawValue
            modell.aktualisiertAm = Date()
        }
    }

    private func speichereWertsachen() {
        let gueltigeEintraege = valuableEntries.filter {
            $0.type != .pleaseSelect
        }

        let gueltigeIDs = Set(gueltigeEintraege.map { $0.id.uuidString })

        gespeicherteWertsachen
            .filter { !gueltigeIDs.contains($0.eintragsID) }
            .forEach { modelContext.delete($0) }

        for entry in gueltigeEintraege {
            let bestehendesModell = gespeicherteWertsachen.first { $0.eintragsID == entry.id.uuidString }
            let modell = bestehendesModell ?? WertsacheModell(eintragsID: entry.id.uuidString)

            if bestehendesModell == nil {
                modelContext.insert(modell)
            }

            modell.art = entry.type.rawValue
            modell.betrag = parsedAmount(entry.amount)
            modell.waehrung = entry.currency.rawValue
            modell.aktualisiertAm = Date()
        }
    }

    private func speichereSteuerdokumente() {
        gespeicherteSteuerdokumente.forEach { modelContext.delete($0) }

        if hasOldTaxReturn && !oldTaxReturnFileName.isEmpty {
            let modell = SteuerdokumentModell(
                eintragsID: "alte-steuern",
                dateiName: oldTaxReturnFileName,
                dokumentPfad: oldTaxReturnFilePath
            )
            modell.dateiDaten = oldTaxReturnFileData
            modelContext.insert(modell)
        }
    }

    private func importiereSteuerdokument(_ sourceURL: URL) {
        let hasSecurityAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let dateiDaten = try? Data(contentsOf: sourceURL)

        do {
            let documentsDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let targetDirectory = documentsDirectory.appendingPathComponent("Steuerdokumente", isDirectory: true)

            if !FileManager.default.fileExists(atPath: targetDirectory.path) {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            }

            if !oldTaxReturnFilePath.isEmpty {
                let oldURL = URL(fileURLWithPath: oldTaxReturnFilePath)
                if FileManager.default.fileExists(atPath: oldURL.path) {
                    try? FileManager.default.removeItem(at: oldURL)
                }
            }

            let fileExtension = sourceURL.pathExtension
            let safeFileName = "steuererklaerung-\(UUID().uuidString).\(fileExtension)"
            let targetURL = targetDirectory.appendingPathComponent(safeFileName)

            try FileManager.default.copyItem(at: sourceURL, to: targetURL)

            oldTaxReturnFileName = sourceURL.lastPathComponent
            oldTaxReturnFilePath = targetURL.path
            oldTaxReturnFileData = dateiDaten
            hasOldTaxReturn = true
            speichereFinanzenInSwiftData()
        } catch {
            print("Steuerdokument konnte nicht importiert werden: \(error.localizedDescription)")
        }
    }

    private func zeigeSteuerdokumentVorschau() {
        if !oldTaxReturnFilePath.isEmpty {
            let url = URL(fileURLWithPath: oldTaxReturnFilePath)

            if FileManager.default.fileExists(atPath: url.path) {
                oldTaxReturnPreviewURL = url
                return
            }
        }

        guard !oldTaxReturnFileName.isEmpty,
              let tempURL = temporaereSteuerdokumentURL() else { return }

        oldTaxReturnPreviewURL = tempURL
    }

    private func temporaereSteuerdokumentURL() -> URL? {
        guard let oldTaxReturnFileData else { return nil }

        let bereinigterDateiname = oldTaxReturnFileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(bereinigterDateiname)

        do {
            try oldTaxReturnFileData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }

    private func loescheSteuerdokument() {
        if !oldTaxReturnFilePath.isEmpty {
            let url = URL(fileURLWithPath: oldTaxReturnFilePath)

            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        oldTaxReturnFileName = ""
        oldTaxReturnFilePath = ""
        oldTaxReturnFileData = nil
        oldTaxReturnPreviewURL = nil
        hasOldTaxReturn = false
        speichereFinanzenInSwiftData()
    }

    // Helper Views
    private func parsedAmount(_ amountText: String) -> Double {
        let normalizedAmount = amountText
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalizedAmount) ?? 0
    }

    private func convertToCHF(amountText: String, currency: CurrencyType) -> Double {
        let amount = parsedAmount(amountText)
        let rate = exchangeRates[currency] ?? 0
        return amount * rate
    }

    private func formatCHF(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) CHF"
    }

    private func fuelleBankdatenAusIBAN(fuer entryID: UUID) async {
        guard let index = bankEntries.firstIndex(where: { $0.id == entryID }) else { return }

        let iban = bankEntries[index].iban
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard iban.count >= 15 else { return }

        do {
            let bankdaten = try await OpenIBANService.validateIBAN(iban)

            await MainActor.run {
                guard let currentIndex = bankEntries.firstIndex(where: { $0.id == entryID }) else { return }

                bankEntries[currentIndex].iban = iban
                zuletztGepruefteIBANs[entryID] = iban

                if let bankName = bankdaten.bankName, !bankName.isEmpty {
                    bankEntries[currentIndex].bankName = bankName
                }

                let addressParts = [bankdaten.zip, bankdaten.city]
                    .compactMap { value in
                        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return trimmedValue.isEmpty ? nil : trimmedValue
                    }

                if !addressParts.isEmpty {
                    bankEntries[currentIndex].bankAddress = addressParts.joined(separator: " ")
                }

                speichereFinanzenInSwiftData()
            }
        } catch {
            print("IBAN konnte nicht geprüft werden: \(error.localizedDescription)")
        }
    }

    private func loadExchangeRates() async {
        do {
            let response = try await ExchangeRateService.fetchRatesToCHF()
            exchangeRates = response.rates
            exchangeRateDate = response.date
            exchangeRateErrorMessage = ""
        } catch {
            exchangeRates = [.chf: 1.0]
            exchangeRateDate = ""
            exchangeRateErrorMessage = "Wechselkurse konnten nicht geladen werden. Zurzeit werden nur CHF-Beträge korrekt im Total berücksichtigt."
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

    private func labelledDecimalTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let formattedValue = formatDecimalInput(newValue)

                    if formattedValue != newValue {
                        text.wrappedValue = formattedValue
                    }
                }
        }
    }

    private func labelledMoneyField(_ title: String, amount: Binding<String>, currency: Binding<CurrencyType>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(title, text: amount)
                    .keyboardType(.decimalPad)
                    .onChange(of: amount.wrappedValue) { _, newValue in
                        let formattedValue = formatDecimalInput(newValue)

                        if formattedValue != newValue {
                            amount.wrappedValue = formattedValue
                        }
                    }

                Picker("Währung", selection: currency) {
                    ForEach(CurrencyType.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 92, alignment: .trailing)
            }
        }
    }

    private func formatDecimalInput(_ value: String) -> String {
        let digitsOnly = String(value.filter { $0.isNumber })

        guard !digitsOnly.isEmpty else {
            return ""
        }

        let integerDigits = removeLeadingZeros(from: digitsOnly)
        return formatThousands(integerDigits)
    }

    private func removeLeadingZeros(from digits: String) -> String {
        let trimmedDigits = digits.drop { $0 == "0" }
        return trimmedDigits.isEmpty ? "0" : String(trimmedDigits)
    }

    private func formatThousands(_ digits: String) -> String {
        guard !digits.isEmpty else {
            return ""
        }

        let reversedDigits = Array(digits.reversed())
        var groupedCharacters: [Character] = []

        for (index, character) in reversedDigits.enumerated() {
            if index > 0 && index % 3 == 0 {
                groupedCharacters.append("'")
            }

            groupedCharacters.append(character)
        }

        return String(groupedCharacters.reversed())
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

struct ExchangeRateResponse {
    let date: String
    let rates: [CurrencyType: Double]
}

struct FrankfurterResponse: Decodable {
    let date: String
    let rates: [String: Double]
}

enum ExchangeRateService {
    static func fetchRatesToCHF() async throws -> ExchangeRateResponse {
        let currencies = CurrencyType.allCases
            .filter { $0 != .chf }
            .map { $0.rawValue }
            .joined(separator: ",")

        guard let url = URL(string: "https://api.frankfurter.app/latest?from=CHF&to=\(currencies)") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterResponse.self, from: data)

        var ratesToCHF: [CurrencyType: Double] = [.chf: 1.0]

        for currency in CurrencyType.allCases where currency != .chf {
            if let chfToForeignRate = response.rates[currency.rawValue], chfToForeignRate > 0 {
                ratesToCHF[currency] = 1 / chfToForeignRate
            }
        }

        return ExchangeRateResponse(date: response.date, rates: ratesToCHF)
    }
}

// TODO: Sobald das Land im Profil persistiert wird, soll die Default-Währung aus dem Profil-Land abgeleitet werden. Aktuell wird bewusst CHF als Default verwendet.
enum CurrencyType: String, CaseIterable, Identifiable {
    case chf = "CHF"
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case jpy = "JPY"
    case aud = "AUD"
    case cad = "CAD"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"

    var id: String { rawValue }
}

struct DebtEntry: Identifiable {
    let id: UUID
    var type: DebtType
    var amount: String
    var currency: CurrencyType
    var creditor: String

    init(
        id: UUID = UUID(),
        type: DebtType = .pleaseSelect,
        amount: String = "",
        currency: CurrencyType = .chf,
        creditor: String = ""
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currency = currency
        self.creditor = creditor
    }
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
    let id: UUID
    var type: PropertyType
    var marketValue: String
    var marketValueCurrency: CurrencyType
    var imputedRentalValue: String
    var imputedRentalValueCurrency: CurrencyType

    init(
        id: UUID = UUID(),
        type: PropertyType = .pleaseSelect,
        marketValue: String = "",
        marketValueCurrency: CurrencyType = .chf,
        imputedRentalValue: String = "",
        imputedRentalValueCurrency: CurrencyType = .chf
    ) {
        self.id = id
        self.type = type
        self.marketValue = marketValue
        self.marketValueCurrency = marketValueCurrency
        self.imputedRentalValue = imputedRentalValue
        self.imputedRentalValueCurrency = imputedRentalValueCurrency
    }
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
    let id: UUID
    var type: ValuableType
    var amount: String
    var currency: CurrencyType

    init(
        id: UUID = UUID(),
        type: ValuableType = .pleaseSelect,
        amount: String = "",
        currency: CurrencyType = .chf
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currency = currency
    }
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
    let id: UUID
    var bankName: String
    var iban: String
    var accountType: AccountType
    var bankAddress: String
    var advisor: String
    var assets: String
    var currency: CurrencyType

    init(
        id: UUID = UUID(),
        bankName: String = "",
        iban: String = "",
        accountType: AccountType = .pleaseSelect,
        bankAddress: String = "",
        advisor: String = "",
        assets: String = "",
        currency: CurrencyType = .chf
    ) {
        self.id = id
        self.bankName = bankName
        self.iban = iban
        self.accountType = accountType
        self.bankAddress = bankAddress
        self.advisor = advisor
        self.assets = assets
        self.currency = currency
    }
}
struct OpenIBANResponse: Decodable {
    let valid: Bool
    let iban: String?
    let bankData: OpenIBANBankData?
}

struct OpenIBANBankData: Decodable {
    let bankCode: String?
    let name: String?
    let zip: String?
    let city: String?
    let bic: String?
}

struct OpenIBANBankLookupResult {
    let bankName: String?
    let zip: String?
    let city: String?
    let bic: String?
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
    let id: UUID
    var type: InsuranceType
    var provider: String
    var policyNumber: String
    var amount: String
    var currency: CurrencyType
    var notes: String

    init(
        id: UUID = UUID(),
        type: InsuranceType = .pleaseSelect,
        provider: String = "",
        policyNumber: String = "",
        amount: String = "",
        currency: CurrencyType = .chf,
        notes: String = ""
    ) {
        self.id = id
        self.type = type
        self.provider = provider
        self.policyNumber = policyNumber
        self.amount = amount
        self.currency = currency
        self.notes = notes
    }
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
        .modelContainer(
            for: [
                BankkontoModell.self,
                SchuldenModell.self,
                VersicherungModell.self,
                LiegenschaftModell.self,
                WertsacheModell.self,
                SteuerdokumentModell.self
            ],
            inMemory: true
        )
}

enum OpenIBANService {
    static func validateIBAN(_ iban: String) async throws -> OpenIBANBankLookupResult {
        var components = URLComponents(string: "https://openiban.com/validate/\(iban)")
        components?.queryItems = [
            URLQueryItem(name: "getBIC", value: "true"),
            URLQueryItem(name: "validateBankCode", value: "true")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenIBANResponse.self, from: data)

        guard response.valid else {
            throw URLError(.badServerResponse)
        }

        return OpenIBANBankLookupResult(
            bankName: response.bankData?.name,
            zip: response.bankData?.zip,
            city: response.bankData?.city,
            bic: response.bankData?.bic
        )
    }
}
