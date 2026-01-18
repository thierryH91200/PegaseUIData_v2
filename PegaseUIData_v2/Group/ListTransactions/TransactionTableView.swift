//
//  TransactionTableView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 26/02/2025.
//  Refactored by Claude Code on 14/01/2026.
//

import SwiftUI
import SwiftData
import OSLog

/// Main table view for displaying transactions with header and list
///
/// Features:
/// - Column headers with proper widths
/// - Account balance calculation
/// - Transaction selection info display
/// - Copy/Cut/Paste support via clipboard
/// - Real-time balance updates
struct TransactionTableView: View {

    @EnvironmentObject private var currentAccountManager: CurrentAccountManager
    @EnvironmentObject private var colorManager: ColorManager

    var filteredTransactions: [EntityTransaction]?

    private var transactions: [EntityTransaction] {
        filteredTransactions ?? ListTransactionsManager.shared.listTransactions
    }

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

    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }

    var body: some View {
        mainContent
            .onChange(of: colorManager.colorChoix) { old, new in
                // Color scheme changed
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsAddEdit)) { _ in
                AppLogger.transactions.debug("transactionsAddEdit notification received")

                _ = ListTransactionsManager.shared.getAllData()
                withAnimation {
                    refresh.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsImported)) { _ in
                AppLogger.transactions.debug("transactionsImported notification received")

                _ = ListTransactionsManager.shared.getAllData()
                withAnimation {
                    refresh.toggle()
                }
            }
            .onChange(of: currentAccountManager.currentAccountID) { old, new in
                AppLogger.account.debug("Account change detected: \(String(describing: new))")
                _ = ListTransactionsManager.shared.getAllData()

                withAnimation {
                    refresh.toggle()
                }
            }
            .onChange(of: selectedTransactions) { _, _ in
                AppLogger.ui.debug("selectionDidChange called")
                selectionDidChange()
            }
            .onAppear() {
                balanceCalculation()
                selectionDidChange()
            }
            // Clipboard handlers
            .onReceive(NotificationCenter.default.publisher(for: .copySelectedTransactions)) { _ in
                clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
                isCutOperation = false
                AppLogger.ui.info("Copied \(clipboardTransactions.count) transaction(s)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .cutSelectedTransactions)) { _ in
                clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
                isCutOperation = true
                AppLogger.ui.info("Cut \(clipboardTransactions.count) transaction(s)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .pasteSelectedTransactions)) { _ in
                pasteTransactions()
            }
    }

    // MARK: - View Components

    private var mainContent: some View {
        VStack {
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

                    TransactionRowGroup(
                        selectedTransactions: $selectedTransactions,
                        filteredTransactions: filteredTransactions
                    )
                }
                .listStyle(.plain)
                .frame(minWidth: 800, maxWidth: 1200)
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

    // MARK: - Private Methods

    @MainActor
    func resetDatabase(using context: ModelContext) {
        let transactions = ListTransactionsManager.shared.getAllData()

        AppLogger.data.warning("Resetting database - deleting \(transactions.count) transactions")

        for transaction in transactions {
            context.delete(transaction)
        }

        try? context.save()
        balanceCalculation()
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

            let amountStr = formatter.string(from: solde as NSNumber)!
            let strExpense = formatter.string(from: expense as NSNumber)!
            let strIncome = formatter.string(from: income as NSNumber)!
            let count = selectedEntities.count

            let info = AttributedString(String(localized: "Selected \(count) transactions. "))

            var expenseAttr = AttributedString("Expenses: \(strExpense)")
            expenseAttr.foregroundColor = expense < 0 ? .red : .blue

            var incomeAttr = AttributedString(String(localized: ", Incomes: \(strIncome)"))
            incomeAttr.foregroundColor = income < 0 ? .red : .blue

            let totalAttr = AttributedString(String(localized: ", Total: \(amountStr)"))

            information = info + expenseAttr + incomeAttr + totalAttr
        }
    }

    private func balanceCalculation() {
        guard let initCompte = InitAccountManager.shared.getAllData() else {
            AppLogger.data.warning("No initial account data found")
            return
        }

        var balanceRealise = initCompte.realise
        var balancePrevu = initCompte.prevu
        var balanceEngage = initCompte.engage
        let initialBalance = balancePrevu + balanceEngage + balanceRealise

        let transactions = ListTransactionsManager.shared.listTransactions

        let count = transactions.count

        for index in stride(from: count - 1, to: -1, by: -1) {
            let transaction = transactions[index]

            let status = transaction.status?.type ?? .inProgress

            switch status {
            case .planned:
                balancePrevu += transaction.amount
            case .inProgress:
                balanceEngage += transaction.amount
            case .executed:
                balanceRealise += transaction.amount
            }

            transaction.solde = (index == count - 1) ?
                (transaction.amount) + initialBalance :
                (transactions[index + 1].solde ?? 0.0) + (transaction.amount)
        }

        self.soldeBanque = balanceRealise
        self.soldeReel = balanceRealise + balanceEngage
        self.soldeFinal = balanceRealise + balanceEngage + balancePrevu

        AppLogger.data.debug("Balance calculated - Bank: \(soldeBanque), Real: \(soldeReel), Final: \(soldeFinal)")
    }

    private func pasteTransactions() {
        guard let targetAccount = CurrentAccountManager.shared.getAccount() else {
            AppLogger.transactions.error("No target account for paste operation")
            return
        }

        AppLogger.transactions.info("Pasting \(clipboardTransactions.count) transaction(s)")

        for transaction in clipboardTransactions {

            let status = StatusManager.shared.find(name: transaction.status!.name)
            let paymentMode = PaymentModeManager.shared.find(name: transaction.paymentMode!.name)

            var newTransaction = EntityTransaction()
            newTransaction.dateOperation = transaction.dateOperation
            newTransaction.datePointage = transaction.datePointage
            newTransaction.status = status
            newTransaction.paymentMode = paymentMode
            newTransaction.checkNumber = transaction.checkNumber
            newTransaction.bankStatement = transaction.bankStatement

            newTransaction.account = targetAccount

            for item in transaction.sousOperations {
                let sousOperation = EntitySousOperation()

                let category = CategoryManager.shared.find(name: item.category!.name)

                sousOperation.libelle = item.libelle
                sousOperation.amount = item.amount
                sousOperation.category = category

                newTransaction = ListTransactionsManager.shared.addSousTransaction(transaction: newTransaction, sousTransaction: sousOperation)
            }
        }

        if isCutOperation {
            for transaction in clipboardTransactions {
                ListTransactionsManager.shared.delete(entity: transaction)
            }
        }

        try? ListTransactionsManager.shared.save()

        _ = ListTransactionsManager.shared.getAllData()
        clipboardTransactions = []
        isCutOperation = false

        withAnimation {
            refresh.toggle()
        }
    }
}
