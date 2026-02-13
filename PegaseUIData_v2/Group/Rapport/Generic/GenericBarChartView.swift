//
//  GenericBarChartView.swift
//  PegaseUIData
//
//  Generic view for bar charts
//  Replaces CategorieBar1, CategorieBar2, RubriqueBar, RecetteDepenseBar views
//

import SwiftUI
import SwiftData
import DGCharts
import AppKit
import UniformTypeIdentifiers

// MARK: - Generic Bar Chart View

/// Generic view for displaying bar charts
/// Configurable via data extractor strategy
struct GenericBarChartView<ViewModel: GenericBarChartViewModel>: View {

    @StateObject var viewModel: ViewModel

    let transactions: [EntityTransaction]
    let title: String
    let showCategoryFilter: Bool
    let showExportButton: Bool

    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    /// Closure to create the bar chart representable
    let barChartBuilder: (_ viewModel: ViewModel, _ entries: [BarChartDataEntry], _ onSelectBar: @escaping (Int, DataGraph) -> Void) -> AnyView

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    @State private var chartView: BarChartView?
    @State private var selectedItem: DataGraph? = nil
    @State private var filteredTransactions: [EntityTransaction] = []
    @State private var sliderFilteredTransactions: [EntityTransaction] = []

    private let oneDay = 3600.0 * 24.0

    private var totalDaysRange: ClosedRange<Double> {
        viewModel.computeTotalDaysRange(minDate: minDate, maxDate: maxDate)
    }

