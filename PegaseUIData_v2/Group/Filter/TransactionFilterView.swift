//
//  TransactionFilterView.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 16/01/2026.
//

import SwiftUI
import SwiftData
import Combine

/// Vue complète avec PredicateEditor et liste filtrée de transactions
struct TransactionFilterView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TransactionFilterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Predicate Editor
            TransactionPredicateEditorView(
                predicate: $viewModel.currentPredicate,
                onPredicateChange: viewModel.applyPredicate
            )
            .frame(minHeight: 220)
            .padding()

            Divider()

            // Results
            resultsList
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Filtrage des transactions")
                    .font(.headline)

                if let predicate = viewModel.currentPredicate {
                    Text(predicate.predicateFormat)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Aucun filtre appliqué")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(viewModel.filteredTransactions.count) résultats")
                    .font(.headline)

                if viewModel.isFiltered {
                    Text("sur \(viewModel.totalCount) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Clear button
            if viewModel.currentPredicate != nil {
                Button(action: viewModel.clearFilter) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Effacer le filtre")
            }
        }
        .padding()
    }

    private var resultsList: some View {
        Group {
            if viewModel.filteredTransactions.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(viewModel.filteredTransactions) { transaction in
                        TransactionRowView(transaction: transaction)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Aucune transaction trouvée")
                .font(.headline)
                .foregroundColor(.secondary)

            if viewModel.isFiltered {
                Text("Essayez d'ajuster les critères de filtre")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: EntityTransaction

    var body: some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.dateOperationString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if transaction.dateOperation != transaction.datePointage {
                    Text("P: \(transaction.datePointageString)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Divider()

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.statusString)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    if !transaction.checkNumber.isEmpty {
                        Text("• \(transaction.checkNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(transaction.paymentModeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text(transaction.amountString)
                .font(.headline)
                .foregroundColor(transaction.amount >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
final class TransactionFilterViewModel: ObservableObject {
    @Published var currentPredicate: NSPredicate?
    @Published var filteredTransactions: [EntityTransaction] = []
    @Published var isFiltered: Bool = false

    private var modelContext: ModelContext?
    private var allTransactions: [EntityTransaction] = []

    var totalCount: Int {
        allTransactions.count
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadAllTransactions()
        applyPredicate(currentPredicate)
    }

    func applyPredicate(_ predicate: NSPredicate?) {
        guard let modelContext else {
            print("❌ ModelContext est nil")
            return
        }

        print("🔍 Application du prédicat...")

        // Si pas de prédicat, charger toutes les transactions
        guard let predicate = predicate else {
            print("   → Aucun prédicat, chargement de toutes les transactions")
            filteredTransactions = allTransactions
            currentPredicate = nil
            isFiltered = false
            return
        }

        print("   → NSPredicate format: \(predicate.predicateFormat)")

        do {
            // Valider le prédicat
            print("   → Validation du prédicat...")
            try PredicateEditorValidator.validate(predicate)
            print("   ✅ Prédicat valide")

            // Convertir en SwiftData Predicate
            print("   → Conversion en SwiftData Predicate...")
            let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: predicate)

            if swiftDataPredicate == nil {
                print("   ⚠️ Conversion a retourné nil, utilisation sans prédicat")
                filteredTransactions = allTransactions
                currentPredicate = nil
                isFiltered = false
                return
            }

            print("   ✅ Prédicat SwiftData créé")

            // Créer le FetchDescriptor
            print("   → Création du FetchDescriptor...")
            let descriptor = FetchDescriptor<EntityTransaction>(
                predicate: swiftDataPredicate,
                sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
            )

            // Fetch
            print("   → Fetch en cours...")
            filteredTransactions = try modelContext.fetch(descriptor)
            print("   ✅ Fetch réussi: \(filteredTransactions.count) résultats")

            // Update state
            currentPredicate = predicate
            isFiltered = true

        } catch let error as PredicateValidationError {
            print("❌ Erreur de validation : \(error.localizedDescription)")
            print("   → Chargement de toutes les transactions")
            currentPredicate = nil
            filteredTransactions = allTransactions
            isFiltered = false

        } catch {
            print("❌ Erreur de fetch : \(error)")
            print("   Type d'erreur: \(type(of: error))")
            print("   Description: \(error.localizedDescription)")

            // En cas d'erreur de fetch, essayer sans prédicat
            print("   → Tentative de chargement sans prédicat...")
            do {
                let descriptor = FetchDescriptor<EntityTransaction>(
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                filteredTransactions = try modelContext.fetch(descriptor)
                print("   ✅ Chargement sans prédicat réussi: \(filteredTransactions.count) résultats")
            } catch {
                print("   ❌ Échec même sans prédicat: \(error)")
                filteredTransactions = allTransactions
            }

            currentPredicate = nil
            isFiltered = false
        }
    }

    func clearFilter() {
        currentPredicate = nil
        filteredTransactions = allTransactions
        isFiltered = false
    }

    private func loadAllTransactions() {
        guard let modelContext else { return }

        do {
            let descriptor = FetchDescriptor<EntityTransaction>(
                sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
            )
            allTransactions = try modelContext.fetch(descriptor)
            filteredTransactions = allTransactions
        } catch {
            print("❌ Erreur de chargement : \(error)")
            allTransactions = []
            filteredTransactions = []
        }
    }
}

