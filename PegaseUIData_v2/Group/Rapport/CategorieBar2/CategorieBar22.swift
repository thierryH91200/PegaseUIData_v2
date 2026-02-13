////
////  CategorieBar21.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
//
import SwiftUI
import SwiftData
import DGCharts
import Combine

struct GraphPoint {
    let month: Int        // ex: 202111
    let rubric: String   // ex: "Alimentation"
    let value: Double    // somme du mois pour la rubrique
    let color: NSColor
    
    init(month: Int, rubric: String, value: Double, color: NSColor) {
        self.month = month
        self.rubric = rubric
        self.value = value
        self.color = color
    }
}

final class CategoryBar2ViewModel: ObservableObject {
    
    @Published var listTransactions : [EntityTransaction] = []

    var chartView : BarChartView?

    @Published var graphData: [GraphPoint] = []
    
    func buildGraphData(
        transactions: [EntityTransaction],
        startDate: Date,
        endDate: Date
    ) {
        var accumulator: [Key: Double] = [:]
        var colors: [String: NSColor] = [:]

        for transaction in transactions {
            // Use datePointage for consistency with getAllData() and sectionIdentifier
            // This ensures bank card transactions with deferred debit are properly included
            let date = transaction.datePointage

            guard
                date >= startDate,
                date <= endDate,
                let section = Int(transaction.sectionIdentifier ?? "202211") // "202111"
            else { continue }

            for sub in transaction.sousOperations {
                guard
                    let rubric = sub.category?.rubric?.name,
                    let color = sub.category?.rubric?.color
                else { continue }

                let key = Key(month: section, rubric: rubric)
                accumulator[key, default: 0] += sub.amount
                colors[rubric] = color
            }
        }

        self.graphData = accumulator.map { key, value in
            GraphPoint(
                month: key.month,
                rubric: key.rubric,
                value: abs(value),
                color: colors[key.rubric] ?? .systemBlue
            )
        }
        .sorted {
            if $0.month == $1.month {
                return $0.rubric < $1.rubric
            }
            return $0.month < $1.month
        }

        #if DEBUG
        debugPrintGraph()
        #endif
    }

    // MARK: - Debug

    private func debugPrintGraph() {
        let grouped = Dictionary(grouping: graphData, by: { $0.month })
        for month in grouped.keys.sorted() {
            print("📅 \(month)")
            for g in grouped[month]! {
                print("   • \(g.rubric): \(g.value)")
            }
        }
    }

    // MARK: - Key

    private struct Key: Hashable {
        let month: Int
        let rubric: String
    }
}

