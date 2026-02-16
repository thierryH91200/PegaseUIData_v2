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
extension TransactionTableViewModern {

    // MARK: - Actions

    func createNewTransaction() {
        transactionManager.isCreationMode = true
        transactionManager.selectedTransaction = nil
    }

    func updateStatus(for uuids: Set<UUID>, to statusName: String) {
        guard let status = StatusManager.shared.find(name: statusName) else { return }
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.status = status
        }

        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Statut mis à jour vers '\(statusName)' pour \(selected.count) transaction(s)")
    }

    func updatePaymentMode(for uuids: Set<UUID>, to modeName: String) {
        guard let mode = PaymentModeManager.shared.find(name: modeName) else { return }
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.paymentMode = mode
        }

        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Mode de paiement mis à jour vers '\(modeName)' pour \(selected.count) transaction(s)")
        if modeName == String(localized: "Bank Card") {
            handleDataChange()
            loadDisclosureState()
        }
    }

    func updateBankStatement(for uuids: Set<UUID>, to statement: String) {
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.bankStatement = Double(statement) ?? 0.0
        }

        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Relevé bancaire mis à jour vers '\(statement)' pour \(selected.count) transaction(s)")
    }
    func updatePointingDate(for uuids: Set<UUID>, to date: Date) {
        let selected = transactions.filter { uuids.contains($0.uuid) }

        for transaction in selected {
            transaction.datePointage = date
        }

        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }

        // Mettre à jour sans reconstruire les groupes pour éviter le scroll
        _ = ListTransactionsManager.shared.getAllData()
        updateDashboard()

        AppLogger.transactions.info("Pointing date mis à jour vers '\(date)' pour \(selected.count) transaction(s)")
    }

    func duplicateTransactions(_ uuids: Set<UUID>) {
        let selected = transactions.filter { uuids.contains($0.uuid) }

        guard let targetAccount = CurrentAccountManager.shared.getAccount() else {
            AppLogger.transactions.error("Aucun compte cible pour l'opération de duplication")
            ToastManager.shared.show("Erreur: aucun compte cible", icon: "xmark.circle.fill", type: .error)
            return
        }

        for transaction in selected {
            var newTransaction = EntityTransaction(account: targetAccount)
            newTransaction.dateOperation = transaction.dateOperation
            newTransaction.datePointage = transaction.datePointage
            newTransaction.status = transaction.status
            newTransaction.paymentMode = transaction.paymentMode
            newTransaction.checkNumber = transaction.checkNumber
            newTransaction.bankStatement = transaction.bankStatement

            for item in transaction.sousOperations {
                let sousOperation = EntitySousOperation()
                sousOperation.libelle = item.libelle
                sousOperation.amount = item.amount
                sousOperation.category = item.category

                newTransaction = ListTransactionsManager.shared.addSousTransaction(transaction: newTransaction, sousTransaction: sousOperation)
            }
        }

        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }
        handleDataChange()

        let message = selected.count == 1 ? "Transaction dupliquée" : "\(selected.count) transactions dupliquées"
        ToastManager.shared.show(message, icon: "doc.on.doc.fill", type: .success)
        AppLogger.transactions.info("Dupliqué \(selected.count) transaction(s)")
    }

    func deleteTransactions(_ uuids: Set<UUID>) {
        // Collecter les entités depuis groupedData (source fiable avec toutes les transactions)
        var allTransactions: [EntityTransaction] = []
        for group in groupedData {
            collectTransactions(from: group, into: &allTransactions)
        }
        let selected = allTransactions.filter { uuids.contains($0.uuid) }
        let count = selected.count
        guard count > 0 else { return }

        if count < 50 {
            // Suppression immédiate pour les petits lots
            ListTransactionsManager.shared.delete(entities: selected)

            do {
                try ListTransactionsManager.shared.save()
            } catch {
                AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
                ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
            }
            selectedTransactions.removeAll()
            handleDataChange()

            let message = count == 1 ? "Transaction supprimée" : "\(count) transactions supprimées"
            ToastManager.shared.show(message, icon: "trash.fill", type: .success)
            AppLogger.transactions.info("Delete \(count) transaction(s)")
        } else {
            // Pour les gros lots, afficher la sheet de progression
            pendingDeletions = selected
            deleteProgress = 0
            deleteTotalCount = count
            deleteCurrentCount = 0
            showDeleteProgress = true
        }
    }

    func performBatchDeletion() {
        let entities = pendingDeletions
        guard !entities.isEmpty else { return }

        Task { @MainActor in
            await ListTransactionsManager.shared.deleteBatched(
                entities: entities,
                batchSize: 100
            ) { current, total in
                deleteCurrentCount = current
                deleteProgress = Double(current) / Double(total)
            }

            do {
                try ListTransactionsManager.shared.save()
            } catch {
                AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
                ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
            }

            selectedTransactions.removeAll()
            handleDataChange()
            pendingDeletions = []
            showDeleteProgress = false

            let message = "\(entities.count) transactions supprimées"
            ToastManager.shared.show(message, icon: "trash.fill", type: .success)
            AppLogger.transactions.info("Supprimé \(entities.count) transaction(s)")
        }
    }

    func selectAllTransactions() {
        // Ouvrir tous les DisclosureGroup pour que SwiftUI rende toutes les lignes
        for group in groupedData {
            let monthKey = "month_\(group.year)_\(group.month ?? 0)"
            disclosureStates[monthKey] = true

            // Ouvrir aussi les sous-groupes (Carte Bancaire, etc.)
            if let subGroups = group.monthGroups {
                for subGroup in subGroups where subGroup.isPaymentModeGroup {
                    let cbKey = "cb_\(group.year)_\(group.month ?? 0)"
                    disclosureStates[cbKey] = true
                }
            }
        }

        // Extraire tous les UUIDs depuis groupedData (qui contient toutes les transactions affichées)
        var allUUIDs = Set<UUID>()
        for group in groupedData {
            collectUUIDs(from: group, into: &allUUIDs)
        }
        selectedTransactions = allUUIDs
    }

    /// Collecte récursivement les UUIDs des transactions depuis la hiérarchie de groupes
    private func collectUUIDs(from group: TransactionYearGroup, into uuids: inout Set<UUID>) {
        if let txns = group.transactions {
            for txn in txns {
                uuids.insert(txn.uuid)
            }
        }
        if let children = group.monthGroups {
            for child in children {
                collectUUIDs(from: child, into: &uuids)
            }
        }
    }

    /// Collecte récursivement les EntityTransaction depuis la hiérarchie de groupes
    private func collectTransactions(from group: TransactionYearGroup, into result: inout [EntityTransaction]) {
        if let txns = group.transactions {
            result.append(contentsOf: txns)
        }
        if let children = group.monthGroups {
            for child in children {
                collectTransactions(from: child, into: &result)
            }
        }
    }

    func copySelected() {
        clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
        isCutOperation = false

        let message = clipboardTransactions.count == 1 ? "Transaction copiée" : "\(clipboardTransactions.count) transactions copiées"
        ToastManager.shared.show(message, icon: "doc.on.doc.fill", type: .info)
        AppLogger.ui.info("Copié \(clipboardTransactions.count) transaction(s)")
    }

    func cutSelected() {
        clipboardTransactions = transactions.filter { selectedTransactions.contains($0.uuid) }
        isCutOperation = true

        let message = clipboardTransactions.count == 1 ? "Transaction coupée" : "\(clipboardTransactions.count) transactions coupées"
        ToastManager.shared.show(message, icon: "scissors", type: .info)
        AppLogger.ui.info("Coupé \(clipboardTransactions.count) transaction(s)")
    }

    func pasteTransactions() {
        guard !clipboardTransactions.isEmpty else {
            ToastManager.shared.show("Presse-papiers vide", icon: "exclamationmark.triangle.fill", type: .warning)
            return
        }

        guard let targetAccount = CurrentAccountManager.shared.getAccount() else {
            AppLogger.transactions.error("Aucun compte cible pour l'opération de collage")
            ToastManager.shared.show("Erreur: aucun compte cible", icon: "xmark.circle.fill", type: .error)
            return
        }

        let pastedCount = clipboardTransactions.count

        for transaction in clipboardTransactions {
            let status = transaction.status.flatMap { StatusManager.shared.find(name: $0.name) }
            let paymentMode = transaction.paymentMode.flatMap { PaymentModeManager.shared.find(name: $0.name) }

            var newTransaction = EntityTransaction(account: targetAccount)
            newTransaction.dateOperation = transaction.dateOperation
            newTransaction.datePointage = transaction.datePointage
            newTransaction.status = status
            newTransaction.paymentMode = paymentMode
            newTransaction.checkNumber = transaction.checkNumber
            newTransaction.bankStatement = transaction.bankStatement

            for item in transaction.sousOperations {
                let sousOperation = EntitySousOperation()
                let category = item.category.flatMap { CategoryManager.shared.find(name: $0.name) }
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

        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.transactions.error("Save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }
        clipboardTransactions = []
        isCutOperation = false
        handleDataChange()

        let message = pastedCount == 1 ? "Transaction collée" : "\(pastedCount) transactions collées"
        ToastManager.shared.show(message, icon: "doc.on.clipboard.fill", type: .success)
        AppLogger.transactions.info("Collé \(pastedCount) transaction(s)")
    }

    // MARK: - Disclosure State Management

    private func saveDisclosureState() {
        guard let accountName = compteCurrent?.name else { return }
        let key = "disclosureStatesModern_" + accountName
        if let data = try? JSONEncoder().encode(disclosureStates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadDisclosureState() {
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

    func toggleDisclosure(for key: String) {
        disclosureStates[key] = !(disclosureStates[key] ?? false)
        saveDisclosureState()
    }

    func isExpanded(for key: String) -> Bool {
        return disclosureStates[key] ?? true
    }
}

// MARK: - Delete Progress Sheet

/// Sheet affichant la progression de la suppression batch
struct DeleteProgressSheet: View {
    let totalCount: Int
    @Binding var currentCount: Int
    @Binding var progress: Double
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.title)
                    .foregroundColor(.red)
                Text("Suppression en cours")
                    .font(.title2.bold())
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                ProgressView(value: progress) {
                    Text("\(currentCount) / \(totalCount)")
                        .font(.headline)
                        .monospacedDigit()
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)
            }

            Text("Veuillez patienter pendant la suppression des transactions...")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .frame(width: 420, height: 200)
        .interactiveDismissDisabled()
        .onAppear {
            onStart()
        }
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
    var isPaymentModeGroup: Bool = false  // Indique si c'est un sous-groupe par mode de paiement

    var transaction: EntityTransaction? {
        // Retourne la transaction seulement si ce n'est pas un groupe (a des transactions)
        return transactions?.first
    }
}

