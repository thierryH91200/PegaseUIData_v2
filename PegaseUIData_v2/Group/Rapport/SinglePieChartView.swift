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


struct SinglePieChartView: NSViewRepresentable {
    let entries: [PieChartDataEntry]
    let title: String

    let formatterPrice: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.locale = Locale.current
        _formatter.numberStyle = .currency
        return _formatter
    }()

    func makeNSView(context: Context) -> PieChartView {
        let chartView = PieChartView()
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


