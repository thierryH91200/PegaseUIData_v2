//
//  OperationDialog3.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 27/02/2025.
//

import SwiftUI
import AppKit
import SwiftData
import Observation
import OSLog

// MARK: 1. Composant principal
struct OperationDialogView: View {

    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var transactionManager: TransactionSelectionManager
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
//    @EnvironmentObject var dataManager: ListDataManager
    
    @EnvironmentObject var formState: TransactionFormState
    
    @State var setReleve        = Set<Double>()
    @State var setMontant       = Set<Double>()
    @State var setModePaiement  = Set<EntityPaymentMode>()
    @State var setStatut        = Set<EntityStatus>()
    @State var setNumber        = Set<String>()
    @State var setTransfert     = Set<String>()
    @State var setCheck_In_Date = Set<Date>()
    @State var setDateOperation = Set<Date>()
    
    // États du formulaire déplacés dans un State Object
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // En-tête avec information de transaction
            FormTitleView(formMode: transactionManager.formMode)
            Divider()
            
            VStack {
                TransactionFormUnifiedView()
            }
            .onChange(of: transactionManager.selectedTransactions) { old, newSelection in
                formState.updateBatchValues(from: newSelection)
            }
            
            // Section des sous-opérations
            SubOperationsSectionView(
                subOperations       : $formState.subOperations,
                currentSubOperation : $formState.currentSousTransaction,
                isShowingDialog     : $formState.isShowingDialog
            )
            .id(UUID()) // ✅ Force SwiftUI à redessiner la vue
            
            Spacer()
            
