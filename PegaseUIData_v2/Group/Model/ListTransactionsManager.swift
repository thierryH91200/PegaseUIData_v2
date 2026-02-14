//
//  EntityTransactions.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import SwiftUI
import SwiftData
import AppKit
import Combine


protocol ListManaging {
    func createTransactions(formState: TransactionFormState) -> EntityTransaction?
    func find(uuid: UUID) -> EntityTransaction?
    func getAllComments(for account: EntityAccount) throws -> [String]
    func delete(entity: EntityTransaction)

}

final class ListTransactionsManager: ListManaging, ObservableObject {
    
    static let shared = ListTransactionsManager()
    
    private var cache: [UUID: [EntityTransaction]] = [:]

    func prefetchTransactions(for account: EntityAccount) {
        let key = account.uuid
        guard cache[key] == nil else { return }
        let transactions = fetchTransactions(for: account)
        cache[key] = transactions
    }
    
    func cachedTransactions(for account: EntityAccount) -> [EntityTransaction]? {
        let key = account.uuid
        return cache[key]
    }

    
    private func fetchTransactions(for account: EntityAccount, ascending: Bool = true) -> [EntityTransaction] {
        guard let context = modelContext else { return [] }
        let acctID = account.uuid
        let predicate = #Predicate<EntityTransaction> { $0.account.uuid == acctID }
        let sort = [
            SortDescriptor(\EntityTransaction.datePointage, order: ascending ? .forward : .reverse),
            SortDescriptor(\EntityTransaction.dateOperation, order: ascending ? .forward : .reverse)
        ]
        let descriptor = FetchDescriptor<EntityTransaction>(predicate: predicate, sortBy: sort)
        do {
            return try context.fetch(descriptor)
        } catch {
            printTag("Erreur lors de la récupération des données avec SwiftData : \(error)", flag: true)
            return []
        }
    }

    
    @Published var listTransactions = [EntityTransaction]()

    var ascending = false

