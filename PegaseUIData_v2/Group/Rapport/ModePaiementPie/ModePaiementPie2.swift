////
////  ModePaiementPie1.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
//
import SwiftUI
import SwiftData
import DGCharts
import Combine

class ModePaymentPieViewModel: ObservableObject {
    @Published var recetteArray: [DataGraph] = []
    @Published var depenseArray: [DataGraph] = []

    @Published var dataEntriesDepense: [PieChartDataEntry] = []
    @Published var dataEntriesRecette: [PieChartDataEntry] = []
    
    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    
    var listTransactions: [EntityTransaction] = []

    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()

    func updateChartData( startDate: Date, endDate: Date) {
        
        listTransactions = ListTransactionsManager.shared.getAllData(from:startDate, to:endDate)

        var dataArrayExpense = [DataGraph]()
        var dataArrayIncome = [DataGraph]()

        for listTransaction in listTransactions {

            let amount = listTransaction.amount
            let name = listTransaction.paymentMode?.name ?? "Inconnu"
            let color = listTransaction.paymentMode?.color ?? .gray

            if amount < 0 {
                let data = DataGraph(name: name, value: abs(amount), color: color)
                dataArrayExpense.append(data)
            } else {
                let data = DataGraph(name: name, value: amount, color: color)
                dataArrayIncome.append(data)
            }
        }

        self.depenseArray = summarizeData(from: dataArrayExpense, maxCategories: 6)
        self.recetteArray = summarizeData(from: dataArrayIncome, maxCategories: 6)
        
        self.dataEntriesDepense = pieChartEntries(from: depenseArray)
        self.dataEntriesRecette = pieChartEntries(from: recetteArray)
    }
    
    private func summarizeData(from array: [DataGraph], maxCategories: Int = 6) -> [DataGraph] {
        let grouped = Dictionary(grouping: array, by: { $0.name })
        
        let summarized = grouped.map { (key, values) in
            let total = values.map { $0.value }.reduce(0, +)
            return DataGraph(name: key, value: total, color: values.first?.color ?? .gray)
        }

        // Trier du plus grand au plus petit
        let sorted = summarized.sorted { abs($0.value) > abs($1.value) }

        if sorted.count <= maxCategories {
            return sorted
        }

        let main = sorted.prefix(maxCategories)
        let other = sorted.dropFirst(maxCategories)

        let totalOthers = other.map { $0.value }.reduce(0, +)
        let othersData = DataGraph(name: "Autres", value: totalOthers, color: .gray)

        return Array(main) + [othersData]
    }
    
    private func pieChartEntries(from array: [DataGraph]) -> [PieChartDataEntry] {
        array.map {
            PieChartDataEntry(value: abs($0.value), label: $0.name, data: $0)
        }
    }
}
