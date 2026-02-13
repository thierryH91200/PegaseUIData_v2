//
//  TransactionDialogViewModel.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData
import Combine

/// Unified ViewModel that encapsulates all state and logic for the OperationDialog
/// Replaces multiple EnvironmentObjects and reduces coupling
@MainActor
final class TransactionDialogViewModel: ObservableObject {

    // MARK: - State Objects
    @Published var coreState: CoreTransactionFormState
    @Published var referenceData: FormReferenceData
    @Published var batchState: BatchEditState
    @Published var subOperationState: SubOperationFormState

    // MARK: - Dependencies (passed in)
    let transactionManager: TransactionSelectionManager
    let currentAccountManager: CurrentAccountManager

    // MARK: - Computed Properties
    var isCreationMode: Bool {
        transactionManager.isCreationMode
    }

    var selectedTransactions: [EntityTransaction] {
        transactionManager.selectedTransactions
    }

    var isBatchEdit: Bool {
        selectedTransactions.count > 1
    }

    // MARK: - Initialization
    init(
        transactionManager: TransactionSelectionManager,
        currentAccountManager: CurrentAccountManager
    ) {
        self.transactionManager = transactionManager
        self.currentAccountManager = currentAccountManager

        // Initialize state objects
        self.coreState = CoreTransactionFormState()
        self.referenceData = FormReferenceData()
        self.batchState = BatchEditState()
        self.subOperationState = SubOperationFormState()
    }

    // MARK: - Lifecycle Methods

    /// Load all necessary data when dialog appears
    func onAppear() async {
        do {
            // Load reference data
            try await FormStateInitializer.loadReferenceData(into: referenceData)

            // Configure based on mode
            if isCreationMode {
                FormStateInitializer.configureForCreation(
                    coreState: coreState,
                    referenceData: referenceData
                )
            } else if isBatchEdit {
                FormStateInitializer.configureForBatchEdit(
                    transactions: selectedTransactions,
                    batchState: batchState
                )
            } else if let transaction = selectedTransactions.first {
                FormStateInitializer.configureForEditing(
                    transaction: transaction,
                    coreState: coreState
                )
            }
        } catch {
            printTag("❌ Erreur lors du chargement des données : \(error)")
        }
    }

    // MARK: - Actions

    /// Save the current transaction(s)
    func save() {
        do {
            try TransactionPersistenceService.performSave(
                isCreationMode: isCreationMode,
                selectedTransactions: selectedTransactions,
                coreState: coreState,
                subOperationState: subOperationState
            )
            reset()
        } catch {
            printTag("❌ Erreur lors de la sauvegarde : \(error)")
        }
    }

    /// Cancel editing and reset state
    func cancel() {
        reset()
    }

    /// Reset all state to initial values
    func reset() {
        coreState.reset()
        batchState.reset()
        subOperationState.reset()

        // Reset transaction selection
        transactionManager.selectedTransactions = []
        transactionManager.isCreationMode = true
    }

    // MARK: - Sub-Operation Methods

    /// Add a new sub-operation
    func addSubOperation(amount: Double, comment: String, rubric: EntityRubric?) {
        let subOp = EntitySousOperation()
        subOp.amount = amount
        subOp.libelle = comment
        subOp.category?.rubric = rubric

        subOperationState.subOperations.append(subOp)
        subOperationState.currentSousTransaction = subOp
    }

    /// Delete a sub-operation
    func deleteSubOperation(_ subOp: EntitySousOperation) {
        subOperationState.subOperations.removeAll { $0.id == subOp.id }
    }

    // MARK: - Validation

    /// Check if form can be saved
    func canSave() -> Bool {
        return TransactionFormValidator.isValid(coreState)
    }

    /// Get validation errors
    func validationErrors() -> [TransactionValidationError] {
        return TransactionFormValidator.validate(coreState)
    }
}
