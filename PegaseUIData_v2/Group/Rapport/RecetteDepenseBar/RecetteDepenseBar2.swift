////
////  RecetteDepenseBar1.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
//
import SwiftUI
import SwiftData
import DGCharts
import Combine


class RecetteDepenseBarViewModel: ObservableObject {
    @Published var recetteArray: [DataGraph] = []
    @Published var depenseArray: [DataGraph] = []
    
    @Published var dataEntriesDepense: [BarChartDataEntry] = []
    @Published var dataEntriesRecette: [BarChartDataEntry] = []
    
    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    
    @Published var selectedCategories: Set<String> = []
    
    @Published var selectedStart: Double = 0
    @Published var selectedEnd: Double = 30

//    var chartView : BarChartView?

    var listTransactions: [EntityTransaction] = []
    
    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()
        
    let formatterDate: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = DateFormatter.dateFormat(fromTemplate: "MM yy", options: 0, locale: Locale.current)
        return fmt
    }()

    
    func computeChartData(startDate: Date, endDate: Date) -> (expense: [DataGraph], income: [DataGraph]) {
        let listTransactions = ListTransactionsManager.shared.getAllData(from: startDate, to: endDate)

        var dataArray = [DataGraph]()
        for listTransaction in listTransactions {
            let value = listTransaction.amount
            let id   = listTransaction.sectionIdentifier!
            let data  = DataGraph(name: id, value: value)
            dataArray.append(data)
        }

        var resultArrayExpense = [DataGraph]()
        var resultArrayIncome  = [DataGraph]()

        let allKeys = Set<String>(dataArray.map { $0.name })
        for key in allKeys {
            var data = dataArray.filter({ $0.name == key && $0.value < 0 })
            var sum = data.map({ $0.value }).reduce(0, +)
            resultArrayExpense.append(DataGraph(name: key, value: sum))

            data = dataArray.filter({ $0.name == key && $0.value >= 0 })
            sum = data.map({ $0.value }).reduce(0, +)
            resultArrayIncome.append(DataGraph(name: key, value: sum))
        }

        resultArrayExpense = resultArrayExpense.sorted(by: { $0.name < $1.name })
        resultArrayIncome = resultArrayIncome.sorted(by: { $0.name < $1.name })
        return (expense: resultArrayExpense, income: resultArrayIncome)
    }

    func applyData(expense resultArrayExpense: [DataGraph], income resultArrayIncome: [DataGraph], to chartView: BarChartView) -> BarChartData? {
        // If there's no data, clear the chart and return
        guard !resultArrayExpense.isEmpty && !resultArrayIncome.isEmpty else {
            chartView.data = nil
            DispatchQueue.main.async {
                chartView.notifyDataSetChanged()
            }
            return nil
        }

        let groupSpace = 0.2
        let barSpace = 0.00
        let barWidth = 0.4

        // Build entries and dynamic labels from section identifiers
        var entriesExpense = [BarChartDataEntry]()
        var entriesIncome = [BarChartDataEntry]()

        var xLabels: [String] = []
        var components = DateComponents()
        var dateString = ""

        for i in 0 ..< resultArrayExpense.count {
            entriesExpense.append(BarChartDataEntry(x: Double(i), y: abs(resultArrayExpense[i].value)))
            entriesIncome.append(BarChartDataEntry(x: Double(i), y: resultArrayIncome[i].value))

            let numericSection = Int(resultArrayExpense[i].name)
            components.year = numericSection! / 100
            components.month = numericSection! % 100

            if let date = Calendar.current.date(from: components) {
                dateString = formatterDate.string(from: date)
            }
            xLabels.append(dateString)
        }

        // Create or update data sets
        var dataSet1: BarChartDataSet
        var dataSet2: BarChartDataSet

        if chartView.data == nil /*|| chartView.data?.dataSetCount != 2*/ {
            var label = String(localized: "Expenses")
            dataSet1 = BarChartDataSet(entries: entriesExpense, label: label)
            dataSet1.colors = [#colorLiteral(red: 1, green: 0.1474981606, blue: 0, alpha: 1)]
            dataSet1.valueFormatter = DefaultValueFormatter(formatter: formatterPrice)

            label = String(localized: "Incomes")
            dataSet2 = BarChartDataSet(entries: entriesIncome, label: label)
            dataSet2.colors = [#colorLiteral(red: 0.01680417731, green: 0.1983509958, blue: 1, alpha: 1)]
            dataSet2.valueFormatter = DefaultValueFormatter(formatter: formatterPrice)
        } else {
            dataSet1 = (chartView.data!.dataSets[0] as! BarChartDataSet)
            dataSet1.replaceEntries(entriesExpense)

            dataSet2 = (chartView.data!.dataSets[1] as! BarChartDataSet)
            dataSet2.replaceEntries(entriesIncome)
        }
        printTag("dataSet1 : \(dataSet1)")
        printTag("dataSet2 : \(dataSet2)")

        // Build BarChartData
        let data = BarChartData(dataSets: [dataSet1, dataSet2])
        data.barWidth = barWidth
        data.groupBars(fromX: Double(0), groupSpace: groupSpace, barSpace: barSpace)
        data.setValueFormatter(DefaultValueFormatter(formatter: formatterPrice))
        data.setValueFont(NSFont(name: "HelveticaNeue-Light", size: CGFloat(8.0))!)
        data.setValueTextColor(.black)

        let groupCount = resultArrayExpense.count + 1
        let startYear = 0
        let endYear = startYear + groupCount

        chartView.xAxis.axisMinimum = Double(startYear)
        chartView.xAxis.axisMaximum = Double(endYear)
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xLabels)
//        data.groupBars(fromX: Double(startYear), groupSpace: groupSpace, barSpace: barSpace)
        
        chartView.data = data
//        chartView.data.barWidth = barWidth
        chartView.gridBackgroundColor = NSUIColor.white

        DispatchQueue.main.async {
            data.notifyDataChanged()
            chartView.notifyDataSetChanged()
        }
        return data
    }

    func updateChartData( startDate: Date, endDate: Date) {
        
        listTransactions = ListTransactionsManager.shared.getAllData(from:startDate, to:endDate)

        // grouped and sum
        self.recetteArray.removeAll()
        self.depenseArray.removeAll()
        var dataArray = [DataGraph]()
        
        for listTransaction in listTransactions {
            
            let value = listTransaction.amount
            let id   = listTransaction.sectionIdentifier!
            
            let data  = DataGraph(name: id, value: value)
            dataArray.append(data)
        }
        
        let allKeys = Set<String>(dataArray.map { $0.name })
        for key in allKeys {
            var data = dataArray.filter({ $0.name == key && $0.value < 0 })
            var sum = data.map({ $0.value }).reduce(0, +)
            self.recetteArray.append(DataGraph(name: key, value: sum))
            
            data = dataArray.filter({ $0.name == key && $0.value >= 0 })
            sum = data.map({ $0.value }).reduce(0, +)
            self.depenseArray.append(DataGraph(name: key, value: sum))
        }
        
        self.depenseArray = depenseArray.sorted(by: { $0.name < $1.name })
        self.recetteArray = recetteArray.sorted(by: { $0.name < $1.name })
        
        let depenseEntries = depenseArray.enumerated().map { (idx, item) in
            BarChartDataEntry(x: Double(idx), y: item.value)
        }
        let recetteEntries = recetteArray.enumerated().map { (idx, item) in
            BarChartDataEntry(x: Double(idx), y: item.value)
        }
        DispatchQueue.main.async {
            self.dataEntriesDepense = depenseEntries
            self.dataEntriesRecette = recetteEntries
        }
    }
}
