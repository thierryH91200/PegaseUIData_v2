//
//  Graph.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 19/03/2025.
//

import AppKit
import SwiftUI
import DGCharts

struct DataGraph : Equatable{
    
    var section = ""
    var name = ""
    var value: Double = 0.0
    var color: NSColor = .orange
    
    init () {
    }
    
    init(section: String = "", name: String, value: Double, color: NSColor = .blue)
    {
        self.section = section
        self.name = name
        self.value  = value
        self.color  = color
    }
}

class CurrencyValueFormatter: NSObject, AxisValueFormatter
{
    let formatter = NumberFormatter()

    public override init() {
        super.init()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: Locale.current.identifier)
        formatter.maximumFractionDigits = 2
    }
    
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String
    {
        let currency = formatter.string(from: value as NSNumber)!
        return currency
    }
}

class CurrencyValueFormatter1: ValueFormatter {
    private let formatter: NumberFormatter

    init(currencyCode: String = "EUR") {
        formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale.current
    }

    public func stringForValue(_ value: Double,
                                 entry: ChartDataEntry,
                                 dataSetIndex: Int,
                                 viewPortHandler: ViewPortHandler?) -> String {
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

class PieValueFormatter: ValueFormatter {
    let formatter: NumberFormatter

    init(currencyCode: String) {
        self.formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
    }

    public func stringForValue(_ value: Double,
                                 entry: ChartDataEntry,
                                 dataSetIndex: Int,
                                 viewPortHandler: ViewPortHandler?) -> String {
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// Résultat affiché : "1,2 k€", "850 €", etc.
class CompactCurrencyFormatter: ValueFormatter {
    private let numberFormatter: NumberFormatter

    init() {
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 1
    }

    public func stringForValue(_ value: Double,
                                 entry: ChartDataEntry,
                                 dataSetIndex: Int,
                                 viewPortHandler: ViewPortHandler?) -> String {
        let absValue = abs(value)
        let suffix: String
        let displayValue: Double

        switch absValue {
        case 1_000_000...:
            displayValue = absValue / 1_000_000
            suffix = " M€"
        case 1_000...:
            displayValue = absValue / 1_000
            suffix = " k€"
        default:
            displayValue = absValue
            suffix = " €"
        }

        let formatted = numberFormatter.string(from: NSNumber(value: displayValue)) ?? "\(displayValue)"
        return formatted + suffix
    }
}
