//
//  FormReferenceData.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import SwiftData
import Combine


/// Reference data loaded once and shared across form components
/// This data is read-only after initialization
@MainActor
final class FormReferenceData: ObservableObject {
    @Published var accounts: [EntityAccount] = []
    @Published var paymentModes: [EntityPaymentMode] = []
    @Published var status: [EntityStatus] = []

    func reset() {
        accounts.removeAll()
        paymentModes.removeAll()
        status.removeAll()
    }
}
