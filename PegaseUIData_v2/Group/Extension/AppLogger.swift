//
//  AppLogger.swift
//  PegaseUIData
//
//  Created by Claude Code on 14/01/2026.
//

import Foundation
import OSLog

/// Centralized logging system for PegaseUIData using OSLog
///
/// Usage:
/// ```swift
/// AppLogger.transactions.info("Transaction created: \(transactionID)")
/// AppLogger.data.error("Failed to save: \(error)")
/// ```
enum AppLogger {

    // MARK: - Logger Categories

    /// Logs related to transaction operations (create, update, delete)
    static let transactions = Logger(subsystem: subsystem, category: "transactions")

    /// Logs related to data persistence and SwiftData operations
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Logs related to UI interactions and view lifecycle
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Logs related to import/export operations (CSV, OFX)
    static let importExport = Logger(subsystem: subsystem, category: "import-export")

    /// Logs related to account management
    static let account = Logger(subsystem: subsystem, category: "account")

    /// Logs related to reports and charts
    static let reports = Logger(subsystem: subsystem, category: "reports")

    /// Logs related to scheduling and recurring transactions
    static let scheduler = Logger(subsystem: subsystem, category: "scheduler")

    /// Logs related to bank reconciliation
    static let reconciliation = Logger(subsystem: subsystem, category: "reconciliation")

    // MARK: - Configuration

    private static let subsystem = "com.pegase.uidata"
}

// MARK: - Legacy Compatibility

/// Temporary compatibility function to replace printTag() calls
/// TODO: Gradually replace all printTag() calls with AppLogger usage
//@available(*, deprecated, message: "Use AppLogger instead")
func printTag(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
    AppLogger.ui.debug("\(logMessage)")

    #if DEBUG
    print("🔍 \(logMessage)")
    #endif
}
