//
//  ChartDataProviders.swift
//  PegaseUIData
//
//  Generic protocols and strategies for chart data extraction
//  Enables factorization of 24+ report views into reusable components
//

import SwiftUI
import DGCharts

// MARK: - Data Extraction Strategy Protocol

/// Protocol defining how to extract chart data from transactions
/// Each report type implements this differently (by category, rubric, paymentMode, etc.)
protocol ChartDataExtractor {
    /// Extract data from transactions for the chart
    func extractData(from transactions: [EntityTransaction]) -> [DataGraph]

    /// Filter transactions based on a selected item name
    func filterTransactions(_ transactions: [EntityTransaction], by itemName: String, transactionType: TransactionTypeFilter?) -> [EntityTransaction]
}

// MARK: - Transaction Type Filter

enum TransactionTypeFilter {
    case expense
    case income

    var isExpense: Bool { self == .expense }
}

// MARK: - Concrete Data Extractors

/// Extracts data grouped by Rubric (from sousOperations)
struct RubricDataExtractor: ChartDataExtractor {
    func extractData(from transactions: [EntityTransaction]) -> [DataGraph] {
        var dataArray: [DataGraph] = []

        for transaction in transactions {
            for sousOperation in transaction.sousOperations {
                if let rubric = sousOperation.category?.rubric {
                    let name = rubric.name
                    let value = sousOperation.amount
                    let color = rubric.color
                    dataArray.append(DataGraph(name: name, value: value, color: color))
                }
            }
        }

        return groupAndSum(dataArray)
    }

    func filterTransactions(_ transactions: [EntityTransaction], by itemName: String, transactionType: TransactionTypeFilter?) -> [EntityTransaction] {
        transactions.filter { tx in
            let hasRubric = tx.sousOperations.contains { $0.category?.rubric?.name == itemName }
            if let type = transactionType {
                let isExpense = tx.amount < 0
                let matchesType = (type == .expense && isExpense) || (type == .income && !isExpense)
                return hasRubric && matchesType
            }
            return hasRubric
        }
    }
}

/// Extracts data grouped by Payment Mode
struct PaymentModeDataExtractor: ChartDataExtractor {
    func extractData(from transactions: [EntityTransaction]) -> [DataGraph] {
        var dataArray: [DataGraph] = []

        for transaction in transactions {
            let name = transaction.paymentMode?.name ?? "Inconnu"
            let color = transaction.paymentMode?.color ?? .gray
            dataArray.append(DataGraph(name: name, value: transaction.amount, color: color))
        }

        return groupAndSum(dataArray)
    }

    func filterTransactions(_ transactions: [EntityTransaction], by itemName: String, transactionType: TransactionTypeFilter?) -> [EntityTransaction] {
        transactions.filter { tx in
            let matchesPaymentMode = tx.paymentMode?.name == itemName
            if let type = transactionType {
                let isExpense = tx.amount < 0
                let matchesType = (type == .expense && isExpense) || (type == .income && !isExpense)
                return matchesPaymentMode && matchesType
            }
            return matchesPaymentMode
        }
    }
}

/// Extracts data grouped by Category
struct CategoryDataExtractor: ChartDataExtractor {
    func extractData(from transactions: [EntityTransaction]) -> [DataGraph] {
        var dataArray: [DataGraph] = []

        for transaction in transactions {
            for sousOperation in transaction.sousOperations {
                if let category = sousOperation.category {
                    let name = category.name
                    let value = sousOperation.amount
                    let color = category.rubric?.color  ?? NSColor.black
                    dataArray.append(DataGraph(name: name, value: value, color: color))
                }
            }
        }

        return groupAndSum(dataArray)
    }

    func filterTransactions(_ transactions: [EntityTransaction], by itemName: String, transactionType: TransactionTypeFilter?) -> [EntityTransaction] {
        transactions.filter { tx in
            let hasCategory = tx.sousOperations.contains { $0.category?.name == itemName }
            if let type = transactionType {
                let isExpense = tx.amount < 0
                let matchesType = (type == .expense && isExpense) || (type == .income && !isExpense)
                return hasCategory && matchesType
            }
            return hasCategory
        }
    }
}

