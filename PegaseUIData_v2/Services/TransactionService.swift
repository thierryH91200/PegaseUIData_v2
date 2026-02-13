//
//  TransactionService.swift
//  PegaseUIData
//
//  Service layer for transaction operations
//  Provides clean API for transaction CRUD and business logic
//

import Foundation
import SwiftData
import Combine

// MARK: - Transaction Service Protocol

/// Protocol defining transaction service operations
protocol TransactionServiceProtocol: DataService, DateRangeFilterable, CacheableService, UndoableService where Entity == EntityTransaction {

    /// Create a new transaction for the current account
    func createTransaction(formState: TransactionFormState) -> EntityTransaction?

    /// Get all transactions for the current account
    func getAllTransactions(ascending: Bool) -> [EntityTransaction]

    /// Get transactions within a date range
    func getTransactions(from startDate: Date, to endDate: Date, ascending: Bool) -> [EntityTransaction]

    /// Add a sub-transaction to an existing transaction
    func addSubTransaction(to transaction: EntityTransaction, subTransaction: EntitySousOperation) -> EntityTransaction

    /// Get all unique comments for an account
    func getAllComments(for account: EntityAccount) throws -> [String]

    /// Find transaction by UUID
    func findTransaction(uuid: UUID) -> EntityTransaction?
}

// MARK: - Transaction Service Implementation

/// Concrete implementation of TransactionServiceProtocol
/// Wraps ListTransactionsManager to provide clean service interface
@MainActor
final class TransactionService: TransactionServiceProtocol, ObservableObject {

    // MARK: - Singleton (for backward compatibility)
    static let shared = TransactionService()

    // MARK: - Published Properties
    @Published private(set) var transactions: [EntityTransaction] = []

    // MARK: - Private Properties
    private var lastAccountID: UUID?
    private var lastAscending: Bool?
    private var ascending: Bool = false

    // MARK: - DataService Protocol
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Fetch Operations

    func fetchAll() -> [EntityTransaction] {
        return getAllTransactions(ascending: true)
    }

    func fetch(byUUID uuid: UUID) -> EntityTransaction? {
        return findTransaction(uuid: uuid)
    }

    func fetch(from startDate: Date, to endDate: Date) -> [EntityTransaction] {
        return getTransactions(from: startDate, to: endDate, ascending: true)
    }

    // MARK: - Transaction Operations

    func getAllTransactions(ascending: Bool = true) -> [EntityTransaction] {
        guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
            return []
        }

        let currentAccountID = currentAccount.uuid

        // Check cache
        if lastAccountID == currentAccountID,
           lastAscending == ascending,
           !transactions.isEmpty {
            return transactions
        }

        self.ascending = ascending

        let predicate = #Predicate<EntityTransaction> { $0.account.uuid == currentAccountID }
        let sort = [
            SortDescriptor(\EntityTransaction.datePointage, order: ascending ? .forward : .reverse),
            SortDescriptor(\EntityTransaction.dateOperation, order: ascending ? .forward : .reverse)
        ]

        let fetchDescriptor = FetchDescriptor<EntityTransaction>(
            predicate: predicate,
            sortBy: sort
        )

