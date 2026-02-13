//
//  Untitled 3.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

struct RubriquePie: View {
    
    @StateObject private var viewModel = RubriquePieViewModel()
    
    let transactions: [EntityTransaction]
    
    @Binding var minDate: Date
    @Binding var maxDate: Date
    
    @Binding var dashboard: DashboardState

    @State private var selectedRubrique: String? = nil
    @State private var selectedTransactionType: TransactionType? = nil
    @State private var sliderFilteredTransactions: [EntityTransaction] = []

    enum TransactionType {
        case expense
        case income
    }

    private var filteredTransactions: [EntityTransaction] {
        guard let selectedRubric = selectedRubrique else {
            // Pas de rubrique sélectionnée, retourner les transactions filtrées par le slider
            return sliderFilteredTransactions
        }

        // If "Autres" is selected, we can't filter properly
        if selectedRubric == "Autres" {
            return sliderFilteredTransactions
        }

        let filtered = sliderFilteredTransactions.filter { transaction in
            // Filter by rubrique from sousOperations
            let hasSousOperationWithRubric = transaction.sousOperations.contains { sousOp in
                sousOp.category?.rubric?.name == selectedRubric
            }

            // Also filter by transaction type if specified
            if let type = selectedTransactionType {
                let isExpense = transaction.amount < 0
                let matchesType = (type == .expense && isExpense) || (type == .income && !isExpense)
                return hasSousOperationWithRubric && matchesType
            }
            return hasSousOperationWithRubric
        }

        printTag("Selected rubrique: \(selectedRubric), Type: \(String(describing: selectedTransactionType)), Filtered count: \(filtered.count), Total: \(sliderFilteredTransactions.count)")

        return filtered
    }

    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    
    var body: some View {
        VStack {
            HStack {
                Text(String(localized:"Rubrique pie"))
                    .font(.headline)

                if let rubrique = selectedRubrique, let type = selectedTransactionType {
                    let typeLabel = type == .expense ? "Expense" : "Income"
                    Text("[\(typeLabel): \(rubrique)]")
                        .font(.caption)
                        .foregroundColor(type == .expense ? .red : .green)
                }
            }
            .padding()
            
            HStack {
                if viewModel.dataEntriesDepense.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No expenses over the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {

                    SinglePie3ChartView(
                        entries: viewModel.dataEntriesDepense,
                        title: String(localized : "Expenses"),
                        onSelectSlice: { label in
                            printTag("Expense slice selected: \(label ?? "nil")")
                            withAnimation {
                                selectedRubrique = label
                                selectedTransactionType = .expense
                            }
                            printTag("State after expense selection - Rubrique: \(selectedRubrique ?? "nil"), Type: \(String(describing: selectedTransactionType))")
                        },
                        onClearSelection: {
                            printTag("Selection cleared")
                            selectedRubrique = nil
                            selectedTransactionType = nil
                        }
                    )
                    .frame(width: 600, height: 400)
                    .padding()
                }
                if viewModel.dataEntriesRecette.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No receipts for the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {
                    SinglePie3ChartView(
                        entries: viewModel.dataEntriesRecette,
                        title: String(localized : "Receipts"),
                        onSelectSlice: { label in
                            printTag("Income slice selected: \(label ?? "nil")")
                            withAnimation {
                                selectedRubrique = label
                                selectedTransactionType = .income
                            }
                            printTag("State after income selection - Rubrique: \(selectedRubrique ?? "nil"), Type: \(String(describing: selectedTransactionType))")
                        },
                        onClearSelection: {
                            printTag("Selection cleared")
                            selectedRubrique = nil
                            selectedTransactionType = nil
                        }
                    )
                    .frame(width: 600, height: 400)
                    .padding()
                }
            }
            GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("From \(formattedDate(from: selectedStart)) to \(formattedDate(from: selectedEnd))")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        if let rubrique = selectedRubrique, let type = selectedTransactionType {
                            Spacer()
                            HStack {
                                let typeLabel = type == .expense ? "Expense" : "Income"
                                Text("\(typeLabel): \(rubrique)")
                                    .font(.callout)
                                    .foregroundColor(type == .expense ? .red : .green)
                                Button(action: {
                                    selectedRubrique = nil
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
                .padding(.top, 4)
                .padding(.horizontal)
                TransactionListContainer(
                    dashboard: $dashboard,
                    filteredTransactions: filteredTransactions
                )
                .id("\(selectedRubrique ?? "all")_\(selectedTransactionType == .expense ? "expense" : selectedTransactionType == .income ? "income" : "none")")
            }
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
    
    func formattedDate(from dayOffset: Double) -> String {
        let cal = Calendar.current
        let base = cal.startOfDay(for: minDate)
        let date = cal.date(byAdding: .day, value: Int(dayOffset), to: base) ?? base
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