            // Boutons d'action
            ActionButtonsView(
                cancelAction: handleCancel,
                saveAction  : handleSave
            )
        }
        .padding()
        .sheet(isPresented: $formState.isShowingDialog) {
            SubOperationDialog( subOperation: $formState.currentSousTransaction )
        }
        
        .onChange(of: formState.subOperations) { oldValue, newValue in
            formState.subOperations = Array(newValue) // Force SwiftUI à détecter un changement
        }
        .onChange(of: currentAccountManager.currentAccountID) { old, newValue in
            if !newValue.isEmpty  {
                refreshData()
            }
        }
        .onChange(of: transactionManager.selectedTransaction) { old, newTransaction in
            if transactionManager.isCreationMode == false, let transaction = newTransaction, old != newTransaction {
                loadTransactionData(transaction)
            }
        }
        .onAppear {
            Task {
                do {
                    configureDataManagers()
                    try await configureFormState()
                    
                    if transactionManager.isCreationMode == false, let transaction = transactionManager.selectedTransaction {
                        loadTransactionData(transaction)
                    }
                    
                } catch {
                    AppLogger.ui.error("Dialog configuration failed: \(error.localizedDescription)")
                }
            }
            setStatut = Set(transactionManager.selectedTransactions.map { $0.status! })
            
            setModePaiement = Set(
                transactionManager.selectedTransactions
                    .compactMap { $0.paymentMode } // Ignore ceux qui sont nil
            )
        }
    }
    
    @ViewBuilder
    private var batchEditSection: some View {
        let uniqueStatus = transactionManager.selectedTransactions.compactMap { $0.status }.uniqueElement
        let uniqueMode = transactionManager.selectedTransactions.compactMap { $0.paymentMode }.uniqueElement
        let uniqueDate = transactionManager.selectedTransactions.map { $0.dateOperation }.uniqueElement
        let uniquePointingDate = transactionManager.selectedTransactions.map { $0.datePointage }.uniqueElement
        let uniqueBankStatement = transactionManager.selectedTransactions.map { $0.bankStatement }.uniqueElement

        BatchEditFormView(
            uniqueStatus: uniqueStatus,
            uniqueMode: uniqueMode,
            uniqueDate: uniqueDate,
            uniquePointingDate: uniquePointingDate,
            uniqueBankStatement: uniqueBankStatement
        )
    }
    
    private func handleCancel() {
        resetListTransactions()
        transactionManager.selectedTransaction = nil
        transactionManager.selectedTransactions.removeAll()
        transactionManager.isCreationMode = true
        dismiss()
    }

    private func handleSave() {
        saveActions()
        transactionManager.selectedTransaction = nil
        transactionManager.selectedTransactions.removeAll()
        transactionManager.isCreationMode = true
    }
    
    // Méthodes extraites et simplifiées
    private func configureDataManagers() {
        formState.accounts = AccountManager.shared.getAllData()
    }
    
    private func refreshData() {
        _ = ListTransactionsManager.shared.getAllData()
    }
    
    func configureFormState() async throws {
        
        // Configuration des comptes
        formState.accounts = AccountManager.shared.getAllData()
        formState.selectedAccount = CurrentAccountManager.shared.getAccount()
        
        // Configuration des modes de paiement
        let modes = PaymentModeManager.shared.getAllData()
            formState.paymentModes = modes
            // Sélection sécurisée du premier mode de paiement
            formState.selectedMode = modes.first

        // Configuration des différents status
        if let account = CurrentAccountManager.shared.getAccount() {
            let status = StatusManager.shared.getAllData(for: account)
            formState.status = status
            // Sélection sécurisée du premier status
            formState.selectedStatus = status.first
        }
    }
    
    private func loadTransactionData(_ transaction : EntityTransaction) {
        formState.transactionDate        = transaction.dateOperation.noon
        formState.pointingDate           = transaction.datePointage.noon
        formState.checkNumber            = Int(transaction.checkNumber) ?? 0
        formState.bankStatement          = transaction.bankStatement
        formState.selectedMode           = transaction.paymentMode
        formState.selectedStatus         = transaction.status
        formState.selectedAccount        = transaction.account
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppLogger.transactions.debug("Sub-operations count: \(transaction.sousOperations.count)")
            formState.subOperations = transaction.sousOperations
        }
        formState.currentTransaction     = transaction
    }
    
    func saveActions() {
        contextSaveEdition()
        
        if transactionManager.isCreationMode {
            // Mode création : on crée une seule transaction
            let sousTransaction = formState.currentSousTransaction
            guard let sousTransaction else { return }
            var transaction = formState.currentTransaction!
            
            transaction = ListTransactionsManager.shared.addSousTransaction(transaction: transaction, sousTransaction: sousTransaction)

        } else {
            // Mode édition : modifier toutes les transactions sélectionnées
            for transaction in transactionManager.selectedTransactions {
                transaction.updatedAt = Date().noon
                transaction.datePointage = formState.pointingDate.noon
                transaction.dateOperation = formState.transactionDate.noon
                transaction.paymentMode = formState.selectedMode
                transaction.status = formState.selectedStatus
                transaction.bankStatement = formState.bankStatement
                transaction.checkNumber = String(formState.checkNumber)
                transaction.account = formState.selectedAccount!
            }
        }

        do {
            try ListTransactionsManager.shared.save()
            let count = transactionManager.selectedTransactions.count
            AppLogger.transactions.info("\(count) transaction(s) saved")
        } catch {
            AppLogger.transactions.error("Transaction save failed: \(error.localizedDescription)")
            ToastManager.shared.show(
                error.localizedDescription,
                icon: "xmark.circle.fill",
                type: .error
            )
        }

        resetListTransactions()
        if transactionManager.isCreationMode {
            NotificationCenter.default.post(name: .transactionsAddEdit, object: nil)
        } else {
            NotificationCenter.default.post(name: .transactionsEdited, object: nil)
        }
    }
    
    func contextSaveEdition() {
        guard let account = CurrentAccountManager.shared.getAccount() else {
            AppLogger.account.error("Cannot retrieve current account")
            return
        }
        
        // Création d'une nouvelle transaction
        if transactionManager.isCreationMode == true {
            createNewTransaction(account)
        } else {
            updateTransaction(account)
        }
    }
    
    // Création de l'entité transaction
    private func createNewTransaction(_ account: EntityAccount) {

        let transaction = EntityTransaction(account: account)

        transaction.dateOperation = formState.transactionDate.noon
        transaction.datePointage = formState.pointingDate.noon
        transaction.paymentMode = formState.selectedMode
        transaction.status = formState.selectedStatus
        transaction.bankStatement = Double(formState.selectedBankStatement) ?? 0
        transaction.checkNumber = String(formState.checkNumber)
        transaction.account = account
        
        formState.currentTransaction = transaction
    }
    
    private func updateTransaction(_ account: EntityAccount) {
        
        let transaction = formState.currentTransaction
        
        transaction?.updatedAt = Date().noon
        
        transaction?.datePointage = formState.pointingDate.noon
        transaction?.dateOperation = formState.transactionDate.noon
        transaction?.paymentMode = formState.selectedMode
        transaction?.status = formState.selectedStatus
        transaction?.bankStatement = formState.bankStatement
        transaction?.checkNumber = String(formState.checkNumber)
        transaction?.account = account
        
        formState.currentTransaction = transaction
    }
        
    func resetListTransactions() {
        
        let entityPreference = PreferenceManager.shared.getAllData()

        formState.currentTransaction = nil
        formState.currentSousTransaction = nil
        formState.subOperations = []
        formState.selectedMode = entityPreference?.paymentMode
        formState.selectedStatus = entityPreference?.status
        formState.bankStatement = 0.0
        formState.checkNumber = 0
    }
    
    func printTimeElapsedWhenRunningCode(title:String, operation:()->()) {
        let startTime = CFAbsoluteTimeGetCurrent()
        operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        AppLogger.ui.debug("Time elapsed for \(title): \(timeElapsed) s.")
    }
}

struct UnifiedTransactionEditorView: View {
    @ObservedObject var transactionManager: TransactionSelectionManager
    @ObservedObject var formState: TransactionFormState

