//
//  OperationDialog4.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 09/03/2025.
//


import SwiftUI
import AppKit
import SwiftData
import Observation
import Combine

@MainActor
final class TransactionFormState: ObservableObject {
    // 🧾 Données principales du formulaire
    @Published var accounts: [EntityAccount] = []
    @Published var transactionDate: Date = Date().noon
    @Published var pointingDate: Date = Date().noon
    @Published var paymentModes: [EntityPaymentMode] = []
    @Published var status: [EntityStatus] = []
    @Published var bankStatement: Double = 0.0
    @Published var checkNumber: Int = 0
    @Published var amount: String = ""

    @Published var selectedBankStatement: String = ""
    @Published var selectedStatus: EntityStatus? = nil
    @Published var selectedMode: EntityPaymentMode? = nil
    @Published var selectedAccount: EntityAccount? = nil

    // 🔁 Indicateur de mode édition groupée (batch editing)
    @Published var isBatchEditing: Bool = false

    // 🧩 Valeurs uniques extraites automatiquement lors d’un batch edit
    @Published var batchUniqueTransactionDate: Date? = nil
    @Published var batchUniquePointingDate: Date? = nil
    @Published var batchUniqueStatus: EntityStatus? = nil
    @Published var batchUniqueMode: EntityPaymentMode? = nil
    @Published var batchUniqueBankStatement: String? = nil
    
    @Published var subOperations: [EntitySousOperation] = []
    @Published var currentSousTransaction: EntitySousOperation? = nil
    @Published var isShowingDialog: Bool = false
    
    @Published var currentTransaction: EntityTransaction? = nil
    @Published var entityTransactions: [EntityTransaction] = []


    // 📥 Méthode pour charger des valeurs batch depuis les transactions sélectionnées
    func updateBatchValues(from transactions: [EntityTransaction]) {
        isBatchEditing = transactions.count > 1

        batchUniqueTransactionDate = transactions.map { $0.dateOperation }.uniqueElement
        batchUniquePointingDate = transactions.map { $0.datePointage }.uniqueElement
        batchUniqueStatus = transactions.compactMap { $0.status }.uniqueElement
        batchUniqueMode = transactions.compactMap { $0.paymentMode }.uniqueElement
        batchUniqueBankStatement = transactions.map { $0.bankStatement }.uniqueElement.map { String($0) }
    }

    // 🔄 Réinitialisation complète
    func reset() {
        isBatchEditing = false
        batchUniqueTransactionDate = nil
        batchUniquePointingDate = nil
        batchUniqueStatus = nil
        batchUniqueMode = nil
        batchUniqueBankStatement = nil

        transactionDate = Date().noon
        pointingDate = Date().noon
        checkNumber = 0
        bankStatement = 0.0
        amount = ""
        selectedBankStatement = ""
        selectedStatus = nil
        selectedMode = nil
        selectedAccount = nil
    }
}
