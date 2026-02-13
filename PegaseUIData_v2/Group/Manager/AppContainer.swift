////
////  AppContainer.swift
////  PegaseUIData
////
////  Centralized dependency container for all managers
////  Enables dependency injection via @EnvironmentObject while maintaining
////  backward compatibility with .shared singletons
////
////  Usage:
////  1. In App: .environmentObject(AppContainer.shared)
////  2. In Views: @EnvironmentObject var container: AppContainer
////  3. Access: container.transactions, container.categories, etc.
////
//
//import SwiftUI
//import SwiftData
//import Combine
//
///// Centralized container for all application services/managers
///// Provides dependency injection capabilities while maintaining backward compatibility
//@MainActor
//final class AppContainer: ObservableObject {
//
//    // MARK: - Singleton (for backward compatibility)
//
//    /// Shared instance for backward compatibility with existing .shared calls
//    /// New code should prefer @EnvironmentObject injection
//    static let shared = AppContainer()
//
//    // MARK: - Core Managers
//
//    /// Current account manager - tracks the active account
//    @Published private(set) var currentAccount: CurrentAccountManager
//
//    /// Transaction list manager - handles transaction CRUD operations
//    @Published private(set) var transactions: ListTransactionsManager
//
//    /// Transaction selection manager - tracks selected transactions in UI
//    @Published private(set) var transactionSelection: TransactionSelectionManager
//
//    // MARK: - Reference Data Managers
//
//    /// Category manager - handles expense/income categories
//    @Published private(set) var categories: CategoryManager
//
//    /// Rubric manager - handles category groupings
//    @Published private(set) var rubrics: RubricManager
//
//    /// Payment mode manager - handles payment methods
//    @Published private(set) var paymentModes: PaymentModeManager
//
//    /// Status manager - handles transaction statuses
//    @Published private(set) var statuses: StatusManager
//
//    // MARK: - Entity Managers
//
//    /// Bank manager - handles bank information
//    @Published private(set) var banks: BankManager
//
//    /// Identity manager - handles account holder information
//    @Published private(set) var identities: IdentityManager
//
//    /// Scheduler manager - handles recurring transactions
//    @Published private(set) var schedulers: SchedulerManager
//
//    /// Preference manager - handles user preferences
//    @Published private(set) var preferences: PreferenceManager
//
//    // MARK: - UI Managers
//
//    /// Color manager - handles app color schemes
//    @Published private(set) var colors: ColorManager
//
//    /// Toast manager - handles toast notifications
//    @Published private(set) var toasts: ToastManager
//
//    // MARK: - Initialization
//
//    private init() {
//        // Initialize with existing singletons for backward compatibility
//        self.currentAccount = CurrentAccountManager.shared
//        self.transactions = ListTransactionsManager.shared
//        self.transactionSelection = TransactionSelectionManager()
//        self.categories = CategoryManager.shared
//        self.rubrics = RubricManager.shared
//        self.paymentModes = PaymentModeManager.shared
//        self.statuses = StatusManager.shared
//        self.banks = BankManager.shared
//        self.identities = IdentityManager.shared
//        self.schedulers = SchedulerManager.shared
//        self.preferences = PreferenceManager.shared
//        self.colors = ColorManager()
//        self.toasts = ToastManager.shared
//    }
//
//    /// Initialize with custom managers (for testing)
//    init(
//        currentAccount: CurrentAccountManager,
//        transactions: ListTransactionsManager,
//        categories: CategoryManager,
//        rubrics: RubricManager,
//        paymentModes: PaymentModeManager,
//        statuses: StatusManager
//    ) {
//        self.currentAccount = currentAccount
//        self.transactions = transactions
//        self.transactionSelection = TransactionSelectionManager()
//        self.categories = categories
//        self.rubrics = rubrics
//        self.paymentModes = paymentModes
//        self.statuses = statuses
//        self.banks = BankManager.shared
//        self.identities = IdentityManager.shared
//        self.schedulers = SchedulerManager.shared
//        self.preferences = PreferenceManager.shared
//        self.colors = ColorManager()
//        self.toasts = ToastManager.shared
//    }
//
//    // MARK: - Context Configuration
//
//    /// Configure all managers with a ModelContext
//    /// Call this after the ModelContainer is available
//    func configure(with context: ModelContext) {
//        transactions.modelContext = context
//        categories.modelContext = context
//        rubrics.modelContext = context
//        paymentModes.modelContext = context
//        statuses.modelContext = context
//        banks.modelContext = context
//        identities.modelContext = context
//        schedulers.modelContext = context
//        preferences.modelContext = context
//    }
//}
//
//// MARK: - Environment Key
//
//private struct AppContainerKey: EnvironmentKey {
//    static let defaultValue: AppContainer = AppContainer.shared
//}
//
//extension EnvironmentValues {
//    var appContainer: AppContainer {
//        get { self[AppContainerKey.self] }
//        set { self[AppContainerKey.self] = newValue }
//    }
//}
//
//// MARK: - View Extension for Easy Access
//
//extension View {
//    /// Inject the AppContainer into the environment
//    func withAppContainer(_ container: AppContainer = .shared) -> some View {
//        self.environmentObject(container)
//    }
//}
