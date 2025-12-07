//
//  Untitled 2.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 25/03/2025.
//

import SwiftUI
import SwiftData

struct ListTransactionsView100: View {
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTransactions: Set<UUID> = []
    @State private var refresh = false

    @Binding var dashboard: DashboardState

    private var transactions: [EntityTransaction] { ListTransactionsManager.shared.listTransactions }
//    private var transactions: [EntityTransaction] { ListTransactionsViewModel.listTransactions }

    var body: some View {
        
        VStack(spacing: 0) {
            
            SummaryView(
                dashboard: $dashboard
            )
            
            #if DEBUG
                        Button("Load demo data") {
                            loadDemoData()
                        }
                        .textCase(.lowercase) // empêche SwiftUI de mettre en majuscules
                        .padding(.bottom)
            #endif
            
            Divider()
            ListTransactions200(
                dashboard: $dashboard,
                isVisible: $dashboard.isVisible,
                selectedTransactions: $selectedTransactions
            )
            .padding()
            .id(refresh)
            
            .task {
                await performFalseTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: .loadDemoRequested)) { _ in
                loadDemoData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetDatabaseRequested)) { _ in
                resetDatabase()
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsAddEdit)) { _ in
                printTag("transactionsAddEdit notification received")
                
                _ = ListTransactionsManager.shared.getAllData()
                withAnimation {
                    selectedTransactions.removeAll()
                }
                updateSummary()
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsImported)) { _ in
                printTag("transactionsImported notification received")
                
                _ = ListTransactionsManager.shared.getAllData()
                withAnimation {
                    selectedTransactions.removeAll()
                }
                updateSummary()
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsSelectionChanged)) { _ in
                withAnimation {
                    refresh.toggle()
                }
                updateSummary()
            }
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.modifierFlags.contains(.command), let characters = event.charactersIgnoringModifiers else {
                        return event
                    }
                    
                    switch characters {
                    case "c":
                        NotificationCenter.default.post(name: .copySelectedTransactions, object: nil)
                        return nil
                    case "x":
                        NotificationCenter.default.post(name: .cutSelectedTransactions, object: nil)
                        return nil
                    case "v":
                        NotificationCenter.default.post(name: .pasteSelectedTransactions, object: nil)
                        return nil
                    default:
                        return event
                    }
                }
            }
            .onAppear(perform: updateSummary)
            .onChange(of: transactions) { _, _ in updateSummary() }
        }
    }
    
    private func updateSummary() {
        dashboard.executed = calculateExecuted()
        dashboard.engaged  = dashboard.executed + calculateEngaged()
        dashboard.planned  = dashboard.engaged + self.calculatePlanned()
    }
    
    @MainActor
    func resetDatabase() {
        let transactions = ListTransactionsManager.shared.getAllData()
        
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        try? modelContext.save()
    }
    
    private func performFalseTask() async {
        // Exécuter une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        dashboard.isVisible = true
    }
    
    @MainActor
    func loadDemoData() {
        let demoTransactions: [(String, Double, Int)] = [
            ("Achat supermarché", -45.60, 2),
            ("Salaire", 2000.00, 0),
            ("Facture électricité", -120.75, 1),
            ("Virement reçu", 350.00, 2),
            ("Abonnement streaming", -12.99, 1)
        ]
    }
    
    func calculatePlanned() -> Double {
        transactions
            .filter { $0.status?.type == .planned }
            .map(\.amount)
            .reduce(0, +)
    }
    
    func calculateEngaged() -> Double {
        transactions
            .filter { $0.status?.type == .inProgress }
            .map(\.amount)
            .reduce(0, +)
    }
    
    func calculateExecuted() -> Double {
        transactions
            .filter { $0.status?.type == .executed  }
            .map(\.amount)
            .reduce(0, +)
    }
}

struct ListTransactions200: View {
    
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject private var currentAccountManager : CurrentAccountManager
    @EnvironmentObject private var colorManager          : ColorManager
    
    private var transactions: [EntityTransaction] { ListTransactionsManager.shared.listTransactions }
    
    @Binding var dashboard: DashboardState
    @Binding var isVisible: Bool
    @Binding var selectedTransactions: Set<UUID>
    @State private var information: AttributedString = ""
    
    @State private var refresh = false
    @State private var currentSectionIndex: Int = 0
    
    @State var soldeBanque = 0.0
    @State var soldeReel = 0.0
    @State var soldeFinal = 0.0
    
    // Clipboard state for copy/cut/paste
    @State private var clipboardTransactions: [EntityTransaction] = []
    @State private var isCutOperation = false
    
