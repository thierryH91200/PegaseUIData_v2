//
//  RubriqueBar.swift
//  PegaseUIData
//
//  Created by thierryH24 on 22/09/2025.
//


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

struct RubriqueBar: View {
    
    @StateObject private var viewModel = RubriqueBarViewModel()

    let transactions: [EntityTransaction]
    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState
    
    @AppStorage("RubriqueBar.selectedRubrique") private var storedRubrique: String = ""
    
    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    @State private var filteredTransactions: [EntityTransaction] = []
    @State private var sliderFilteredTransactions: [EntityTransaction] = []
    @State private var selectedBarIndex: Int? = nil

    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Picker("Rubric", selection: $viewModel.nameRubrique) {
                    ForEach(viewModel.availableRubrics, id: \.self) { rub in
                        Text(rub.isEmpty ? String(localized: "(All)") : rub).tag(rub)
                    }
                }
                .font(.headline)
                .frame(maxWidth: 260)
            }
            .padding(.horizontal)
            .onChange(of: viewModel.nameRubrique) { _, newValue in
                storedRubrique = newValue
                updateChart()
            }
            if viewModel.dataEntries.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                    Text("No expenses over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                
                DGBarChart5Representable(
                    viewModel: viewModel,
                    entries: viewModel.dataEntries,
                    title: String(localized: "Rubric Bar Chart"),
                    labels: viewModel.labels,
                    selectedIndex: $selectedBarIndex
                )
                .frame(maxWidth: .infinity,maxHeight: 400)
                .padding()
                .onChange(of: selectedBarIndex) { _, index in
                    guard let index else {
                        // Bar deselected: restore slider-filtered transactions
                        filteredTransactions = sliderFilteredTransactions
                        return
                    }
                    guard index < viewModel.labels.count else { return }

                    // labels are section codes (e.g. "202511", "202512")
                    let sectionCode = viewModel.labels[index]
                    let cal = Calendar.current
                    let monthCode = Int(sectionCode) ?? 0
                    let year = monthCode / 100
                    let month = monthCode % 100

                    filteredTransactions = sliderFilteredTransactions.filter { tx in
                        // Filter by month (using datePointage for consistency)
                        let comps = cal.dateComponents([.year, .month], from: tx.datePointage)
                        guard comps.year == year && comps.month == month else { return false }

                        // If a specific rubric is selected in the Picker, also filter by rubric
                        if !viewModel.nameRubrique.isEmpty {
                            return tx.sousOperations.contains { $0.category?.rubric?.name == viewModel.nameRubrique }
                        }
                        return true
                    }
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
                            sliderDateLabel(value)
                        },
                        thumbSize: 24,
                        trackHeight: 6
                    )
                    .frame(height: 30)
                }
                .padding(.top, 4)
                .padding(.horizontal)
                TransactionListContainer(dashboard: $dashboard, filteredTransactions: filteredTransactions)
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
            viewModel.nameRubrique = storedRubrique
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
        guard start <= end else { return }
        viewModel.updateChartData(startDate: start, endDate: end)

        // Met à jour les transactions filtrées par le slider
        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        sliderFilteredTransactions = all.filter { tx in
            tx.datePointage >= start && tx.datePointage <= end
        }

        // Clear bar selection when slider changes
        selectedBarIndex = nil
        filteredTransactions = sliderFilteredTransactions
    }
    
    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
