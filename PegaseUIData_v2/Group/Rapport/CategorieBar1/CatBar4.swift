////
////  CatBar4.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 16/04/2025.
////

import SwiftUI
import SwiftData
import DGCharts


extension Notification.Name {
    static let BarChart7NeedsRefresh = Notification.Name("BarChart7NeedsRefresh")
}

struct DGBarChart7Representable: NSViewRepresentable {
    
    @ObservedObject var viewModel: CategorieBar1ViewModel
    let entries: [BarChartDataEntry]
    /// Called when a bar is tapped. Provides the selected index and its associated DataGraph.
    var onSelectBar: ((Int, DataGraph) -> Void)? = nil


    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: DGBarChart7Representable
        weak var chartView: BarChartView?
        private var refreshObserver: NSObjectProtocol?

        init(parent: DGBarChart7Representable) {
            self.parent = parent
            super.init()
            refreshObserver = NotificationCenter.default.addObserver(forName: .BarChart7NeedsRefresh, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Skip automatic refresh when a bar is selected
                    guard self.parent.viewModel.isBarSelectionActive == false else { return }
                    guard let chartView = self.chartView else { return }
                    self.parent.setData(on: chartView, with: self.parent.viewModel.resultArray)
                }
            }
        }

        deinit {
            if let observer = refreshObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func chartValueSelected(_ chartView: ChartViewBase,
                                entry: ChartDataEntry,
                                highlight: Highlight) {
            let index = Int(highlight.x)
            let entryX = entry.x
            let dataSetIndex = Int(highlight.dataSetIndex)

            printTag("index: \(index), entryX: \(entryX), dataSetIndex: \(dataSetIndex) ")

#if DEBUG
            if parent.entries.indices.contains(index) {
                print("Selected \(parent.entries[index])")
            } else {
                print("Selected index out of range: \(index)")
            }
#endif
            
            // Notify SwiftUI about the selection to display transactions
            if parent.viewModel.resultArray.indices.contains(index) {
                let item = parent.viewModel.resultArray[index]
                parent.onSelectBar?(index, item)
            }
            
            // Filter transactions by the selected rubric (bar) within the current range
            if parent.viewModel.resultArray.indices.contains(index) {
                let item = parent.viewModel.resultArray[index]
                self.parent.viewModel.handleBarSelection(rubricName: item.name)
            }
        }

        func chartValueNothingSelected(_ chartView: ChartViewBase) {
            self.parent.viewModel.clearBarSelection()
        }
    }


    func makeNSView(context: Context) -> BarChartView {
        
        let chartView = BarChartView()
        context.coordinator.chartView = chartView
        chartView.delegate = context.coordinator
        configure(chartView) // voir ci-dessous
        return chartView
    }
    
    func updateNSView(_ nsView: BarChartView, context: Context) {
        setData(on: nsView, with: viewModel.resultArray)
    }
    
    func setData(on chartView: BarChartView, with data: [DataGraph]) {
        // If there's no data, clear the chart and return
        guard !data.isEmpty else {
            chartView.data = nil
            chartView.notifyDataSetChanged()
            return
        }

        // Build entries and colors
        var entries: [BarChartDataEntry] = []
        var colors: [NSColor] = []
        var labels: [String] = []

        for (i, item) in data.enumerated() {
            entries.append(BarChartDataEntry(x: Double(i), y: item.value))
            labels.append(item.name)
            colors.append(item.color)
        }

        // Configure xAxis labels
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.labelCount = labels.count

        // Create or update dataset
        if chartView.data == nil {
            let dataSet = BarChartDataSet(entries: entries, label: "Rubric")
            dataSet.colors = colors
            dataSet.drawValuesEnabled = true
            dataSet.barBorderWidth = 0.1
            dataSet.valueFormatter = DefaultValueFormatter(formatter: viewModel.formatterPrice)

            let barData = BarChartData(dataSets: [dataSet])
            barData.setValueFormatter(DefaultValueFormatter(formatter: viewModel.formatterPrice))
            let valueFont = NSFont(name: "HelveticaNeue-Light", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .light)
            barData.setValueFont(valueFont)
            barData.setValueTextColor(NSColor.labelColor)

            chartView.data = barData
        } else {
            if let set1 = chartView.data?.dataSets.first as? BarChartDataSet {
                set1.colors = colors
                set1.replaceEntries(entries)
            }
            chartView.data?.notifyDataChanged()
            chartView.notifyDataSetChanged()
        }
    }
    
    func configure(_ chartView: BarChartView) {
        
        // MARK: General
        chartView.drawBarShadowEnabled      = false

        chartView.drawValueAboveBarEnabled  = true
        chartView.maxVisibleCount           = 60
        chartView.drawGridBackgroundEnabled = true
        chartView.drawBordersEnabled        = true
        chartView.gridBackgroundColor       = .windowBackgroundColor
        chartView.fitBars                   = true
        chartView.highlightPerTapEnabled   = true
        chartView.highlightFullBarEnabled  = true

        chartView.pinchZoomEnabled          = false
        chartView.doubleTapToZoomEnabled    = false
        chartView.dragEnabled               = false
        chartView.noDataText = String(localized:"No chart data available.")
        
        // MARK: Axis
        setUpAxis(chartView: chartView)
        
        // MARK: Legend
        initializeLegend(chartView.legend)
        
        // MARK: Description
        chartView.chartDescription.enabled = false
    }
    
    func initializeLegend(_ legend: Legend) {
        
        legend.horizontalAlignment = .left
        legend.verticalAlignment = .top
        legend.orientation = .vertical
        legend.font = NSFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        legend.textColor = NSColor.labelColor
    }
    
    func setUpAxis(chartView: BarChartView) {
        // MARK: xAxis
        let xAxis = chartView.xAxis
        xAxis.labelPosition            = .bottom
        xAxis.labelFont                = NSFont.systemFont(ofSize: 14, weight: .light)
        xAxis.drawGridLinesEnabled     = true
        xAxis.granularity              = 1
        xAxis.enabled                  = true
        xAxis.labelTextColor           = .labelColor
        xAxis.labelCount               = 10

        // MARK: leftAxis
        let leftAxis                   = chartView.leftAxis
        leftAxis.labelFont = NSFont(name: "HelveticaNeue-Light", size: 10) ?? NSFont.systemFont(ofSize: 10, weight: .light)
        leftAxis.labelCount            = 12
        leftAxis.drawGridLinesEnabled  = true
        leftAxis.granularityEnabled    = true
        leftAxis.granularity           = 1
        leftAxis.valueFormatter        = CurrencyValueFormatter()
        leftAxis.labelTextColor        = .labelColor

        // MARK: rightAxis
        chartView.rightAxis.enabled    = false
    }
    
}
