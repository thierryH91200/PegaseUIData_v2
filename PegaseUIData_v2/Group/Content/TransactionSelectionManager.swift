//
//  TransactionSelectionManager.swift
//  PegaseUIData_v2
//
//  Manages transaction selection state for the UI
//  Extracted from Content.swift for better code organization
//

import SwiftUI
import Combine

enum FormMode {
    case create
    case editSingle(EntityTransaction)
    case editMultiple([EntityTransaction])
}

class TransactionSelectionManager: ObservableObject, Identifiable {
    @Published var selectedTransaction: EntityTransaction?
    @Published var selectedTransactions: [EntityTransaction] = []

    @Published var isCreationMode: Bool = true
    @Published var lastSelectedTransactionID: UUID?

    var formMode: FormMode {
        switch selectedTransactions.count {
        case 0:
            return .create
        case 1:
            guard let firstTransaction = selectedTransactions.first else {
                return .create
            }
            return .editSingle(firstTransaction)
        default:
            return .editMultiple(selectedTransactions)
        }
    }

    var isMultiSelection: Bool {
        selectedTransactions.count > 1
    }
}