    // Cache pour éviter les rechargements inutiles
    private var lastAccountID: UUID?
    private var lastAscending: Bool?
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }
    var undoManager: UndoManager? {
        DataContext.shared.context?.undoManager
    }

    init() { }
    
    func reset() {
        listTransactions.removeAll()
    }

    @discardableResult
    func createTransactions(formState: TransactionFormState) -> EntityTransaction? {
        // Create entityTransaction
        guard let context = modelContext else {
            print("⚠️ Erreur: modelContext n'est pas disponible")
            return nil
        }

        guard let account = CurrentAccountManager.shared.getAccount() else {
            print("⚠️ Erreur: aucun compte courant trouvé")
            return nil
        }

        let transaction = EntityTransaction(account: account)
        transaction.uuid = UUID()

        formState.currentTransaction = transaction
        context.insert(transaction)

        return transaction
    }

    func getAllData(from startDate: Date? = nil, to endDate: Date? = nil, ascending: Bool = true) -> [EntityTransaction] {
        let all = loadAllTransactions(ascending: ascending) // Méthode qui charge toutes les transactions
        guard let start = startDate, let end = endDate else {
            return all
        }
        return all.filter { $0.datePointage >= start && $0.datePointage <= end }
    }
    
    // MARK: getAllData
    func loadAllTransactions(ascending: Bool = true, forceReload: Bool = false) -> [EntityTransaction] {

        let currentAccount = CurrentAccountManager.shared.getAccount()
        guard let currentAccount = currentAccount else {
            return []
        }

        let currentAccountID = currentAccount.uuid

        // Vérifier si on peut utiliser le cache (même compte, même tri, données déjà chargées)
        if !forceReload,
           lastAccountID == currentAccountID,
           lastAscending == ascending,
           !listTransactions.isEmpty {
            // Retourner les données en cache sans déclencher de mise à jour @Published
            return listTransactions
        }

        self.ascending = ascending

        // Création du prédicat pour filtrer les transactions par compte
        let predicate = #Predicate<EntityTransaction> { $0.account.uuid == currentAccountID }
        let sort = [
            SortDescriptor(\EntityTransaction.datePointage, order: ascending ? .forward : .reverse),
            SortDescriptor(\EntityTransaction.dateOperation, order: ascending ? .forward : .reverse)
        ]

        // Création du FetchDescriptor avec les tri par datePointage et dateOperation
        let fetchDescriptor = FetchDescriptor<EntityTransaction>(
            predicate: predicate,
            sortBy: sort)

        do {
            // Récupération des entités depuis le contexte
            let fetchedTransactions = try modelContext?.fetch(fetchDescriptor) ?? []

            // Mettre à jour le cache
            lastAccountID = currentAccountID
            lastAscending = ascending

            // Seulement mettre à jour @Published si le contenu a changé
            if fetchedTransactions.map({ $0.uuid }) != listTransactions.map({ $0.uuid }) {
                listTransactions = fetchedTransactions
                print("début Transactions  sepa")
                // for listTransaction in listTransactions {
                 print("Transactions count = ",listTransactions.count )
                // }
                print("fin Transactions")
            }

        } catch {
            printTag("Erreur lors de la récupération des données avec SwiftData : \(error)", flag: true)
            return []
        }

        // Ajuste les dates si le compte est en mode démo
        if currentAccount.isDemo {
            adjustDate(for: currentAccount)
        }
        return listTransactions
    }

    /// Invalide le cache et force un rechargement au prochain appel
    func invalidateCache() {
        lastAccountID = nil
        lastAscending = nil
    }

    func addSousTransaction(transaction: EntityTransaction, sousTransaction: EntitySousOperation ) -> EntityTransaction {
        
        modelContext?.insert(transaction)
        sousTransaction.transaction = transaction
        modelContext?.insert(sousTransaction)
        transaction.addSubOperation(sousTransaction)

        return transaction
    }

    
    func find(uuid: UUID) -> EntityTransaction? {
        // Création du prédicat pour filtrer les transactions par UUID
        let predicate = #Predicate<EntityTransaction> { $0.uuid == uuid }

        // Création du FetchDescriptor pour récupérer une entité correspondant à l'UUID
        let fetchDescriptor = FetchDescriptor<EntityTransaction>(
            predicate: predicate
        )

        do {
            // Récupération des entités correspondant au prédicat
            let results = try modelContext?.fetch(fetchDescriptor) ?? []
            
            // Retourner le premier résultat, s'il existe
            return results.first
        } catch {
            printTag("Erreur lors de la récupération des données avec SwiftData : \(error)", flag: true)
            return nil
        }
    }
    
    func getAllComments(for account: EntityAccount) throws -> [String] {
        var comments = [String]()
        
        let lhs = account.uuid
        let predicate = #Predicate<EntityTransaction>{ transaction in transaction.account.uuid == lhs }
        let sort = [SortDescriptor(\EntityTransaction.dateOperation, order: .reverse)]
        
        let descriptor = FetchDescriptor<EntityTransaction>(
            predicate: predicate,
            sortBy: sort )

        // Fetch les transactions liées à l'account
        do {
            // Fetch transactions with error handling
            let entityTransactions = try modelContext?.fetch(descriptor) ?? []
            
            // Process transactions and their split operations
            for entityTransaction in entityTransactions {
                let splitTransactions = entityTransaction.sousOperations
                    let splitComments = splitTransactions.compactMap { $0.libelle }
                    comments.append(contentsOf: splitComments)
            }
            
            // Return unique comments
            return comments.uniqueElements
        } catch {
            throw error  // Or handle the error as needed for your use case
        }
    }


    // MARK: remove Transaction
    @MainActor
    func delete(entity: EntityTransaction) {
        guard let modelContext else {
            printTag("Container invalide.", flag: true)
            return
        }
        invalidateCache()  // Invalider le cache car les données changent
        modelContext.undoManager = undoManager
        modelContext.undoManager?.beginUndoGrouping()
        modelContext.undoManager?.setActionName(String(localized: "Delete Person"))
        modelContext.delete(entity)
        modelContext.undoManager?.endUndoGrouping()
    }
    
    /// Suppression batch optimisée : un seul undo grouping et une seule invalidation de cache
    @MainActor
    func delete(entities: [EntityTransaction]) {
        guard let modelContext else {
            printTag("Container invalide.", flag: true)
            return
        }
        guard !entities.isEmpty else { return }
        invalidateCache()
        modelContext.undoManager = undoManager
        modelContext.undoManager?.beginUndoGrouping()
        modelContext.undoManager?.setActionName(
            entities.count == 1
                ? String(localized: "Delete Transaction")
                : String(localized: "Delete \(entities.count) Transactions")
        )
        for entity in entities {
            modelContext.delete(entity)
        }
        modelContext.undoManager?.endUndoGrouping()
    }

    /// Suppression batch avec progression — supprime par lots et yield entre chaque lot pour laisser l'UI se rafraîchir
    @MainActor
    func deleteBatched(
        entities: [EntityTransaction],
        batchSize: Int = 100,
        onProgress: @escaping (Int, Int) -> Void
    ) async {
        guard let modelContext else {
            printTag("Container invalide.", flag: true)
            return
        }
        guard !entities.isEmpty else { return }
        let total = entities.count
        invalidateCache()
        modelContext.undoManager = undoManager
        modelContext.undoManager?.beginUndoGrouping()
        modelContext.undoManager?.setActionName(
            String(localized: "Delete \(total) Transactions")
        )
        for (index, entity) in entities.enumerated() {
            modelContext.delete(entity)

            if (index + 1) % batchSize == 0 || index == total - 1 {
                onProgress(index + 1, total)
                await Task.yield()
            }
        }
        modelContext.undoManager?.endUndoGrouping()
    }
    
    func printTransactions() {
        for entity in listTransactions {
            print(entity.datePointage)
            print(entity.dateOperation)
            print(entity.status?.name ?? "no status")
            print(entity.paymentMode?.name ?? "defaultMode")
            let subs = entity.sousOperations
            for sub in subs {
                print(sub.libelle ?? "Sans libellé")
                print(sub.category?.name ?? "Cat def")
                print(sub.category?.rubric!.name ?? "Rub def")
                print(sub.amount)
            }
        }
    }

    func adjustDate (for account: EntityAccount) {
        let currentAccount = account

        guard listTransactions.isEmpty == false else {return}
        let diffDate = (listTransactions.first?.datePointage.timeIntervalSinceNow)!
        for entity in listTransactions {
            entity.datePointage  = (entity.datePointage  - diffDate).noon
            entity.dateOperation = (entity.dateOperation - diffDate).noon
        }
        currentAccount.isDemo = false
    }
    
    func save() throws {
        invalidateCache()  // Invalider le cache car les données changent
        do {
            try modelContext?.save()
        } catch {
            throw EnumError.saveFailed
        }
    }

    
    @MainActor
    func undo() {
        assert(Thread.isMainThread)
        guard let context = modelContext else { return }
        guard let undoManager = context.undoManager else { return }
        printTag("Undo stack canUndo: \(undoManager.canUndo), isUndoing: \(undoManager.isUndoing), isRedoing: \(undoManager.isRedoing)", flag: false)
        if undoManager.canUndo {
            undoManager.undo()
            printTag("Undo executed. Re-fetching...", flag: false)
            let refreshed = getAllData(ascending: ascending)
            printTag("Refetch count: \(refreshed.count)", flag: false)
        }
    }
