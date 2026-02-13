//////
//////  CategorieBar23.swift
//////  PegaseUIData
//////
//////  Created by Thierry hentic on 17/04/2025.
//////
////
import SwiftUI
import SwiftData
import DGCharts


struct CategorieBar2View2: View {
        
    @StateObject var viewModel : CategoryBar2ViewModel

    let transactions: [EntityTransaction]

    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30

    @State private var chartView: BarChartView?
    @State private var selectedItem: DataGraph? = nil
    @State private var filteredTransactions: [EntityTransaction] = []
    @State private var sliderFilteredTransactions: [EntityTransaction] = []
    
    var body: some View {
        VStack {
            Text("CategorieBar2View2")
                .font(.headline)
                .padding()
            HStack {
                if viewModel.graphData.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No entries over the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {
                                        
                    DGBarChart2Representable(
                        data: {
                            return viewModel.graphData
                        }(),
                        valueFormatter: {
                            let nf = NumberFormatter()
                            nf.numberStyle = .currency
                            return nf
                        }(),
                        onSelectBar: { index, item in
                            selectedItem = item

                            // Filter by rubric AND month
                            let cal = Calendar.current
                            let monthCode = Int(item.section) ?? 0  // e.g. 202512
                            let year = monthCode / 100
                            let month = monthCode % 100

                            filteredTransactions = sliderFilteredTransactions.filter { tx in
                                let matchesRubric = tx.sousOperations.contains { $0.category?.rubric?.name == item.name }
                                guard matchesRubric else { return false }
                                let comps = cal.dateComponents([.year, .month], from: tx.datePointage)
                                return comps.year == year && comps.month == month
                            }
                        },
                        onClearSelection: {
                            // Restore to slider-filtered transactions
                            filteredTransactions = sliderFilteredTransactions
                            selectedItem = nil
                        },
                        isStacked: false
                    )
                    .frame(maxWidth: .infinity, maxHeight: 400)
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
                            sliderDateLabel( value)
                        },
                        thumbSize: 24,
                        trackHeight: 6
                    )
                    .frame(height: 30)
                }
                .padding(.top, 4)
                .padding(.horizontal)
                TransactionListContainer(
                    dashboard: $dashboard,
                    filteredTransactions: filteredTransactions
                )
            }
            .padding()
            Spacer()
        }
        .onAppear {
            // Initialize slider bounds based on available data
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            // Initialiser avec toutes les transactions
            let allTransactions = ListTransactionsManager.shared.getAllData()
            sliderFilteredTransactions = allTransactions
            filteredTransactions = allTransactions
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
        .onChange(of: selectedStart) { _, _ in
            updateChart()
        }
        .onChange(of: selectedEnd) { _, _ in
            updateChart()
        }
    }
    
    private func sliderDateLabel(_ value: Double) -> String {
        let cal = Calendar.current
        let base = cal.startOfDay(for: minDate)
        let date = cal.date(byAdding: .day, value: Int(value), to: base) ?? base

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    
    private func updateChart() {
        guard minDate <= maxDate else { return }
        let start = Calendar.current.date(byAdding: .day, value: Int(selectedStart), to: minDate)!
        let end = Calendar.current.date(byAdding: .day, value: Int(selectedEnd), to: minDate)!

        #if DEBUG
        print("[CategorieBar23] updateChart start:", start, "end:", end)
        #endif

        guard start <= end else { return }

        // Fetch transactions for the period
        let txInRange = ListTransactionsManager.shared.getAllData(from: start, to: end)
        viewModel.listTransactions = txInRange

        // Build monthly grouped data (graphData) for the bar chart
        viewModel.buildGraphData(transactions: txInRange, startDate: start, endDate: end)

        #if DEBUG
        print("[CategorieBar23] graphData count after update:", viewModel.graphData.count)
        #endif

        // Met à jour les transactions filtrées par le slider
        sliderFilteredTransactions = txInRange
        selectedItem = nil
        filteredTransactions = sliderFilteredTransactions
    }
    
    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

}


