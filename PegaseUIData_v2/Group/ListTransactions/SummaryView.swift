//
//  SummaryView.swift
//  PegaseUIData
//
//  Created by Claude Code on 14/01/2026.
//  Displays account balance summary (Final, Actual, Bank balances)
//

import SwiftUI

/// Displays a summary of account balances with three columns:
/// - Final balance (planned + engaged + executed)
/// - Actual balance (engaged + executed)
/// - Bank balance (executed only)
///
/// Note: Transaction statuses:
/// - Planned: Future estimated transactions with modifiable amounts
/// - Engaged: Committed transactions awaiting clearance
/// - Executed: Cleared/pointed transactions from bank statements
struct SummaryView: View {
    @Binding var dashboard: DashboardState

    var body: some View {
        HStack(spacing: 0) {

            // Final Balance (Planned + Engaged + Executed)
            balanceCard(
                title: String(localized: "Final balance"),
                amount: dashboard.planned,
                color: .purple
            )

            // Actual Balance (Engaged + Executed)
            balanceCard(
                title: String(localized: "Actual balance"),
                amount: dashboard.engaged,
                color: .green
            )

            // Bank Balance (Executed only)
            balanceCard(
                title: String(localized: "Bank balance"),
                amount: dashboard.executed,
                color: .red
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Private Components

    /// Creates a balance card with title, amount, and color
    @ViewBuilder
    private func balanceCard(title: String, amount: Double, color: Color) -> some View {
        VStack {
            Text(title)
            Text(amount, format: .currency(code: currencyCode))
                .font(.title)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.cyan.opacity(0.1), Color.cyan.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .border(Color.black, width: 1)
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }
}


