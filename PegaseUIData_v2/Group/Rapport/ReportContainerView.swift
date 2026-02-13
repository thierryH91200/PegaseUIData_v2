//
//  ReportContainerView.swift
//  PegaseUIData
//
//  Generic container view for all report types (charts, pies, bars)
//  Eliminates code duplication across CatBar1, CategorieBar21, RubriquePie1, etc.
//

import SwiftUI

/// Generic container view for reports that handles common logic:
/// - Loading transactions
/// - Managing date range (minDate, maxDate)
/// - Watching for account changes
/// - Dashboard state management
///
/// Usage:
/// ```swift
/// ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
///     CategorieBar1View1(transactions: transactions, minDate: minDate, maxDate: maxDate, dashboard: dashboard)
/// }
/// ```
struct ReportContainerView<Content: View>: View {

    @EnvironmentObject private var currentAccountManager: CurrentAccountManager
    @Binding var dashboard: DashboardState

    @State private var transactions: [EntityTransaction] = []
    @State private var minDate: Date = Date()
    @State private var maxDate: Date = Date()
    @State private var refresh = false

    /// Convenience initializer with trailing closure syntax
    init(
        dashboard: Binding<DashboardState>,
        @ViewBuilder content: @escaping (_ transactions: [EntityTransaction], _ minDate: Binding<Date>, _ maxDate: Binding<Date>, _ dashboard: Binding<DashboardState>) -> Content
    ) {
        self._dashboard = dashboard
        self.content = content
    }

    /// Builder closure that creates the specific report view
    let content: (_ transactions: [EntityTransaction], _ minDate: Binding<Date>, _ maxDate: Binding<Date>, _ dashboard: Binding<DashboardState>) -> Content

    var body: some View {
        content(transactions, $minDate, $maxDate, $dashboard)
            .id(refresh)
            .task {
                await performFalseTask()
            }
            .onAppear {
                Task { @MainActor in
                    await loadTransactions()
                }
            }
            .onChange(of: currentAccountManager.currentAccountID) { old, new in
                printTag("Chgt de compte détecté: \(String(describing: new))")
                Task { @MainActor in
                    await loadTransactions()
                    withAnimation {
                        refresh.toggle()
                    }
                }
            }
    }

    // MARK: - Private Methods

    private func performFalseTask() async {
        try? await Task.sleep(nanoseconds: UIConstants.standardDelay)
        dashboard.isVisible = true
    }

    @MainActor
    private func loadTransactions() async {
        transactions = ListTransactionsManager.shared.getAllData()
        minDate = transactions.first?.datePointage ?? Date()
        maxDate = transactions.last?.datePointage ?? Date()
    }
}

