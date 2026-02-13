//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

struct RecetteDepensePie: View {
    
    @StateObject private var viewModel = RecetteDepensePieViewModel()
    
    let transactions: [EntityTransaction]
    
    @Binding var minDate: Date
    @Binding var maxDate: Date
    
    @Binding var dashboard: DashboardState

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30

    @State private var selectedPaymentMode: String? = nil
    @State private var selectedTransactionType: TransactionType? = nil
    @State private var sliderFilteredTransactions: [EntityTransaction] = []

    enum TransactionType {
        case expense
        case income
    }

    private var filteredTransactions: [EntityTransaction] {
        guard let selectedMode = selectedPaymentMode else {
            // Pas de mode sélectionné, retourner les transactions filtrées par le slider
            return sliderFilteredTransactions
        }

        // If "Autres" is selected, we can't filter properly
        if selectedMode == "Autres" {
            return sliderFilteredTransactions
        }

        let filtered = sliderFilteredTransactions.filter { transaction in
            let matchesPaymentMode = transaction.paymentMode?.name == selectedMode

            // Also filter by transaction type if specified
            if let type = selectedTransactionType {
                let isExpense = transaction.amount < 0
                let matchesType = (type == .expense && isExpense) || (type == .income && !isExpense)
                return matchesPaymentMode && matchesType
            }

            return matchesPaymentMode
        }
        return filtered
    }

    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }
    
    private var headerView: some View {
        HStack {
            HStack {
                Text(String(localized:"Recette Dépense Pie"))
                    .font(.headline)

                if let mode = selectedPaymentMode, let type = selectedTransactionType {
                    let typeLabel = type == .expense ? "Expense" : "Income"
                    Text("[\(typeLabel): \(mode)]")
                        .font(.caption)
                        .foregroundColor(type == .expense ? .red : .green)
                }
            }
            .padding()
        }
    }
    
    private var expenseChartView: some View {
        Group {
            if viewModel.dataEntriesDepense.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                    Text("No expenses over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                SinglePie2ChartView(
                    entries: viewModel.dataEntriesDepense,
                    title: String(localized : "Expenses"),
                    onSelectSlice: { label in
                        withAnimation {
                            selectedPaymentMode = label
                            selectedTransactionType = .expense
                        }
                    },
                    onClearSelection: {
                        selectedPaymentMode = nil
                        selectedTransactionType = nil
                    }
                )
                .frame(width: 600, height: 400)
                .padding()
            }
        }
    }
    
    private var recetteChartView: some View {
        Group {
            if viewModel.dataEntriesRecette.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                    Text("No receipts over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                SinglePie2ChartView(
                    entries: viewModel.dataEntriesRecette,
                    title: String(localized : "Receipts"),
                    onSelectSlice: { label in
                        withAnimation {
                            selectedPaymentMode = label
                            selectedTransactionType = .income
                        }
                    },
                    onClearSelection: {
                        selectedPaymentMode = nil
                        selectedTransactionType = nil
                    }
                )
                .frame(width: 600, height: 400)
                .padding()
            }
        }
    }
    
    private var dateRangeText: some View {
        Text("From \(formattedDate(from: selectedStart)) to \(formattedDate(from: selectedEnd))")
            .font(.callout)
            .foregroundColor(.secondary)
    }
    
    private var selectionBadge: some View {
        Group {
            if let mode = selectedPaymentMode, let type = selectedTransactionType {
                HStack {
                    let typeLabel = type == .expense ? "Expense" : "Income"
                    Text("\(typeLabel): \(mode)")
                        .font(.callout)
                        .foregroundColor(type == .expense ? .red : .green)
                    Button(action: {
                        selectedPaymentMode = nil
                        selectedTransactionType = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((type == .expense ? Color.red : Color.green).opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var rangeSliderView: some View {
        RangeSlider(
            lowerValue: $selectedStart,
            upperValue: $selectedEnd,
            totalRange: totalDaysRange,
            valueLabel: { value in
                sliderDateLabel(value)
            },
            thumbSize: 24,
            trackHeight: 6
        )
        .frame(height: 30)
    }
    
    private var transactionList: some View {
        TransactionListContainer(
            dashboard: $dashboard,
            filteredTransactions: filteredTransactions
        )
        .id("\(selectedPaymentMode ?? "all")_\(selectedTransactionType == .expense ? "expense" : selectedTransactionType == .income ? "income" : "none")")
    }
    
    private var filterGroupBox: some View {
        GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    dateRangeText
                    if selectedPaymentMode != nil && selectedTransactionType != nil {
                        Spacer()
                        selectionBadge
                    }
                }
                
                rangeSliderView
            }
            .padding(.top, 4)
            .padding(.horizontal)
            
            transactionList
        }
        .padding()
    }

    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            HStack {
                expenseChartView
                recetteChartView
            }
            
            filterGroupBox
            
            Spacer()
        }
        .onAppear {
            // Initialize slider bounds based on available data
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            // Initialiser avec toutes les transactions
            sliderFilteredTransactions = ListTransactionsManager.shared.getAllData()
            updatePieData()
        }
        .onChange(of: minDate) { _, _ in
            selectedStart = 0
            updatePieData()
        }
        .onChange(of: maxDate) { _, _ in
            selectedEnd = totalDaysRange.upperBound
            updatePieData()
        }
        .onChange(of: selectedStart) { _, _ in
            updatePieData()
        }
        .onChange(of: selectedEnd) { _, _ in
            updatePieData()
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
    
    private func updatePieData() {
        // Ensure prerequisites are valid
        guard selectedStart <= selectedEnd else { return }
        guard minDate <= maxDate else { return }

        let calendar = Calendar.current
        let startOfMin = calendar.startOfDay(for: minDate)

        guard let start = calendar.date(byAdding: .day, value: Int(selectedStart), to: startOfMin),
              let endRaw = calendar.date(byAdding: .day, value: Int(selectedEnd), to: startOfMin) else {
            return
        }

        // Clamp to maxDate then extend to end-of-day for inclusive range
        let endClamped = min(endRaw, maxDate)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: endClamped)) ?? endClamped

        viewModel.updateChartData(startDate: start, endDate: endOfDay)

        // Met à jour les transactions filtrées par le slider
        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        sliderFilteredTransactions = all.filter { tx in
            tx.datePointage >= start && tx.datePointage <= endOfDay
        }
    }
    
    private func updateChart() {
        let start = Calendar.current.date(byAdding: .day,
                                          value: Int(selectedStart),
                                          to: minDate)!
        let end = Calendar.current.date(byAdding: .day,
                                        value: Int(selectedEnd),
                                        to: minDate)!
        viewModel.updateChartData( startDate: start, endDate: end)
    }
    
    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

