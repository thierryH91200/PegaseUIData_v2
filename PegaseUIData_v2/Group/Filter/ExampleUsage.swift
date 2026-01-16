//
//  ExampleUsage.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 16/01/2026.
//

import SwiftUI
import SwiftData

// MARK: - Exemple 1: Utilisation de la vue complète

struct Example1_FullView: View {
    var body: some View {
        TransactionFilterView()
            .frame(width: 1000, height: 700)
    }
}

// MARK: - Exemple 2: Utilisation avec binding personnalisé

struct Example2_CustomBinding: View {
    @State private var predicate: NSPredicate?
    @Environment(\.modelContext) private var modelContext
    @State private var transactions: [EntityTransaction] = []

    var body: some View {
        VStack {
            // PredicateEditor
            TransactionPredicateEditorView(
                predicate: $predicate,
                onPredicateChange: fetchTransactions
            )
            .frame(height: 250)
            .padding()

            Divider()

            // Affichage des résultats
            Text("\(transactions.count) transactions trouvées")
                .font(.headline)

            List(transactions) { transaction in
                HStack {
                    Text(transaction.dateOperationString)
                    Spacer()
                    Text(transaction.amountString)
                        .foregroundColor(transaction.amount >= 0 ? .green : .red)
                }
            }
        }
    }

    private func fetchTransactions(_ predicate: NSPredicate?) {
        do {
            let descriptor = TransactionPredicateParser.createFetchDescriptor(from: predicate)
            transactions = try modelContext.fetch(descriptor)
        } catch {
            print("Erreur: \(error)")
            transactions = []
        }
    }
}

// MARK: - Exemple 3: Parser seul

struct Example3_ParserOnly: View {
    @Environment(\.modelContext) private var modelContext
    @State private var results = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Exemple de parsing NSPredicate → SwiftData")
                .font(.headline)

            Button("Tester: amount > 100") {
                testPredicate("amount > 100")
            }

            Button("Tester: dateOperation > Date()") {
                let nsPred = NSPredicate(format: "dateOperation > %@", Date() as CVarArg)
                testPredicateObject(nsPred)
            }

            Button("Tester: status == 'Validé'") {
                testPredicate("status == 'Validé'")
            }

            Text(results)
                .font(.caption)
                .padding()
        }
        .padding()
    }

    private func testPredicate(_ format: String) {
        let nsPredicate = NSPredicate(format: format)
        testPredicateObject(nsPredicate)
    }

    private func testPredicateObject(_ nsPredicate: NSPredicate) {
        // Convertir
        let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: nsPredicate)

        if let predicate = swiftDataPredicate {
            // Utiliser dans un fetch
            let descriptor = FetchDescriptor<EntityTransaction>(predicate: predicate)

            do {
                let transactions = try modelContext.fetch(descriptor)
                results = "✅ Succès!\nNSPredicate: \(nsPredicate.predicateFormat)\n\nRésultats: \(transactions.count) transactions"
            } catch {
                results = "❌ Erreur fetch: \(error.localizedDescription)"
            }
        } else {
            results = "❌ Conversion échouée"
        }
    }
}

// MARK: - Exemple 4: Filtres prédéfinis

struct Example4_PredefinedFilters: View {
    @State private var selectedFilter: FilterPreset = .all
    @State private var predicate: NSPredicate?

    enum FilterPreset: String, CaseIterable {
        case all = "Toutes"
        case highAmount = "Montant > 1000"
        case thisMonth = "Ce mois"
        case validated = "Validées"

        var predicate: NSPredicate? {
            switch self {
            case .all:
                return nil
            case .highAmount:
                return NSPredicate(format: "amount > 1000")
            case .thisMonth:
                let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
                return NSPredicate(format: "dateOperation >= %@", startOfMonth as CVarArg)
            case .validated:
                return NSPredicate(format: "status == 'Validé'")
            }
        }
    }

    var body: some View {
        VStack {
            // Filtres rapides
            Picker("Filtre", selection: $selectedFilter) {
                ForEach(FilterPreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedFilter) { _, newValue in
                predicate = newValue.predicate
            }

            Divider()

            // Editor de prédicat
            TransactionPredicateEditorView(
                predicate: $predicate,
                onPredicateChange: { _ in }
            )
            .frame(height: 200)
            .padding()

            Divider()

            if let pred = predicate {
                Text("Filtre actif: \(pred.predicateFormat)")
                    .font(.caption)
                    .padding()
            }
        }
    }
}

// MARK: - Previews

#Preview("Exemple 1 - Vue complète") {
    Example1_FullView()
        .modelContainer(for: EntityTransaction.self, inMemory: true)
}

#Preview("Exemple 2 - Binding personnalisé") {
    Example2_CustomBinding()
        .frame(width: 800, height: 600)
        .modelContainer(for: EntityTransaction.self, inMemory: true)
}

#Preview("Exemple 3 - Parser seul") {
    Example3_ParserOnly()
        .frame(width: 600, height: 400)
        .modelContainer(for: EntityTransaction.self, inMemory: true)
}

#Preview("Exemple 4 - Filtres prédéfinis") {
    Example4_PredefinedFilters()
        .frame(width: 800, height: 600)
        .modelContainer(for: EntityTransaction.self, inMemory: true)
}
