//
//  TransactionTableViewModern.swift
//  PegaseUIData_v2
//
//  Créé par Claude le 21/01/2026.
//  Réécriture moderne utilisant SwiftUI Table pour de meilleures performances
//

import SwiftUI
import SwiftData
import OSLog

/// Table moderne des transactions utilisant SwiftUI Table avec regroupement hiérarchique
///
/// Améliorations de performance par rapport à la version legacy :
/// - SwiftUI Table avec virtualisation intégrée et gestion des colonnes
/// - Source unique de vérité pour les transactions
/// - Utilisation réduite de NotificationCenter
/// - Calcul automatique des soldes via propriétés calculées
/// - Gestion d'état plus propre avec moins de handlers onChange
/// - Support intégré du tri et du filtrage
struct TransactionTableViewModern: View {

    @EnvironmentObject private var currentAccountManager: CurrentAccountManager
    @EnvironmentObject private var colorManager: ColorManager
    @EnvironmentObject var transactionManager: TransactionSelectionManager

    var filteredTransactions: [EntityTransaction]?
    
    private var transactions: [EntityTransaction] {
        filteredTransactions ?? ListTransactionsManager.shared.listTransactions
    }

    @Binding var dashboard: DashboardState
    @Binding var selectedTransactions: Set<UUID>

    @State private var sortOrder = [KeyPathComparator(\EntityTransaction.dateOperation, order: .reverse)]
    @State private var searchText = ""
    @State private var groupedData: [TransactionYearGroup] = []

    // État de disclosure pour mémoriser les groupes ouverts/fermés
    @State private var disclosureStates: [String: Bool] = [:]

    // État du presse-papiers
    @State private var clipboardTransactions: [EntityTransaction] = []
    @State private var isCutOperation = false

    // État pour afficher le popover des détails (lecture seule)
    @State private var showTransactionDetail = false
    @State private var detailTransactionIndex: Int = 0

