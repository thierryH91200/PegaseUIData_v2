////
////  CategorieBar24.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
//
import SwiftUI
import SwiftData
import DGCharts


extension Notification.Name { static let BarChart2NeedsRefresh = Notification.Name("BarChart2NeedsRefresh") }

struct DGBarChart2Representable: NSViewRepresentable {
    
    let data: [GraphPoint]
    let valueFormatter: NumberFormatter
    var onSelectBar: ((Int, DataGraph) -> Void)? = nil
    var onClearSelection: (() -> Void)? = nil
    var isStacked: Bool = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    @MainActor
    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: DGBarChart2Representable
        weak var chartView: BarChartView?
        
        private var refreshObserver: NSObjectProtocol?
        
        @MainActor
        init(parent: DGBarChart2Representable) {
            self.parent = parent
            super.init()
            refreshObserver = NotificationCenter.default.addObserver(
                forName: .BarChart2NeedsRefresh,
                object: nil,
                queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard let chartView = self.chartView else { return }
                        self.parent.setData(on: chartView, with: self.parent.data)
                    }
                }
        }
        
        deinit {
            if let observer = refreshObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        public func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {

            let monthIndex = Int(highlight.x)
            let dataSetIndex = highlight.dataSetIndex

            // Retrieve the rubric name from the dataset label
            guard let dataSets = chartView.data?.dataSets,
                  dataSetIndex < dataSets.count,
                  let rubricName = dataSets[dataSetIndex].label
            else { return }

            // Find the matching GraphPoint
            let months = Array(Set(parent.data.map { $0.month })).sorted()
            guard monthIndex < months.count else { return }
            let month = months[monthIndex]

            if let point = parent.data.first(where: { $0.month == month && $0.rubric == rubricName }) {
                let item = DataGraph(section: String(month), name: point.rubric, value: point.value, color: point.color)
                parent.onSelectBar?(monthIndex, item)
            }
        }
        
        public func chartValueNothingSelected(_ chartView: ChartViewBase)
        {
            parent.onClearSelection?()
        }
    }
    
    func makeNSView(context: Context) -> BarChartView {
        let chartView = BarChartView()
        context.coordinator.chartView = chartView
        chartView.delegate = context.coordinator
        configure(chartView)
        // Enable selection highlighting similar to DGBarChart7
        chartView.highlightPerTapEnabled = true
        chartView.highlightFullBarEnabled = true
        // Set initial data from data property
        setData(on: chartView, with: data)
        
        return chartView
    }
    
    func updateNSView(_ nsView: BarChartView, context: Context) {
        setData(on: nsView, with: data)
    }

    
    func setData(on chartView: BarChartView, with data: [GraphPoint]) {
        
        guard !data.isEmpty else {
            chartView.data = nil
            chartView.notifyDataSetChanged()
            return
        }
        
        // 1️⃣ Mois uniques (axe X)
        let months = Array(Set(data.map { $0.month })).sorted()
        
        // 2️⃣ Rubriques uniques (datasets)
        let rubrics = Array(Set(data.map { $0.rubric })).sorted()
        
        // 3️⃣ Création des DataSets
        var dataSets: [BarChartDataSet] = []
        
        for rubric in rubrics {
            var entries: [BarChartDataEntry] = []
            
            for (monthIndex, month) in months.enumerated() {
                let value = data
                    .filter { $0.month == month && $0.rubric == rubric }
                    .map(\.value)
                    .reduce(0, +)
                
                entries.append(
                    BarChartDataEntry(x: Double(monthIndex), y: value)
                )
            }
            
            let color = data.first { $0.rubric == rubric }?.color ?? .systemBlue
            let set = BarChartDataSet(entries: entries, label: rubric)
            set.colors = [color]
            set.drawValuesEnabled = true
            
            dataSets.append(set)
        }
        
        // 4️⃣ BarChartData + grouping
        let barData = BarChartData(dataSets: dataSets)
        
        let groupSpace = 0.25
        let barSpace   = 0.05
        let barWidth   = (1.0 - groupSpace) / Double(dataSets.count) - barSpace
        
        barData.barWidth = barWidth
        barData.groupBars(fromX: 0, groupSpace: groupSpace, barSpace: barSpace)
        
        // 5️⃣ Axe X (labels mois)
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMM yyyy"
        
        let labels = months.map { month -> String in
            let year = month / 100
            let m    = month % 100
            let date = Calendar.current.date(from: DateComponents(year: year, month: m))!
            return formatter.string(from: date)
        }
        
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.granularity = 1
        chartView.xAxis.centerAxisLabelsEnabled = true

        chartView.xAxis.axisMinimum = 0
        chartView.xAxis.axisMaximum =
        barData.groupWidth(groupSpace: groupSpace, barSpace: barSpace)
        * Double(months.count)
        
        chartView.fitBars = false
        chartView.data = barData
        chartView.notifyDataSetChanged()
    }
    
    private func configure(_ chartView: BarChartView) {
        // MARK: General
        chartView.borderColor = .controlBackgroundColor
        chartView.gridBackgroundColor = .windowBackgroundColor
        chartView.drawBarShadowEnabled      = false
        chartView.drawValueAboveBarEnabled  = true
        chartView.maxVisibleCount           = 60
        chartView.drawGridBackgroundEnabled = true
        chartView.gridBackgroundColor       = .windowBackgroundColor
        
        chartView.fitBars                   = true
        chartView.drawBordersEnabled        = true
        
        chartView.pinchZoomEnabled          = false
        chartView.doubleTapToZoomEnabled    = false
        chartView.dragEnabled               = false
        chartView.noDataText                = String(localized:"No chart data available.")
        
        chartView.highlightPerTapEnabled   = true
        chartView.highlightFullBarEnabled  = true
        
        // MARK: xAxis
        let xAxis                      = chartView.xAxis
        xAxis.labelPosition           = .bottom
        xAxis.labelFont               = NSFont.systemFont(ofSize: 14, weight: .light)
        xAxis.drawGridLinesEnabled    = true
        xAxis.granularity             = 1
        xAxis.enabled                = true
        xAxis.labelTextColor          = .labelColor
        //        xAxis.labelCount              = min(labels.count, 10)
        
        // MARK: leftAxis
        let leftAxis                  = chartView.leftAxis
        leftAxis.labelFont            = NSFont(name: "HelveticaNeue-Light", size: 10) ?? NSFont.systemFont(ofSize: 10, weight: .light)
        leftAxis.labelTextColor       = .labelColor
        
        //        leftAxis.drawGridLinesEnabled = true
        //        leftAxis.granularityEnabled   = true
        leftAxis.granularity          = 1
        leftAxis.valueFormatter       = CurrencyValueFormatter()
        
        // MARK: rightAxis
        chartView.rightAxis.enabled   = false
        
        // MARK: legend
        initializeLegend(chartView.legend)
        
        // MARK: description
        chartView.chartDescription.enabled = false
    }
    
    func initializeLegend(_ legend: Legend) {
        
        legend.horizontalAlignment = .left
        legend.verticalAlignment   = .bottom
        legend.orientation         = .horizontal
        legend.font                = NSFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        legend.textColor           = NSColor.labelColor
        legend.form                          = .square
        
    }


}
