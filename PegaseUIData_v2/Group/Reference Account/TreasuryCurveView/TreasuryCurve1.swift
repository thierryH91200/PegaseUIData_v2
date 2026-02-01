//
//  Untitled 2.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts


struct TreasuryCurveView: View {
    
    @Binding var dashboard: DashboardState

    @State private var transactions: [EntityTransaction] = []
    @State private var allTransactions: [EntityTransaction] = []

    @State private var lowerValue: Double = 0
    @State private var upperValue: Double = 0
    @State private var minDate: Date = Date()
    @State private var maxDate: Date = Date()

    var body: some View {
        VStack(spacing: 0) {

            TreasuryCurve(dashboard: $dashboard,
                          allTransactions: $allTransactions)
                .task {
                    await performFalseTask()
                }
        }
        .onAppear {
            dashboard.isVisible = true
            transactions = ListTransactionsManager.shared.getAllData().sorted(by: { $0.datePointage < $1.datePointage })

            // init des valeurs
            if let first = transactions.first?.datePointage, let last = transactions.last?.datePointage {
                let days = last.timeIntervalSince(first) / 86400
                lowerValue = 0
                upperValue = days
            }
        }
        .onDisappear {
            // Invalider le cache pour forcer un rechargement quand on retourne à une autre vue
            ListTransactionsManager.shared.invalidateCache()
            // Forcer le rechargement complet des transactions
            _ = ListTransactionsManager.shared.loadAllTransactions(forceReload: true)
            // Notifier les autres vues qu'elles doivent rafraîchir leurs données
            NotificationCenter.default.post(name: .transactionsNeedRefresh, object: nil)
        }

    }
    
    private func performFalseTask() async {
        // Exécuter une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        dashboard.isVisible = false
    }
}
