////
////  RecetteDepenseBar2.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
import SwiftUI
import SwiftData
import DGCharts
import Combine


struct RecetteDepenseBarView: View {
    
    @EnvironmentObject private var currentAccountManager : CurrentAccountManager

    @Binding var isVisible: Bool
    @Binding var dashboard: DashboardState
    @State private var transactions: [EntityTransaction] = []
    @State private var minDate: Date = Date()
    @State private var maxDate: Date = Date()
    
    @State private var refresh = false

    var body: some View {
        RecetteDepenseView(
            transactions: transactions,
            dashboard: $dashboard,
            minDate: $minDate,
            maxDate: $maxDate
        )
        .id(refresh)
        .task {
            await performFalseTask()
        }
        .onAppear {
            Task {
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
    
    private func performFalseTask() async {
        // Exécute une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        isVisible = false
    }
    private func loadTransactions() async {
        transactions = ListTransactionsManager.shared.getAllData()
        minDate = transactions.first?.dateOperation ?? Date()
        maxDate = transactions.last?.dateOperation ?? Date()
    }
}

