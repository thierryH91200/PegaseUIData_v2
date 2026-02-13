//
//  SinglePieChartView 2.swift
//  PegaseUIData
//
//  Created by thierryH24 on 21/09/2025.
//


import SwiftUI
import SwiftData
import DGCharts
import Combine


struct SinglePie3ChartView: NSViewRepresentable {
    let entries: [PieChartDataEntry]
    let title: String
    var onSelectSlice: ((String?) -> Void)? = nil
    var onClearSelection: (() -> Void)? = nil

    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, ChartViewDelegate {
        var parent: SinglePie3ChartView
        weak var chartView: PieChartView?

        init(parent: SinglePie3ChartView) {
            self.parent = parent
            super.init()
        }

        func chartValueSelected(_ chartView: ChartViewBase,
                                entry: ChartDataEntry,
                                highlight: Highlight) {
            guard let pieView = chartView as? PieChartView else { return }
            self.chartView = pieView

            // Extract label and value
            let value = entry.y
            let percent = highlight.y
            let label: String
            if let dataSet = pieView.data?.dataSets[safe: Int(highlight.dataSetIndex)] as? PieChartDataSet,
               let pieEntry = dataSet.entries[safe: Int(highlight.x)] as? PieChartDataEntry,
               let entryLabel = pieEntry.label {
                label = entryLabel
            } else if let pieEntry = entry as? PieChartDataEntry, let entryLabel = pieEntry.label {
                label = entryLabel
            } else {
                label = ""
            }

            parent.onSelectSlice?(label)

            // Format currency using parent's formatter
            let formattedValue = parent.formatterPrice.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
            let formattedPercent = String(format: "%.1f%%", percent)

            let title = label.isEmpty ? "\(formattedValue) (\(formattedPercent))" : "\(label)\n\(formattedValue) (\(formattedPercent))"
            let centerText = NSMutableAttributedString(string: title)
            centerText.setAttributes([
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ], range: NSRange(location: 0, length: centerText.length))
            pieView.centerAttributedText = centerText
        }

        func chartValueNothingSelected(_ chartView: ChartViewBase) {
            guard let pieView = chartView as? PieChartView else { return }
            let centerText = NSMutableAttributedString(string: parent.title)
            centerText.setAttributes([
                .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ], range: NSRange(location: 0, length: centerText.length))
            pieView.centerAttributedText = centerText

            parent.onClearSelection?()
        }
    }

    func makeNSView(context: Context) -> PieChartView {
        let chartView = PieChartView()
        chartView.delegate = context.coordinator
        context.coordinator.chartView = chartView
        chartView.noDataText = String(localized: "No chart data available.")
        chartView.usePercentValuesEnabled = false
        chartView.drawHoleEnabled = true
        chartView.holeRadiusPercent = 0.4
        chartView.transparentCircleRadiusPercent = 0.45

        let centerText = NSMutableAttributedString(string: title)
        centerText.setAttributes([
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ], range: NSRange(location: 0, length: centerText.length))
        chartView.centerAttributedText = centerText

        chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)

        return chartView
    }

    func updateNSView(_ nsView: PieChartView, context: Context) {
        let dataSet = PieChartDataSet(entries: entries, label: "")
        dataSet.colors = ChartColorTemplates.material() + ChartColorTemplates.pastel()
        dataSet.drawValuesEnabled = true
        dataSet.valueTextColor = .black
        dataSet.entryLabelColor = .black
        dataSet.sliceSpace = 2.0

        let data = PieChartData(dataSet: dataSet)
        let formatter = PieValueFormatter(currencyCode: "EUR")
        data.setValueFormatter(formatter)
        data.setValueFont(.systemFont(ofSize: 11))

        nsView.data = data
        nsView.notifyDataSetChanged()
    }
    
    func initializeLegend(_ legend: Legend) {
        legend.horizontalAlignment = .left
        legend.verticalAlignment = .top
        legend.orientation = .vertical
        legend.font = NSFont(name: "HelveticaNeue-Light", size: CGFloat(14.0))!
        legend.textColor = NSColor.labelColor
    }

}



