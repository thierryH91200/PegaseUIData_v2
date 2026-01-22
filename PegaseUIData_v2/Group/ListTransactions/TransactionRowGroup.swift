////
////  TransactionRowGroup.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 25/03/2025.
////  Refactored by Claude Code on 14/01/2026.
////
//
//import SwiftUI
//import SwiftData
//import UniformTypeIdentifiers
//import OSLog
//
///// Displays transactions grouped by year and month with disclosure groups
/////
///// Features:
///// - Hierarchical grouping (Year → Month → Transactions)
///// - Persistent disclosure state (remembers which groups are expanded)
///// - Context menu for import/export operations
///// - CSV file import with column mapping
///// - Multi-select support
//struct TransactionRowGroup: View {
//
//    @Environment(\.dismiss) private var dismiss
//
//    @EnvironmentObject private var currentAccountManager: CurrentAccountManager
//    @EnvironmentObject private var colorManager: ColorManager
//
//    @Binding var selectedTransactions: Set<UUID>
//    @State private var info: String = ""
//
//    @State private var showFileImporter = false
//    @State private var csvData: [[String]] = []
//    @State private var columnMapping: [String: Int] = [:]
//
//    // Transaction attributes for CSV mapping
//    let transactionAttributes = [
//        String(localized: "Pointage Date"),
//        String(localized: "Operation Date"),
//        String(localized: "Comment"),
//        String(localized: "Rubric"),
//        String(localized: "Category"),
//        String(localized: "Payment method"),
//        String(localized: "Status"),
//        String(localized: "Amount")
//    ]
//
//    var filteredTransactions: [EntityTransaction]?
//
//    private var transactions: [EntityTransaction] {
//        filteredTransactions ?? ListTransactionsManager.shared.listTransactions
//    }
//
//    var compteCurrent: EntityAccount? {
//        CurrentAccountManager.shared.getAccount()
//    }
//
//    @State var name: String = "NID"
//    @State private var disclosureStates: [String: Bool] = [:]
//
//    // Cache for grouped transactions to avoid recalculating on every render
//    @State private var cachedGroupedTransactions: [YearGroup] = []
//    @State private var cachedVisibleTransactions: [EntityTransaction] = []
//    @State private var lastTransactionCount: Int = 0
//
//    private func isExpanded(for key: String) -> Binding<Bool> {
//        Binding(
//            get: { disclosureStates[key, default: false] },
//            set: { newValue in
//                disclosureStates[key] = newValue
//                saveDisclosureState()
//            }
//        )
//    }
//
//    var body: some View {
//        List(selection: $selectedTransactions) {
//            ForEach(cachedGroupedTransactions, id: \.year) { yearGroup in
//                Section(header:
//                    Label("Year : \(yearGroup.year)", systemImage: "calendar")
//                        .font(.headline)
//                        .contentShape(Rectangle())
//                        .buttonStyle(PlainButtonStyle())
//                ) {
//                    ForEach(yearGroup.monthGroups, id: \.month) { monthGroup in
//                        let key = "month_\(yearGroup.year)_\(monthGroup.month)"
//                        DisclosureGroup(isExpanded: isExpanded(for: key)) {
//                            LazyVStack(spacing: 0) {
//                                ForEach(monthGroup.transactions) { transaction in
//                                    TransactionRow(
//                                        transaction: transaction,
//                                        selectedTransactions: $selectedTransactions,
//                                        visibleTransactions: cachedVisibleTransactions
//                                    )
//                                    .foregroundColor(.black)
//                                    .contentShape(Rectangle())
//                                    .background(Color.clear)
//                                    .id(transaction.uuid)
//                                }
//                            }
//                        } label: {
//                            Label("Month : \(monthGroup.month)", systemImage: "calendar")
//                                .font(.subheadline.bold())
//                                .foregroundColor(.primary)
//                                .contentShape(Rectangle())
//                                .buttonStyle(PlainButtonStyle())
//                        }
//                    }
//                }
//            }
//        }
//        .frame(minHeight: 800)
//        .contextMenu {
//            Button {
//                showFileImporter = true
//            } label: {
//                Label("Import a CSV file", systemImage: "tray.and.arrow.down")
//            }
//            Button {
//                AppLogger.importExport.info("Export transactions requested")
//            } label: {
//                Label("Export", systemImage: "tray.and.arrow.up")
//            }
//        }
//        .onAppear {
//            updateGroupedTransactionsCache()
//            loadDisclosureState()
//            name = compteCurrent?.name ?? "NID"
//            let key = "disclosureStates" + name
//            if let savedData = UserDefaults.standard.data(forKey: key),
//               let loadedStates = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
//                disclosureStates = loadedStates
//            }
//        }
//        .onChange(of: transactions.count) { _, newCount in
//            if newCount != lastTransactionCount {
//                updateGroupedTransactionsCache()
//                lastTransactionCount = newCount
//            }
//        }
//        .onChange(of: transactions.first?.datePointage) { _, _ in
//            // Detect changes in transaction data (not just count)
//            updateGroupedTransactionsCache()
//        }
//        .fileImporter(
//            isPresented: $showFileImporter,
//            allowedContentTypes: [.commaSeparatedText],
//            allowsMultipleSelection: false
//        ) { result in
//            handleFileImport(result: result)
//        }
//
//        if !csvData.isEmpty {
//            csvImportSection
//        }
//    }
//
//    // MARK: - View Components
//
//    private var csvImportSection: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("CSV Preview").font(.headline)
//
//            ScrollView([.horizontal, .vertical]) {
//                HStack(alignment: .top, spacing: 0) {
//                    TableView(data: csvData)
//                }
//                .frame(minWidth: CGFloat((csvData.first?.count ?? 1) * 200), alignment: .leading)
//                .background(Color.clear)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//
//            Text("Match the columns:").font(.headline)
//
//            ForEach(transactionAttributes, id: \.self) { attribute in
//                Picker(attribute, selection: Binding(
//                    get: { columnMapping[attribute] ?? -1 },
//                    set: { columnMapping[attribute] = $0 }
//                )) {
//                    let csvData1 = csvData.dropFirst()
//                    Text("Ignore").tag(-1)
//                    ForEach(0..<(csvData1.first?.count ?? 0), id: \.self) { index in
//                        Text("Column \(index)").tag(index)
//                    }
//                }
//                .frame(width: 300)
//                .pickerStyle(MenuPickerStyle())
//            }
//
//            HStack(spacing: 20) {
//                Button(action: {
//                    importCSVTransactions()
//                    dismiss()
//                }) {
//                    Label("Import", systemImage: "tray.and.arrow.down")
//                        .padding()
//                        .background(Color.green)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                        .disabled(columnMapping.isEmpty)
//                        .fixedSize()
//                }
//
//                Button(action: {
//                    dismiss()
//                }) {
//                    Label("Cancel", systemImage: "stop")
//                        .padding()
//                        .background(Color.red)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                        .disabled(columnMapping.isEmpty)
//                        .fixedSize()
//                }
//            }
//            .padding(.top, 10)
//        }
//    }
//
//    // MARK: - Private Methods
//
//    /// Updates the cached grouped transactions to avoid recalculating on every render
//    private func updateGroupedTransactionsCache() {
//        cachedGroupedTransactions = groupTransactionsByYear(transactions: transactions)
//        cachedVisibleTransactions = cachedGroupedTransactions.flatMap { $0.monthGroups.flatMap { $0.transactions } }
//        AppLogger.transactions.debug("Updated grouped transactions cache: \(cachedGroupedTransactions.count) years, \(cachedVisibleTransactions.count) transactions")
//    }
//
//    private func handleFileImport(result: Result<[URL], Error>) {
//        switch result {
//        case .success(let urls):
//            if let url = urls.first, let data = readCSV(from: url) {
//                csvData = data
//                AppLogger.importExport.info("CSV file loaded: \(url.lastPathComponent)")
//            }
//        case .failure(let error):
//            AppLogger.importExport.error("File selection error: \(error.localizedDescription)")
//        }
//    }
//
//    func getString(from row: [String], index: Int?) -> String {
//        guard let index = index, index >= 0, index < row.count else { return "" }
//        return row[index]
//    }
//
//    func getDouble(from row: [String], index: Int?) -> Double {
//        guard let index = index, index >= 0, index < row.count else { return 0.0 }
//        let value = row[index].replacingOccurrences(of: String(","), with: ".")
//        return Double(value) ?? 0.0
//    }
//
//    func getDate(from row: [String], index: Int?) -> Date? {
//        guard let index = index, index >= 0, index < row.count else { return Date().noon }
//        let formatter = DateFormatter()
//        formatter.dateFormat = "dd-MM-yyyy"
//        return formatter.date(from: row[index])?.noon
//    }
//
//    func readCSV(from url: URL) -> [[String]]? {
//        guard url.startAccessingSecurityScopedResource() else {
//            AppLogger.importExport.warning("Cannot access security-scoped resource: \(url.path)")
//            return nil
//        }
//
//        defer { url.stopAccessingSecurityScopedResource() }
//
//        do {
//            let content = try String(contentsOf: url, encoding: .utf8)
//            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
//
//            let separator: Character = content.contains(";") ? ";" : ","
//
//            let parsedData = rows.map { $0.components(separatedBy: String(separator)) }
//            AppLogger.importExport.info("CSV parsed successfully: \(rows.count) rows")
//            return parsedData
//        } catch {
//            AppLogger.importExport.error("CSV read error: \(error.localizedDescription)")
//            return nil
//        }
//    }
//
//    func importCSVTransactions() {
//        guard !csvData.isEmpty else { return }
//
//        let count = csvData.count
//        AppLogger.importExport.info("Importing \(count) CSV transactions")
//
//        guard let account = CurrentAccountManager.shared.getAccount() else {
//            AppLogger.importExport.error("No account selected for import")
//            return
//        }
//
//        let entityPreference = PreferenceManager.shared.getAllData(for: account)
//
//        for row in csvData.dropFirst() {
//            let datePointage = getDate(from: row, index: columnMapping[String(localized: "Pointage Date")]) ?? Date().noon
//            let dateOperation = getDate(from: row, index: columnMapping[String(localized: "Operation Date")]) ?? datePointage
//            let libelle = getString(from: row, index: columnMapping[String(localized: "Comment")])
//
//            let bankStatement = 0.0
//
//            let category = getString(from: row, index: columnMapping[String(localized: "Category")])
//            let entityCategory = CategoryManager.shared.find(name: category) ?? entityPreference?.category
//
//            let paymentMode = getString(from: row, index: columnMapping[String(localized: "Payment method")])
//            let entityModePaiement = PaymentModeManager.shared.find(name: paymentMode) ?? entityPreference?.paymentMode
//
//            let status = getString(from: row, index: columnMapping[String(localized: "Status")])
//            let entityStatus = StatusManager.shared.find(name: status) ?? entityPreference?.status
//
//            let amount = getDouble(from: row, index: columnMapping[String(localized: "Amount")])
//
//            var transaction = EntityTransaction()
//
//            transaction.createAt = Date().noon
//            transaction.updatedAt = Date().noon
//
//            transaction.dateOperation = dateOperation.noon
//            transaction.datePointage = datePointage.noon
//            transaction.paymentMode = entityModePaiement
//            transaction.status = entityStatus
//            transaction.bankStatement = bankStatement
//            transaction.checkNumber = "0"
//            transaction.account = account
//
//            let sousTransaction = EntitySousOperation()
//            sousTransaction.libelle = libelle
//            sousTransaction.amount = amount
//            sousTransaction.category = entityCategory
//
//            transaction = ListTransactionsManager.shared.addSousTransaction(transaction: transaction, sousTransaction: sousTransaction)
//        }
//
//        do {
//            try ListTransactionsManager.shared.save()
//            AppLogger.importExport.info("CSV import successful 🎉")
//        } catch {
//            AppLogger.importExport.error("Save error during import: \(error.localizedDescription)")
//        }
//    }
//
//    private func saveDisclosureState() {
//        let key = "disclosureStates" + name
//        if let data = try? JSONEncoder().encode(disclosureStates) {
//            UserDefaults.standard.set(data, forKey: key)
//        }
//    }
//
//    private func loadDisclosureState() {
//        let key = "disclosureStates" + name
//        if let savedData = UserDefaults.standard.data(forKey: key),
//           let loadedStates = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
//            disclosureStates = loadedStates
//
//            for yearGroup in groupTransactionsByYear(transactions: transactions) {
//                for monthGroup in yearGroup.monthGroups {
//                    let key = "month_\(yearGroup.year)_\(monthGroup.month)"
//                    if disclosureStates[key] == nil {
//                        disclosureStates[key] = true
//                    }
//                }
//            }
//        }
//    }
//}
