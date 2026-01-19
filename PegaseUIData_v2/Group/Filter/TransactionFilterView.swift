//
//  TransactionFilterView.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 16/01/2026.
//

import SwiftUI
import SwiftData
import Combine
import os

/// Vue complète avec PredicateEditor et liste filtrée de transactions
struct TransactionFilterView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TransactionFilterViewModel()
    
    @EnvironmentObject private var currentAccountManager: CurrentAccountManager
    
    @State private var refresh = false

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
        .id(refresh)
        
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .onChange(of: currentAccountManager.currentAccountID) { old, new in
            AppLogger.account.debug("Account change detected: \(String(describing: new))")
            viewModel.loadAllTransactions()

            withAnimation {
                refresh.toggle()
            }
        }

    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transaction filteringTransaction filtering")
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
                    Text("on \(viewModel.totalCount) total")
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

            Text("No transactions found")
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
                
                Text(transaction.datePointageString)
                    .font(.caption2)
                    .foregroundColor(.orange)
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
                HStack {
                    Text(transaction.paymentModeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(transaction.bankStatementString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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

        // Combiner avec le prédicat de l'éditeur
        var finalPredicate: NSPredicate? = predicate ?? nil
        if let userPredicate = predicate {
            print("   → Prédicat utilisateur: \(userPredicate.predicateFormat)")
            finalPredicate = userPredicate
            print("   → Prédicat combiné: \(finalPredicate?.predicateFormat ?? "")")
        } else {
            print("   → Aucun prédicat utilisateur, utilisation du prédicat compte uniquement")
        }

        do {
            // Valider le prédicat combiné
            print("   → Validation du prédicat...")
            try PredicateEditorValidator.validate(finalPredicate)
            print("   ✅ Prédicat valide")

            // Convertir en SwiftData Predicate
            print("   → Conversion en SwiftData Predicate...")
            let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: finalPredicate)

            if swiftDataPredicate == nil {
                print("   ⚠️ Conversion a retourné nil, chargement avec prédicat compte uniquement")
                // Fallback: utiliser seulement le prédicat compte
                let descriptor = FetchDescriptor<EntityTransaction>(
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                filteredTransactions = try  modelContext.fetch(descriptor)
                currentPredicate = predicate
                isFiltered = predicate != nil
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
            isFiltered = predicate != nil

        } catch let error as PredicateValidationError {
            print("❌ Erreur de validation : \(error.localizedDescription)")
            print("   → Chargement avec prédicat compte uniquement")
            do {
                let descriptor = FetchDescriptor<EntityTransaction>(
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                filteredTransactions = try modelContext.fetch(descriptor)
            } catch {
                print("   ❌ Échec du chargement: \(error)")
                filteredTransactions = []
            }
            currentPredicate = nil
            isFiltered = false

        } catch {
            print("❌ Erreur de fetch : \(error)")
            print("   Type d'erreur: \(type(of: error))")
            print("   Description: \(error.localizedDescription)")

            // En cas d'erreur de fetch, essayer avec prédicat compte uniquement
            print("   → Tentative de chargement avec prédicat compte uniquement...")
            do {
                let descriptor = FetchDescriptor<EntityTransaction>(
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                filteredTransactions = try modelContext.fetch(descriptor)
                print("   ✅ Chargement avec compte uniquement réussi: \(filteredTransactions.count) résultats")
            } catch {
                print("   ❌ Échec même avec compte uniquement: \(error)")
                filteredTransactions = []
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

    func loadAllTransactions() {
        
        allTransactions = ListTransactionsManager.shared.getAllData()
        filteredTransactions = allTransactions
    }
}