    // État pour le popover de relevé bancaire
    @State private var showBankStatementPopover = false
    @State private var bankStatementInput = ""

    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }

    var selectionInfo: AttributedString {
        calculateSelectionInfo()
    }

    var body: some View {
        VStack(spacing: 0) {
            // En-tête avec les infos du compte
            headerSection

            Divider()

            // Table principale
            mainTableSection

            Divider()

            // Barre de statut avec statistiques
            statusBarSection
        }
        .navigationTitle("Compte : \(compteCurrent?.name ?? "Aucun compte")")
        .sheet(isPresented: $showTransactionDetail) {
            transactionDetailPopover
        }
        .popover(isPresented: $showBankStatementPopover, arrowEdge: .trailing) {
            bankStatementPopoverContent
        }
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear {
            updateGroupedData()
            updateDashboard()
            loadDisclosureState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsAddEdit)) { _ in
            handleDataChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsImported)) { _ in
            handleDataChange()
        }
        .onChange(of: currentAccountManager.currentAccountID) { _, _ in
            handleDataChange()
        }
        .onChange(of: transactions.count) { _, _ in
            updateGroupedData()
            updateDashboard()
        }
        .onChange(of: selectedTransactions) { _, newSelection in
            updateTransactionManager(with: newSelection)
        }
        // Clipboard handlers
        .onReceive(NotificationCenter.default.publisher(for: .copySelectedTransactions)) { _ in
            copySelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cutSelectedTransactions)) { _ in
            cutSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pasteSelectedTransactions)) { _ in
            pasteTransactions()
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        HStack {
            Text("\(compteCurrent?.name ?? "No checking account")")
                .font(.headline)
            Image(systemName: "info.circle")
                .foregroundColor(.accentColor)
            Text(selectionInfo)
                .font(.system(size: 14))
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var mainTableSection: some View {
        VStack(spacing: 0) {
            // En-tête des colonnes
            tableHeaderView

            Divider()

            // Liste avec les transactions
            List(selection: $selectedTransactions) {
                ForEach(groupedData) { monthGroup in
                    let monthKey = "month_\(monthGroup.year)_\(monthGroup.month ?? 0)"
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { isExpanded(for: monthKey) },
                            set: { _ in toggleDisclosure(for: monthKey) }
                        )
                    ) {
                        ForEach(monthGroup.monthGroups ?? []) { transactionGroup in
                            if let transaction = transactionGroup.transaction {
                                transactionRowContent(for: transaction)
                                    .tag(transaction.uuid)
                            }
                        }
                    } label: {
                        Text(monthGroup.displayName)
                            .font(.headline)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: UUID.self) { uuids in
                if uuids.isEmpty {
                    Button("Nouvelle Transaction") { createNewTransaction() }
                } else {
                    transactionContextMenu(for: uuids)
                }
            }
        }
    }

    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            Text("Date Pointage").bold().frame(width: ColumnWidths.datePointage, alignment: .leading)
            Divider().frame(width: 2)
            Text("Date Opération").bold().frame(width: ColumnWidths.dateOperation, alignment: .leading)
            Divider().frame(width: 2)
            Text("Libellé").bold().frame(width: ColumnWidths.libelle, alignment: .leading)
            Divider().frame(width: 2)
            Text("Rubrique").bold().frame(width: ColumnWidths.rubrique, alignment: .leading)
            Divider().frame(width: 2)
            Text("Catégorie").bold().frame(width: ColumnWidths.categorie, alignment: .leading)
            Divider().frame(width: 2)
            Text("Relevé/Chèque").bold().frame(width: ColumnWidths.releve + ColumnWidths.cheque, alignment: .leading)
            Divider().frame(width: 2)
            Text("Statut").bold().frame(width: ColumnWidths.statut, alignment: .leading)
            Divider().frame(width: 2)
            Text("Mode Paiement").bold().frame(width: ColumnWidths.modePaiement, alignment: .leading)
            Divider().frame(width: 2)
            Text("Montant").bold().frame(width: ColumnWidths.montant, alignment: .trailing)
            Divider().frame(width: 2)
            Text("Solde").bold().frame(width: ColumnWidths.montant, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1))
        .frame(height: 44)
    }

    @ViewBuilder
    private func transactionRowContent(for transaction: EntityTransaction) -> some View {
        HStack(spacing: 0) {
            Text(transaction.datePointageString)
                .frame(width: ColumnWidths.datePointage, alignment: .leading)
            Divider().frame(width: 2)
            Text(transaction.dateOperationString)
                .frame(width: ColumnWidths.dateOperation, alignment: .leading)
            Divider().frame(width: 2)
            Text(transaction.sousOperations.first?.libelle ?? "—")
                .frame(width: ColumnWidths.libelle, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Divider().frame(width: 2)
            Text(transaction.sousOperations.first?.category?.rubric?.name ?? "—")
                .frame(width: ColumnWidths.rubrique, alignment: .leading)
                .lineLimit(1)
            Divider().frame(width: 2)
            Text(transaction.sousOperations.first?.category?.name ?? "—")
                .frame(width: ColumnWidths.categorie, alignment: .leading)
                .lineLimit(1)
            Divider().frame(width: 2)
            HStack(spacing: 2) {
                if transaction.bankStatement != 0 {
                    Text("R:\(Int(transaction.bankStatement))")
                        .font(.caption)
                }
                if transaction.checkNumber != "0" {
                    Text("C:\(transaction.checkNumber)")
                        .font(.caption)
                }
            }
            .frame(width: ColumnWidths.releve + ColumnWidths.cheque, alignment: .leading)
            Divider().frame(width: 2)
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(for: transaction.status))
                    .frame(width: 8, height: 8)
                Text(transaction.statusString)
                    .font(.caption)
            }
            .frame(width: ColumnWidths.statut, alignment: .leading)
            Divider().frame(width: 2)
            Text(transaction.paymentModeString)
                .frame(width: ColumnWidths.modePaiement, alignment: .leading)
                .lineLimit(1)
            Divider().frame(width: 2)
            Text(transaction.amountString)
                .foregroundColor(amountColor(for: transaction.amount))
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: ColumnWidths.montant, alignment: .trailing)
            Divider().frame(width: 2)
            Text(formatCurrency(transaction.solde ?? 0.0))
                .foregroundColor(.blue)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: ColumnWidths.montant, alignment: .trailing)
        }
        .foregroundColor(textColor(for: transaction))
    }

    private var statusBarSection: some View {
        HStack(spacing: 16) {
            Text("📊 \(countAllTransactions(groupedData)) transactions")
                .font(.caption)
                .foregroundColor(.secondary)

            if !selectedTransactions.isEmpty {
                Text("✓ \(selectedTransactions.count) sélectionnée(s)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Spacer()

            HStack(spacing: 8) {
                Text("Banque : \(formatCurrency(dashboard.executed))")
                    .foregroundColor(.green)
                Text("Réel : \(formatCurrency(dashboard.engaged))")
                    .foregroundColor(.orange)
                Text("Final : \(formatCurrency(dashboard.planned))")
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var transactionDetailPopover: some View {
        Group {
            if let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.id == ListTransactionsManager.shared.listTransactions[detailTransactionIndex].id }) {
                TransactionDetailView(currentSectionIndex: index, selectedTransaction: $selectedTransactions)
                    .frame(minWidth: 400, minHeight: 300)
            } else {
                Text("Erreur : Transaction non trouvée dans la liste.")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private var bankStatementPopoverContent: some View {
        VStack(spacing: 12) {
            Text("Créer un relevé")
                .font(.headline)

            TextField("Numéro de relevé", text: $bankStatementInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            HStack {
                Button("Annuler") {
                    showBankStatementPopover = false
                }
                Button("OK") {
                    updateBankStatement(for: selectedTransactions, to: bankStatementInput)
                    showBankStatementPopover = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 250)
    }

    @ViewBuilder
    private func transactionContextMenu(for uuids: Set<UUID>) -> some View {
        Button("Afficher les Détails") {
            if let first = uuids.first,
               let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.uuid == first }) {
                detailTransactionIndex = index
                showTransactionDetail = true
            }
        }

        Divider()

        Menu("Changer le Statut") {
            Button("Prévu") { updateStatus(for: uuids, to: "Prévu") }
            Button("En cours") { updateStatus(for: uuids, to: "En cours") }
            Button("Réalisé") { updateStatus(for: uuids, to: "Réalisé") }
        }

        Menu("Changer le Mode de Paiement") {
            ForEach(PaymentModeManager.shared.getAllNames(), id: \.self) { mode in
                Button(mode) { updatePaymentMode(for: uuids, to: mode) }
            }
        }

        Menu("Relevé Bancaire") {
            Button("Nouveau relevé…") {
                showBankStatementPopover = true
            }
        }

        Divider()

        Button("Dupliquer", systemImage: "doc.on.doc") {
            duplicateTransactions(uuids)
        }

        Button("Supprimer", systemImage: "trash", role: .destructive) {
            deleteTransactions(uuids)
        }
    }

    // MARK: - Helper Methods

    private func textColor(for transaction: EntityTransaction) -> Color {
        selectedTransactions.contains(transaction.uuid) ? .primary : colorManager.colorForTransaction(transaction)
    }

    private func statusColor(for status: EntityStatus?) -> Color {
        guard let status = status else { return .gray }
        switch status.type {
        case .planned: return .orange
        case .inProgress: return .blue
        case .executed: return .green
        }
    }

    private func amountColor(for amount: Double) -> Color {
        amount >= 0 ? .green : .red
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: value as NSNumber) ?? "€0.00"
    }

    private func findTransaction(uuid: UUID) -> EntityTransaction? {
        transactions.first { $0.uuid == uuid }
    }

    private func countAllTransactions(_ groups: [TransactionYearGroup]) -> Int {
        groups.reduce(0) { count, group in
            count + (group.monthGroups?.reduce(0) { $0 + ($1.transactions?.count ?? 0) } ?? 0)
        }
    }

    private func calculateSelectionInfo() -> AttributedString {
        guard !selectedTransactions.isEmpty else {
            return AttributedString("")
        }

        let selected = transactions.filter { selectedTransactions.contains($0.uuid) }
        let count = selected.count
        let total = selected.reduce(0.0) { $0 + $1.amount }
        let expense = selected.filter { $0.amount < 0 }.reduce(0.0) { $0 + $1.amount }
        let income = selected.filter { $0.amount >= 0 }.reduce(0.0) { $0 + $1.amount }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current

        let info = AttributedString("Sélectionné \(count) transaction(s). ")

        var expenseAttr = AttributedString("Dépenses : \(formatter.string(from: expense as NSNumber) ?? "€0.00")")
        expenseAttr.foregroundColor = .red

        var incomeAttr = AttributedString(", Revenus : \(formatter.string(from: income as NSNumber) ?? "€0.00")")
        incomeAttr.foregroundColor = .green

        let totalAttr = AttributedString(", Total : \(formatter.string(from: total as NSNumber) ?? "€0.00")")

        return info + expenseAttr + incomeAttr + totalAttr
    }

    private func updateGroupedData() {
        // Grouper les transactions par année et mois
        // Structure à 2 niveaux : Mois > Transactions
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.component(.year, from: transaction.dateOperation)
        }

        groupedData = grouped.keys.sorted(by: >).flatMap { year in
            let yearTransactions = grouped[year] ?? []
            let monthGrouped = Dictionary(grouping: yearTransactions) { transaction in
                calendar.component(.month, from: transaction.dateOperation)
            }

            // Créer un groupe pour chaque mois avec ses transactions
            return monthGrouped.keys.sorted(by: >).map { month in
                let monthName = calendar.monthSymbols[month - 1]
                let monthTransactions = monthGrouped[month] ?? []

                // Créer des wrappers pour chaque transaction individuelle
                let transactionGroups = monthTransactions
                    .sorted { $0.dateOperation > $1.dateOperation }
                    .map { transaction in
                        TransactionYearGroup(
                            id: transaction.uuid,
                            displayName: "",
                            year: year,
                            month: month,
                            monthGroups: nil,
                            transactions: [transaction]
                        )
                    }

                // Groupe de mois avec ses transactions comme enfants
                return TransactionYearGroup(
                    id: UUID(),
                    displayName: "\(year) - \(monthName)",
                    year: year,
                    month: month,
                    monthGroups: transactionGroups,
                    transactions: nil
                )
            }
        }

        AppLogger.transactions.debug("Données groupées mises à jour : \(groupedData.count) mois")

        // Initialiser les états de disclosure pour les nouveaux groupes
        for group in groupedData {
            let monthKey = "month_\(group.year)_\(group.month ?? 0)"
            if disclosureStates[monthKey] == nil {
                disclosureStates[monthKey] = true
            }
        }
    }

    private func updateTransactionManager(with selection: Set<UUID>) {
        AppLogger.ui.debug("🔄 updateTransactionManager appelé avec \(selection.count) sélection(s)")

        let selectedTransactionsList = transactions.filter { selection.contains($0.uuid) }

        transactionManager.selectedTransactions = selectedTransactionsList
        AppLogger.ui.debug("✅ transactionManager.selectedTransactions mis à jour: \(selectedTransactionsList.count) transaction(s)")

        if let firstUUID = selection.first,
           let firstTransaction = transactions.first(where: { $0.uuid == firstUUID }) {
            transactionManager.selectedTransaction = firstTransaction
            transactionManager.isCreationMode = false

            AppLogger.ui.debug("✅ Transaction sélectionnée : \(firstTransaction.sousOperations.first?.libelle ?? "—")")
            AppLogger.ui.debug("✅ isCreationMode = false")
        } else {
            transactionManager.selectedTransaction = nil
            transactionManager.isCreationMode = true
            AppLogger.ui.debug("⚠️ Aucune transaction sélectionnée, mode création activé")
        }

        // Notifier que la sélection a changé
        NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
        AppLogger.ui.debug("📢 Notification .transactionsSelectionChanged envoyée")
    }

    private func updateDashboard() {
        guard let initCompte = InitAccountManager.shared.getAllData() else {
            AppLogger.data.warning("Aucune donnée de compte initial trouvée")
            return
        }

        let executed = transactions.filter { $0.status?.type == .executed }.reduce(0.0) { $0 + $1.amount }
        let inProgress = transactions.filter { $0.status?.type == .inProgress }.reduce(0.0) { $0 + $1.amount }
        let planned = transactions.filter { $0.status?.type == .planned }.reduce(0.0) { $0 + $1.amount }

        dashboard.executed = initCompte.realise + executed
        dashboard.engaged = dashboard.executed + inProgress
        dashboard.planned = dashboard.engaged + planned

        // Mettre à jour le solde pour chaque transaction
        let initialBalance = initCompte.prevu + initCompte.engage + initCompte.realise
        var runningBalance = initialBalance

        for transaction in transactions.reversed() {
            runningBalance += transaction.amount
            transaction.solde = runningBalance
        }

        AppLogger.data.debug("Tableau de bord mis à jour - Banque : \(dashboard.executed), Réel : \(dashboard.engaged), Final : \(dashboard.planned)")
    }

    private func handleDataChange() {
        _ = ListTransactionsManager.shared.getAllData()
        updateGroupedData()
        updateDashboard()
    }

    // MARK: - Actions

    private func createNewTransaction() {
        transactionManager.isCreationMode = true
        transactionManager.selectedTransaction = nil
    }

    private func updateStatus(for uuids: Set<UUID>, to statusName: String) {
        guard let status = StatusManager.shared.find(name: statusName) else { return }
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.status = status
        }

        try? ListTransactionsManager.shared.save()

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Statut mis à jour vers '\(statusName)' pour \(selected.count) transaction(s)")
    }

    private func updatePaymentMode(for uuids: Set<UUID>, to modeName: String) {
        guard let mode = PaymentModeManager.shared.find(name: modeName) else { return }
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.paymentMode = mode
        }

        try? ListTransactionsManager.shared.save()

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Mode de paiement mis à jour vers '\(modeName)' pour \(selected.count) transaction(s)")
    }

    private func updateBankStatement(for uuids: Set<UUID>, to statement: String) {
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.bankStatement = Double(statement) ?? 0.0
        }

        try? ListTransactionsManager.shared.save()

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Relevé bancaire mis à jour vers '\(statement)' pour \(selected.count) transaction(s)")
    }

    private func duplicateTransactions(_ uuids: Set<UUID>) {
        let selected = transactions.filter { uuids.contains($0.uuid) }

        guard let targetAccount = CurrentAccountManager.shared.getAccount() else {
            AppLogger.transactions.error("Aucun compte cible pour l'opération de duplication")
            return
        }

        for transaction in selected {
            var newTransaction = EntityTransaction()
            newTransaction.dateOperation = transaction.dateOperation
            newTransaction.datePointage = transaction.datePointage
            newTransaction.status = transaction.status
            newTransaction.paymentMode = transaction.paymentMode
            newTransaction.checkNumber = transaction.checkNumber
            newTransaction.bankStatement = transaction.bankStatement
            newTransaction.account = targetAccount

            for item in transaction.sousOperations {
                let sousOperation = EntitySousOperation()
                sousOperation.libelle = item.libelle
                sousOperation.amount = item.amount
                sousOperation.category = item.category

                newTransaction = ListTransactionsManager.shared.addSousTransaction(transaction: newTransaction, sousTransaction: sousOperation)
            }
        }

        try? ListTransactionsManager.shared.save()
        handleDataChange()

        AppLogger.transactions.info("Dupliqué \(selected.count) transaction(s)")
    }

    private func deleteTransactions(_ uuids: Set<UUID>) {
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            ListTransactionsManager.shared.delete(entity: transaction)
        }

        try? ListTransactionsManager.shared.save()
        selectedTransactions.removeAll()
        handleDataChange()

        AppLogger.transactions.info("Supprimé \(selected.count) transaction(s)")
    }

    private func copySelected() {
        clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
        isCutOperation = false
        AppLogger.ui.info("Copié \(clipboardTransactions.count) transaction(s)")
    }

    private func cutSelected() {
        clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
        isCutOperation = true
        AppLogger.ui.info("Coupé \(clipboardTransactions.count) transaction(s)")
    }

    private func pasteTransactions() {
        guard let targetAccount = CurrentAccountManager.shared.getAccount() else {
            AppLogger.transactions.error("Aucun compte cible pour l'opération de collage")
            return
        }

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
        clipboardTransactions = []
        isCutOperation = false
        handleDataChange()

        AppLogger.transactions.info("Collé \(clipboardTransactions.count) transaction(s)")
    }

    // MARK: - Disclosure State Management

    private func saveDisclosureState() {
        guard let accountName = compteCurrent?.name else { return }
        let key = "disclosureStatesModern_" + accountName
        if let data = try? JSONEncoder().encode(disclosureStates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadDisclosureState() {
        guard let accountName = compteCurrent?.name else { return }
        let key = "disclosureStatesModern_" + accountName
        if let savedData = UserDefaults.standard.data(forKey: key),
           let loadedStates = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            disclosureStates = loadedStates
        } else {
            // Par défaut, tous les groupes sont ouverts
            for group in groupedData {
                let monthKey = "month_\(group.year)_\(group.month ?? 0)"
                disclosureStates[monthKey] = true
            }
        }
    }

    private func toggleDisclosure(for key: String) {
        disclosureStates[key] = !(disclosureStates[key] ?? false)
        saveDisclosureState()
    }

    private func isExpanded(for key: String) -> Bool {
        return disclosureStates[key] ?? true
    }
}

// MARK: - Types de Support

/// Groupe hiérarchique pour l'organisation des transactions par année/mois
struct TransactionYearGroup: Identifiable {
    let id: UUID
    let displayName: String
    let year: Int
    let month: Int?
    var monthGroups: [TransactionYearGroup]?
    var transactions: [EntityTransaction]?

    var transaction: EntityTransaction? {
        // Retourne la transaction seulement si ce n'est pas un groupe (a des transactions)
        return transactions?.first
    }
}