        do {
            let fetchedTransactions = try modelContext?.fetch(fetchDescriptor) ?? []

            // Update cache
            lastAccountID = currentAccountID
            lastAscending = ascending

            if fetchedTransactions.map({ $0.uuid }) != transactions.map({ $0.uuid }) {
                transactions = fetchedTransactions
            }

            // Adjust dates if demo account
            if currentAccount.isDemo {
                adjustDatesForDemo(account: currentAccount)
            }

            return transactions
        } catch {
            printTag("Error fetching transactions: \(error)", flag: true)
            return []
        }
    }

    func getTransactions(from startDate: Date, to endDate: Date, ascending: Bool = true) -> [EntityTransaction] {
        let all = getAllTransactions(ascending: ascending)
        return all.filter { $0.datePointage >= startDate && $0.datePointage <= endDate }
    }

    @discardableResult
    func createTransaction(formState: TransactionFormState) -> EntityTransaction? {
        guard let context = modelContext else {
            printTag("Error: modelContext not available")
            return nil
        }

        guard let account = CurrentAccountManager.shared.getAccount() else {
            printTag("Error: no current account")
            return nil
        }

        let transaction = EntityTransaction(account: account)
        transaction.uuid = UUID()

        formState.currentTransaction = transaction
        context.insert(transaction)

        invalidateCache()
        return transaction
    }

    func addSubTransaction(to transaction: EntityTransaction, subTransaction: EntitySousOperation) -> EntityTransaction {
        modelContext?.insert(transaction)
        subTransaction.transaction = transaction
        modelContext?.insert(subTransaction)
        transaction.addSubOperation(subTransaction)

        invalidateCache()
        return transaction
    }

    func findTransaction(uuid: UUID) -> EntityTransaction? {
        let predicate = #Predicate<EntityTransaction> { $0.uuid == uuid }
        let fetchDescriptor = FetchDescriptor<EntityTransaction>(predicate: predicate)

        do {
            let results = try modelContext?.fetch(fetchDescriptor) ?? []
            return results.first
        } catch {
            printTag("Error finding transaction: \(error)", flag: true)
            return nil
        }
    }

    func getAllComments(for account: EntityAccount) throws -> [String] {
        var comments = [String]()

        let lhs = account.uuid
        let predicate = #Predicate<EntityTransaction> { $0.account.uuid == lhs }
        let sort = [SortDescriptor(\EntityTransaction.dateOperation, order: .reverse)]

        let descriptor = FetchDescriptor<EntityTransaction>(
            predicate: predicate,
            sortBy: sort
        )

        let entityTransactions = try modelContext?.fetch(descriptor) ?? []

        for transaction in entityTransactions {
            let splitComments = transaction.sousOperations.compactMap { $0.libelle }
            comments.append(contentsOf: splitComments)
        }

        return comments.uniqueElements
    }

    // MARK: - Delete Operations

    func delete(_ entity: EntityTransaction) throws {
        guard let context = modelContext else {
            throw ServiceError.contextUnavailable
        }

        invalidateCache()

        context.undoManager = DataContext.shared.undoManager
        context.undoManager?.beginUndoGrouping()
        context.undoManager?.setActionName(String(localized: "Delete Transaction"))
        context.delete(entity)
        context.undoManager?.endUndoGrouping()
    }

    // MARK: - Save Operations

    func save() throws {
        invalidateCache()
        guard let context = modelContext else {
            throw ServiceError.contextUnavailable
        }
        try context.save()
    }

    // MARK: - CacheableService Protocol

    func invalidateCache() {
        lastAccountID = nil
        lastAscending = nil
    }

    var isCacheValid: Bool {
        guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
            return false
        }
        return lastAccountID == currentAccount.uuid && lastAscending == ascending && !transactions.isEmpty
    }

    // MARK: - UndoableService Protocol

    func undo() {
        guard let context = modelContext else { return }
        guard let undoManager = context.undoManager else { return }

        if undoManager.canUndo {
            undoManager.undo()
            invalidateCache()
            _ = getAllTransactions(ascending: ascending)
        }
    }

    func redo() {
        guard let context = modelContext else { return }
        guard let undoManager = context.undoManager else { return }

        if undoManager.canRedo {
            undoManager.redo()
            invalidateCache()
            _ = getAllTransactions(ascending: ascending)
        }
    }

    // MARK: - Private Helpers

    private func adjustDatesForDemo(account: EntityAccount) {
        guard !transactions.isEmpty else { return }

        let diffDate = transactions.first!.datePointage.timeIntervalSinceNow
        for entity in transactions {
            entity.datePointage = (entity.datePointage - diffDate).noon
            entity.dateOperation = (entity.dateOperation - diffDate).noon
        }
        account.isDemo = false
    }
}

// MARK: - Transaction Query Builder

/// Fluent API for building transaction queries
///
@MainActor
struct TransactionQuery {
    private var predicate: Predicate<EntityTransaction>?
    private var sortDescriptors: [SortDescriptor<EntityTransaction>] = []
    private var fetchLimit: Int?
    private var dateRange: (start: Date, end: Date)?
    private let service: TransactionService

    init(service: TransactionService ) {
        self.service = service
    }

    func forAccount(_ account: EntityAccount) -> TransactionQuery {
        var query = self
        let uuid = account.uuid
        query.predicate = #Predicate<EntityTransaction> { $0.account.uuid == uuid }
        return query
    }

    func dateRange(from start: Date, to end: Date) -> TransactionQuery {
        var query = self
        query.dateRange = (start, end)
        return query
    }

    func sorted(by keyPath: KeyPath<EntityTransaction, Date>, ascending: Bool = true) -> TransactionQuery {
        var query = self
        query.sortDescriptors.append(SortDescriptor(keyPath, order: ascending ? .forward : .reverse))
        return query
    }

    func limit(_ count: Int) -> TransactionQuery {
        var query = self
        query.fetchLimit = count
        return query
    }

    func execute() -> [EntityTransaction] {
        var results = service.getAllTransactions(ascending: true)

        if let range = dateRange {
            results = results.filter { $0.datePointage >= range.start && $0.datePointage <= range.end }
        }

        if let limit = fetchLimit {
            results = Array(results.prefix(limit))
        }

        return results
    }
}

// MARK: - Convenience Extensions

extension TransactionService {
    /// Get transactions for a specific date
    func getTransactions(for date: Date) -> [EntityTransaction] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return getTransactions(from: startOfDay, to: endOfDay)
    }

    /// Get transactions for the current month
    func getTransactionsForCurrentMonth() -> [EntityTransaction] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        return getTransactions(from: startOfMonth, to: endOfMonth)
    }

    /// Get total amount for a date range
    func getTotalAmount(from startDate: Date, to endDate: Date) -> Double {
        return getTransactions(from: startDate, to: endDate).reduce(0) { $0 + $1.amount }
    }

    /// Get expense total (negative amounts)
    func getExpenseTotal(from startDate: Date, to endDate: Date) -> Double {
        return getTransactions(from: startDate, to: endDate)
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + $1.amount }
    }

    /// Get income total (positive amounts)
    func getIncomeTotal(from startDate: Date, to endDate: Date) -> Double {
        return getTransactions(from: startDate, to: endDate)
            .filter { $0.amount >= 0 }
            .reduce(0) { $0 + $1.amount }
    }
}
