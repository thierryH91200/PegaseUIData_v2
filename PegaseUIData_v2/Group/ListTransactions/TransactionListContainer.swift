//
//  TransactionListContainer.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 25/03/2025.
//  Refactored by Claude Code on 14/01/2026.
//

import SwiftUI
import SwiftData
import OSLog

/// Top-level container view for the transaction list feature
///
/// Features:
/// - Summary dashboard showing balances (Final, Actual, Bank)
/// - Transaction table with filtering and selection
/// - Keyboard shortcuts for copy/cut/paste
/// - Demo data loading (DEBUG only)
/// - Balance calculation based on transaction status
/// - Real-time updates via NotificationCenter
///
//            TransactionTableView(
//filteredTransactions: filteredTransactions,
//dashboard: $dashboard,
//isVisible: $dashboard.isVisible,
//selectedTransactions: $selectedTransactions
//)

struct TransactionListContainer: View {

    @State private var selectedTransactions: Set<UUID> = []

    @Binding var dashboard: DashboardState

    var filteredTransactions: [EntityTransaction]?

    private var transactions: [EntityTransaction] {
        filteredTransactions ?? ListTransactionsManager.shared.listTransactions
    }

    var body: some View {

        VStack(spacing: 0) {

            SummaryView(dashboard: $dashboard)

            #if DEBUG
            Button("Load demo data") {
                loadDemoData()
            }
            .textCase(.lowercase)
            .padding(.bottom)
            #endif

            Divider()

            TransactionTableViewModern(
                filteredTransactions: filteredTransactions,
                dashboard: $dashboard,
                selectedTransactions: $selectedTransactions
            )
            .padding()
            .task {
                await performInitialTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: .loadDemoRequested)) { _ in
                loadDemoData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetDatabaseRequested)) { _ in
                resetDatabase()
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsAddEdit)) { _ in
                handleTransactionUpdate(source: "transactionsAddEdit")
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsImported)) { _ in
                handleTransactionUpdate(source: "transactionsImported")
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsSelectionChanged)) { _ in
                updateSummary()
            }
            .onAppear {
                setupKeyboardShortcuts()
            }
            .onAppear(perform: updateSummary)
            .onChange(of: transactions) { _, _ in
                updateSummary()
            }
        }
    }

    // MARK: - Private Methods

    /// Consolidated handler for transaction updates to reduce duplicate code
    private func handleTransactionUpdate(source: String) {
        AppLogger.transactions.debug("\(source) notification received")
        _ = ListTransactionsManager.shared.getAllData()
        withAnimation {
            selectedTransactions.removeAll()
        }
        updateSummary()
    }

    private func updateSummary() {
        let initAccount = InitAccountManager.shared.getAllData()

        dashboard.executed = calculateExecuted() + (initAccount?.realise ?? 0.0)
        dashboard.engaged = dashboard.executed + calculateEngaged() + (initAccount?.engage ?? 0.0)
        dashboard.planned = dashboard.engaged + self.calculatePlanned() + (initAccount?.prevu ?? 0.0)
    }

    @MainActor
    func resetDatabase() {
        let transactions = ListTransactionsManager.shared.getAllData()

        AppLogger.data.warning("Resetting database - deleting \(transactions.count) transactions")

        for transaction in transactions {
            ListTransactionsManager.shared.delete(entity: transaction)
        }
        do {
            try ListTransactionsManager.shared.save()
        } catch {
            AppLogger.data.error("Reset database save failed: \(error.localizedDescription)")
        }
    }

    private func performInitialTask() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        dashboard.isVisible = true
    }

    @MainActor
    func loadDemoData() {
        let demoTransactions: [(String, Double, Int)] = [
            ("Achat supermarché", -45.60, 2),
            ("Salaire", 2000.00, 0),
            ("Facture électricité", -120.75, 1),
            ("Virement reçu", 350.00, 2),
            ("Abonnement streaming", -12.99, 1)
        ]

        AppLogger.data.info("Loading \(demoTransactions.count) demo transactions")
        // TODO: Implement demo data creation logic
    }

    // MARK: - Balance Calculations

    /// Calculates the total planned balance (transactions with status = planned)
    func calculatePlanned() -> Double {
        transactions
            .filter { $0.status?.type == .planned }
            .map(\.amount)
            .reduce(0, +)
    }

    /// Calculates the total engaged balance (transactions with status = inProgress)
    func calculateEngaged() -> Double {
        transactions
            .filter { $0.status?.type == .inProgress }
            .map(\.amount)
            .reduce(0, +)
    }

    /// Calculates the total executed balance (transactions with status = executed)
    func calculateExecuted() -> Double {
        transactions
            .filter { $0.status?.type == .executed }
            .map(\.amount)
            .reduce(0, +)
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  let characters = event.charactersIgnoringModifiers else {
                return event
            }

            switch characters {
            case "c":
                NotificationCenter.default.post(name: .copySelectedTransactions, object: nil)
                AppLogger.ui.debug("Copy shortcut triggered")
                return nil
            case "x":
                NotificationCenter.default.post(name: .cutSelectedTransactions, object: nil)
                AppLogger.ui.debug("Cut shortcut triggered")
                return nil
            case "v":
                NotificationCenter.default.post(name: .pasteSelectedTransactions, object: nil)
                AppLogger.ui.debug("Paste shortcut triggered")
                return nil
            case "a":
                NotificationCenter.default.post(name: .selectAllTransactions, object: nil)
                AppLogger.ui.debug("Select All shortcut triggered")
                return nil
            default:
                return event
            }
        }
    }
}
