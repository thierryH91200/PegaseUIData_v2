//
//  SubOperationFormState.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData
import Combine


/// State specific to sub-operations (sous-opérations)
/// Separate from main transaction form state
@MainActor
final class SubOperationFormState: ObservableObject {
    @Published var subOperations: [EntitySousOperation] = []
    @Published var currentSousTransaction: EntitySousOperation? = nil
    @Published var isShowingDialog: Bool = false

    func reset() {
        subOperations.removeAll()
        currentSousTransaction = nil
        isShowingDialog = false
    }
}
