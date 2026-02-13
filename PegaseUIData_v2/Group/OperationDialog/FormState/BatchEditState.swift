//
//  BatchEditState.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData
import Combine

/// State specific to batch editing multiple transactions
/// Only used when multiple transactions are selected
@MainActor
final class BatchEditState: ObservableObject {
    @Published var isBatchEditing: Bool = false

    // Unique values extracted from selected transactions
    @Published var batchUniqueTransactionDate: Date? = nil
    @Published var batchUniquePointingDate: Date? = nil
    @Published var batchUniqueStatus: EntityStatus? = nil
    @Published var batchUniqueMode: EntityPaymentMode? = nil
    @Published var batchUniqueBankStatement: String? = nil

    /// Update batch values from selected transactions
    func updateBatchValues(from transactions: [EntityTransaction]) {
        isBatchEditing = transactions.count > 1

        batchUniqueTransactionDate = transactions.map { $0.dateOperation }.uniqueElement
        batchUniquePointingDate = transactions.map { $0.datePointage }.uniqueElement
        batchUniqueStatus = transactions.compactMap { $0.status }.uniqueElement
        batchUniqueMode = transactions.compactMap { $0.paymentMode }.uniqueElement
        batchUniqueBankStatement = transactions.map { $0.bankStatement }.uniqueElement.map { String($0) }
    }

    func reset() {
        isBatchEditing = false
        batchUniqueTransactionDate = nil
        batchUniquePointingDate = nil
        batchUniqueStatus = nil
        batchUniqueMode = nil
        batchUniqueBankStatement = nil
    }
}

// Helper extension for extracting unique values
extension Array where Element: Equatable {
    var uniqueElement: Element? {
        guard let first = first else { return nil }
        return allSatisfy { $0 == first } ? first : nil
    }
}
