//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import Combine
import DGCharts

class RubriquePieViewModel: ObservableObject {
    @Published var depenseArray: [DataGraph] = []
    @Published var recetteArray: [DataGraph] = []
    
    @Published var dataEntriesDepense: [PieChartDataEntry] = []
    @Published var dataEntriesRecette: [PieChartDataEntry] = []

    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    @Published var selectedCategories: Set<String> = []
    
    var listTransactions: [EntityTransaction] = []
    
    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()

    func updateChartData(  startDate: Date, endDate: Date) {
        
        listTransactions = ListTransactionsManager.shared.getAllData(from:startDate, to:endDate)
        
        var dataArrayExpense = [DataGraph]()
        var dataArrayIncome  = [DataGraph]()

        var rubrique = ""
        var value = 0.0
        var color = NSColor.blue
        let section = ""
        
        for listeOperation in listTransactions {
            
            let sousOperations = listeOperation.sousOperations
            for sousOperation in sousOperations {
                
                value = sousOperation.amount
                rubrique = (sousOperation.category?.rubric!.name)!
                color = (sousOperation.category?.rubric!.color)!
                
                if value < 0 {
                    dataArrayExpense.append( DataGraph( name: rubrique, value: value, color: color))
                    
                } else {
                    dataArrayIncome.append( DataGraph(section: section, name: rubrique, value: value, color: color))
                }
            }
        }
        
        self.depenseArray.removeAll()
        let allKeys = Set<String>(dataArrayExpense.map { $0.name })
        for key in allKeys {
            let data = dataArrayExpense.filter({ $0.name == key })
            let sum = data.map({ $0.value }).reduce(0, +)
            self.depenseArray.append(DataGraph(name: key, value: sum, color: data[0].color))
        }
        self.depenseArray = self.depenseArray.sorted(by: { $0.name < $1.name })
        
        recetteArray.removeAll()
        let allKeysR = Set<String>(dataArrayIncome.map { $0.name })
        for key in allKeysR {
            let data = dataArrayIncome.filter({ $0.name == key })
            let sum = data.map({ $0.value }).reduce(0, +)
            self.recetteArray.append(DataGraph(name: key, value: sum, color: data[0].color))
        }
        recetteArray = recetteArray.sorted(by: { $0.name < $1.name })
        
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

