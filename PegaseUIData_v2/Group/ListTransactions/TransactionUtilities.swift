//
//  TransactionUtilities.swift
//  PegaseUIData
//
//  Created by Claude Code on 14/01/2026.
//  Consolidated utility functions for transaction list management
//

import SwiftUI
import Foundation

// MARK: - Data Structures

/// Represents a group of transactions by year
struct YearGroup {
    var year: Int
    var monthGroups: [MonthGroup]
}

/// Represents a group of transactions by month
struct MonthGroup {
    var month: String
    var transactions: [EntityTransaction]
}

/// Alternative year grouping structure
struct TransactionsByYear: Identifiable {
    let id = UUID()
    let year: String
    let months: [TransactionsByMonth]
}

/// Alternative month grouping structure
struct TransactionsByMonth: Identifiable {
    let id = UUID()
    let year: String
    let month: Int
    let transactions: [EntityTransaction]

    /// Formatted month name (e.g., "February")
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL"
        if let transaction = transactions.first {
            let date = transaction.datePointage
            return formatter.string(from: date).capitalized
        }
        return String(localized: "Unknown Month")
    }

    /// Total amount for the month
    var totalAmount: Double {
        transactions.reduce(0.0) { $0 + $1.amount }
    }
}

/// Year-Month composite key for grouping
struct YearMonth: Hashable {
    let year: String
    let month: Int
}

// MARK: - Grouping Functions

/// Groups transactions by year and month
/// - Parameter transactions: Array of transactions to group
/// - Returns: Array of YearGroup sorted by year (descending)
func groupTransactionsByYear(transactions: [EntityTransaction]) -> [YearGroup] {
    var groupedItems: [YearGroup] = []
    let calendar = Calendar.current

    // Group transactions by year
    let groupedByYear = Dictionary(grouping: transactions) { (transaction) -> Int in
        let components = calendar.dateComponents([.year], from: transaction.datePointage)
        return components.year ?? 0
    }

    for (year, yearTransactions) in groupedByYear {
        var yearGroup = YearGroup(year: year, monthGroups: [])

        let groupedByMonth = Dictionary(grouping: yearTransactions) { (transaction) -> Int in
            let components = calendar.dateComponents([.month], from: transaction.datePointage)
            return components.month ?? 0
        }

        for (month, monthTransactions) in groupedByMonth.sorted(by: { $0.key > $1.key }) {
            let monthName = DateFormatter().monthSymbols[month - 1]
            let monthGroup = MonthGroup(
                month: monthName,
                transactions: monthTransactions.sorted(by: { $0.datePointage > $1.datePointage })
            )

            yearGroup.monthGroups.append(monthGroup)
        }

        groupedItems.append(yearGroup)
    }

    return groupedItems.sorted(by: { $0.year > $1.year })
}

/// Alternative grouping function using string-based years
/// - Parameter transactions: Array of transactions to group
/// - Returns: Array of TransactionsByYear sorted by year (descending)
func groupTransactionsByYearString(transactions: [EntityTransaction]) -> [TransactionsByYear] {
    var dictionaryByYear: [String: [TransactionsByMonth]] = [:]
    var yearMonthDict: [YearMonth: [EntityTransaction]] = [:]

    for transaction in transactions {
        guard let yearString = transaction.sectionYear else { continue }
        let datePointage = transaction.datePointage
        let calendar = Calendar.current
        let month = calendar.component(.month, from: datePointage)

        let key = YearMonth(year: yearString, month: month)
        yearMonthDict[key, default: []].append(transaction)
    }

    // Convert yearMonthDict to dictionaryByYear
    for (yearMonth, trans) in yearMonthDict {
        let byMonth = TransactionsByMonth(year: yearMonth.year, month: yearMonth.month, transactions: trans)
        dictionaryByYear[yearMonth.year, default: []].append(byMonth)
    }

    var result: [TransactionsByYear] = []
    for (year, monthsArray) in dictionaryByYear {
        let sortedMonths = monthsArray.sorted { $0.month > $1.month }
        result.append(TransactionsByYear(year: year, months: sortedMonths))
    }

    return result.sorted { $0.year > $1.year }
}

// MARK: - Formatting Functions

/// Formats a price with the current locale's currency
/// - Parameter amount: Amount to format
/// - Returns: Formatted currency string
func formatPrice(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
}

/// Cleans a string to extract a valid Double value
/// - Parameter string: String potentially containing a numeric value
/// - Returns: Extracted Double or 0.0 if parsing fails
func cleanDouble(from string: String) -> Double {
    // Remove all non-numeric characters except comma and dot
    let cleanedString = string.filter { "0123456789,.".contains($0) }

    // Convert comma to dot if necessary
    let normalized = cleanedString.replacingOccurrences(of: ",", with: ".")

    return Double(normalized) ?? 0.0
}

// MARK: - View Components

/// SwiftUI view for displaying prices with automatic currency formatting
struct PriceText: View {
    let amount: Double

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }
}

/// Gradient text view component
struct GradientText: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.custom("Silom", size: 16))
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Date Extensions
extension Date {
    /// Formats the date for display (short format, no time)
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user copies selected transactions (Cmd+C)
    static let copySelectedTransactions = Notification.Name("copySelectedTransactions")

    /// Posted when user cuts selected transactions (Cmd+X)
    static let cutSelectedTransactions = Notification.Name("cutSelectedTransactions")

    /// Posted when user pastes transactions (Cmd+V)
    static let pasteSelectedTransactions = Notification.Name("pasteSelectedTransactions")

    /// Posted when user selects all transactions (Cmd+A)
    static let selectAllTransactions = Notification.Name("selectAllTransactions")

    /// Posted when transaction selection changes
    static let transactionsSelectionChanged = Notification.Name("transactionsSelectionChanged")
}
