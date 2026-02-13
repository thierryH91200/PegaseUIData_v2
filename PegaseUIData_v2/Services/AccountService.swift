//
//  AccountService.swift
//  PegaseUIData
//
//  Service layer for account operations
//  Provides clean API for account management and related entities
//

import Foundation
import SwiftData
import Combine
import OSLog

// MARK: - Account Service Protocol

/// Protocol defining account service operations
protocol AccountServiceProtocol: DataService where Entity == EntityAccount {

    /// Get the current active account
    var currentAccount: EntityAccount? { get }

    /// Set the current account by UUID string
    @discardableResult
    func setCurrentAccount(_ id: String) -> Bool

    /// Clear the current account
    func clearCurrentAccount()

    /// Create a new account with basic info
    func createAccount(name: String, icon: String, folder: EntityFolderAccount) -> EntityAccount

    /// Create a fully configured account with all related entities
    @MainActor
    func createFullAccount(
        nameAccount: String,
        nameImage: String,
        idName: String,
        idSurName: String,
        numAccount: String
    ) -> EntityAccount?

    /// Get all accounts
    func getAllAccounts() -> [EntityAccount]

    /// Get account by UUID
    func getAccount(uuid: UUID) -> EntityAccount?

    /// Delete an account
    func deleteAccount(_ account: EntityAccount) throws

    /// Get account balance
    @MainActor
    func getBalance(for account: EntityAccount) -> Double

    /// Get expense total for account in date range
    func getExpenseTotal(for account: EntityAccount, from startDate: Date, to endDate: Date) -> Double

    /// Get income total for account in date range
    func getIncomeTotal(for account: EntityAccount, from startDate: Date, to endDate: Date) -> Double
}

// MARK: - Account Service Implementation

/// Concrete implementation of AccountServiceProtocol
@MainActor
final class AccountService: AccountServiceProtocol, ObservableObject {

    // MARK: - Singleton
    static let shared = AccountService()

    // MARK: - Published Properties
    @Published private(set) var accounts: [EntityAccount] = []
    @Published private(set) var currentAccountID: String = ""

    // MARK: - DataService Protocol
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Current Account Management

    var currentAccount: EntityAccount? {
        guard let uuid = UUID(uuidString: currentAccountID) else {
            return nil
        }
        return getAccount(uuid: uuid)
    }

    @discardableResult
    func setCurrentAccount(_ id: String) -> Bool {
        guard let uuid = UUID(uuidString: id) else {
            AppLogger.account.warning("setCurrentAccount: Invalid UUID \(id)")
            return false
        }

        guard let account = getAccount(uuid: uuid) else {
            AppLogger.account.warning("setCurrentAccount: Account not found \(id)")
            return false
        }

        // Invalidate transaction cache when changing account
        ListTransactionsManager.shared.invalidateCache()

        currentAccountID = account.uuid.uuidString
        return true
    }

    func clearCurrentAccount() {
        currentAccountID = ""
    }

    // MARK: - Fetch Operations

    func fetchAll() -> [EntityAccount] {
        return getAllAccounts()
    }

    func fetch(byUUID uuid: UUID) -> EntityAccount? {
        return getAccount(uuid: uuid)
    }

    func getAllAccounts() -> [EntityAccount] {
        do {
            let request = FetchDescriptor<EntityAccount>()
            accounts = try modelContext?.fetch(request) ?? []
        } catch {
            AppLogger.account.error("Error fetching accounts: \(error.localizedDescription)")
        }
        return accounts
    }

