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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var resultsList: some View {
        Group {
            if viewModel.filteredTransactions.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    Header()
                    Divider()
                    List {
                        ForEach(viewModel.filteredTransactions) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
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
struct Header: View {

    var body: some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 0) {
                Text("Date Operation")
                    .font(.caption2)
                    .foregroundColor(.primary)

                Text("Date Pointage")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible
            // Details
            VStack(alignment: .leading, spacing: 0) {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.primary)

                Text("Check Number")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            VStack(alignment: .leading, spacing: 0) {
                Text("Payment Mode")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Bank Statement")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            VStack(alignment: .leading, spacing: 0) {
                Text("Rubric")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Category")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            VStack(alignment: .leading, spacing: 0) {
                Text("Libelle")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Amount")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 200, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            Spacer()

            // Amount
            Text("Amount")
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.1))
        .frame(height: 30)

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
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 87, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            // Details
            VStack(alignment: .leading, spacing: 4) {
                VStack {
                    Text(transaction.statusString)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if !transaction.checkNumber.isEmpty {
                        Text("• \(transaction.checkNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            VStack {
                Text(transaction.paymentModeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transaction.bankStatementString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            VStack {
                Text(transaction.sousOperations.first?.category?.rubric?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transaction.sousOperations.first?.category?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            VStack {
                Text(transaction.sousOperations.first?.libelle ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatPrice(transaction.sousOperations.first?.amount ?? 0.0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, alignment: .leading)
            Divider()
                .frame(width: 2)          // épaisseur (verticale) pour un Divider horizontal
                .background(Color.gray)    // couleur du trait
                .opacity(0.8)              // un peu plus visible

            Spacer()
            // Amount
            VStack {
                Text(transaction.amountString)
                    .font(.headline)
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
            }
            .frame(width: 100, alignment: .leading)
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

            // Fetch
            print("   → Fetch en cours...")

            // Si le prédicat SwiftData est nil (SUBQUERY non supporté), faire le filtrage en mémoire
            if swiftDataPredicate == nil && finalPredicate != nil {
                print("   ⚠️ Prédicat non supporté par SwiftData, post-filtrage en mémoire...")
                let allDescriptor = FetchDescriptor<EntityTransaction>(
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                let allTransactions = try modelContext.fetch(allDescriptor)

                // Filtrer en mémoire avec NSPredicateManualEvaluator
                filteredTransactions = allTransactions.filter { transaction in
                    NSPredicateManualEvaluator.evaluate(predicate: finalPredicate!, transaction: transaction)
                }
                print("   ✅ Post-filtrage réussi: \(filteredTransactions.count) résultats sur \(allTransactions.count)")
            } else if let swiftDataPredicate {
                // Utiliser le SwiftData Predicate si disponible
                print("   ✅ Prédicat SwiftData créé")
                print("   → Création du FetchDescriptor...")
                let descriptor = FetchDescriptor<EntityTransaction>(
                    predicate: swiftDataPredicate,
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                filteredTransactions = try modelContext.fetch(descriptor)
                print("   ✅ Fetch réussi: \(filteredTransactions.count) résultats")
            } else {
                // Aucun prédicat
                print("   → Chargement sans filtre")
                let descriptor = FetchDescriptor<EntityTransaction>(
                    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
                )
                filteredTransactions = try modelContext.fetch(descriptor)
                print("   ✅ Fetch réussi: \(filteredTransactions.count) résultats")
            }

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

