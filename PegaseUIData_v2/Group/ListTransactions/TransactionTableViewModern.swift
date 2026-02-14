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
    @State private var showPointingDate = false
    @State private var bankStatementInput = ""
    @State private var pointingDate = Date()
    
    @State private var info = ""
    
    // État pour le calcul asynchrone du dashboard
    @State private var isCalculatingDashboard = false
    @State private var dashboardTask: Task<Void, Never>?

    // État pour la sheet de progression de suppression
    @State var showDeleteProgress = false
    @State var deleteProgress: Double = 0
    @State var deleteTotalCount: Int = 0
    @State var deleteCurrentCount: Int = 0
    @State var pendingDeletions: [EntityTransaction] = []

    
    
    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }
    
    // Vérifie si le regroupement CB est activé dans les préférences
    var shouldGroupCarteBancaire: Bool {
        return PreferenceManager.shared.getAllData()?.groupCarteBancaire ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Table principale
            mainTableSection
            
            Divider()
            
            // Barre de statut avec statistiques
            statusBarSection
        }
        .navigationTitle("Account: \(compteCurrent?.name ?? "No account")")
        .sheet(isPresented: $showTransactionDetail) {
            transactionDetailPopover
        }
        .sheet(isPresented: $showDeleteProgress) {
            DeleteProgressSheet(
                totalCount: deleteTotalCount,
                currentCount: $deleteCurrentCount,
                progress: $deleteProgress,
                onStart: { performBatchDeletion() }
            )
        }
        .popover(isPresented: $showBankStatementPopover, arrowEdge: .trailing) {
            bankStatementPopoverContent
        }
        .frame(minWidth: filteredTransactions != nil ? 600 : 1000,
               minHeight: filteredTransactions != nil ? 200 : 600)
        .onAppear {
            handleDataChange()
            loadDisclosureState()
        }
        .popover(isPresented: $showPointingDate, arrowEdge: .trailing) {
            pointingDateContent
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
        .onReceive(NotificationCenter.default.publisher(for: .transactionsNeedRefresh)) { _ in
            // Rafraîchissement forcé quand on revient d'une autre vue (ex: TreasuryCurveView)
            handleDataChange()
        }
        .onChange(of: currentAccountManager.currentAccountID) { _, _ in
            handleDataChange()
            loadDisclosureState()
        }
        .onChange(of: transactions.count) { oldCount, newCount in
            // Si filteredTransactions est fourni (ex: dans les rapports),
            // on accepte les changements de count car c'est le filtrage par sélection de barre/pie
            if filteredTransactions != nil {
                updateGroupedData()
                updateDashboard()
            } else if newCount < oldCount && oldCount > 0 {
                // Si le count diminue significativement sans filteredTransactions,
                // c'est probablement un filtrage non désiré
                // (ex: TreasuryCurve4 qui modifie listTransactions avec des données filtrées)
                // Forcer le rechargement complet dans ce cas
                handleDataChange()
            } else {
                updateGroupedData()
                updateDashboard()
            }
        }
        .onChange(of: selectedTransactions) { _, newSelection in
            updateTransactionManager(with: newSelection)
            info = selectionDidChange()
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
        .onReceive(NotificationCenter.default.publisher(for: .selectAllTransactions)) { _ in
            selectAllTransactions()
        }
        .withToastContainer()
    }
    
    // MARK: - View Components
    
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
                if uuids.isEmpty && selectedTransactions.isEmpty {
                    Button("New Transaction") { createNewTransaction() }
                } else {
                    // Utiliser selectedTransactions (source complète) au lieu de uuids
                    // car uuids ne contient que les éléments rendus par la List lazy
                    transactionContextMenu(for: selectedTransactions.isEmpty ? uuids : selectedTransactions)
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
            Text("Status").bold().frame(width: ColumnWidths.statut, alignment: .leading)
            Divider().frame(width: 2)
            Text("Payment method").bold().frame(width: ColumnWidths.modePaiement, alignment: .leading)
            Divider().frame(width: 2)
            Text("Amount").bold().frame(width: ColumnWidths.montant, alignment: .trailing)
            Divider().frame(width: 2)
            Text("Solde").bold().frame(width: ColumnWidths.montant, alignment: .trailing)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
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
            // Left: count
            Text("📊 \(countAllTransactions(groupedData)) transactions")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            // Selection badge with strong accent
            if !selectedTransactions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                    Text(info)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor)
                )
                .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 3)
                .transition(.scale.combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: selectedTransactions)
        
        
    }

    func selectionDidChange() -> String {
        
        if selectedTransactions.isEmpty == false {
            
            let selected = transactions.filter { selectedTransactions.contains($0.uuid) }
            
            var amount = 0.0
            var solde = 0.0
            var expense = 0.0
            var income = 0.0
            
            let formatter = NumberFormatter()
            formatter.locale = Locale.current
            formatter.numberStyle = .currency
            
            for row in selected {
                
                amount = (row.amount)
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
            let count = selectedTransactions.count
            let info = String(localized:"\(count) selected transactions Expenses : \(strExpense) Incomes : \(strIncome) Total : \(amountStr)")
            
            return info
        }
        return "No transactions selected"
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
    
    private var pointingDateContent: some View {
        VStack(spacing: 12) {
            Text("Change Pointing Date")
                .font(.headline)
            
            DatePicker("Pointage Date", selection: $pointingDate, displayedComponents: .date)
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    showPointingDate = false
                }
                Button("OK") {
                    updatePointingDate(for: selectedTransactions, to: pointingDate)
                    showPointingDate = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding()
        .onAppear {
            let selected = transactions.filter { selectedTransactions.contains($0.uuid) }
            pointingDate = selected.first?.datePointage ?? Date()
        }
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
        
        Menu("Change Pointing Date") {
            Button("Pointing Date") {
                showPointingDate = true
            }
        }
        
        Menu("Change Payment Method") {
            ForEach(PaymentModeManager.shared.getAllNames(), id: \.self) { mode in
                Button(mode) { updatePaymentMode(for: uuids, to: mode) }
            }
        }
        
        Menu("Change the Statut") {
            Button("Planned") { updateStatus(for: uuids, to: String(localized:"Planned")) }
            Button("In progress") { updateStatus(for: uuids, to: String(localized:"In progress")) }
            Button("Executed") { updateStatus(for: uuids, to: String(localized: "Executed")) }
        }
        
        Menu("Change the bank statement") {
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
            count + countTransactionsRecursive(group)
        }
    }

    /// Recursively count transactions in a group hierarchy (supports 3-level CB grouping)
    private func countTransactionsRecursive(_ group: TransactionYearGroup) -> Int {
        let directCount = group.transactions?.count ?? 0
        let childrenCount = group.monthGroups?.reduce(0) { $0 + countTransactionsRecursive($1) } ?? 0
        return directCount + childrenCount
    }
    
    private func updateGroupedData() {
        // Grouper les transactions par année et mois
        // Structure à 3 niveaux pour Carte Bancaire (si activé) : Mois > Carte Bancaire > Transactions
        // Structure à 2 niveaux pour autres : Mois > Transactions
        let calendar = Calendar.current
        let groupCB = shouldGroupCarteBancaire  // Vérifie la préférence
        
        // IMPORTANT: Utiliser datePointage de manière cohérente pour l'année ET le mois
        // Cela évite les incohérences quand dateOperation et datePointage sont dans des mois différents
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.component(.year, from: transaction.datePointage)
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
                
                // Fonction de tri cohérente avec le calcul du solde
                // (datePointage décroissant, puis dateOperation décroissant, puis createAt décroissant, puis UUID)
                let sortForDisplay: (EntityTransaction, EntityTransaction) -> Bool = { t1, t2 in
                    if t1.datePointage == t2.datePointage {
                        if t1.dateOperation == t2.dateOperation {
                            if t1.createAt == t2.createAt {
                                // UUID comme critère final pour ordre déterministe
                                return t1.uuid.uuidString > t2.uuid.uuidString
                            }
                            return t1.createAt > t2.createAt
                        }
                        return t1.dateOperation > t2.dateOperation
                    }
                    return t1.datePointage > t2.datePointage
                }
                
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
                            .sorted(by: sortForDisplay)
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
                        .sorted(by: sortForDisplay)
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
                        .sorted(by: sortForDisplay)
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
        // Annuler tout calcul en cours pour éviter les doublons
        dashboardTask?.cancel()

        dashboardTask = Task {
            await updateDashboardAsync()
        }
    }

    /// Calcul asynchrone du dashboard et du solde courant
    /// Les calculs lourds (tri, filtrage, solde) sont déportés en arrière-plan
    /// pour ne pas bloquer le thread principal (UI)
    @MainActor
    private func updateDashboardAsync() async {
        guard let initCompte = InitAccountManager.shared.getAllData() else {
            AppLogger.data.warning("Aucune donnée de compte initial trouvée")
            return
        }

        isCalculatingDashboard = true

        // Capturer les données nécessaires pour le calcul en arrière-plan
        // On copie les valeurs légères (montant, statut, dates, uuid) pour éviter
        // d'accéder aux objets SwiftData depuis un thread non-principal
        struct TransactionSnapshot {
            let index: Int
            let amount: Double
            let statusType: StatusType?
            let datePointage: Date
            let dateOperation: Date
            let createAt: Date
            let uuidString: String
        }

        let snapshots: [TransactionSnapshot] = transactions.enumerated().map { index, t in
            TransactionSnapshot(
                index: index,
                amount: t.amount,
                statusType: t.status?.type,
                datePointage: t.datePointage,
                dateOperation: t.dateOperation,
                createAt: t.createAt,
                uuidString: t.uuid.uuidString
            )
        }

        let realise = initCompte.realise
        let engage = initCompte.engage
        let prevu = initCompte.prevu

        // Vérifier l'annulation avant le calcul lourd
        guard !Task.isCancelled else {
            isCalculatingDashboard = false
            return
        }

        // Calcul lourd en arrière-plan (tri + solde + agrégats)
        let result = await Task.detached(priority: .userInitiated) {
            // Agrégats par statut (3 passes en 1 seule boucle)
            var executedSum = 0.0
            var inProgressSum = 0.0
            var plannedSum = 0.0

            for snap in snapshots {
                switch snap.statusType {
                case .executed:
                    executedSum += snap.amount
                case .inProgress:
                    inProgressSum += snap.amount
                case .planned:
                    plannedSum += snap.amount
                default:
                    break
                }
            }

            // Vérifier l'annulation avant le tri
            guard !Task.isCancelled else { return nil as (Double, Double, Double, [(Int, Double)])? }

            // Tri par datePointage, dateOperation, createAt, UUID (croissant)
            let sortedSnapshots = snapshots.sorted { t1, t2 in
                if t1.datePointage == t2.datePointage {
                    if t1.dateOperation == t2.dateOperation {
                        if t1.createAt == t2.createAt {
                            return t1.uuidString < t2.uuidString
                        }
                        return t1.createAt < t2.createAt
                    }
                    return t1.dateOperation < t2.dateOperation
                }
                return t1.datePointage < t2.datePointage
            }

            // Calcul du solde courant
            let initialBalance = prevu + engage + realise
            var runningBalance = initialBalance
            var soldeResults: [(Int, Double)] = []
            soldeResults.reserveCapacity(sortedSnapshots.count)

            for snap in sortedSnapshots {
                guard !Task.isCancelled else { return nil }
                runningBalance += snap.amount
                soldeResults.append((snap.index, runningBalance))
            }

            let executedDashboard = realise + executedSum
            let engagedDashboard = executedDashboard + inProgressSum
            let plannedDashboard = engagedDashboard + plannedSum

            return (executedDashboard, engagedDashboard, plannedDashboard, soldeResults)
        }.value

        // Vérifier l'annulation et la validité du résultat
        guard !Task.isCancelled, let (executedVal, engagedVal, plannedVal, soldeResults) = result else {
            isCalculatingDashboard = false
            return
        }

        // Mise à jour de l'UI sur le thread principal
        dashboard.executed = executedVal
        dashboard.engaged = engagedVal
        dashboard.planned = plannedVal

        // Appliquer les soldes calculés aux transactions
        for (index, solde) in soldeResults {
            if index < transactions.count {
                transactions[index].solde = solde
            }
        }

        isCalculatingDashboard = false
    }

    func handleDataChange() {
        // Forcer le rechargement pour s'assurer que les données sont à jour
        // Cela évite les problèmes de cache quand on revient d'une autre vue
        // ou quand TreasuryCurve4 a modifié listTransactions avec des données filtrées
        _ = ListTransactionsManager.shared.loadAllTransactions(forceReload: true)
        updateGroupedData()
        updateDashboard()
    }
    
}