    func getAccount(uuid: UUID) -> EntityAccount? {
        guard let ctx = modelContext else {
            AppLogger.account.error("getAccount: ModelContext unavailable")
            return nil
        }

        let predicate = #Predicate<EntityAccount> { $0.uuid == uuid }
        var descriptor = FetchDescriptor<EntityAccount>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try ctx.fetch(descriptor).first
        } catch {
            AppLogger.account.error("Error fetching account: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Create Operations

    func createAccount(name: String, icon: String, folder: EntityFolderAccount) -> EntityAccount {
        let account = EntityAccount()
        account.name = name
        account.nameIcon = icon
        account.uuid = UUID()
        account.folder = folder
        modelContext?.insert(account)
        do {
            try save()
        } catch {
            AppLogger.account.error("Account creation save failed: \(error.localizedDescription)")
        }
        return account
    }

    func createFullAccount(
        nameAccount: String,
        nameImage: String,
        idName: String,
        idSurName: String,
        numAccount: String
    ) -> EntityAccount? {

        let account = EntityAccount()
        account.name = nameAccount
        account.nameIcon = nameImage
        account.dateEcheancier = Date().noon
        account.uuid = UUID()

        // Create identity
        let identity = IdentityManager.shared.create(name: idName, surName: idSurName)
        identity.account = account
        account.identity = identity

        // Create init account
        do {
            let initAccount = try InitAccountManager.shared.create(numAccount: numAccount, for: account)
            initAccount.account = account
            account.initAccount = initAccount
        } catch {
            AppLogger.account.error("Failed to create InitAccount: \(error.localizedDescription)")
            return nil
        }

        modelContext?.insert(account)
        do {
            try save()
        } catch {
            AppLogger.account.error("Full account save failed: \(error.localizedDescription)")
        }
        return account
    }

    @MainActor
    func createOptionAccount(
        account: EntityAccount,
        idName: String,
        idSurName: String,
        numAccount: String
    ) -> EntityAccount {

        let id = account.uuid.uuidString
        setCurrentAccount(id)

        // Identity
        let identity = EntityIdentity(name: idName, surName: idSurName, account: account)
        account.identity = identity

        // Bank Info
        let banqueInfo = EntityBanqueInfo(account: account)
        account.bank = banqueInfo

        // Init Account
        let initAccount = EntityInitAccount(account: account)
        initAccount.codeAccount = numAccount
        initAccount.account = account
        account.initAccount = initAccount

        // Payment Mode
        PaymentModeManager.shared.createDefaultPaymentModes(for: account)
        account.paymentMode = PaymentModeManager.shared.modePayments

        // Status
        StatusManager.shared.defaultStatus(account: account)
        account.status = StatusManager.shared.resolveStatuses(for: account)

        // Rubric
        RubricManager.shared.defaultRubric(for: account)
        let rubric = RubricManager.shared.getAllData(account: account)
        account.rubric = rubric

        // Preference
        let entityPreference = PreferenceManager.shared.defaultPref(account: account)
        account.preference = entityPreference

        modelContext?.insert(account)
        do {
            try save()
        } catch {
            AppLogger.account.error("Full account creation save failed: \(error.localizedDescription)")
        }
        return account
    }

    // MARK: - Delete Operations

    func delete(_ entity: EntityAccount) throws {
        try deleteAccount(entity)
    }

    func deleteAccount(_ account: EntityAccount) throws {
        guard let context = modelContext else {
            throw ServiceError.contextUnavailable
        }

        context.undoManager = DataContext.shared.undoManager
        context.undoManager?.beginUndoGrouping()
        context.undoManager?.setActionName("Delete Account")
        context.delete(account)
        context.undoManager?.endUndoGrouping()
        try context.save()
    }

    // MARK: - Save Operations

    func save() throws {
        guard let context = modelContext else {
            throw ServiceError.contextUnavailable
        }
        try context.save()
    }

    // MARK: - Financial Calculations

    func getBalance(for account: EntityAccount) -> Double {
        guard account.isAccount else { return 0.0 }
        return account.transactions.reduce(0.0) { $0 + $1.amount }
    }

    func getExpenseTotal(for account: EntityAccount, from startDate: Date, to endDate: Date) -> Double {
        return account.transactions
            .filter { $0.dateOperation >= startDate && $0.dateOperation <= endDate && $0.amount < 0 }
            .reduce(0.0) { $0 + $1.amount }
    }

    func getIncomeTotal(for account: EntityAccount, from startDate: Date, to endDate: Date) -> Double {
        return account.transactions
            .filter { $0.dateOperation >= startDate && $0.dateOperation <= endDate && $0.amount >= 0 }
            .reduce(0.0) { $0 + $1.amount }
    }
}

// MARK: - Account Statistics

extension AccountService {

    /// Get account statistics for a date range
    func getStatistics(for account: EntityAccount, from startDate: Date, to endDate: Date) -> AccountStatistics {
        let transactions = account.transactions.filter {
            $0.dateOperation >= startDate && $0.dateOperation <= endDate
        }

        let expenses = transactions.filter { $0.amount < 0 }
        let incomes = transactions.filter { $0.amount >= 0 }

        return AccountStatistics(
            totalTransactions: transactions.count,
            totalExpenses: expenses.reduce(0) { $0 + $1.amount },
            totalIncome: incomes.reduce(0) { $0 + $1.amount },
            expenseCount: expenses.count,
            incomeCount: incomes.count,
            averageExpense: expenses.isEmpty ? 0 : expenses.reduce(0) { $0 + $1.amount } / Double(expenses.count),
            averageIncome: incomes.isEmpty ? 0 : incomes.reduce(0) { $0 + $1.amount } / Double(incomes.count)
        )
    }
}

/// Account statistics data
struct AccountStatistics {
    let totalTransactions: Int
    let totalExpenses: Double
    let totalIncome: Double
    let expenseCount: Int
    let incomeCount: Int
    let averageExpense: Double
    let averageIncome: Double

    var netAmount: Double {
        totalIncome + totalExpenses // expenses are negative
    }
}
