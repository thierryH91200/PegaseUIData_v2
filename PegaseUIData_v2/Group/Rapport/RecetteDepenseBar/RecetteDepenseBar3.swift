////
////  RecetteDepenseBar3.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

struct RecetteDepenseView: View {
    
    @StateObject private var viewModel = RecetteDepenseBarViewModel()

    let transactions: [EntityTransaction]
    @Binding var dashboard: DashboardState


    @Binding var minDate: Date
    @Binding var maxDate: Date
    
    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }
    @State private var data: BarChartData?
    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    private let oneDay = 3600.0 * 24.0 // one day
    
    @State private var chartView: BarChartView?

    var body: some View {
        
        VStack {
            Text(String(localized:"RecetteDepenseBar3"))
                .font(.headline)
                .padding()
            
            HStack {
                if viewModel.dataEntriesRecette.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No receipts over the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {
                    DGBarChart4Representable(
                        entries: viewModel.dataEntriesRecette,
                        title: "Recettes",
                        labels: viewModel.recetteArray.map {$0.name},
                        data: data,
                        lowerValue: $selectedStart,
                        upperValue: $selectedEnd
                    )
                    .frame(maxWidth: .infinity,maxHeight: 400)
                    .padding()
                }
            }
            GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From \(formattedDate(from: selectedStart)) to \(formattedDate(from: selectedEnd))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    RangeSlider(
                        lowerValue: $selectedStart,
                        upperValue: $selectedEnd,
                        totalRange: totalDaysRange,
                        valueLabel: { value in
                            let cal = Calendar.current
                            let base = cal.startOfDay(for: minDate)
                            let date = cal.date(byAdding: .day, value: Int(value), to: base) ?? base
                            let formatter = DateFormatter()
                            formatter.dateStyle = .short
                            let date1 = formatter.string(from: date)
                            return date1
                        },
                        thumbSize: 24,
                        trackHeight: 6
                    )
                    .frame(height: 30)
                    ListTransactionsView100(dashboard: $dashboard)
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.horizontal)
            }
        }
        .onAppear {
            let listTransactions = ListTransactionsManager.shared.getAllData()
            if let first = listTransactions.first?.dateOperation, let last = listTransactions.last?.dateOperation {
                minDate = first
                maxDate = last
                selectedStart = 0
                selectedEnd = max(0, maxDate.timeIntervalSince(minDate) / oneDay)
            } else {
                let now = Date()
                minDate = now
                maxDate = now
                selectedStart = 0
                selectedEnd = 0
            }
            chartView = BarChartView()
            if let chartView = chartView {
                CategorieBar1ViewModel.shared.configure(with: chartView)
            }
            updateChart()
        }
        .onChange(of: minDate) { _, _ in
            selectedStart = 0
            updateChart()
        }
        .onChange(of: maxDate) { _, _ in
            selectedEnd = totalDaysRange.upperBound
            updateChart()
        }
        .onChange(of: selectedStart) { _, newStart in
            viewModel.selectedStart = newStart
            updateChart()
        }
        .onChange(of: selectedEnd) { _, newEnd in
            viewModel.selectedEnd = newEnd
            updateChart()
        }
    }
    
    private func updateChart() {
        guard minDate <= maxDate else { return }
        let start = Calendar.current.date(byAdding: .day, value: Int(selectedStart), to: minDate)!
        let end = Calendar.current.date(byAdding: .day, value: Int(selectedEnd), to: minDate)!
        guard start <= end else { return }
        let result = viewModel.computeChartData(startDate: start, endDate: end)
        viewModel.depenseArray = result.expense
        viewModel.recetteArray = result.income
        if let chartView = chartView {
            data = viewModel.applyData(expense: result.expense, income: result.income, to: chartView)
        }

        let depenseEntries = result.expense.enumerated().map { (idx, item) in
            BarChartDataEntry(x: Double(idx), y: item.value)
        }
        let recetteEntries = result.income.enumerated().map { (idx, item) in
            BarChartDataEntry(x: Double(idx), y: item.value)
        }
        DispatchQueue.main.async {
            viewModel.dataEntriesDepense = depenseEntries
            viewModel.dataEntriesRecette = recetteEntries
        }
    }

    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

