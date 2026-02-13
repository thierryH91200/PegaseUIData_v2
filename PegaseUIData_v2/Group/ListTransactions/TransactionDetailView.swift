//
//  TransactionDetailView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 23/03/2025.
//  Refactored by Claude Code on 14/01/2026.
//

import SwiftUI
import SwiftData

/// Displays detailed information about a single transaction in a popover
///
/// Features:
/// - Shows all transaction fields (dates, amounts, status, payment method)
/// - Displays sub-operation details (comment, category, rubric)
/// - Navigation to previous/next transactions
/// - Formatted dates and currency amounts
struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss

    private var transaction: EntityTransaction {
        ListTransactionsManager.shared.listTransactions[currentSectionIndex]
    }

    @State var currentSectionIndex: Int
    @Binding var selectedTransaction: Set<UUID>
    @State var refresh = false

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: - Navigation Buttons
            navigationButtons

            // MARK: - Header
            Text("Transaction Details")
                .font(.title)
                .bold()
                .padding(.bottom, 10)

            // MARK: - Metadata
            metadataSection

            Divider()

            // MARK: - Transaction Details
            transactionDetailsSection

            Divider()

            // MARK: - Sub-Operation Details
            subOperationSection

            Spacer()

            // MARK: - Close Button
            closeButton
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            if let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.uuid == selectedTransaction.first }) {
                currentSectionIndex = index
            }
        }
    }

    // MARK: - View Components

    private var navigationButtons: some View {
        HStack {
            Button(action: { showPreviousSection() }) {
                Text("◀️")
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .disabled(currentSectionIndex == 0)

            Spacer()

            Button(action: { showNextSection() }) {
                Text("▶️")
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .disabled(currentSectionIndex >= ListTransactionsManager.shared.listTransactions.count - 1)
        }
        .padding()
    }

    private var metadataSection: some View {
        Group {
            detailRow(
                label: String(localized: "Created at :"),
                value: Self.dateFormatter.string(from: transaction.createAt)
            )
            detailRow(
                label: String(localized: "Update at :"),
                value: Self.dateFormatter.string(from: transaction.updatedAt)
            )
        }
    }

    private var transactionDetailsSection: some View {
        Group {
            HStack {
                Text("Amount :")
                    .bold()
                Spacer()
                Text(transaction.amount, format: .currency(code: currencyCode))
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
            }

            Divider()

            detailRow(
                label: String(localized: "Date of pointing :"),
                value: Self.dateFormatter.string(from: transaction.datePointage)
            )
            detailRow(
                label: String(localized: "Date operation :"),
                value: Self.dateFormatter.string(from: transaction.dateOperation)
            )
            detailRow(
                label: String(localized: "Payment method :"),
                value: transaction.paymentMode?.name ?? "—"
            )
            detailRow(
                label: String(localized: "Bank Statement :"),
                value: String(transaction.bankStatement)
            )
            detailRow(
                label: String(localized: "Status :"),
                value: transaction.status?.name ?? "N/A"
            )
        }
    }

    private var subOperationSection: some View {
        Group {
            if let premiereSousOp = transaction.sousOperations.first {
                detailRow(
                    label: String(localized: "Comment :"),
                    value: premiereSousOp.libelle ?? String(localized: "No description")
                )
                detailRow(
                    label: String(localized: "Rubric :"),
                    value: premiereSousOp.category?.rubric?.name ?? "N/A"
                )
                detailRow(
                    label: String(localized: "Category :"),
                    value: premiereSousOp.category?.name ?? "N/A"
                )
                HStack {
                    Text("Amount :")
                        .bold()
                    Spacer()
                    Text(premiereSousOp.amount, format: .currency(code: currencyCode))
                        .foregroundColor(premiereSousOp.amount >= 0 ? .green : .red)
                }
            } else {
                Text("No sub-operations available")
                    .italic()
                    .foregroundColor(.gray)
            }
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Text("Close")
                    .frame(width: 100)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Spacer()
        }
    }

    /// Reusable detail row component
    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .bold()
            Spacer()
            Text(value)
        }
    }

    // MARK: - Private Methods

    private func showPreviousSection() {
        guard currentSectionIndex > 0 else { return }
        currentSectionIndex -= 1
    }

    private func showNextSection() {
        guard currentSectionIndex < ListTransactionsManager.shared.listTransactions.count - 1 else { return }
        currentSectionIndex += 1
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }
}
