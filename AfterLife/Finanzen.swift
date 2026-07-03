
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

    private let finanzenHintergrundFarbe = Color(red: 0.985, green: 0.975, blue: 0.955)
    private let finanzenKartenFarbe = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let finanzenAkzentFarbe = Color(red: 0.62, green: 0.47, blue: 0.18)
    @State private var ausgewaehlteFinanzenBereiche: Set<FinanzenBereich> = []
    @State private var scrollZuFinanzEintragID: UUID?


    private var totalAssets: Double {
        bankEntries.reduce(0) { result, entry in
            result + convertToCHF(amountText: entry.assets, currency: entry.currency)
        }
    }

    private var finanzenHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(finanzenAkzentFarbe)
                    .frame(width: 40, height: 40)
                    .background(finanzenAkzentFarbe.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Finanzübersicht")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Halte fest, wo Vermögen, Schulden, Versicherungen und wichtige Unterlagen zu finden sind.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(finanzenKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    
    private func istFinanzenBereichAusgewaehlt(_ bereich: FinanzenBereich) -> Bool {
        bereich == .alle ? ausgewaehlteFinanzenBereiche.isEmpty : ausgewaehlteFinanzenBereiche.contains(bereich)
    }

    private func finanzenBereichAntippen(_ bereich: FinanzenBereich) {
        if bereich == .alle {
            ausgewaehlteFinanzenBereiche.removeAll()
            return
        }

        if ausgewaehlteFinanzenBereiche.contains(bereich) {
            ausgewaehlteFinanzenBereiche.remove(bereich)
        } else {
            ausgewaehlteFinanzenBereiche.insert(bereich)
        }

        let alleEinzelbereiche = Set(FinanzenBereich.allCases.filter { $0 != .alle })

        if ausgewaehlteFinanzenBereiche == alleEinzelbereiche || ausgewaehlteFinanzenBereiche.isEmpty {
            ausgewaehlteFinanzenBereiche.removeAll()
        }
    }

    private var finanzenBereichChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FinanzenBereich.allCases) { bereich in
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                            finanzenBereichAntippen(bereich)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: bereich.systemImage)
                                .font(.caption.weight(.semibold))

                            Text(bereich.titel)
                                .font(.subheadline.weight(.semibold))

                            let anzahl = anzahlFuerBereich(bereich)
                            if anzahl > 0 {
                                Text("\(anzahl)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(istFinanzenBereichAusgewaehlt(bereich) ? finanzenAkzentFarbe : .white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        istFinanzenBereichAusgewaehlt(bereich) ? Color.white.opacity(0.95) : finanzenAkzentFarbe,
                                        in: Capsule()
                                    )
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .foregroundStyle(istFinanzenBereichAusgewaehlt(bereich) ? .white : finanzenAkzentFarbe)
                        .background(
                            istFinanzenBereichAusgewaehlt(bereich) ? finanzenAkzentFarbe : finanzenKartenFarbe,
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(finanzenAkzentFarbe.opacity(istFinanzenBereichAusgewaehlt(bereich) ? 0 : 0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func zeigtBereich(_ bereich: FinanzenBereich) -> Bool {
        ausgewaehlteFinanzenBereiche.isEmpty || ausgewaehlteFinanzenBereiche.contains(bereich)
    }

    private func anzahlFuerBereich(_ bereich: FinanzenBereich) -> Int {
        switch bereich {
        case .alle:
            return bankEntries.count + debts.count + propertyEntries.count + valuableEntries.count + insuranceEntries.count + (hasOldTaxReturn ? 1 : 0)
        case .konten:
            return bankEntries.count
        case .schulden:
            return debts.count
        case .liegenschaften:
            return propertyEntries.count
        case .wertsachen:
            return valuableEntries.count
        case .steuern:
            return hasOldTaxReturn ? 1 : 0
        case .versicherungen:
            return insuranceEntries.count
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
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                if entryCount == 0 {
                    Text("Noch keine Einträge erfasst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if entryCount > 1 {
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
                        .background(Circle().fill(finanzenAkzentFarbe))
                        .shadow(color: finanzenAkzentFarbe.opacity(0.22), radius: 6, x: 0, y: 3)
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
            .background(Color.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(finanzenAkzentFarbe.opacity(0.10), lineWidth: 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(finanzenKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var steuerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alte Steuern zur Orientierung")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
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
                        .background(Circle().fill(finanzenAkzentFarbe))
                        .shadow(color: finanzenAkzentFarbe.opacity(0.22), radius: 6, x: 0, y: 3)
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
                            .foregroundStyle(finanzenAkzentFarbe)

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
                            Image(systemName: "eye.fill")
                                .foregroundStyle(finanzenAkzentFarbe)
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
                    .background(Color.white.opacity(0.70))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(finanzenAkzentFarbe.opacity(0.10), lineWidth: 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(finanzenKartenFarbe)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
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
            guard entry.type == .pensionFund || entry.type == .pillar3a || entry.type == .vestedBenefits || entry.type == .lifeInsurance else {
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
                [entry.id.uuidString, entry.type.rawValue, entry.typeDescription, entry.amount, entry.currency.rawValue].joined(separator: "|")
            }.joined(separator: "#"),
            String(hasOldTaxReturn),
            oldTaxReturnFileName,
            oldTaxReturnFilePath,
            oldTaxReturnFileData?.count.description ?? ""
        ].joined(separator: "§")
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    finanzenHero

                    finanzenBereichChips

                    if zeigtBereich(.konten) {
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
                                let neuerEintrag = BankEntry()
                                bankEntries.append(neuerEintrag)
                                if bankEntries.count > 1 {
                                    showBankEntries = true
                                }
                                scrollZuFinanzEintragID = neuerEintrag.id
                                speichereFinanzenInSwiftData()
                            },
                            content: {
                                bankEntryList
                            }
                        )
                    }

                    if zeigtBereich(.schulden) {
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
                                let neuerEintrag = DebtEntry()
                                debts.append(neuerEintrag)
                                if debts.count > 1 {
                                    showDebtEntries = true
                                }
                                scrollZuFinanzEintragID = neuerEintrag.id
                                speichereFinanzenInSwiftData()
                            },
                            content: {
                                debtEntryList
                            }
                        )
                    }

                    if zeigtBereich(.liegenschaften) {
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
                                let neuerEintrag = PropertyEntry()
                                propertyEntries.append(neuerEintrag)
                                if propertyEntries.count > 1 {
                                    showPropertyEntries = true
                                }
                                scrollZuFinanzEintragID = neuerEintrag.id
                                speichereFinanzenInSwiftData()
                            },
                            content: {
                                propertyEntryList
                            }
                        )
                    }

                    if zeigtBereich(.wertsachen) {
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
                                let neuerEintrag = ValuableEntry()
                                valuableEntries.append(neuerEintrag)
                                if valuableEntries.count > 1 {
                                    showValuableEntries = true
                                }
                                scrollZuFinanzEintragID = neuerEintrag.id
                                speichereFinanzenInSwiftData()
                            },
                            content: {
                                valuableEntryList
                            }
                        )
                    }

                    if zeigtBereich(.steuern) {
                        steuerSection
                    }

                    if zeigtBereich(.versicherungen) {
                        finanzSection(
                            title: "Versicherungen",
                            totalTitle: "Total Vorsorgewerte",
                            totalValue: totalInsuranceAssets,
                            showApproximation: hasMixedCurrencies(insuranceEntries.compactMap { entry in
                                guard entry.type == .pensionFund || entry.type == .pillar3a || entry.type == .vestedBenefits || entry.type == .lifeInsurance else { return nil }
                                return entry.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.currency
                            }),
                            entryCount: insuranceEntries.count,
                            isExpanded: $showInsuranceEntries,
                            addAction: {
                                let neuerEintrag = InsuranceEntry()
                                insuranceEntries.append(neuerEintrag)
                                if insuranceEntries.count > 1 {
                                    showInsuranceEntries = true
                                }
                                scrollZuFinanzEintragID = neuerEintrag.id
                                speichereFinanzenInSwiftData()
                            },
                            content: {
                                insuranceEntryList
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(finanzenHintergrundFarbe)
            .tint(finanzenAkzentFarbe)
            .navigationTitle("Finanzen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExchangeRateInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(finanzenAkzentFarbe)
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
                                        .foregroundStyle(finanzenAkzentFarbe.opacity(0.75))
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
                .onChange(of: scrollZuFinanzEintragID) { _, zielID in
                    guard let zielID else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            scrollProxy.scrollTo(zielID, anchor: .center)
                        }
                        scrollZuFinanzEintragID = nil
                    }
                }
            }
        }
    }
    private var bankEntryList: some View {
        ForEach(Array($bankEntries.enumerated()), id: \.element.id) { index, $bankEntry in
            FinanzenSwipeToDeleteRow(
                accentColor: finanzenAkzentFarbe,
                deleteAction: {
                    bankEntries.removeAll { $0.id == bankEntry.id }
                    speichereFinanzenInSwiftData()
                }
            ) {
                DetailBox {
                    HStack {
                        Text("Konto \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()
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
                .padding(12)
                .background(Color.white.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
                }
            }
            .id(bankEntry.id)
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
            FinanzenSwipeToDeleteRow(
                accentColor: finanzenAkzentFarbe,
                deleteAction: {
                    debts.removeAll { $0.id == debt.id }
                    speichereFinanzenInSwiftData()
                }
            ) {
                DetailBox {
                    HStack {
                        Text("Schuld \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()
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
                .padding(12)
                .background(Color.white.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
                }
            }
            .id(debt.id)
        }
    }
    private var propertyEntryList: some View {
        ForEach(Array($propertyEntries.enumerated()), id: \.element.id) { index, $propertyEntry in
            FinanzenSwipeToDeleteRow(
                accentColor: finanzenAkzentFarbe,
                deleteAction: {
                    propertyEntries.removeAll { $0.id == propertyEntry.id }
                    speichereFinanzenInSwiftData()
                }
            ) {
                DetailBox {
                    HStack {
                        Text("Liegenschaft \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()
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
                .padding(12)
                .background(Color.white.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
                }
            }
            .id(propertyEntry.id)
        }
    }

    private var valuableEntryList: some View {
        ForEach(Array($valuableEntries.enumerated()), id: \.element.id) { index, $valuableEntry in
            FinanzenSwipeToDeleteRow(
                accentColor: finanzenAkzentFarbe,
                deleteAction: {
                    valuableEntries.removeAll { $0.id == valuableEntry.id }
                    speichereFinanzenInSwiftData()
                }
            ) {
                DetailBox {
                    HStack {
                        Text("Wertsache \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()
                    }

                    Picker("Art", selection: $valuableEntry.type) {
                        ForEach(ValuableType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    if valuableEntry.type != .pleaseSelect {
                        labelledTextField("Beschreibung / Art", text: $valuableEntry.typeDescription)

                        labelledMoneyField("Betrag", amount: $valuableEntry.amount, currency: $valuableEntry.currency)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
                }
            }
            .id(valuableEntry.id)
        }
    }

    private var insuranceEntryList: some View {
        ForEach(Array($insuranceEntries.enumerated()), id: \.element.id) { index, $insuranceEntry in
            FinanzenSwipeToDeleteRow(
                accentColor: finanzenAkzentFarbe,
                deleteAction: {
                    insuranceEntries.removeAll { $0.id == insuranceEntry.id }
                    speichereFinanzenInSwiftData()
                }
            ) {
                DetailBox {
                    HStack {
                        Text("Versicherung \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()
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

                        if insuranceEntry.type == .pensionFund || insuranceEntry.type == .pillar3a || insuranceEntry.type == .vestedBenefits {
                            labelledMoneyField("Betrag", amount: $insuranceEntry.amount, currency: $insuranceEntry.currency)
                        }

                        if insuranceEntry.type == .lifeInsurance {
                            labelledMoneyField("Versicherungssumme", amount: $insuranceEntry.amount, currency: $insuranceEntry.currency)
                        }

                        labelledMultilineTextField("Bemerkungen", text: $insuranceEntry.notes, lineLimit: 2...5)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(finanzenAkzentFarbe.opacity(0.12), lineWidth: 1)
                }
            }
            .id(insuranceEntry.id)
        }
    }
// Custom swipe-to-delete row for Finanzen

struct FinanzenSwipeToDeleteRow<Content: View>: View {
    var accentColor: Color
    let deleteAction: () -> Void
    let content: Content

    @State private var offsetX: CGFloat = 0
    @State private var istGeloescht = false

    private let revealOffset: CGFloat = -92
    private let fullDeleteThreshold: CGFloat = -148
    private let maxOffset: CGFloat = -164

    init(
        accentColor: Color,
        deleteAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
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
                            .fill(Color.red)

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
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            let startOffset = offsetX == revealOffset ? revealOffset : 0
                            let neuePosition = min(0, max(maxOffset, value.translation.width + startOffset))

                            if neuePosition <= 0 {
                                offsetX = neuePosition
                            }
                        }
                        .onEnded { value in
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
                    typeDescription: wertsache.beschreibung,
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
            modell.beschreibung = entry.typeDescription
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
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(finanzenKartenFarbe.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func labelledDecimalTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(finanzenKartenFarbe.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(finanzenKartenFarbe.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(finanzenKartenFarbe.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

enum FinanzenBereich: String, CaseIterable, Identifiable, Hashable {
    case alle
    case konten
    case schulden
    case liegenschaften
    case wertsachen
    case steuern
    case versicherungen

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .alle: return "Alle"
        case .konten: return "Konten"
        case .schulden: return "Schulden"
        case .liegenschaften: return "Liegenschaften"
        case .wertsachen: return "Wertsachen"
        case .steuern: return "Steuern"
        case .versicherungen: return "Versicherungen"
        }
    }

    var systemImage: String {
        switch self {
        case .alle: return "square.grid.2x2.fill"
        case .konten: return "building.columns.fill"
        case .schulden: return "minus.circle.fill"
        case .liegenschaften: return "house.fill"
        case .wertsachen: return "sparkles"
        case .steuern: return "doc.text.fill"
        case .versicherungen: return "shield.fill"
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
    var typeDescription: String
    var amount: String
    var currency: CurrencyType

    init(
        id: UUID = UUID(),
        type: ValuableType = .pleaseSelect,
        typeDescription: String = "",
        amount: String = "",
        currency: CurrencyType = .chf
    ) {
        self.id = id
        self.type = type
        self.typeDescription = typeDescription
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
