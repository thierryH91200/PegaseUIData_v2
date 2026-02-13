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
    case missingComment

    var errorDescription: String? {
        switch self {
        case .missingAccount:
            return NSLocalizedString("No account selected", comment: "")
        case .missingAmount:
            return NSLocalizedString("Amount is required", comment: "")
        case .invalidAmount:
            return NSLocalizedString("Amount is invalid", comment: "")
        case .missingDate:
            return NSLocalizedString("Date is required", comment: "")
        case .invalidDateRange:
            return NSLocalizedString("Pointing date cannot be earlier than operation date", comment: "")
        case .missingPaymentMode:
            return NSLocalizedString("Payment method is required", comment: "")
        case .missingStatus:
            return NSLocalizedString("Status is required", comment: "")
        case .missingComment:
            return NSLocalizedString("Comment is required", comment: "")
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
            errors.append(.missingComment)
        }

        return errors
    }
}
