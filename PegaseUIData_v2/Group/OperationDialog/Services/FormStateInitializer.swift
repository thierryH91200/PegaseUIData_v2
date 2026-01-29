//
//  FormStateInitializer.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData

/// Service responsible for initializing form state with data from managers
/// Centralizes all manager calls that were duplicated across files
@MainActor
struct FormStateInitializer {

    /// Load all reference data needed for the form
    static func loadReferenceData(into referenceData: FormReferenceData) async throws {
        referenceData.accounts = AccountManager.shared.getAllData()
        referenceData.paymentModes = PaymentModeManager.shared.getAllData()

        if let account = CurrentAccountManager.shared.getAccount() {
            referenceData.status = StatusManager.shared.getAllData(for: account)
        }
    }

    /// Initialize form state from current account preferences
    static func initializeFromPreferences(
        coreState: CoreTransactionFormState,
        referenceData: FormReferenceData
    ) {
        guard let account = CurrentAccountManager.shared.getAccount(),
              let preference = PreferenceManager.shared.getAllData() else {
            return
        }

        coreState.selectedAccount = account
        coreState.selectedMode = preference.paymentMode
        coreState.selectedStatus = preference.status
    }

    /// Configure form for creating a new transaction
    static func configureForCreation(
        coreState: CoreTransactionFormState,
        referenceData: FormReferenceData
    ) {
        coreState.reset()
        initializeFromPreferences(coreState: coreState, referenceData: referenceData)
        coreState.transactionDate = Date().noon
        coreState.pointingDate = Date().noon
    }

    /// Configure form for editing an existing transaction
    static func configureForEditing(
        transaction: EntityTransaction,
        coreState: CoreTransactionFormState
    ) {
        coreState.loadFrom(transaction: transaction)
    }

    /// Configure form for batch editing multiple transactions
    static func configureForBatchEdit(
        transactions: [EntityTransaction],
        batchState: BatchEditState
    ) {
        batchState.updateBatchValues(from: transactions)
    }
}
