//
//  EntityTransactions.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import Foundation
import SwiftData
import Combine

@Model final class EntityTransaction {

    var createAt:  Date = Date().noon
    var updatedAt: Date = Date().noon

    var datePointage:  Date = Date().noon
    var dateOperation: Date = Date().noon

    var bankStatement: Double = 0.0
    var checkNumber: String = ""
    
    var status: EntityStatus?
    var paymentMode: EntityPaymentMode?
    
    @Relationship(deleteRule: .cascade, inverse: \EntitySousOperation.transaction)
    var sousOperations: [EntitySousOperation] = []

    var amount: Double {
        sousOperations.reduce(0.0) { $0 + $1.amount }
    }

    @Attribute(.ephemeral) var solde: Double? = 0.0
    
    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship var account: EntityAccount
    
//    @Relationship(inverse: \EntityTransactions.operationLiee)
//    var operationLiee: EntityTransactions?
    
    private var _sectionIdentifier: String?

// Propriété calculée pour obtenir l'identifiant de section complet (année * 100 + mois).
    var sectionIdentifier: String? {
        let date = datePointage
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        if let year = components.year, let month = components.month {
            return String(format: "%ld", year * 100 + month)
        }
        return nil
    }
    
    /// Propriété calculée pour obtenir uniquement l'année de la date de pointage.
    var sectionYear: String? {
        let date = datePointage
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: date)
        if let year = components.year {
            return String(format: "%ld", year)
        }
        return nil
    }

    /// Initialize a new transaction with the current account
    /// - Throws: AccountError.currentAccountNotFound if no current account is set
    @MainActor
    public init() throws {
        self.createAt = Date().noon
        self.updatedAt = Date().noon

        guard let account = CurrentAccountManager.shared.getAccount() else {
            throw AccountError.currentAccountNotFound
        }
        self.account = account
    }

    /// Initialize a new transaction with a specific account (safe initializer)
    @MainActor
    public init(account: EntityAccount) {
        self.createAt = Date().noon
        self.updatedAt = Date().noon
        self.account = account
    }
}

extension EntityTransaction {
    @MainActor
    func addSubOperation(_ subOperation: EntitySousOperation) {
        guard !sousOperations.contains(where: { $0.id == subOperation.id }) else {
            return // Ne pas ajouter si elle existe déjà
        }
        subOperation.transaction = self
        sousOperations.append(subOperation)
        // updateAmount()
    }
    
    @MainActor
    func replaceSubOperations(with newOperations: [EntitySousOperation]) {
        sousOperations.removeAll()
        for op in newOperations {
            op.transaction = self
        }
        sousOperations.append(contentsOf: newOperations)
    }
    @MainActor
    func removeSubOperation(_ subOperation: EntitySousOperation) {
        guard let index = sousOperations.firstIndex(where: { $0.id == subOperation.id }) else {
            return
        }
        sousOperations.remove(at: index)
    }
}


extension EntityTransaction {
    var dateOperationString: String {
        return dateOperation.formatted()
    }
    var dateTransactionString: String {
        return dateOperation.formatted()
    }

    var datePointageString: String {
        return datePointage.formatted()
    }
    
    var bankStatementString: String {
        return String(format: "%.0f", bankStatement)
    }
    
    var statusString: String {
        return status.map { "\($0.name)" } ?? "N/A"
    }
    
    var paymentModeString: String {
        return paymentMode.map { "\($0.name)" } ?? "N/A"
    }
    
    var amountString: String {
        let price = formatPrice(amount)
        return price
    }
}

