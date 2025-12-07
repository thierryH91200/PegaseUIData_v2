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

class RubriqueBarViewModel: ObservableObject {
    @Published var resultArray: [DataGraph] = []
    @Published var dataArray: [DataGraph] = []
    
    @Published var dataEntries: [BarChartDataEntry] = []
    @Published var nameRubrique: String = ""
    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    @Published var selectedCategories: Set<String> = []
    
    @Published var availableRubrics: [String] = []

    var listTransactions: [EntityTransaction] = []
    
    @Published var selectedStart: Double = 0
    @Published var selectedEnd: Double = 30
    
    
//    var totalValue: Double {
//        resultArray.map { $0.value }.reduce(0, +)
//    }
//    
    var labels: [String] {
        resultArray.map { $0.name }
    }
    
    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()
    
    func updateChartData( startDate: Date, endDate: Date) {
        
        dataArray.removeAll()
        // If no rubric name is provided, we still compute totals per section using all sousOperations
        
        listTransactions = ListTransactionsManager.shared.getAllData(from:startDate, to:endDate)
        
        // Build available rubrics from the current transaction window
        let rubricSet = Set(listTransactions.flatMap { txn in
            txn.sousOperations.compactMap { $0.category?.rubric?.name }
        })
        self.availableRubrics = [""] + rubricSet.sorted() // "" means all
        
        //        delegate?.updateListeTransactions( listTransactions)
        
        // grouped by month/year
        var name = ""
        var value = 0.0
        var color = NSColor.blue
        var section = ""
        resultArray.removeAll()
        dataArray.removeAll()
        
        for listTransaction in listTransactions {
            
            section = listTransaction.sectionIdentifier ?? ""
            let sousOperations = listTransaction.sousOperations
            value = 0.0
            name = nameRubrique
            for sousOperation in sousOperations {
                let rubricName = sousOperation.category?.rubric?.name ?? ""
                if nameRubrique.isEmpty || rubricName == nameRubrique {
                    value += sousOperation.amount
                    if let c = sousOperation.category?.rubric?.color { color = c }
                    if name.isEmpty { name = rubricName }
                }
            }
            self.dataArray.append( DataGraph(section: section, name: name, value: value, color: color))
        }
        self.dataArray = self.dataArray.sorted(by: { $0.name < $1.name })
        self.dataArray = self.dataArray.sorted(by: { $0.section < $1.section })
        
        let allKeys = Set<String>(dataArray.map { $0.section })
        let strAllKeys = allKeys.sorted()
        
        for key in strAllKeys {
            let data = dataArray.filter({ $0.section == key })
            let sum = data.map({ $0.value }).reduce(0, +)
            self.resultArray.append(DataGraph(section: key, name: key, value: sum, color: color))
        }
        dataArray = resultArray
        // Ensure a stable order for bars and labels
        let ordered = resultArray
        self.dataEntries = ordered.enumerated().map { index, item in
            BarChartDataEntry(x: Double(index), y: item.value)
        }
        // labels is computed from resultArray via the computed property
    }
}
