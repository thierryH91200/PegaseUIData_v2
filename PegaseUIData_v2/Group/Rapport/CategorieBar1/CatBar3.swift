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

    
    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    private let oneDay = 3600.0 * 24.0 // one day
    
    @State private var chartView: BarChartView?
    @State private var selectedItem: DataGraph? = nil
    
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
                        selectedItem = item
                    })
                .frame(maxWidth: .infinity, maxHeight: 400)
                .padding()
                .onAppear {
                    viewModel.updateAccount(minDate: minDate)
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
                        .frame(height: 50)
                }
                .padding(.top, 4)
                .padding(.horizontal)
                ListTransactionsView100(dashboard: $dashboard)

            }
            .padding()
            Spacer()
        }
        .onAppear {
            
            let listTransactions = ListTransactionsManager.shared.getAllData()
            minDate = listTransactions.first?.dateOperation ?? Date()
            maxDate = listTransactions.last?.dateOperation ?? Date()
            selectedEnd = maxDate.timeIntervalSince(minDate) / oneDay

            chartView = BarChartView()
            if let chartView = chartView {
                CategorieBar1ViewModel.shared.configure(with: chartView)
            }
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
        let cal = Calendar.current
        let base = cal.startOfDay(for: minDate)

        // Calcul des bornes de période alignées sur la journée civile
        let start = cal.date(byAdding: .day, value: Int(selectedStart), to: base)!
        let endInclusive = cal.date(byAdding: .day, value: Int(selectedEnd), to: base)!
        let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endInclusive))!

        // 1) Met à jour le graphique en barres (endInclusive pour inclure la journée complète)
        viewModel.updateChartData(startDate: start, endDate: endInclusive)

        // 2) Met à jour la liste globale des transactions pour synchroniser la liste et les autres vues
        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)

        // Filtrage par dateOperation afin d'être cohérent avec minDate/maxDate obtenues dans onAppear
        let filtered = all.filter { tx in
            tx.dateOperation >= start && tx.dateOperation < endExclusive
        }

        if ListTransactionsManager.shared.listTransactions != filtered {
            ListTransactionsManager.shared.listTransactions = filtered
            NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
            NotificationCenter.default.post(name: .treasuryChartNeedsRefresh, object: nil)
        }
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

    private func findChartView(in window: NSWindow?) -> BarChartView? {
        guard let views = window?.contentView?.subviews else { return nil }
        for view in views {
            if let chart = view.subviews.compactMap({ $0 as? BarChartView }).first {
                return chart
            }
        }
        return nil
    }
}


