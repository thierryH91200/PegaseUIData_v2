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
    
    var transactions: [EntityTransaction] {
        filteredTransactions ?? ListTransactionsManager.shared.listTransactions
    }

    @Binding var dashboard: DashboardState
    @Binding var selectedTransactions: Set<UUID>

    @State private var sortOrder = [KeyPathComparator(\EntityTransaction.datePointage, order: .reverse)]
    @State private var searchText = ""
    @State var groupedData: [TransactionYearGroup] = []

    // État de disclosure pour mémoriser les groupes ouverts/fermés
    @State var disclosureStates: [String: Bool] = [:]

    // État du presse-papiers
    @State var clipboardTransactions: [EntityTransaction] = []
    @State var isCutOperation = false

    // État pour afficher le popover des détails (lecture seule)
    @State private var showTransactionDetail = false
    @State private var detailTransactionIndex: Int = 0

    // État pour le popover de relevé bancaire
    @State private var showBankStatementPopover = false
    @State private var bankStatementInput = ""

    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }

    // Vérifie si le regroupement CB est activé dans les préférences
    var shouldGroupCarteBancaire: Bool {
        return PreferenceManager.shared.getAllData()?.groupCarteBancaire ?? false
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
        .navigationTitle("Account : \(compteCurrent?.name ?? "No account")")
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
        .onReceive(NotificationCenter.default.publisher(for: .transactionsEdited)) { _ in
            // Édition seule : mise à jour des données sans reconstruire les groupes (pas de scroll)
            _ = ListTransactionsManager.shared.getAllData()
            updateDashboard()
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
                            // Si c'est un sous-groupe "Carte Bancaire"
                            if transactionGroup.isPaymentModeGroup {
                                let cbKey = "cb_\(monthGroup.year)_\(monthGroup.month ?? 0)"
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { isExpanded(for: cbKey) },
                                        set: { _ in toggleDisclosure(for: cbKey) }
                                    )
                                ) {
                                    ForEach(transactionGroup.monthGroups ?? []) { cbTransaction in
                                        if let transaction = cbTransaction.transaction {
                                            transactionRowContent(for: transaction)
                                                .tag(transaction.uuid)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "creditcard.fill")
                                            .foregroundColor(.blue)
                                        Text(transactionGroup.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                }
                            } else if let transaction = transactionGroup.transaction {
                                // Transaction normale (pas Carte Bancaire)
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
                    Button("New Transaction") { createNewTransaction() }
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
            Text("Date Operation").bold().frame(width: ColumnWidths.dateOperation, alignment: .leading)
            Divider().frame(width: 2)
            Text("Comment").bold().frame(width: ColumnWidths.libelle, alignment: .leading)
            Divider().frame(width: 2)
            Text("Rubric").bold().frame(width: ColumnWidths.rubrique, alignment: .leading)
            Divider().frame(width: 2)
            Text("Catégory").bold().frame(width: ColumnWidths.categorie, alignment: .leading)
            Divider().frame(width: 2)
            Text("Relevé/Chèque").bold().frame(width: ColumnWidths.releve + ColumnWidths.cheque, alignment: .leading)
            Divider().frame(width: 2)
            Text("Statut").bold().frame(width: ColumnWidths.statut, alignment: .leading)
            Divider().frame(width: 2)
            Text("Payment method").bold().frame(width: ColumnWidths.modePaiement, alignment: .leading)
            Divider().frame(width: 2)
            Text("Amount").bold().frame(width: ColumnWidths.montant, alignment: .trailing)
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
                Text("Error: Transaction not found in the list.")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private var bankStatementPopoverContent: some View {
        VStack(spacing: 12) {
            Text("Create a statement")
                .font(.headline)

            TextField("Statement number", text: $bankStatementInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            HStack {
                Button("Cancel") {
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
        Button("Show Details") {
            if let first = uuids.first,
               let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.uuid == first }) {
                detailTransactionIndex = index
                showTransactionDetail = true
            }
        }

        Divider()

        Menu("Change the Statut") {
            Button("Planned") { updateStatus(for: uuids, to: "Prévu") }
            Button("In progress") { updateStatus(for: uuids, to: "En cours") }
            Button("Executed") { updateStatus(for: uuids, to: "Réalisé") }
        }

        Menu("Change Payment Method") {
            ForEach(PaymentModeManager.shared.getAllNames(), id: \.self) { mode in
                Button(mode) { updatePaymentMode(for: uuids, to: mode) }
            }
        }

        Menu("Bank statement") {
            Button("New bank statement") {
                showBankStatementPopover = true
            }
        }

        Divider()

        Button("Duplcate", systemImage: "doc.on.doc") {
            duplicateTransactions(uuids)
        }

        Button("Remove", systemImage: "trash", role: .destructive) {
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

        let info = AttributedString("Sélection \(count) transaction(s). ")

        var expenseAttr = AttributedString("Expenses : \(formatter.string(from: expense as NSNumber) ?? "€0.00")")
        expenseAttr.foregroundColor = .red

        var incomeAttr = AttributedString(", Revenus : \(formatter.string(from: income as NSNumber) ?? "€0.00")")
        incomeAttr.foregroundColor = .green

        let totalAttr = AttributedString(", Total : \(formatter.string(from: total as NSNumber) ?? "€0.00")")

        return info + expenseAttr + incomeAttr + totalAttr
    }

    private func updateGroupedData() {
        // Grouper les transactions par année et mois
        // Structure à 3 niveaux pour Carte Bancaire (si activé) : Mois > Carte Bancaire > Transactions
        // Structure à 2 niveaux pour autres : Mois > Transactions
        let calendar = Calendar.current
        let groupCB = shouldGroupCarteBancaire  // Vérifie la préférence

        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.component(.year, from: transaction.dateOperation)
        }

        groupedData = grouped.keys.sorted(by: >).flatMap { year in
            let yearTransactions = grouped[year] ?? []
            let monthGrouped = Dictionary(grouping: yearTransactions) { transaction in
                calendar.component(.month, from: transaction.datePointage)
            }

            // Créer un groupe pour chaque mois avec ses transactions
            return monthGrouped.keys.sorted(by: >).map { month in
                let monthName = calendar.monthSymbols[month - 1]
                let monthTransactions = monthGrouped[month] ?? []

                var transactionGroups: [TransactionYearGroup] = []

                if groupCB {
                    // Mode avec regroupement CB activé
                    let carteBancaireTransactions = monthTransactions.filter {
                        $0.paymentMode?.name.lowercased().contains("carte") == true
                    }
                    let otherTransactions = monthTransactions.filter {
                        $0.paymentMode?.name.lowercased().contains("carte") != true
                    }

                    // Créer le sous-groupe "Carte Bancaire" s'il y a des transactions CB
                    if !carteBancaireTransactions.isEmpty {
                        let cbChildren = carteBancaireTransactions
                            .sorted { $0.datePointage > $1.datePointage }
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

                        // Calculer le total des transactions CB
                        let cbTotal = carteBancaireTransactions.reduce(0.0) { $0 + $1.amount }
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        formatter.locale = Locale.current
                        let cbTotalFormatted = formatter.string(from: cbTotal as NSNumber) ?? "0,00 €"

                        let cbGroup = TransactionYearGroup(
                            id: UUID(),
                            displayName: "Carte Bancaire (\(carteBancaireTransactions.count)) : \(cbTotalFormatted)",
                            year: year,
                            month: month,
                            monthGroups: cbChildren,
                            transactions: nil,
                            isPaymentModeGroup: true
                        )
                        transactionGroups.append(cbGroup)
                    }

                    // Ajouter les autres transactions directement (sans sous-groupe)
                    let otherGroups = otherTransactions
                        .sorted { $0.datePointage > $1.datePointage }
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
                    transactionGroups.append(contentsOf: otherGroups)

                } else {
                    // Mode sans regroupement CB - toutes les transactions au même niveau
                    transactionGroups = monthTransactions
                        .sorted { $0.datePointage > $1.datePointage }
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
            // Initialiser aussi l'état pour le sous-groupe Carte Bancaire
            if let subGroups = group.monthGroups {
                for subGroup in subGroups where subGroup.isPaymentModeGroup {
                    let cbKey = "cb_\(group.year)_\(group.month ?? 0)"
                    if disclosureStates[cbKey] == nil {
                        disclosureStates[cbKey] = false  // Fermé par défaut
                    }
                }
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

    func updateDashboard() {
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

    func handleDataChange() {
        _ = ListTransactionsManager.shared.getAllData()
        updateGroupedData()
        updateDashboard()
    }

 }