//    func undo() {
//        guard let context = modelContext else {
//            assertionFailure("ModelContext is nil in undo()")
//            return
//        }
//        guard let undoManager = context.undoManager else {
//            printTag("UndoManager is nil. No undo available.", flag: true)
//            return
//        }
//
//        // Sécurité: éviter undo pendant une édition/animation critique
//        if undoManager.isUndoing || undoManager.isRedoing {
//            printTag("Undo/Redo already in progress.", flag: true)
//            return
//        }
//
//        // Exécuter l'undo
//        if undoManager.canUndo {
//            undoManager.undo()
//            _ = getAllData(ascending: ascending)
//        }
//    }

    func redo() {
        guard let context = modelContext else {
            assertionFailure("ModelContext is nil in redo()")
            return
        }
        guard let undoManager = context.undoManager else {
            printTag("UndoManager is nil. No redo available.", flag: true)
            return
        }
        if undoManager.isUndoing || undoManager.isRedoing {
            printTag("Undo/Redo already in progress.", flag: true)
            return
        }

        undoManager.redo()
        _ = getAllData(ascending: ascending)
    }

    
}

//class ListTransactionsViewModel: ObservableObject {
//
//    @Published var account: EntityAccount
//    @Published var listTransactions: [EntityTransaction]
//    private let manager: ListTransactionsManager
//
//    init(account: EntityAccount, manager: ListTransactionsManager) {
//        self.account = account
//        self.manager = manager
//        self.listTransactions = []
//
//        loadInitialData()
//    }
//
//    private func loadInitialData() {
//        listTransactions = manager.getAllData()
//    }
//}
//

