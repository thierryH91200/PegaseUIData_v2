//
//  GenericPieChartView.swift
//  PegaseUIData
//
//  Generic view for dual pie charts (expenses/income)
//  Replaces RubriquePie, RecetteDepensePie, ModePaiementPie views
//

import SwiftUI
import SwiftData
import DGCharts

// MARK: - Generic Dual Pie Chart View

/// Generic view for displaying expense/income pie charts
/// Configurable via data extractor strategy
struct GenericDualPieChartView<ViewModel: GenericPieChartViewModel>: View {

    @StateObject var viewModel: ViewModel

    let transactions: [EntityTransaction]
    let title: String
    let expenseTitle: String
    let incomeTitle: String

    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    /// Closure to create the pie chart representable
    let pieChartBuilder: (_ entries: [PieChartDataEntry], _ title: String, _ onSelect: @escaping (String?) -> Void, _ onClear: @escaping () -> Void) -> AnyView

    @State private var selectedItem: String? = nil
    @State private var selectedTransactionType: TransactionTypeFilter? = nil
    @State private var sliderFilteredTransactions: [EntityTransaction] = []

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30

    private var totalDaysRange: ClosedRange<Double> {
        viewModel.computeTotalDaysRange(minDate: minDate, maxDate: maxDate)
    }

    private var filteredTransactions: [EntityTransaction] {
        guard let selectedName = selectedItem else {
            return sliderFilteredTransactions
        }

        if selectedName == "Autres" {
            return sliderFilteredTransactions
        }

        return viewModel.filterTransactions(sliderFilteredTransactions, by: selectedName, transactionType: selectedTransactionType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            headerView

            // Charts
            HStack {
                expenseChartView
                incomeChartView
            }

            // Filter GroupBox
            filterGroupBox

            Spacer()
        }
        .onAppear {
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
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

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(title)
                .font(.headline)

            if let item = selectedItem, let type = selectedTransactionType {
                let typeLabel = type == .expense ? String(localized: "Expense") : String(localized: "Income")
                Text("[\(typeLabel): \(item)]")
                    .font(.caption)
                    .foregroundColor(type == .expense ? .red : .green)
            }
        }
        .padding()
    }

    private var expenseChartView: some View {
        Group {
            if viewModel.dataEntriesDepense.isEmpty {
                emptyChartPlaceholder(message: String(localized: "No expenses over the period"))
            } else {
                pieChartBuilder(
                    viewModel.dataEntriesDepense,
                    expenseTitle,
                    { label in
                        withAnimation {
                            selectedItem = label
                            selectedTransactionType = .expense
                        }
                    },
                    {
                        selectedItem = nil
                        selectedTransactionType = nil
                    }
                )
                .frame(width: 600, height: 400)
                .padding()
            }
        }
    }

    private var incomeChartView: some View {
        Group {
            if viewModel.dataEntriesRecette.isEmpty {
                emptyChartPlaceholder(message: String(localized: "No receipts for the period"))
            } else {
                pieChartBuilder(
                    viewModel.dataEntriesRecette,
                    incomeTitle,
                    { label in
                        withAnimation {
                            selectedItem = label
                            selectedTransactionType = .income
                        }
                    },
                    {
                        selectedItem = nil
                        selectedTransactionType = nil
                    }
                )
                .frame(width: 600, height: 400)
                .padding()
            }
        }
    }

    private func emptyChartPlaceholder(message: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(width: 600, height: 400)
        .padding()
    }

    private var filterGroupBox: some View {
        GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("From \(viewModel.formattedDate(from: selectedStart, baseDate: minDate)) to \(viewModel.formattedDate(from: selectedEnd, baseDate: minDate))")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    if let item = selectedItem, let type = selectedTransactionType {
                        Spacer()
                        selectionBadge(item: item, type: type)
                    }
                }

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