    // Récupère le compte courant de manière sécurisée.
    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }
    
    var body: some View {
        mainContent
            .onChange(of: colorManager.colorChoix) { old, new in
            }
        
            .onReceive(NotificationCenter.default.publisher(for: .transactionsAddEdit)) { _ in
                printTag("transactionsAddEdit notification received")
                
                _ = ListTransactionsManager.shared.getAllData()
                withAnimation {
                    refresh.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsImported)) { _ in
                printTag("transactionsImported notification received")
                
                _ = ListTransactionsManager.shared.getAllData()
                withAnimation {
                    refresh.toggle()
                }
            }

            .onChange(of: currentAccountManager.currentAccountID) { old, new in
                printTag("Chgt de compte détecté: \(String(describing: new))")
                _ = ListTransactionsManager.shared.getAllData()
                
                withAnimation {
                    refresh.toggle()
                }
            }
        
            .onChange(of: selectedTransactions) { _, _ in
                printTag("selectionDidChange called")
                selectionDidChange()
            }
        
            .onAppear() {
                balanceCalculation()
                selectionDidChange()
            }
        
        // Clipboard/copy/cut/paste handlers
            .onReceive(NotificationCenter.default.publisher(for: .copySelectedTransactions)) { _ in
                clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
                isCutOperation = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .cutSelectedTransactions)) { _ in
                clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
                isCutOperation = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .pasteSelectedTransactions)) { _ in
                if let targetAccount = CurrentAccountManager.shared.getAccount() {
                    
                    for transaction in clipboardTransactions {
                        
                        let status = StatusManager.shared.find(name : transaction.status!.name)
                        let paymentMode = PaymentModeManager.shared.find(name: transaction.paymentMode!.name)
                        
                        let newTransaction = EntityTransaction()
                        newTransaction.dateOperation = transaction.dateOperation
                        newTransaction.datePointage  = transaction.datePointage
                        newTransaction.status        = status
                        newTransaction.paymentMode   = paymentMode
                        newTransaction.checkNumber   = transaction.checkNumber
                        newTransaction.bankStatement = transaction.bankStatement
                        
                        newTransaction.account = targetAccount
                        
                        for item in transaction.sousOperations {
                            let sousOperation = EntitySousOperation()
                            
                            let category = CategoryManager.shared.find(name: item.category!.name)
                            
                            sousOperation.libelle     = item.libelle
                            sousOperation.amount      = item.amount
                            sousOperation.category    = category
                            sousOperation.transaction = newTransaction
                            
                            modelContext.insert(sousOperation)
                            newTransaction.addSubOperation(sousOperation)
                        }
                        
                        modelContext.insert(newTransaction)
                    }
                    if isCutOperation {
                        for transaction in clipboardTransactions {
                            modelContext.delete(transaction)
                        }
                    }
                    try? modelContext.save()
                    
                    _ = ListTransactionsManager.shared.getAllData()
                    clipboardTransactions = []
                    isCutOperation = false
                    withAnimation {
                        refresh.toggle()
                    }
                }
            }
    }
    
    private var mainContent: some View {
        VStack {
            //            summaryViewSection
            headerViewSection
            transactionListSection
        }
    }
    
    private var summaryViewSection: some View {
        dashboard.planned = soldeReel
        dashboard.engaged = soldeFinal
        dashboard.executed = soldeBanque
        return SummaryView(
            dashboard: $dashboard
        )
            .frame(maxWidth: .infinity, maxHeight: 100)
    }
    
    private var headerViewSection: some View {
        HStack {
            Text("\(compteCurrent?.name ?? String(localized: "No checking account"))")
            Image(systemName: "info.circle")
                .foregroundColor(.accentColor)
            Text(information)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var transactionListSection: some View {
        NavigationView {
            GeometryReader { _ in
                List {
                    Section(header: EmptyView()) {
                        HStack(spacing: 0) {
                            columnGroup1()
                            columnGroup2()
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    OperationRow(selectedTransactions: $selectedTransactions)
                }
                .listStyle(.plain)
                .frame(minWidth: 800, maxWidth: 1200)
//                .frame(height: .infinity)
                .id(refresh)
            }
            .background(Color.white)
        }
    }
    @ViewBuilder
    func verticalDivider() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 2, height: 20)
            .padding(.horizontal, 2)
    }
        
    @MainActor
    func resetDatabase(using context: ModelContext) {
        let transactions = ListTransactionsManager.shared.getAllData()
        
        for transaction in transactions {
            context.delete(transaction)
        }
        
        try? context.save()
//        loadTransactions()
        balanceCalculation()
    }
    
    private func columnGroup1() -> some View {
        HStack(spacing: 0) {
            Text("Date of pointing").bold().frame(width: ColumnWidths.datePointage, alignment: .leading)
            verticalDivider()
            Text("Date operation").bold().frame(width: ColumnWidths.dateOperation, alignment: .leading)
            verticalDivider()
            Text("Comment").bold().frame(width: ColumnWidths.libelle, alignment: .leading)
            verticalDivider()
            Text("Rubric").bold().frame(width: ColumnWidths.rubrique, alignment: .leading)
            verticalDivider()
            Text("Category").bold().frame(width: ColumnWidths.categorie, alignment: .leading)
            verticalDivider()
            Text("Amount").bold().frame(width: ColumnWidths.sousMontant, alignment: .leading)
            verticalDivider()
            Text("Bank Statement").bold().frame(width: ColumnWidths.releve, alignment: .leading)
            verticalDivider()
            Text("Check Number").bold().frame(width: ColumnWidths.cheque, alignment: .leading)
            verticalDivider()
        }
    }
    
    private func columnGroup2() -> some View {
        HStack(spacing: 0) {
            Text("Status").bold().frame(width: ColumnWidths.statut, alignment: .leading)
            verticalDivider()
            Text("Payment method").bold().frame(width: ColumnWidths.modePaiement, alignment: .leading)
            verticalDivider()
            Text("Amount").bold().frame(width: ColumnWidths.montant, alignment: .trailing)
        }
    }
    
    func selectionDidChange() {
        
        let selectedRow = selectedTransactions
        if selectedRow.isEmpty == false {
            
            var transactionsSelected = [EntityTransaction]()
            
            var solde = 0.0
            var expense = 0.0
            var income = 0.0
            
            let formatter = NumberFormatter()
            formatter.locale = Locale.current
            formatter.numberStyle = .currency
            
            // Filtrer les transactions correspondantes
            let selectedEntities = transactions.filter { selectedRow.contains($0.uuid) }
            
            for transaction in selectedEntities {
                transactionsSelected.append(transaction)
                let amount = transaction.amount
                
                solde += amount
                if amount < 0 {
                    expense += amount
                } else {
                    income += amount
                }
            }
            
            // Info
            let amountStr = formatter.string(from: solde as NSNumber)!
            let strExpense = formatter.string(from: expense as NSNumber)!
            let strIncome = formatter.string(from: income as NSNumber)!
            let count = selectedEntities.count
            
            let info = AttributedString(String(localized:"Selected \(count) transactions. "))
            
            var expenseAttr = AttributedString("Expenses: \(strExpense)")
            expenseAttr.foregroundColor = expense < 0 ? .red : .blue
            
            var incomeAttr = AttributedString(String(localized:", Incomes: \(strIncome)"))
            incomeAttr.foregroundColor = income < 0 ? .red : .blue
            
            let totalAttr = AttributedString(String(localized:", Total: \(amountStr)"))
            
            information = info + expenseAttr + incomeAttr + totalAttr
        }
    }
    
    private func balanceCalculation() {
        // Récupère les données de l'init
        
        guard let initCompte = InitAccountManager.shared.getAllData() else { return }
        
        // Initialisation des soldes
        var balanceRealise = initCompte.realise
        var balancePrevu   = initCompte.prevu
        var balanceEngage  = initCompte.engage
        let initialBalance = balancePrevu + balanceEngage + balanceRealise
        
        // Vérification des transactions disponibles
        let transactions = ListTransactionsManager.shared.listTransactions
        
        let count = transactions.count
        
        // Calcul des soldes transaction par transaction
        for index in stride(from: count - 1, to: -1, by: -1) {
            let transaction = transactions[index]
            
            let status = transaction.status?.type ?? .inProgress
            
            // Mise à jour des soldes en fonction du status
            switch status {
            case .planned:
                balancePrevu += transaction.amount
            case .inProgress:
                balanceEngage += transaction.amount
            case .executed:
                balanceRealise += transaction.amount
            }
            
            // Calcul du solde de la transaction
            transaction.solde = (index == count - 1) ?
            (transaction.amount) + initialBalance :
            (transactions[index + 1].solde ?? 0.0) + (transaction.amount)
        }
        
        // Mise à jour des soldes finaux
        self.soldeBanque = balanceRealise
        self.soldeReel   = balanceRealise + balanceEngage
        self.soldeFinal  = balanceRealise + balanceEngage + balancePrevu
        
        //    NotificationCenter.send(.updateBalance) // Décommente si nécessaire
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
            
            for (month, monthTransactions) in groupedByMonth {
                let monthName = DateFormatter().monthSymbols[month - 1]
                let monthGroup = MonthGroup(month: monthName, transactions: monthTransactions)
                
                yearGroup.monthGroups.append(monthGroup)
            }
            
            groupedItems.append(yearGroup)
        }
        
        return groupedItems
    }
}

struct YearGroup {
    var year: Int
    var monthGroups: [MonthGroup]
}

struct MonthGroup {
    var month: String
    var transactions: [EntityTransaction]
}


// Exemple d'extension pour formater les dates
extension Date {
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

func formatPrice(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency // format monétaire
    formatter.locale = Locale.current // devise de l'utilisateur
    let format = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    return format
}


struct PriceText: View {
    let amount: Double

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }
}

func cleanDouble(from string: String) -> Double {
    // Supprime les caractères non numériques sauf , et .
    let cleanedString = string.filter { "0123456789,.".contains($0) }
    
    // Convertir la virgule en point si nécessaire
    let normalized = cleanedString.replacingOccurrences(of: ",", with: ".")
    
    return Double(normalized) ?? 0.0
}

// Keyboard shortcut notifications
extension Notification.Name {
    static let copySelectedTransactions = Notification.Name("copySelectedTransactions")
    static let cutSelectedTransactions = Notification.Name("cutSelectedTransactions")
    static let pasteSelectedTransactions = Notification.Name("pasteSelectedTransactions")
    static let transactionsSelectionChanged = Notification.Name("transactionsSelectionChanged")
}
