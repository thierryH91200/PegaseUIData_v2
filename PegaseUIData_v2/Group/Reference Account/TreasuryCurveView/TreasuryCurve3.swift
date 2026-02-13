//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine



@MainActor
protocol TeeasuryManaging {
    func refresh(for account: EntityAccount?, minDate: Date)
    func updateChartData()
}

class TresuryLineViewModel: ObservableObject, TeeasuryManaging {
    
    @Published var listTransactions: [EntityTransaction] = []
    // Transactions of the currently selected day in the chart (for detail UI)
    @Published var selectedDayTransactions: [EntityTransaction] = []
    @Published var dataGraph: [DataTresorerie] = []
    @Published var dataEntries: [ChartDataEntry] = []

    @Published var firstDate: TimeInterval = 0.0
    @Published var lastDate: TimeInterval = 0.0

    @Published var selectedStart: Double = 0
    @Published var selectedEnd: Double = 30
    
    @Published var lowerValue: Double = 0
    @Published var upperValue: Double = 0
    @Published var isDaySelectionActive: Bool = false
    
    @Published var selectedDay: Date? = nil

    let hourSeconds = 3600.0 * 24.0 // one day
    
    static let shared = TresuryLineViewModel()

    
//    func updateAccount(minDate: Date) {
    
    @MainActor func refresh(for account: EntityAccount?, minDate: Date)  {
        guard account != nil else {
            self.listTransactions = []
            self.dataGraph = []
            return
        }
        
        let allTransactions = ListTransactionsManager.shared.getAllData()

        self.listTransactions = allTransactions
        self.updateChartData()
    }
    
    @MainActor func updateChartData() {
        // Do not recompute the series while a day selection is active
        if isDaySelectionActive { return }
        var dataGraph: [DataTresorerie] = []

        guard !listTransactions.isEmpty else {
            DispatchQueue.main.async { self.dataGraph = dataGraph }
            return }

        let calendar = Calendar.current

        // Trier les transactions par datePointage pour un calcul cumulatif correct
        let sortedTransactions = listTransactions.sorted { $0.datePointage < $1.datePointage }

        // Trouver la première date
        guard let firstTransaction = sortedTransactions.first else { return }
        let baseDate = calendar.startOfDay(for: firstTransaction.datePointage)

        // Grouper par jour
        let grouped = Dictionary(grouping: sortedTransactions, by: { calendar.startOfDay(for: $0.datePointage) })

        let startOffset = Int(lowerValue)
        let endOffset = Int(upperValue)

        let initAccount = InitAccountManager.shared.getAllData()
        var soldeRealise = initAccount?.realise ?? 0
        var soldePrevu = initAccount?.prevu ?? 0
        var soldeEngage = initAccount?.engage ?? 0

        for offset in startOffset...endOffset {
            // Utiliser Calendar pour ajouter des jours (cohérent avec startOfDay)
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: baseDate) else { continue }
            let dayTransactions = grouped[dayDate] ?? []

            for tx in dayTransactions {
                switch tx.status?.type {
                case .planned: soldePrevu += tx.amount
                case .inProgress: soldeEngage += tx.amount
                case .executed: soldeRealise += tx.amount
                case .none: break
                }
            }

            // soldeEngage inclut soldeRealise + les "en cours"
            // soldePrevu inclut soldeEngage + les "prévu"
            let engageTotal = soldeRealise + soldeEngage
            let prevuTotal = engageTotal + soldePrevu

            dataGraph.append(DataTresorerie(
                x: Double(offset),
                soldeRealise: soldeRealise,
                soldeEngage: engageTotal,
                soldePrevu: prevuTotal
            ))
        }
        DispatchQueue.main.async {
            self.dataGraph = dataGraph
        }
    }
}

