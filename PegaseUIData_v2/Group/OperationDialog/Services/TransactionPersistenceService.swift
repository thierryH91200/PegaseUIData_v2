//
//  TransactionPersistenceService.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData
import OSLog

/// Service responsible for creating, updating, and persisting transactions
/// Extracts all business logic from OperationDialogView
@MainActor
struct TransactionPersistenceService {

    /// Create a new transaction from form state
    static func createTransaction(
        from coreState: CoreTransactionFormState,
        subOperationState: SubOperationFormState
    ) throws -> EntityTransaction {
        guard let account = coreState.selectedAccount else {
            throw TransactionValidationError.missingAccount
        }

        let transaction = EntityTransaction(account: account)
        transaction.dateOperation = coreState.transactionDate.noon
        transaction.datePointage = coreState.pointingDate.noon
        transaction.paymentMode = coreState.selectedMode
        transaction.status = coreState.selectedStatus
        transaction.bankStatement = Double(coreState.selectedBankStatement) ?? 0
        transaction.checkNumber = String(coreState.checkNumber)
        transaction.account = account
        transaction.createAt = Date().noon
        transaction.updatedAt = Date().noon

        // Add sub-operation if exists
        if let sousTransaction = subOperationState.currentSousTransaction {
            _ = ListTransactionsManager.shared.addSousTransaction(
                transaction: transaction,
                sousTransaction: sousTransaction
            )
        }

        return transaction
    }

    /// Update an existing transaction from form state
    static func updateTransaction(
        _ transaction: EntityTransaction,
        from coreState: CoreTransactionFormState
    ) throws {
        guard let account = coreState.selectedAccount else {
            throw TransactionValidationError.missingAccount
        }

        transaction.updatedAt = Date().noon
        transaction.datePointage = coreState.pointingDate.noon
        transaction.dateOperation = coreState.transactionDate.noon
        transaction.paymentMode = coreState.selectedMode
        transaction.status = coreState.selectedStatus
        transaction.bankStatement = coreState.bankStatement
        transaction.checkNumber = String(coreState.checkNumber)
        transaction.account = account
    }

    /// Update multiple transactions (batch edit)
    static func updateTransactions(
        _ transactions: [EntityTransaction],
        from coreState: CoreTransactionFormState
    ) throws {
        for transaction in transactions {
            try updateTransaction(transaction, from: coreState)
        }
    }

    /// Save all changes to persistent storage
    static func save() throws {
        try ListTransactionsManager.shared.save()
        NotificationCenter.default.post(name: .transactionsAddEdit, object: nil)
    }

    /// Complete save operation - validates, creates/updates, and persists
    static func performSave(
        isCreationMode: Bool,
        selectedTransactions: [EntityTransaction],
        coreState: CoreTransactionFormState,
        subOperationState: SubOperationFormState
    ) throws {
        // Validate first
        let errors = TransactionFormValidator.validate(coreState)
        guard errors.isEmpty else {
            throw errors.first!
        }

        if isCreationMode {
            // Create new transaction
            let transaction = try createTransaction(
                from: coreState,
                subOperationState: subOperationState
            )
            coreState.currentTransaction = transaction
        } else {
            // Update existing transaction(s)
            if selectedTransactions.count == 1,
               let transaction = selectedTransactions.first {
                try updateTransaction(transaction, from: coreState)
            } else {
                try updateTransactions(selectedTransactions, from: coreState)
            }
        }

        // Persist to database
        try save()

        AppLogger.transactions.info("\(selectedTransactions.count) transaction(s) saved")
    }
}
