//
//  Untitled 4.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine


struct DGBarChart5Representable: NSViewRepresentable {
    @ObservedObject var viewModel: RubriqueBarViewModel

    let entries: [BarChartDataEntry]
    let title: String
    let labels: [String]
    
    let chartView = BarChartView()
    
    @State var firstDate: TimeInterval = 0.0
    @State var lastDate: TimeInterval = 0.0
    let hourSeconds = 3600.0 * 24.0 // one day

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }


    func makeNSView(context: Context) -> BarChartView {
        
        chartView.delegate = context.coordinator

        initChart()
        
        let dataSet = BarChartDataSet(entries: entries, label: "Categorie Bar1")
        dataSet.colors = ChartColorTemplates.colorful()
        
        let data = BarChartData(dataSet: dataSet)
        chartView.data = data
        
        // Personnalisation du graphique
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.labelCount = labels.count
        chartView.xAxis.granularity = 1
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.animate(yAxisDuration: 1.5)
        
        return chartView
    }
    
    func updateNSView(_ nsView: BarChartView, context: Context) {
        nsView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        nsView.xAxis.labelCount = labels.count
        nsView.xAxis.granularity = 1
        nsView.xAxis.drawGridLinesEnabled = false
        
        if let data = nsView.data, let set = data.dataSets.first as? BarChartDataSet {
            set.replaceEntries(entries)
            data.notifyDataChanged()
            nsView.notifyDataSetChanged()
        } else {
            let dataSet = BarChartDataSet(entries: entries, label: "Recette Depense Bar")
            dataSet.colors = ChartColorTemplates.colorful()
            nsView.data = BarChartData(dataSet: dataSet)
            nsView.notifyDataSetChanged()
        }
    }
    
    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: DGBarChart5Representable
        var isUpdating = false
        
        init(parent: DGBarChart5Representable) {
            self.parent = parent
        }
        
        public func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            
            let index = Int(highlight.x)
            let entryX = entry.x
            let dataSetIndex = Int(highlight.dataSetIndex)
            
            printTag("index: \(index), entryX: \(entryX), dataSetIndex: \(dataSetIndex) ")

        }
        
        public func chartValueNothingSelected(_ chartView: ChartViewBase)
        {
        }

    }
    
    private func initChart() {
        
            
            // MARK: General

            chartView.drawBarShadowEnabled      = false
            chartView.drawValueAboveBarEnabled  = true
            chartView.maxVisibleCount           = 60
            chartView.drawBordersEnabled        = true
            chartView.drawGridBackgroundEnabled = true
            chartView.gridBackgroundColor       = .windowBackgroundColor
            chartView.fitBars                   = true
            
            chartView.pinchZoomEnabled          = false
            chartView.doubleTapToZoomEnabled    = false
            chartView.dragEnabled               = false
            chartView.noDataText                = "No chart Data Available"
            
            
            // MARK : xAxis
            let xAxis                      = chartView.xAxis
            xAxis.granularity = 1
            xAxis.gridLineWidth = 1.0
            xAxis.labelFont      = NSFont(name: "HelveticaNeue-Light", size: CGFloat(12.0))!
            xAxis.labelPosition = .bottom
            xAxis.labelTextColor           = .labelColor
            
            // MARK: leftAxis
            let leftAxis                   = chartView.leftAxis
            leftAxis.labelFont             = NSFont(name: "HelveticaNeue-Light", size: CGFloat(10.0))!
            leftAxis.labelCount            = 6
            leftAxis.drawGridLinesEnabled  = true
            leftAxis.granularityEnabled    = true
            leftAxis.granularity           = 1
            leftAxis.valueFormatter        = CurrencyValueFormatter()
            leftAxis.labelTextColor        = .labelColor
            leftAxis.gridLineWidth = 1.0
            
            // MARK: rightAxis
            chartView.rightAxis.enabled    = false
            
            // MARK: legend
            initializeLegend(chartView.legend)
            
            // MARK: description
            chartView.chartDescription.enabled  = false
    }
    
    func initializeLegend(_ legend: Legend) {
        legend.horizontalAlignment = .right
        legend.verticalAlignment = .top
        legend.orientation = .vertical
        legend.drawInside = true
        legend.xOffset = 10.0
        legend.yEntrySpace = 0.0
        legend.font = NSFont(name: "HelveticaNeue-Light", size: CGFloat(11.0))!
        legend.textColor = NSColor.labelColor
    }
}

