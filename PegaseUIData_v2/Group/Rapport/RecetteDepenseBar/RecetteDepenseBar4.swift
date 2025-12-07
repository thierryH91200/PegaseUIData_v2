////
////  RecetteDepenseBar4.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
import SwiftUI
import SwiftData
import DGCharts
import Combine
import SwiftDate



struct DGBarChart4Representable: NSViewRepresentable {
    
    let entries: [BarChartDataEntry]
    let title: String
    let labels: [String]
    let data : BarChartData?
    
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    
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

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> BarChartView {
        
        let chartView = BarChartView()

        chartView.delegate = context.coordinator
        chartView.noDataText = String(localized:"No chart data available.")
        
        configure(chartView)
        let dataSet = BarChartDataSet(entries: entries, label: "Categorie Bar1")
        dataSet.colors = ChartColorTemplates.colorful()
        
        let data = BarChartData(dataSet: dataSet)
        chartView.data = data

        return chartView
    }
    
    func updateNSView(_ chartView: BarChartView, context: Context) {
        context.coordinator.parent = self

        // Keep axis config in sync
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.labelCount = labels.count
        chartView.xAxis.granularity = 1
        chartView.xAxis.drawGridLinesEnabled = false

        if entries.isEmpty {
            chartView.data = nil
            chartView.fitBars = true

            DispatchQueue.main.async {
                chartView.notifyDataSetChanged()
            }
            return
        }

        chartView.data = data
        chartView.fitBars = true
        DispatchQueue.main.async {
            data?.notifyDataChanged()
            chartView.notifyDataSetChanged()
        }
    }
    
    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: DGBarChart4Representable
        var isUpdating = false
        var fullFilteredCache: [EntityTransaction] = []

        init(parent: DGBarChart4Representable) {
            self.parent = parent
        }

        public func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            let index = highlight.x
//            guard index >= 0, index < parent.labels.count else { return }
            
            let entryX = entry.x
            let dataSetIndex = Int(highlight.dataSetIndex)

            printTag("index: \(index), entryX: \(entryX), dataSetIndex: \(dataSetIndex) ")

            // Compute the current range window based on lower/upper values (in days) from the dataset min date
            let all = ListTransactionsManager.shared.getAllData()
            guard let globalMin = all.first?.dateOperation else { return }
            let cal = Calendar.current
            let rangeStart = cal.date(byAdding: .day, value: Int(parent.lowerValue), to: globalMin) ?? globalMin
            let rangeEndExclusive = cal.date(byAdding: .day, value: Int(parent.upperValue + 1), to: globalMin) ?? globalMin

            // Cache the current range-filtered list once
            if self.fullFilteredCache.isEmpty {
                self.fullFilteredCache = all.filter { tx in
                    tx.dateOperation >= rangeStart && tx.dateOperation < rangeEndExclusive
                }
            }
            
            // Derive the selected month interval from the encoded label (year*1000 + month),
            // else fall back to offset from rangeStart when decoding fails.
            let label = parent.labels[Int(index)]
            var monthStart: Date
            var monthEndExclusive: Date
            if let code = Int(label) {
                let year = code / 100
                let month = code - year * 100
                if (1...12).contains(month) {
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = 1
                    monthStart = cal.date(from: comps) ?? rangeStart.startOfMonth()
                    monthEndExclusive = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                } else {
                    let baseMonthStart = rangeStart.startOfMonth()
                    let derived = cal.date(byAdding: .month, value: Int(index), to: baseMonthStart) ?? baseMonthStart
                    monthStart = derived.startOfMonth()
                    monthEndExclusive = derived.endOfMonth()
                }
            } else {
                let baseMonthStart = rangeStart.startOfMonth()
                let derived = cal.date(byAdding: .month, value: Int(index), to: baseMonthStart) ?? baseMonthStart
                monthStart = derived.startOfMonth()
                monthEndExclusive = derived.endOfMonth()
            }