    var body: some View {
        Group {
            if transactionManager.selectedTransactions.count > 1 {
                batchEditSection
            } else if formState.selectedAccount != nil {
                TransactionFormView()
            } else {
                Text("No transaction selected.")
                    .foregroundColor(.gray)
            }
        }
    }

    private var batchEditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Batch editing of \(transactionManager.selectedTransactions.count) operations")
                .font(.headline)
        }
        .padding()
        .background(.quaternary)
        .cornerRadius(12)
    }
}

struct HelpButton<Content: View>: View {
    @State private var showHelp = false
    let content: () -> Content

    var body: some View {
        Button(action: { showHelp.toggle() }) {
            Image(systemName: "questionmark.circle")
                .imageScale(.large)
        }
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            content()
                .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: 6. Composant des boutons d'action
struct ActionButtonsView: View {
    
    @EnvironmentObject var transactionManager: TransactionSelectionManager

    let cancelAction: () -> Void
    let saveAction:   () -> Void
    
    var body: some View {
        HStack {
            Button(action: cancelAction) {
                Text("Cancel")
                    .frame(width: 100)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(5)
            }
            .accessibilityLabel(String(localized: "Cancel operation"))
            .accessibilityHint(String(localized: "Double tap to discard changes and close"))
            
            Button(action: saveAction ) {
                Text(transactionManager.isCreationMode ? "Add" : "Update")
                    .frame(width: 100)
                    .foregroundColor(.white)
                    .padding()
                    .background(transactionManager.isCreationMode ? .orange : .green)
                    .cornerRadius(5)
            }
            .accessibilityLabel(String(localized: "Save operation"))
            .accessibilityHint(String(localized: "Double tap to save all changes"))
        }
    }
}

struct BatchEditFormView: View {
    @EnvironmentObject var formState: TransactionFormState
    
    let uniqueStatus: EntityStatus?
    let uniqueMode: EntityPaymentMode?
    let uniqueDate: Date?
    let uniquePointingDate: Date?
    let uniqueBankStatement: Double?
    
    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Multiple modifications")
                .font(.title3)
            
            modePaiementPicker  //ok
            statutPicker        //ok
            
            DatePicker("Operation Date", selection: $formState.transactionDate, displayedComponents: .date)
                .foregroundStyle(uniqueDate == nil ? .secondary : .primary)
            
            DatePicker("Pointage Date", selection: $formState.pointingDate, displayedComponents: .date)
                .foregroundStyle(uniquePointingDate == nil ? .secondary : .primary)
            
            FormField(label: String(localized: "Bank Statement")) {
                TextField("", text: Binding(
                    get: { String(format: "%.2f", formState.bankStatement) },
                    set: {
                        if let value = Double($0) {
                            formState.bankStatement = value
                        }
                    }
                ))
                .foregroundStyle(uniqueBankStatement == nil ? .secondary : .primary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            if let value = uniqueBankStatement {
                formState.bankStatement = value
            }
        }
    }
    
    // Picker du mode de paiement
    private var modePaiementPicker: some View {
        let binding = Binding<EntityPaymentMode?>(
            get: { uniqueMode },
            set: { newValue in
                formState.selectedMode = newValue
            }
        )

        return Picker("Payment method", selection: binding) {
            Text("Multiple value").tag(nil as EntityPaymentMode?)
            ForEach(formState.paymentModes, id: \.self) { mode in
                Text(mode.name).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }
    
    // Picker du statut
    private var statutPicker: some View {
        let binding = Binding<EntityStatus?>(
            get: { uniqueStatus },
            set: { newValue in
                formState.selectedStatus = newValue
            }
        )

        return HStack(alignment: .top, spacing: 8) {
            Picker("Status", selection: binding) {
                Text("Multiple value").tag(nil as EntityStatus?)
                ForEach(formState.status, id: \.self) { status in
                    HStack {
                        Circle()
                            .fill(Color(status.color))
                            .frame(width: 10, height: 10)
                        Text(status.name)
                    }
                    .tag(Optional(status)) // important : Optional()
                }
            }
            .pickerStyle(.menu)
            HelpButton {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• **Planned**: estimated check-in date, editable amount")
                    Text("• **Committed**: estimated clocking date, modifiable amount")
                    Text("• **Pointed**: exact date of the statement, amount not modifiable")
                    Divider()
                    Text("💡 **Keyboard shortcuts**: P = Planned, E = Committed, T = Pointed")
                }
                .font(.system(size: 12))
                .padding(8)
            }
        }
    }
}

extension Collection where Element: Hashable {
    /// Retourne l'élément unique s'il est le seul dans la collection, sinon nil
    var uniqueElement: Element? {
        let uniqueValues = Set(self)
        return uniqueValues.count == 1 ? uniqueValues.first : nil
    }
}

