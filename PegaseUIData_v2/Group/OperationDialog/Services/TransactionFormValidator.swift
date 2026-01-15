//
//  TransactionFormValidator.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import Foundation

/// Validation errors for transaction forms
enum TransactionValidationError: LocalizedError {
    case missingAccount
    case missingAmount
    case invalidAmount
    case missingDate
    case invalidDateRange
    case missingPaymentMode
    case missingStatus

    var errorDescription: String? {
        switch self {
        case .missingAccount:
            return "Aucun compte sélectionné"
        case .missingAmount:
            return "Le montant est requis"
        case .invalidAmount:
            return "Le montant est invalide"
        case .missingDate:
            return "La date est requise"
        case .invalidDateRange:
            return "La date de pointage ne peut pas être antérieure à la date d'opération"
        case .missingPaymentMode:
            return "Le mode de paiement est requis"
        case .missingStatus:
            return "Le statut est requis"
        }
    }
}

/// Service responsible for validating transaction form data
@MainActor
struct TransactionFormValidator {

    /// Validate core transaction form state
    static func validate(_ coreState: CoreTransactionFormState) -> [TransactionValidationError] {
        var errors: [TransactionValidationError] = []

        // Validate account
        if coreState.selectedAccount == nil {
            errors.append(.missingAccount)
        }

        // Validate amount
        if coreState.amount.isEmpty {
            errors.append(.missingAmount)
        } else if Double(coreState.amount) == nil {
            errors.append(.invalidAmount)
        }

        // Validate payment mode
        if coreState.selectedMode == nil {
            errors.append(.missingPaymentMode)
        }

        // Validate status
        if coreState.selectedStatus == nil {
            errors.append(.missingStatus)
        }

        // Validate date range
        if coreState.pointingDate < coreState.transactionDate {
            errors.append(.invalidDateRange)
        }

        return errors
    }

    /// Check if form is valid (no errors)
    static func isValid(_ coreState: CoreTransactionFormState) -> Bool {
        return validate(coreState).isEmpty
    }

    /// Validate sub-operation
    static func validateSubOperation(amount: Double, comment: String) -> [TransactionValidationError] {
        var errors: [TransactionValidationError] = []

        if amount == 0 {
            errors.append(.missingAmount)
        }

        if comment.isEmpty {
            errors.append(.missingAccount) // Repurposed for "missing comment"
        }

        return errors
    }
}
