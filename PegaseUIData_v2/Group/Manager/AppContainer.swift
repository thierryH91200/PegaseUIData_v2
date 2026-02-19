//
//  AppContainer.swift
//  PegaseUIData
//
//  Centralized dependency container for all managers
//  Enables dependency injection via @EnvironmentObject while maintaining
//  backward compatibility with .shared singletons
//
//  Usage:
//  1. In App: .environmentObject(AppContainer.shared)
//  2. In Views: @EnvironmentObject var container: AppContainer
//  3. Access: container.transactions, container.categories, etc.
//

import SwiftUI
import SwiftData
import Combine

/// Centralized container for all application services/managers
/// Provides dependency injection capabilities while maintaining backward compatibility
@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility with existing .shared calls
    /// New code should prefer @EnvironmentObject injection
    static let shared = AppContainer()

    // MARK: - Core Managers

    /// Current account manager - tracks the active account
    @Published private(set) var currentAccount: CurrentAccountManager

    /// Account manager - handles account CRUD operations
    @Published private(set) var accounts: AccountManager

    /// Transaction list manager - handles transaction CRUD operations
    @Published private(set) var transactions: ListTransactionsManager

    /// Transaction selection manager - tracks selected transactions in UI
    @Published private(set) var transactionSelection: TransactionSelectionManager

    // MARK: - Reference Data Managers

    /// Category manager - handles expense/income categories
    @Published private(set) var categories: CategoryManager

    /// Rubric manager - handles category groupings
    @Published private(set) var rubrics: RubricManager

    /// Payment mode manager - handles payment methods
    @Published private(set) var paymentModes: PaymentModeManager

    /// Status manager - handles transaction statuses
    @Published private(set) var statuses: StatusManager

    // MARK: - Entity Managers

    /// Bank manager - handles bank information
    @Published private(set) var banks: BankManager

    /// Identity manager - handles account holder information
    @Published private(set) var identities: IdentityManager

    /// Init account manager - handles initial account balances
    @Published private(set) var initAccounts: InitAccountManager

    /// Scheduler manager - handles recurring transactions
    @Published private(set) var schedulers: SchedulerManager

    /// Preference manager - handles user preferences
    @Published private(set) var preferences: PreferenceManager

    /// Account folder manager - handles account groupings
    @Published private(set) var accountFolders: AccountFolderManager

    /// Bank statement manager - handles bank statements
    @Published private(set) var bankStatements: BankStatementManager

    /// Sub-transaction manager - handles sub-operations
    @Published private(set) var subTransactions: SubTransactionsManager

    /// Cheque book manager - handles check registers
    @Published private(set) var chequeBooks: ChequeBookManager

    // MARK: - UI Managers

    /// Color manager - handles app color schemes
    @Published private(set) var colors: ColorManager

    /// Toast manager - handles toast notifications
    @Published private(set) var toasts: ToastManager

    // MARK: - Initialization

    private init() {
        // Initialize with existing singletons for backward compatibility
        self.currentAccount = CurrentAccountManager.shared
        self.accounts = AccountManager.shared
        self.transactions = ListTransactionsManager.shared
        self.transactionSelection = TransactionSelectionManager()
        self.categories = CategoryManager.shared
        self.rubrics = RubricManager.shared
        self.paymentModes = PaymentModeManager.shared
        self.statuses = StatusManager.shared
        self.banks = BankManager.shared
        self.identities = IdentityManager.shared
        self.initAccounts = InitAccountManager.shared
        self.schedulers = SchedulerManager.shared
        self.preferences = PreferenceManager.shared
        self.accountFolders = AccountFolderManager.shared
        self.bankStatements = BankStatementManager.shared
        self.subTransactions = SubTransactionsManager.shared
        self.chequeBooks = ChequeBookManager.shared
        self.colors = ColorManager()
        self.toasts = ToastManager.shared
    }

    /// Initialize with custom managers (for testing)
    /// All parameters have defaults pointing to .shared singletons
    init(
        currentAccount: CurrentAccountManager? = nil,
        accounts: AccountManager? = nil,
        transactions: ListTransactionsManager? = nil,
        categories: CategoryManager? = nil,
        rubrics: RubricManager? = nil,
        paymentModes: PaymentModeManager? = nil,
        statuses: StatusManager? = nil,
        banks: BankManager? = nil,
        identities: IdentityManager? = nil,
        initAccounts: InitAccountManager? = nil,
        schedulers: SchedulerManager? = nil,
        preferences: PreferenceManager? = nil,
        accountFolders: AccountFolderManager? = nil,
        bankStatements: BankStatementManager? = nil,
        subTransactions: SubTransactionsManager? = nil,
        chequeBooks: ChequeBookManager? = nil
    ) {
        self.currentAccount = currentAccount ?? CurrentAccountManager.shared
        self.accounts = accounts ?? AccountManager.shared
        self.transactions = transactions ?? ListTransactionsManager.shared
        self.transactionSelection = TransactionSelectionManager()
        self.categories = categories ?? CategoryManager.shared
        self.rubrics = rubrics ?? RubricManager.shared
        self.paymentModes = paymentModes ?? PaymentModeManager.shared
        self.statuses = statuses ?? StatusManager.shared
        self.banks = banks ?? BankManager.shared
        self.identities = identities ?? IdentityManager.shared
        self.initAccounts = initAccounts ?? InitAccountManager.shared
        self.schedulers = schedulers ?? SchedulerManager.shared
        self.preferences = preferences ?? PreferenceManager.shared
        self.accountFolders = accountFolders ?? AccountFolderManager.shared
        self.bankStatements = bankStatements ?? BankStatementManager.shared
        self.subTransactions = subTransactions ?? SubTransactionsManager.shared
        self.chequeBooks = chequeBooks ?? ChequeBookManager.shared
        self.colors = ColorManager()
        self.toasts = ToastManager.shared
    }
}

// MARK: - Environment Key

private struct AppContainerKey: EnvironmentKey {
    @MainActor static let defaultValue: AppContainer = AppContainer.shared
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Inject the AppContainer.shared into the environment
    @MainActor
    func withAppContainer() -> some View {
        self.environmentObject(AppContainer.shared)
    }

    /// Inject a specific AppContainer into the environment
    @MainActor
    func withAppContainer(_ container: AppContainer) -> some View {
        self.environmentObject(container)
    }
}

