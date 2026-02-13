//
//  GenericChartViewModel.swift
//  PegaseUIData
//
//  Base ViewModel for all chart views
//  Handles common data loading, filtering, and formatting logic
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

// MARK: - Generic Chart ViewModel

/// Base ViewModel that handles common chart functionality:
/// - Transaction loading and filtering by date range
/// - Currency formatting
/// - Slider date range computation
@MainActor
class GenericChartViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var listTransactions: [EntityTransaction] = []
    @Published var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"

    @Published var selectedStart: Double = 0
    @Published var selectedEnd: Double = 30

    @Published var firstDate: TimeInterval = 0.0
    @Published var lastDate: TimeInterval = 0.0

    // MARK: - Formatters

    let formatterPrice: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .currency
        return formatter
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    // MARK: - Date Range Computation

    /// Compute total days range from min/max dates
    func computeTotalDaysRange(minDate: Date, maxDate: Date) -> ClosedRange<Double> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: minDate)
        let end = calendar.startOfDay(for: maxDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    /// Compute actual start/end dates from slider values
    func computeDateRange(minDate: Date, selectedStart: Double, selectedEnd: Double) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let startOfMin = calendar.startOfDay(for: minDate)

        guard let start = calendar.date(byAdding: .day, value: Int(selectedStart), to: startOfMin),
              let endRaw = calendar.date(byAdding: .day, value: Int(selectedEnd), to: startOfMin) else {
            return nil
        }

        // Extend to end-of-day for inclusive range
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: endRaw)) ?? endRaw

        return (start, endOfDay)
    }

    // MARK: - Date Formatting

    func formattedDate(from dayOffset: Double, baseDate: Date) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: Int(dayOffset), to: baseDate) ?? baseDate
        return dateFormatter.string(from: date)
    }

    func sliderDateLabel(_ value: Double, baseDate: Date) -> String {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: baseDate)
        let date = calendar.date(byAdding: .day, value: Int(value), to: base) ?? base
        return shortDateFormatter.string(from: date)
    }

    // MARK: - Transaction Loading

    /// Load transactions for a date range
    func loadTransactions(from startDate: Date, to endDate: Date) {
        listTransactions = ListTransactionsManager.shared.getAllData(from: startDate, to: endDate)
    }

    /// Filter transactions by date range from slider values
    func filterTransactionsBySlider(minDate: Date, selectedStart: Double, selectedEnd: Double) -> [EntityTransaction] {
        guard let range = computeDateRange(minDate: minDate, selectedStart: selectedStart, selectedEnd: selectedEnd) else {
            return []
        }

        let all = ListTransactionsManager.shared.getAllData(from: nil, to: nil, ascending: true)
        return all.filter { tx in
            tx.datePointage >= range.start && tx.datePointage <= range.end
        }
    }
}

// MARK: - Pie Chart ViewModel

/// ViewModel for dual pie charts (expense/income)
@MainActor
class GenericPieChartViewModel: GenericChartViewModel {

    @Published var depenseArray: [DataGraph] = []
    @Published var recetteArray: [DataGraph] = []

    @Published var dataEntriesDepense: [PieChartDataEntry] = []
    @Published var dataEntriesRecette: [PieChartDataEntry] = []

    private let dataExtractor: ChartDataExtractor

    init(dataExtractor: ChartDataExtractor) {
        self.dataExtractor = dataExtractor
        super.init()
    }

    /// Update chart data for a date range
    func updateChartData(startDate: Date, endDate: Date) {
        loadTransactions(from: startDate, to: endDate)

        let allData = dataExtractor.extractData(from: listTransactions)

        // Split into expense and income
        var expenseData: [DataGraph] = []
        var incomeData: [DataGraph] = []

        for item in allData {
            if item.value < 0 {
                expenseData.append(item)
            } else {
                incomeData.append(item)
            }
        }

        // Summarize with max categories
        self.depenseArray = summarizeData(from: expenseData, maxCategories: 6)
        self.recetteArray = summarizeData(from: incomeData, maxCategories: 6)

        // Convert to pie chart entries
        self.dataEntriesDepense = pieChartEntries(from: depenseArray)
        self.dataEntriesRecette = pieChartEntries(from: recetteArray)
    }

