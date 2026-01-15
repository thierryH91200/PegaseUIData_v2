//
//  CoreTransactionFormState.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData
import Combine

/// Core transaction form state - focused on single transaction editing
/// This replaces the bloated TransactionFormState with only essential fields
@MainActor
final class CoreTransactionFormState: ObservableObject {
    // Date fields
    @Published var transactionDate: Date = Date().noon
    @Published var pointingDate: Date = Date().noon

    // Amount and numbers
    @Published var bankStatement: Double = 0.0
    @Published var checkNumber: Int = 0
    @Published var amount: String = ""

    // Selected values
    @Published var selectedBankStatement: String = ""
    @Published var selectedStatus: EntityStatus? = nil
    @Published var selectedMode: EntityPaymentMode? = nil
    @Published var selectedAccount: EntityAccount? = nil

    // Current transaction being edited
    @Published var currentTransaction: EntityTransaction? = nil

    func reset() {
        transactionDate = Date().noon
        pointingDate = Date().noon
        checkNumber = 0
        bankStatement = 0.0
        amount = ""
        selectedBankStatement = ""
        selectedStatus = nil
        selectedMode = nil
        selectedAccount = nil
        currentTransaction = nil
    }

    /// Load values from an existing transaction
    func loadFrom(transaction: EntityTransaction) {
        currentTransaction = transaction
        transactionDate = transaction.dateOperation
        pointingDate = transaction.datePointage
        bankStatement = transaction.bankStatement
        checkNumber = Int(transaction.checkNumber) ?? 0
        selectedStatus = transaction.status
        selectedMode = transaction.paymentMode
        selectedAccount = transaction.account
        amount = String(transaction.amount)
    }
}
