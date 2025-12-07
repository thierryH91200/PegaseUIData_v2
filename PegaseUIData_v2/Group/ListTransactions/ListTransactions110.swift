//
//  ListTransactions110.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 25/03/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers


struct OperationRow: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var currentAccountManager : CurrentAccountManager
    @EnvironmentObject private var colorManager          : ColorManager
    
    @Binding var selectedTransactions: Set<UUID>
    @State private var info: String = ""
    
    @State private var showFileImporter = false
    @State private var csvData: [[String]] = []
    @State private var columnMapping: [String: Int] = [:] // Associe les attributs aux colonnes

    // Attributs disponibles
    let transactionAttributes = [String(localized:"Pointage Date"),
                                 String(localized:"Operation Date"),
                                 String(localized:"Comment"),
                                 String(localized:"Rubric"),
                                 String(localized:"Category"),
                                 String(localized:"Payment method"),
                                 String(localized:"Status"),
                                 String(localized:"Amount")]

    private var transactions: [EntityTransaction] { ListTransactionsManager.shared.listTransactions }
    // Récupère le compte courant de manière sécurisée.
    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }
    @State var name : String = "NID"
    //    @AppStorage("disclosureStates" + name) var disclosureStatesData: Data = Data()
    
    @State private var disclosureStates: [String: Bool] = [:]
    
    private func isExpanded(for key: String) -> Binding<Bool> {
        Binding(
            get: { disclosureStates[key, default: false] },
            set: { newValue in
                disclosureStates[key] = newValue
                saveDisclosureState()
            }
        )
    }
    
    var body: some View {
        List(selection: $selectedTransactions) {
            let grouped = groupTransactionsByYear(transactions: transactions)
            let visibleTransactions = grouped.flatMap { $0.monthGroups.flatMap { $0.transactions } }
            ForEach(grouped, id: \.year) { yearGroup in
                Section(header:
                    Label("Year : \(yearGroup.year)", systemImage: "calendar")
                        .font(.headline)
                        .contentShape(Rectangle()) // 👈 rend toute la zone réactive
                        .buttonStyle(PlainButtonStyle()) // 👈 évite les interférences
                ) {
                    ForEach(yearGroup.monthGroups, id: \.month) { monthGroup in
                        let key = "month_\(yearGroup.year)_\(monthGroup.month)"
                        DisclosureGroup(isExpanded: isExpanded(for: key)) {
                            ForEach(monthGroup.transactions) { transaction in
                                TransactionLigne(transaction: transaction,
                                                 selectedTransactions: $selectedTransactions,
                                                 visibleTransactions: visibleTransactions)
                                    .foregroundColor(.black)
                                    .contentShape(Rectangle())
                                    .background(Color.clear)
                            }
                        } label: {
                            Label("Month : \(monthGroup.month)", systemImage: "calendar")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .contentShape(Rectangle()) // 👈 rend toute la zone réactive
                                .buttonStyle(PlainButtonStyle()) // 👈 évite les interférences
                        }
                    }
                }
            }
        }
        .frame(minHeight: 800)
        .contextMenu {
            Button {
                showFileImporter = true
            } label: {
                Label("Import a CSV file", systemImage: "tray.and.arrow.down")
            }
            Button {
                printTag("Exporter les transactions")
            } label: {
                Label("Export", systemImage: "tray.and.arrow.up")
            }
        }
        .onAppear(perform: loadDisclosureState)
        .onAppear {
            name = compteCurrent?.name ?? "NID"
            let key = "disclosureStates" + name
            if let savedData = UserDefaults.standard.data(forKey: key),
               let loadedStates = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
                disclosureStates = loadedStates
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first, let data = readCSV(from: url) {
                    csvData = data
                }
            case .failure(let error):
                printTag("Erreur de sélection de fichier : \(error.localizedDescription)")
            }
        }
        if !csvData.isEmpty {
            Text("CSV Preview").font(.headline)
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    TableView(data: csvData)
                }
                .frame(minWidth: CGFloat((csvData.first?.count ?? 1) * 200), alignment: .leading)
                .background(Color.clear)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Match the columns :").font(.headline)
            ForEach(transactionAttributes, id: \.self) { attribute in
                Picker(attribute, selection: Binding(
                    get: { columnMapping[attribute] ?? -1 },
                    set: { columnMapping[attribute] = $0 }
                )) {
                    let csvData1 = csvData.dropFirst()
                    Text("Ignore").tag(-1)
                    ForEach(0..<(csvData1.first?.count ?? 0), id: \.self) { index in
                        Text("Column \(index)").tag(index)
                    }
                }
                .frame(width: 300)
                .pickerStyle(MenuPickerStyle())
            }

            HStack(spacing: 20) {
                Button(action: {
                    importCSVTransactions(context: modelContext)
                    dismiss()
                }) {
                    Label("Import", systemImage: "tray.and.arrow.down")
                        .padding()
                        .background( Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(columnMapping.isEmpty)
                        .fixedSize()
                }

                Button(action: {
                    dismiss()
                }) {
                    Label("Cancel", systemImage: "stop")
                        .padding()
                        .background( Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(columnMapping.isEmpty)
                        .fixedSize()
                }
            }
            .padding(.top, 10)
        }
    }
    
    // Fonctions utilitaires
    func getString(from row: [String], index: Int?) -> String {
        guard let index = index, index >= 0, index < row.count else { return "" }
        return row[index]
    }

    func getDouble(from row: [String], index: Int?) -> Double {
        guard let index = index, index >= 0, index < row.count else { return 0.0 }
        let value = row[index].replacingOccurrences(of: String(","), with: ".")
        return Double(value) ?? 0.0
    }

    func getDate(from row: [String], index: Int?) -> Date? {
        guard let index = index, index >= 0, index < row.count else { return Date().noon }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy" // Ajuste selon le format de ton CSV
        return formatter.date(from: row[index])?.noon
    }
    func readCSV(from url: URL) -> [[String]]? {
        
        guard url.startAccessingSecurityScopedResource() else {
            printTag("⚠️ Impossible d'accéder au fichier (Security Scoped)")
            return nil
        }
        
        defer { url.stopAccessingSecurityScopedResource() } // Libérer l'accès à la fin
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Détecter le séparateur
            let separator: Character = content.contains(";") ? ";" : ","
            
            let parsedData = rows.map { $0.components(separatedBy: String(separator)) }
            return parsedData
        } catch {
            printTag("Erreur lors de la lecture du fichier CSV : \(error.localizedDescription)")
            return nil
        }
    }

    func importCSVTransactions(context: ModelContext) {
        guard !csvData.isEmpty else { return }
        
        let count = csvData.count
        printTag("Importation de \(count) transactions CSV.")
        
        let account = CurrentAccountManager.shared.getAccount()!

        let entityPreference = PreferenceManager.shared.getAllData(for: account)

        for row in csvData.dropFirst() { // Ignorer l'en-tête
            
            let datePointage =  getDate(from: row, index: columnMapping[String(localized:"Pointage Date")])  ?? Date().noon
            let dateOperation = getDate(from: row, index: columnMapping[String(localized:"Operation Date")]) ?? datePointage
            let libelle = getString(from: row, index: columnMapping[String(localized:"Comment")])
            
            let bankStatement = 0.0
            
            //            let rubric = getString(from: row, index: columnMapping[String(localized:"Rubric")])
            let category = getString(from: row, index: columnMapping[String(localized:"Category")])
            
            let entityCategory = CategoryManager.shared.find(name: category) ?? entityPreference?.category
            
            let paymentMode = getString(from: row, index: columnMapping[String(localized:"Payment method")])
            let entityModePaiement = PaymentModeManager.shared.find(name: paymentMode) ?? entityPreference?.paymentMode
            
            let status = getString(from: row, index: columnMapping[String(localized:"Status")])
            let entityStatus = StatusManager.shared.find(name: status) ?? entityPreference?.status
            
            let amount = getDouble(from: row, index: columnMapping[String(localized:"Amount")])
            
            let transaction = EntityTransaction()
            
            transaction.createAt  = Date().noon
            transaction.updatedAt = Date().noon
            
            transaction.dateOperation = dateOperation.noon
            transaction.datePointage  = datePointage.noon
            transaction.paymentMode   = entityModePaiement
            transaction.status        = entityStatus
            transaction.bankStatement = bankStatement
            transaction.checkNumber   = "0"
            transaction.account       = account
            
            let sousTransaction         = EntitySousOperation()
            sousTransaction.libelle     = libelle
            sousTransaction.amount      = amount
            sousTransaction.category    = entityCategory
            sousTransaction.transaction = transaction
            
            context.insert(sousTransaction)
            transaction.addSubOperation(sousTransaction)

            context.insert(transaction)
        }
        
        do {
            try context.save()
            printTag("Importation réussie 🎉")
        } catch {
            printTag("Erreur lors de l'enregistrement : \(error)")
        }
    }

    // Sauvegarde l'état des `DisclosureGroup`
    private func saveDisclosureState() {
        let key = "disclosureStates" + name
        if let data = try? JSONEncoder().encode(disclosureStates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    // Charge l'état sauvegardé au démarrage
    private func loadDisclosureState() {
        let key = "disclosureStates" + name
        if let savedData = UserDefaults.standard.data(forKey: key),
           let loadedStates = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            disclosureStates = loadedStates
            // Ouvre tous les mois par défaut s'ils ne sont pas enregistrés
            for yearGroup in groupTransactionsByYear(transactions: transactions) {
                for monthGroup in yearGroup.monthGroups {
                    let key = "month_\(yearGroup.year)_\(monthGroup.month)"
                    if disclosureStates[key] == nil {
                        disclosureStates[key] = true
                    }
                }
            }
        }
    }
    
    private func groupTransactionsByYear(transactions: [EntityTransaction]) -> [YearGroup] {
        var groupedItems: [YearGroup] = []
        let calendar = Calendar.current
        
        // Group transactions by year
        let groupedByYear = Dictionary(grouping: transactions) { (transaction) -> Int in
            let components = calendar.dateComponents([.year], from: transaction.datePointage)
            return components.year ?? 0
        }
        
        for (year, yearTransactions) in groupedByYear {
            var yearGroup = YearGroup(year: year, monthGroups: [])
            
            let groupedByMonth = Dictionary(grouping: yearTransactions) { (transaction) -> Int in
                let components = calendar.dateComponents([.month], from: transaction.datePointage)
                return components.month ?? 0
            }
            
            for (month, monthTransactions) in groupedByMonth.sorted(by: { $0.key > $1.key }) {
                let monthName = DateFormatter().monthSymbols[month - 1]
                let monthGroup = MonthGroup(month: monthName,
                                            //                                            transactions: monthTransactions.sorted(by: { $0.dateOperation > $1.dateOperation }))
                                            transactions: monthTransactions.sorted(by: { $0.datePointage > $1.datePointage }))
                
                yearGroup.monthGroups.append(monthGroup)
            }
            
            groupedItems.append(yearGroup)
        }
        return groupedItems
    }
}