            TransactionListContainer(
                dashboard: $dashboard,
                filteredTransactions: filteredTransactions
            )
            .id("\(selectedItem ?? "all")_\(selectedTransactionType == .expense ? "expense" : selectedTransactionType == .income ? "income" : "none")")
        }
        .padding()
    }

    private func selectionBadge(item: String, type: TransactionTypeFilter) -> some View {
        HStack {
            let typeLabel = type == .expense ? String(localized: "Expense") : String(localized: "Income")
            Text("\(typeLabel): \(item)")
                .font(.callout)
                .foregroundColor(type == .expense ? .red : .green)
            Button(action: {
                selectedItem = nil
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

    // MARK: - Data Update

    private func updatePieData() {
        guard selectedStart <= selectedEnd else { return }
        guard minDate <= maxDate else { return }

        guard let range = viewModel.computeDateRange(minDate: minDate, selectedStart: selectedStart, selectedEnd: selectedEnd) else {
            return
        }

        viewModel.updateChartData(startDate: range.start, endDate: range.end)

        sliderFilteredTransactions = viewModel.filterTransactionsBySlider(
            minDate: minDate,
            selectedStart: selectedStart,
            selectedEnd: selectedEnd
        )
    }
}

// MARK: - Convenience Initializers

extension GenericDualPieChartView {
    /// Create a rubric-based pie chart view
    static func rubricPie(
        transactions: [EntityTransaction],
        minDate: Binding<Date>,
        maxDate: Binding<Date>,
        dashboard: Binding<DashboardState>
    ) -> GenericDualPieChartView<GenericPieChartViewModel> {
        GenericDualPieChartView<GenericPieChartViewModel>(
            viewModel: GenericPieChartViewModel(dataExtractor: RubricDataExtractor()),
            transactions: transactions,
            title: String(localized: "Rubrique Pie"),
            expenseTitle: String(localized: "Expenses"),
            incomeTitle: String(localized: "Receipts"),
            minDate: minDate,
            maxDate: maxDate,
            dashboard: dashboard,
            pieChartBuilder: { entries, title, onSelect, onClear in
                AnyView(
                    SinglePie3ChartView(
                        entries: entries,
                        title: title,
                        onSelectSlice: onSelect,
                        onClearSelection: onClear
                    )
                )
            }
        )
    }

    /// Create a payment mode-based pie chart view
    static func paymentModePie(
        transactions: [EntityTransaction],
        minDate: Binding<Date>,
        maxDate: Binding<Date>,
        dashboard: Binding<DashboardState>
    ) -> GenericDualPieChartView<GenericPieChartViewModel> {
        GenericDualPieChartView<GenericPieChartViewModel>(
            viewModel: GenericPieChartViewModel(dataExtractor: PaymentModeDataExtractor()),
            transactions: transactions,
            title: String(localized: "Mode Paiement Pie"),
            expenseTitle: String(localized: "Expenses"),
            incomeTitle: String(localized: "Receipts"),
            minDate: minDate,
            maxDate: maxDate,
            dashboard: dashboard,
            pieChartBuilder: { entries, title, onSelect, onClear in
                AnyView(
                    SinglePie1ChartView(
                        entries: entries,
                        title: title,
                        onSelectSlice: onSelect,
                        onClearSelection: onClear
                    )
                )
            }
        )
    }

    /// Create a recette/depense pie chart view
    static func recetteDepensePie(
        transactions: [EntityTransaction],
        minDate: Binding<Date>,
        maxDate: Binding<Date>,
        dashboard: Binding<DashboardState>
    ) -> GenericDualPieChartView<GenericPieChartViewModel> {
        GenericDualPieChartView<GenericPieChartViewModel>(
            viewModel: GenericPieChartViewModel(dataExtractor: PaymentModeDataExtractor()),
            transactions: transactions,
            title: String(localized: "Recette Depense Pie"),
            expenseTitle: String(localized: "Expenses"),
            incomeTitle: String(localized: "Receipts"),
            minDate: minDate,
            maxDate: maxDate,
            dashboard: dashboard,
            pieChartBuilder: { entries, title, onSelect, onClear in
                AnyView(
                    SinglePie2ChartView(
                        entries: entries,
                        title: title,
                        onSelectSlice: onSelect,
                        onClearSelection: onClear
                    )
                )
            }
        )
    }
}