/// Extracts data grouped by Section (month/year) with optional rubric filter
struct SectionRubricDataExtractor: ChartDataExtractor {
    var rubricFilter: String = ""

    func extractData(from transactions: [EntityTransaction]) -> [DataGraph] {
        var dataArray: [DataGraph] = []
        var color = NSColor.blue

        for transaction in transactions {
            let section = transaction.sectionIdentifier ?? ""
            var value = 0.0

            for sousOperation in transaction.sousOperations {
                let rubricName = sousOperation.category?.rubric?.name ?? ""
                if rubricFilter.isEmpty || rubricName == rubricFilter {
                    value += sousOperation.amount
                    if let c = sousOperation.category?.rubric?.color { color = c }
                }
            }

            dataArray.append(DataGraph(section: section, name: section, value: value, color: color))
        }

        // Group by section and sum
        let allKeys = Set(dataArray.map { $0.section })
        var results: [DataGraph] = []
        for key in allKeys.sorted() {
            let data = dataArray.filter { $0.section == key }
            let sum = data.map { $0.value }.reduce(0, +)
            results.append(DataGraph(section: key, name: key, value: sum, color: color))
        }

        return results
    }

    func filterTransactions(_ transactions: [EntityTransaction], by itemName: String, transactionType: TransactionTypeFilter?) -> [EntityTransaction] {
        transactions.filter { tx in
            tx.sectionIdentifier == itemName
        }
    }
}

// MARK: - Helper Functions

/// Groups DataGraph items by name and sums their values
private func groupAndSum(_ dataArray: [DataGraph]) -> [DataGraph] {
    let allKeys = Set(dataArray.map { $0.name })
    var results: [DataGraph] = []

    for key in allKeys {
        let data = dataArray.filter { $0.name == key }
        let sum = data.map { $0.value }.reduce(0, +)
        if let color = data.first?.color {
            results.append(DataGraph(name: key, value: sum, color: color))
        }
    }

    return results.sorted { $0.name < $1.name }
}

/// Splits DataGraph array into expense and income arrays with optional max categories
func splitByTransactionType(_ data: [DataGraph], maxCategories: Int = 6) -> (expenses: [DataGraph], incomes: [DataGraph]) {
    let expenses = data.filter { $0.value < 0 }
    let incomes = data.filter { $0.value >= 0 }

    return (
        summarizeData(from: expenses, maxCategories: maxCategories),
        summarizeData(from: incomes, maxCategories: maxCategories)
    )
}

/// Summarizes data to a maximum number of categories, grouping extras into "Autres"
func summarizeData(from array: [DataGraph], maxCategories: Int = 6) -> [DataGraph] {
    let grouped = Dictionary(grouping: array, by: { $0.name })

    let summarized = grouped.map { (key, values) in
        let total = values.map { $0.value }.reduce(0, +)
        return DataGraph(name: key, value: total, color: values.first?.color ?? .gray)
    }

    let sorted = summarized.sorted { abs($0.value) > abs($1.value) }

    if sorted.count <= maxCategories {
        return sorted
    }

    let main = sorted.prefix(maxCategories)
    let other = sorted.dropFirst(maxCategories)

    let totalOthers = other.map { $0.value }.reduce(0, +)
    let othersData = DataGraph(name: "Autres", value: totalOthers, color: .gray)

    return Array(main) + [othersData]
}

// MARK: - Pie Chart Entry Conversion

func pieChartEntries(from array: [DataGraph]) -> [PieChartDataEntry] {
    array.map {
        PieChartDataEntry(value: abs($0.value), label: $0.name, data: $0)
    }
}

// MARK: - Bar Chart Entry Conversion

func barChartEntries(from array: [DataGraph]) -> [BarChartDataEntry] {
    array.enumerated().map { index, item in
        BarChartDataEntry(x: Double(index), y: item.value)
    }
}
