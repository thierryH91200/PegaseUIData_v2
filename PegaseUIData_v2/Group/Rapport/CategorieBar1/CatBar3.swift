////
////  CatBar.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 16/04/2025.
////
//
import SwiftUI
import SwiftData
import DGCharts
import Combine
import UniformTypeIdentifiers
import AppKit


struct CategorieBar1View1: View {

    @StateObject private var viewModel = CategorieBar1ViewModel()

    let transactions: [EntityTransaction]

    @Binding var minDate: Date
    @Binding var maxDate: Date

    @Binding var dashboard: DashboardState

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    private let oneDay = 3600.0 * 24.0 // one day

    @State private var chartView: BarChartView?
    @State private var selectedItem: DataGraph? = nil
    @State private var filteredTransactions: [EntityTransaction] = []
    @State private var sliderFilteredTransactions: [EntityTransaction] = []

    
    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    var body: some View {
        VStack {
            Text("CategorieBar1View1")
                .font(.headline)
                .padding()

            Text("Total: \(viewModel.totalValue, format: .currency(code: viewModel.currencyCode))")
                .font(.title3)
                .bold()
                .padding(.bottom, 4)

            if !viewModel.labels.isEmpty {
                DisclosureGroup("Visible categories") {
                    Button(viewModel.selectedCategories.count < viewModel.labels.count ? "All select" : "Deselect all") {
                        if viewModel.selectedCategories.count < viewModel.labels.count {
                            viewModel.selectedCategories = Set(viewModel.labels)
                        } else {
                            viewModel.selectedCategories.removeAll()
                        }
                        updateChart()
                    }
                    .font(.caption)
                    .padding(.bottom, 4)

                    ForEach(viewModel.labels, id: \.self) { label in
                        Toggle(label, isOn: Binding(
                            get: { viewModel.selectedCategories.isEmpty || viewModel.selectedCategories.contains(label) },
                            set: { newValue in
                                if newValue {
                                    viewModel.selectedCategories.insert(label)
                                } else {
                                    viewModel.selectedCategories.remove(label)
                                }
                                updateChart()
                            }
                        ))
                    }
                }
                .padding()
            }
            Button("Export to PNG") {
                exportChartAsImage()
            }
            .padding(.bottom, 8)

            if viewModel.dataEntries.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                    Text("No entries over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                
                DGBarChart7Representable(
                    viewModel: viewModel,
                    entries: viewModel.dataEntries,
                    onSelectBar: { index, item in
                        if index < 0 {
                            // Clear selection: restore slider-filtered transactions
                            selectedItem = nil
                            filteredTransactions = sliderFilteredTransactions
                        } else {
                            selectedItem = item
                            // Filter slider-filtered transactions by the selected rubric
                            filteredTransactions = sliderFilteredTransactions.filter { tx in
                                tx.sousOperations.contains { $0.category?.rubric?.name == item.name }
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: 400)
                .padding()
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
        }

        .onAppear {

            let listTransactions = ListTransactionsManager.shared.getAllData()
            sliderFilteredTransactions = listTransactions
            filteredTransactions = listTransactions  // Initialiser avec toutes les transactions
            minDate = listTransactions.first?.datePointage ?? Date()
            maxDate = listTransactions.last?.datePointage ?? Date()
            selectedEnd = maxDate.timeIntervalSince(minDate) / oneDay

            chartView = BarChartView()
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

        // 1) Met à jour le graphique en barres
        viewModel.updateChartData(startDate: start, endDate: end)

        // 2) Met à jour les transactions filtrées par le slider
        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        sliderFilteredTransactions = all.filter { tx in
            tx.datePointage >= start && tx.datePointage <= end
        }

        // 3) Clear bar selection when slider changes
        selectedItem = nil
        filteredTransactions = sliderFilteredTransactions
    }

    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func exportChartAsImage() {
        guard let chartView = chartView else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Graphique.png"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            if let image = chartView.getChartImage(transparent: false),
               let rep = NSBitmapImageRep(data: image.tiffRepresentation!),
               let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }

}
