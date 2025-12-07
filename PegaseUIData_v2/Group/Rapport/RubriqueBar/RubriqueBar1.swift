//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine


struct RubriqueBarView: View {
    
    @EnvironmentObject private var currentAccountManager : CurrentAccountManager

    @Binding var isVisible: Bool
    @State private var transactions: [EntityTransaction] = []
    @State private var minDate: Date = Date()
    @State private var maxDate: Date = Date()
    
    @State private var refresh = false
    
    var body: some View {
        RubriqueBar(
            transactions: transactions,
            minDate: $minDate,
            maxDate: $maxDate
        )
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
    
    private func performFalseTask() async {
        // Exécuter une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        isVisible = false
    }
    
    @MainActor
    private func loadTransactions() async {
        transactions = ListTransactionsManager.shared.getAllData()
        minDate = transactions.first?.dateOperation ?? Date()
        maxDate = transactions.last?.dateOperation ?? Date()
    }
}
