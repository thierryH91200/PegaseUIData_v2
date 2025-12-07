//
//  CategorieBar21.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine


import SwiftUI
import SwiftData
import DGCharts
import Combine


class CategorieBar2ViewModel: ObservableObject {
    
    static let shared = CategorieBar2ViewModel()
        
    var listTransactions : [EntityTransaction] = []

    @Published var resultArray: [DataGraph] = []
    @Published var dataEntries: [BarChartDataEntry] = []
    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    @Published var selectedCategories: Set<String> = []
    
    @Published var firstDate: TimeInterval = 0.0
    @Published var lastDate: TimeInterval = 0.0

    @Published var selectedStart: Double = 0
    @Published var selectedEnd: Double = 30
    
    var chartView : BarChartView?

    var labels: [String] {
        resultArray.map { $0.name }
    }
    
    func configure(with chartView: BarChartView)
    {
        self.chartView = chartView
    }

    func updateChartData( startDate: Date, endDate: Date)
    {
        var arrayUniqueRubriques   = [RubricColor]()

        // Fetch transactions in the requested range
        self.listTransactions = ListTransactionsManager.shared.getAllData(from: startDate, to: endDate)

        // Récupere le nom de toutes les rubriques
        // Récupere les datas pour la période choisie
        var setUniqueRubrique     = Set<RubricColor>()
        var dataRubrique = [DataGraph]()
        
        for listTransaction in listTransactions {
            
            let id = listTransaction.sectionIdentifier!
            
            let sousOperations = listTransaction.sousOperations
            for sousOperation in sousOperations {
                
                let amount    = sousOperation.amount
                
                let nameRubric = sousOperation.category?.rubric?.name
                let color    = sousOperation.category?.rubric?.color
                let rubricColor = RubricColor(name : nameRubric!, color: color!)
                
                setUniqueRubrique.insert(rubricColor)
                
                let data = DataGraph(section: id, name: nameRubric!, value: amount, color: color!)
                dataRubrique.append( data)
            }
        }
        arrayUniqueRubriques = setUniqueRubrique.sorted { $0.name > $1.name }
        
        // sum per rubric for each period
        resultArray.removeAll()
        let allRubricKeys = Set<String>(dataRubrique.map { $0.section })
        for keyRubric in allRubricKeys {
            for dataRubric in arrayUniqueRubriques {
                let data = dataRubrique.filter({ $0.section == keyRubric && $0.name == dataRubric.name  })
                if data.isEmpty == false {
                    let sum = data.map({ $0.value }).reduce(0, +)
                    resultArray.append(DataGraph(section: keyRubric ,name: dataRubric.name, value: sum, color: dataRubric.color))
                } else {
                    resultArray.append(DataGraph(section: keyRubric ,name: dataRubric.name, value: 0, color: dataRubric.color))
                }
            }
        }
        resultArray = resultArray.sorted(by: { $0.name < $1.name })
        resultArray = resultArray.sorted(by: { $0.section < $1.section })
        
        var entries: [BarChartDataEntry] = []
        for (i, item) in self.resultArray.enumerated() {
            entries.append(BarChartDataEntry(x: Double(i), y: item.value))
        }
        self.dataEntries = entries
    }
}

