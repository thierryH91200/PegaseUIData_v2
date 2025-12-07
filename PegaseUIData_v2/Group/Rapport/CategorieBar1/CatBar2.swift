////
////  CatBar3.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 16/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine
import UniformTypeIdentifiers

class CategorieBar1ViewModel: ObservableObject {
    
    @Published var listTransactions : [EntityTransaction] = []
    @Published var isBarSelectionActive: Bool = false
    @Published var isMonthSelectionActive: Bool = false
    
    @Published var resultArray: [DataGraph] = []
    @Published var dataEntries: [BarChartDataEntry] = []
    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    
    @Published var selectedCategories: Set<String> = []
    
    @Published var firstDate: TimeInterval = 0.0
    @Published var lastDate: TimeInterval = 0.0
    
    @Published var selectedStart: Double = 0
    @Published var selectedEnd: Double = 30
    private var fullFilteredCache: [EntityTransaction] = []
    
    var chartView : BarChartView?

    static let shared = CategorieBar1ViewModel()
    
    var totalValue: Double {
        resultArray.map { $0.value }.reduce(0, +)
    }

    var labels: [String] {
        resultArray.map { $0.name }
    }

    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()
    
    func configure(with chartView: BarChartView)
    {
        self.chartView = chartView
    }

    func updateAccount(minDate: Date) {
        let transactions = ListTransactionsManager.shared.getAllData()

        DispatchQueue.main.async {
            self.listTransactions = transactions
            if let first = transactions.first?.dateOperation.timeIntervalSince1970,
               let last = transactions.last?.dateOperation.timeIntervalSince1970 {
                self.firstDate = first
                self.lastDate = last
            }
        }
    }

    func updateChartData( startDate: Date, endDate: Date) {
        // Configure the transaction manager with context if needed

        // Fetch transactions in the requested range
        self.listTransactions = ListTransactionsManager.shared.getAllData(from: startDate, to: endDate)

        guard !listTransactions.isEmpty else {
            self.resultArray = []
            self.dataEntries = []
            return
        }

        // Build flat data from sousOperations
        var dataArray: [DataGraph] = []
        for transaction in listTransactions {
            let sousOperations = transaction.sousOperations
            for sousOperation in sousOperations {
                if let rubric = sousOperation.category?.rubric {
                    let name = rubric.name
                    let value = sousOperation.amount
                    let color = rubric.color
                    dataArray.append(DataGraph(name: name, value: value, color: color))
                }
            }
        }

        // Group by name and sum values
        let allKeys = Set(dataArray.map { $0.name })
        var results: [DataGraph] = []
        for key in allKeys {
            let data = dataArray.filter { $0.name == key }
            let sum = data.map { $0.value }.reduce(0, +)
            if let color = data.first?.color {
                results.append(DataGraph(name: key, value: sum, color: color))
            }
        }

        // Apply category filter if any
        var filteredResults = results
        if !selectedCategories.isEmpty {
            filteredResults = results.filter { selectedCategories.contains($0.name) }
        }

        // Sort and publish
        let sorted = filteredResults.sorted { $0.name < $1.name }
        self.resultArray = sorted

        // Build chart entries
        var entries: [BarChartDataEntry] = []
        for (i, item) in sorted.enumerated() {
            entries.append(BarChartDataEntry(x: Double(i), y: item.value))
        }
        self.dataEntries = entries
    }
    
    func handleBarSelection(rubricName: String) {
        if fullFilteredCache.isEmpty {
            fullFilteredCache = listTransactions
        }
        let filtered = fullFilteredCache.filter { tx in
            tx.sousOperations.contains { $0.category?.rubric?.name == rubricName }
        }
        var didChange = false
        if ListTransactionsManager.shared.listTransactions != filtered {
            ListTransactionsManager.shared.listTransactions = filtered
            didChange = true
        }
        if self.listTransactions != filtered {
            self.listTransactions = filtered
            didChange = true
        }
        if didChange {
            NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
        }
        self.isBarSelectionActive = true
    }

    func clearBarSelection() {
        let restored = self.fullFilteredCache
        self.fullFilteredCache.removeAll()
        var didChange = false
        if ListTransactionsManager.shared.listTransactions != restored {
            ListTransactionsManager.shared.listTransactions = restored
            didChange = true
        }
        if self.listTransactions != restored {
            self.listTransactions = restored
            didChange = true
        }
        if didChange {
            NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
        }
        self.isBarSelectionActive = false
    }
}
