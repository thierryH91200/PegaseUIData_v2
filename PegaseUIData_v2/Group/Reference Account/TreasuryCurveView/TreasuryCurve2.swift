//
//  Untitled 3.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import AppKit


struct TreasuryCurve: View {
    
    @Binding var dashboard: DashboardState

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @StateObject private var viewModel = TresuryLineViewModel()

    @Binding var allTransactions: [EntityTransaction]
    @State private var filteredTransactions: [EntityTransaction] = []

    @State private var lowerValue: Double = 0
    @State private var upperValue: Double = 0
    
    @State private var minDate: Date = Date()
    @State private var maxDate: Date = Date()
    
    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30

    
    @State private var lower: Double = 2
    @State private var upper: Double = 10

    @AppStorage("enableSoundFeedback") private var enableSoundFeedback: Bool = true

    private var durationDays: Double {
        maxDate.timeIntervalSince(minDate) / 86400
    }

    private var totalAmount: Double {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }
    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        let upper = max(1, days)
        return 0...Double(upper)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Treasury curve")
                    .font(.headline)
                    .padding()

                DGLineChartRepresentable(viewModel: viewModel,
                                         entries: viewModel.dataEntries)

                    .frame(width: geometry.size.width, height: 400)
                    .padding()
                    .onAppear {
                        refreshData(for: currentAccountManager.getAccount())
                    }
                    .onChange(of: currentAccountManager.getAccount()) { _, newAccount in
                        refreshData(for: newAccount)
                    }

                GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected period : \(dateFromOffset(selectedStart)) → \(dateFromOffset(selectedEnd))")
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
                        .frame(height: 50)
                        .onAppear {
                            dashboard.isVisible = true

                            // Initialize slider bounds based on available data
                            selectedStart = 0
                            selectedEnd = max(1, totalDaysRange.upperBound)
                            if selectedEnd <= selectedStart {
                                selectedEnd = selectedStart + 1
                            }
                            updateChart()
                        }

                        .onChange(of: selectedStart) { _, _ in applyFilter() }
                        .onChange(of: selectedEnd) { _, _ in applyFilter() }

                        Text("\(selectedDays()) days — \(filteredTransactions.count) transaction\(filteredTransactions.count > 1 ? "s" : "") — Total: \(formattedAmount(totalAmount))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        ListTransactionsView100(
                            dashboard: $dashboard)
                        .frame(height: 600)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers
    private func updateChart() {
        guard minDate <= maxDate else { return }
        let start = Calendar.current.date(byAdding: .day, value: Int(selectedStart), to: minDate)!
        let end = Calendar.current.date(byAdding: .day, value: Int(selectedEnd), to: minDate)!
        guard start <= end else { return }
        viewModel.updateChartData()
    }


    private func refreshData(for account: EntityAccount?) {
        guard let account = account else {
            allTransactions = []
            filteredTransactions = []
            return
        }

        allTransactions = ListTransactionsManager.shared
            .getAllData()
            .filter { $0.account == account }
            .sorted { $0.dateOperation < $1.dateOperation }

        guard let first = allTransactions.first?.dateOperation,
              let last = allTransactions.last?.dateOperation else {
            return
        }

        minDate = first
        maxDate = last

        selectedStart = 0
        selectedEnd = max(1, durationDays)

        viewModel.listTransactions = allTransactions
        viewModel.lowerValue = selectedStart
        viewModel.upperValue = selectedEnd
        viewModel.updateChartData()

        applyFilter()
    }

    private func applyFilter() {
        // Clamp offsets to a valid, non-zero range
        let safeUpperBound = max(totalDaysRange.upperBound, 1)
        let startOffset = max(0, min(selectedStart, safeUpperBound - 1))
        let endOffset = max(startOffset + 1, min(selectedEnd, safeUpperBound))

        let startDate = Calendar.current.date(byAdding: .day, value: Int(startOffset), to: minDate) ?? minDate
        let endDate = Calendar.current.date(byAdding: .day, value: Int(endOffset), to: minDate) ?? maxDate

        filteredTransactions = allTransactions.filter {
            $0.dateOperation >= startDate && $0.dateOperation <= endDate
        }

        viewModel.lowerValue = startOffset
        viewModel.upperValue = endOffset
        viewModel.updateChartData()
    }

    private func selectedDays() -> Int {
        Int(selectedEnd - selectedStart + 1)
    }

    private func dateFromOffset(_ offset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(offset), to: minDate) ?? minDate
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