    /// Filter transactions based on selection
    func filterTransactions(_ transactions: [EntityTransaction], by itemName: String, transactionType: TransactionTypeFilter?) -> [EntityTransaction] {
        if itemName == "Autres" {
            return transactions
        }
        return dataExtractor.filterTransactions(transactions, by: itemName, transactionType: transactionType)
    }
}

// MARK: - Bar Chart ViewModel

/// ViewModel for bar charts
@MainActor
class GenericBarChartViewModel: GenericChartViewModel {

    @Published var dataGraph: [DataGraph] = []
    @Published var dataEntries: [BarChartDataEntry] = []
    @Published var selectedCategories: Set<String> = []

    @Published var isBarSelectionActive: Bool = false
    private var fullFilteredCache: [EntityTransaction] = []

    weak var chartView: BarChartView?

    private let dataExtractor: ChartDataExtractor

    /// Public read access to the data extractor for filtering in views
    var dataExtractorRef: ChartDataExtractor { dataExtractor }

    var totalValue: Double {
        dataGraph.map { $0.value }.reduce(0, +)
    }

    var labels: [String] {
        dataGraph.map { $0.name }
    }

    init(dataExtractor: ChartDataExtractor) {
        self.dataExtractor = dataExtractor
        super.init()
    }

    func configure(with chartView: BarChartView) {
        self.chartView = chartView
    }

    /// Update chart data for a date range
    func updateChartData(startDate: Date, endDate: Date) {
        loadTransactions(from: startDate, to: endDate)

        guard !listTransactions.isEmpty else {
            self.dataGraph = []
            self.dataEntries = []
            return
        }

        var results = dataExtractor.extractData(from: listTransactions)

        // Apply category filter if any
        if !selectedCategories.isEmpty {
            results = results.filter { selectedCategories.contains($0.name) }
        }

        let sorted = results.sorted { $0.name < $1.name }
        self.dataGraph = sorted
        self.dataEntries = barChartEntries(from: sorted)
    }

    /// Handle bar selection - filter transactions by selected item
    func handleBarSelection(itemName: String) {
        if fullFilteredCache.isEmpty {
            fullFilteredCache = listTransactions
        }

        let filtered = dataExtractor.filterTransactions(fullFilteredCache, by: itemName, transactionType: nil)

        var didChange = false
        if ListTransactionsManager.shared.listTransactions != filtered {
            ListTransactionsManager.shared.listTransactions = filtered
            didChange = true
        }
        if self.listTransactions != filtered {
            self.listTransactions = filtered
            didChange = true
        }
        if didChange {
            NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
        }
        self.isBarSelectionActive = true
    }

    /// Clear bar selection
    func clearBarSelection() {
        let restored = self.fullFilteredCache
        self.fullFilteredCache.removeAll()

        var didChange = false
        if ListTransactionsManager.shared.listTransactions != restored {
            ListTransactionsManager.shared.listTransactions = restored
            didChange = true
        }
        if self.listTransactions != restored {
            self.listTransactions = restored
            didChange = true
        }
        if didChange {
            NotificationCenter.default.post(name: .transactionsSelectionChanged, object: nil)
        }
        self.isBarSelectionActive = false
    }
}

// MARK: - Section Bar Chart ViewModel

/// ViewModel for bar charts grouped by section (month/year)
@MainActor
class GenericSectionBarChartViewModel: GenericChartViewModel {

    @Published var resultArray: [DataGraph] = []
    @Published var dataEntries: [BarChartDataEntry] = []
    @Published var nameRubrique: String = ""
    @Published var availableRubrics: [String] = []

    var labels: [String] {
        resultArray.map { $0.name }
    }

    /// Update chart data for a date range with optional rubric filter
    func updateChartData(startDate: Date, endDate: Date) {
        loadTransactions(from: startDate, to: endDate)

        // Build available rubrics
        let rubricSet = Set(listTransactions.flatMap { txn in
            txn.sousOperations.compactMap { $0.category?.rubric?.name }
        })
        self.availableRubrics = [""] + rubricSet.sorted()

        var extractor = SectionRubricDataExtractor()
        extractor.rubricFilter = nameRubrique

        self.resultArray = extractor.extractData(from: listTransactions)
        self.dataEntries = barChartEntries(from: resultArray)
    }
}