            // First, filter by the selected month range
            let monthFiltered = self.fullFilteredCache.filter { tx in
                tx.dateOperation >= monthStart && tx.dateOperation < monthEndExclusive
            }

            // Then, filter by sign depending on the selected dataset:
            // dataSetIndex == 0 -> amount < 0 (expenses)
            // dataSetIndex == 1 -> amount > 0 (income)
            let filtered: [EntityTransaction]
            switch dataSetIndex {
            case 0:
                filtered = monthFiltered.filter { $0.amount < 0 }
            case 1:
                filtered = monthFiltered.filter { $0.amount > 0 }
            default:
                filtered = monthFiltered
            }

            // Publish the filtered list to the shared manager and notify the UI
            DispatchQueue.main.async {
                var didChange = false
                if ListTransactionsManager.shared.listTransactions != filtered {
                    ListTransactionsManager.shared.listTransactions = filtered
                    didChange = true
                }
                if didChange {
                    NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
                }
            }
        }
        
        public func chartValueNothingSelected(_ chartView: ChartViewBase) {
            let restored = self.fullFilteredCache
            self.fullFilteredCache.removeAll()
            DispatchQueue.main.async {
                var didChange = false
                if ListTransactionsManager.shared.listTransactions != restored {
                    ListTransactionsManager.shared.listTransactions = restored
                    didChange = true
                }
                if didChange {
                    NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
                }
            }
        }
    }

        
    private func configure(_ chartView: BarChartView) {
            
        // MARK: General
        chartView.drawBarShadowEnabled      = false
        chartView.drawValueAboveBarEnabled  = true
        chartView.maxVisibleCount           = 60
        chartView.drawBordersEnabled        = true
        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor       = .windowBackgroundColor
        chartView.fitBars                   = true
        chartView.highlightPerTapEnabled   = true
        
        chartView.pinchZoomEnabled          = false
        chartView.doubleTapToZoomEnabled    = false
        chartView.dragEnabled               = false
        chartView.noDataText = "No chart Data Available"
        
        // MARK: xAxis
        let xAxis            = chartView.xAxis
        xAxis.centerAxisLabelsEnabled = true
        xAxis.drawGridLinesEnabled    = true
        xAxis.granularity = 1.0
        xAxis.gridLineWidth = 2.0
        xAxis.labelCount = 20
        xAxis.labelFont      = NSFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .labelColor
        
//        xAxis.axisMinimum = -0.25
//        xAxis.axisMaximum = Double(labels.count) + 0.25
        xAxis.axisMinimum = 0
        xAxis.axisMaximum = Double(labels.count)

        
        // MARK: leftAxis
        let leftAxis                   = chartView.leftAxis
        leftAxis.labelFont             = NSFont(name: "HelveticaNeue-Light", size: CGFloat(10.0))!
        leftAxis.labelCount            = 6
        leftAxis.drawGridLinesEnabled  = true
        leftAxis.granularityEnabled    = true
        leftAxis.granularity           = 1
        leftAxis.valueFormatter        = CurrencyValueFormatter()
        leftAxis.labelTextColor        = .labelColor
        
        // MARK: rightAxis
        chartView.rightAxis.enabled    = false
        
        //             MARK: legend
        let legend = chartView.legend
        legend.horizontalAlignment = .right
        legend.verticalAlignment = .top
        legend.orientation = .vertical
        legend.drawInside                    = true
        legend.xOffset = 10.0
        legend.yEntrySpace = 0.0
        legend.font = NSFont(name: "HelveticaNeue-Light", size: CGFloat(11.0))!
        legend.textColor = .labelColor
        
        //        MARK: description
        chartView.chartDescription.enabled  = false
    }
    
    
}

extension Date {
    func startOfMonth() -> Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: self)))!
    }
    
    func endOfMonth() -> Date {
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: 0), to: self.startOfMonth())!
    }
}