    var body: some View {
        VStack {
            // Title
            Text(title)
                .font(.headline)
                .padding()

            // Total value
            Text("Total: \(viewModel.totalValue, format: .currency(code: viewModel.currencyCode))")
                .font(.title3)
                .bold()
                .padding(.bottom, 4)

            // Category filter (optional)
            if showCategoryFilter && !viewModel.labels.isEmpty {
                categoryFilterView
            }

            // Export button (optional)
            if showExportButton {
                Button("Export to PNG") {
                    exportChartAsImage()
                }
                .padding(.bottom, 8)
            }

            // Chart
            chartContentView

            // Filter GroupBox
            filterGroupBox

            Spacer()
        }
        .onAppear {
            let listTransactions = ListTransactionsManager.shared.getAllData()
            sliderFilteredTransactions = listTransactions
            filteredTransactions = listTransactions
            minDate = listTransactions.first?.datePointage ?? Date()
            maxDate = listTransactions.last?.datePointage ?? Date()
            selectedEnd = maxDate.timeIntervalSince(minDate) / oneDay

            chartView = BarChartView()
            if let chartView = chartView {
                viewModel.configure(with: chartView)
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

    // MARK: - Subviews

    private var categoryFilterView: some View {
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

    private var chartContentView: some View {
        Group {
            if viewModel.dataEntries.isEmpty {
                emptyChartPlaceholder
            } else {
                barChartBuilder(viewModel, viewModel.dataEntries) { index, item in
                    selectedItem = item
                    // Filter transactions by the selected bar item
                    filteredTransactions = viewModel.dataExtractorRef.filterTransactions(
                        sliderFilteredTransactions,
                        by: item.name,
                        transactionType: nil
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: 400)
                .padding()
                .onAppear {
                    viewModel.loadTransactions(from: minDate, to: maxDate)
                }
            }
        }
    }

    private var emptyChartPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
            Text("No entries over the period")
                .foregroundStyle(.secondary)
        }
        .frame(width: 600, height: 400)
        .padding()
    }

    private var filterGroupBox: some View {
        GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("From \(viewModel.formattedDate(from: selectedStart, baseDate: minDate)) to \(viewModel.formattedDate(from: selectedEnd, baseDate: minDate))")
                    .font(.callout)
                    .foregroundColor(.secondary)

                RangeSlider(
                    lowerValue: $selectedStart,
                    upperValue: $selectedEnd,
                    totalRange: totalDaysRange,
                    valueLabel: { value in
                        viewModel.sliderDateLabel(value, baseDate: minDate)
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

    // MARK: - Actions

    private func updateChart() {
        guard minDate <= maxDate else { return }
        let start = Calendar.current.date(byAdding: .day, value: Int(selectedStart), to: minDate)!
        let end = Calendar.current.date(byAdding: .day, value: Int(selectedEnd), to: minDate)!
        guard start <= end else { return }

        viewModel.updateChartData(startDate: start, endDate: end)

        // Update slider-filtered transactions (all transactions in the date range)
        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        sliderFilteredTransactions = all.filter { tx in
            tx.datePointage >= start && tx.datePointage <= end
        }

        // Clear bar selection when slider changes
        selectedItem = nil
        filteredTransactions = sliderFilteredTransactions
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

// MARK: - Generic Section Bar Chart View

/// Generic view for bar charts grouped by section (month/year)
struct GenericSectionBarChartView: View {

    @StateObject private var viewModel = GenericSectionBarChartViewModel()

    let transactions: [EntityTransaction]
    let title: String
    let showRubricPicker: Bool

    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    /// Closure to create the bar chart representable
    let barChartBuilder: (_ entries: [BarChartDataEntry], _ labels: [String]) -> AnyView

    @AppStorage("RubriqueBar.selectedRubrique") private var storedRubrique: String = ""

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    @State private var filteredTransactions: [EntityTransaction] = []

    private var totalDaysRange: ClosedRange<Double> {
        viewModel.computeTotalDaysRange(minDate: minDate, maxDate: maxDate)
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()

            // Rubric picker (optional)
            if showRubricPicker {
                HStack(spacing: 12) {
                    Text("Rubric:")
                    Picker("Rubric", selection: $viewModel.nameRubrique) {
                        ForEach(viewModel.availableRubrics, id: \.self) { rub in
                            Text(rub.isEmpty ? String(localized: "(All)") : rub).tag(rub)
                        }
                    }
                    .frame(maxWidth: 260)
                }
                .padding(.horizontal)
                .onChange(of: viewModel.nameRubrique) { _, newValue in
                    storedRubrique = newValue
                    updateChart()
                }
            }

            // Chart
            if viewModel.dataEntries.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                    Text("No entries over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                barChartBuilder(viewModel.dataEntries, viewModel.labels)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .padding()
            }

            // Filter GroupBox
            GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From \(viewModel.formattedDate(from: selectedStart, baseDate: minDate)) to \(viewModel.formattedDate(from: selectedEnd, baseDate: minDate))")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    RangeSlider(
                        lowerValue: $selectedStart,
                        upperValue: $selectedEnd,
                        totalRange: totalDaysRange,
                        valueLabel: { value in
                            viewModel.sliderDateLabel(value, baseDate: minDate)
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
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            filteredTransactions = ListTransactionsManager.shared.getAllData()
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

    private func updateChart() {
        guard minDate <= maxDate else { return }
        let start = Calendar.current.date(byAdding: .day, value: Int(selectedStart), to: minDate)!
        let end = Calendar.current.date(byAdding: .day, value: Int(selectedEnd), to: minDate)!
        guard start <= end else { return }

        viewModel.updateChartData(startDate: start, endDate: end)

        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        filteredTransactions = all.filter { tx in
            tx.datePointage >= start && tx.datePointage <= end
        }
    }
}

// MARK: - Simple Bar Chart View (for CategorieBar2)

/// Simple bar chart view without selection handling
struct GenericSimpleBarChartView: View {

    @StateObject private var viewModel: GenericBarChartViewModel

    let transactions: [EntityTransaction]
    let title: String

    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    /// Closure to create the bar chart representable
    let barChartBuilder: (_ entries: [BarChartDataEntry], _ labels: [String]) -> AnyView

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    @State private var filteredTransactions: [EntityTransaction] = []

    private var totalDaysRange: ClosedRange<Double> {
        viewModel.computeTotalDaysRange(minDate: minDate, maxDate: maxDate)
    }

    init(
        transactions: [EntityTransaction],
        title: String,
        minDate: Binding<Date>,
        maxDate: Binding<Date>,
        dashboard: Binding<DashboardState>,
        dataExtractor: ChartDataExtractor,
        barChartBuilder: @escaping (_ entries: [BarChartDataEntry], _ labels: [String]) -> AnyView
    ) {
        self._viewModel = StateObject(wrappedValue: GenericBarChartViewModel(dataExtractor: dataExtractor))
        self.transactions = transactions
        self.title = title
        self._minDate = minDate
        self._maxDate = maxDate
        self._dashboard = dashboard
        self.barChartBuilder = barChartBuilder
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()

            // Chart
            if viewModel.dataEntries.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                    Text("No entries over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                barChartBuilder(viewModel.dataEntries, viewModel.labels)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .padding()
            }

            // Filter GroupBox
            GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From \(viewModel.formattedDate(from: selectedStart, baseDate: minDate)) to \(viewModel.formattedDate(from: selectedEnd, baseDate: minDate))")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    RangeSlider(
                        lowerValue: $selectedStart,
                        upperValue: $selectedEnd,
                        totalRange: totalDaysRange,
                        valueLabel: { value in
                            viewModel.sliderDateLabel(value, baseDate: minDate)
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
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            filteredTransactions = ListTransactionsManager.shared.getAllData()
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

        viewModel.updateChartData(startDate: start, endDate: end)

        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        filteredTransactions = all.filter { tx in
            tx.datePointage >= start && tx.datePointage <= end
        }
    }
}
