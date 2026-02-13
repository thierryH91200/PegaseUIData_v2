//
//  EntityPaymentMode.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import SwiftUI
import SwiftData
import Combine
import OSLog

@Model final class EntityPaymentMode: Identifiable , Hashable {
    
    var name: String = ""
    
    @Attribute(.transformable(by: ColorTransformer.self)) var color: NSColor
    
    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship var account: EntityAccount
    
    init(account: EntityAccount, name: String = "Test", color: NSColor = .black ) {
        self.name = name
        self.color = color
        self.account = account
    }

    // Implémentez `Hashable`
    public static func == (lhs: EntityPaymentMode, rhs: EntityPaymentMode) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

extension EntityPaymentMode: CustomStringConvertible {
    public var description: String {
        "EntityPaymentMode(name: \(name), color: \(color), uuid: \(uuid))"
    }
}

@MainActor
protocol PaymentModeManaging {
    
    func create(account: EntityAccount, name: String, color: NSColor) throws -> EntityPaymentMode?
    func update(entity: EntityPaymentMode, name: String, color: NSColor)
    func getAllData() -> [EntityPaymentMode]
    func getAllNames() -> [String]
    func findOrCreate(account: EntityAccount, name: String, color: Color, uuid: UUID) -> EntityPaymentMode
    func find( account: EntityAccount?, name: String) -> EntityPaymentMode?
    func delete(entity: EntityPaymentMode, undoManager: UndoManager?)
    func createDefaultPaymentModes(for account: EntityAccount)

    func save () throws
}

//Gère les opérations CRUD (Create, Read, Update, Delete)
//Interagit directement avec SwiftData
//Contient la logique métier complexe
//Est un singleton (shared)
//Gère les données par défaut
@MainActor
final class PaymentModeManager : PaymentModeManaging, ObservableObject {

    static let shared = PaymentModeManager()
    
    @Published var modePayments = [EntityPaymentMode]()
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    init() { }
    
    func reset() {
        modePayments.removeAll()
        refresh()
    }

    func refresh() {
        let account = CurrentAccountManager.shared.getAccount()
        guard let account else { return }
        
        let lhs = account.uuid
        let predicate = #Predicate<EntityPaymentMode> { $0.account.uuid == lhs }
        let sort = [SortDescriptor(\EntityPaymentMode.name, order: .forward)]
        let fetchDescriptor = FetchDescriptor<EntityPaymentMode>(predicate: predicate, sortBy: sort)
        
        do {
            modePayments = try modelContext?.fetch(fetchDescriptor) ?? []
        } catch {
            AppLogger.data.error("PaymentMode refresh failed: \(error.localizedDescription)")
            modePayments = []
        }
    }
    func create(account: EntityAccount, name: String, color: NSColor) throws -> EntityPaymentMode? {
        let mode = EntityPaymentMode(account: account, name: name, color: color)
        modelContext?.insert(mode)
        do {
            try modelContext?.save()
        } catch {
            AppLogger.data.error("Failed to save payment mode '\(name)': \(error.localizedDescription)")
            throw error
        }
        return mode
    }

    func update(entity: EntityPaymentMode, name: String, color: NSColor) {
        guard let context = modelContext else { return }

        // Re-resolve a live instance in the current context to avoid using a destroyed model
        let id = entity.persistentModelID
        guard let live = context.model(for: id) as? EntityPaymentMode else {
            AppLogger.data.warning("PaymentMode update skipped: unable to resolve live instance in current context")
            return
        }

        live.name = name
        live.color = color
        do {
            try save()
        } catch {
            AppLogger.data.error("PaymentMode save failed: \(error.localizedDescription)")
        }
    }

    @MainActor func getAllData() -> [EntityPaymentMode] {
                
        let account = CurrentAccountManager.shared.getAccount()
        guard account != nil else {
            return []
        }

        let lhs = account!.uuid
        let predicate = #Predicate<EntityPaymentMode> { entity in entity.account.uuid == lhs }
        let sort = [SortDescriptor(\EntityPaymentMode.name, order: .forward)]
        
        let fetchDescriptor = FetchDescriptor<EntityPaymentMode>(
            predicate: predicate,
            sortBy: sort )
        
        do {
            let fetchedData = try modelContext?.fetch(fetchDescriptor) ?? []
            return fetchedData
        } catch {
            AppLogger.data.error("PaymentMode fetch failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: getAllNames ModePaiement
    @MainActor func getAllNames() -> [String] {
        
        return getAllData().map { $0.name }
    }

    // MARK: findOrCreate ModePaiement
    @MainActor func findOrCreate(account: EntityAccount, name: String, color: Color, uuid: UUID) -> EntityPaymentMode {
        if let entity = find(account: account, name: name) {
            return entity
        } else {
            do {
                if let created = try create(account: account, name: name, color: NSColor.fromSwiftUIColor(color)) {
                    return created
                }
            } catch {
                AppLogger.data.error("Failed to create payment mode '\(name)': \(error.localizedDescription)")
            }
            // Fallback: create a minimal instance without persisting
            let fallback = EntityPaymentMode(account: account, name: name, color: NSColor.fromSwiftUIColor(color))
            modelContext?.insert(fallback)
            return fallback
        }
    }
    
    // MARK: find ModePaiement
    @MainActor
    func find( account: EntityAccount? = nil, name: String) -> EntityPaymentMode? {
        
        guard let account = account ?? CurrentAccountManager.shared.getAccount() else {
            AppLogger.data.warning("PaymentMode find: no account available")
            return nil
        }
        
        let lhs = account.uuid
        let predicate = #Predicate<EntityPaymentMode> { $0.account.uuid == lhs && $0.name == name }
        let sort = [SortDescriptor(\EntityPaymentMode.name, order: .forward)] // Trier par le nom

        let fetchDescriptor = FetchDescriptor<EntityPaymentMode>(
            predicate: predicate, // Filtrer par le compte
            sortBy: sort )

        do {
            let searchResults = try modelContext?.fetch(fetchDescriptor) ?? []
            let result = searchResults.isEmpty == false ? searchResults.first : nil
            return result
        } catch {
            AppLogger.data.error("PaymentMode find failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: delete ModePaiement
    func delete(entity: EntityPaymentMode, undoManager: UndoManager?) {
        guard let context = modelContext else { return }

        // Resolve live instance in current context
        let id = entity.persistentModelID
        guard let live = context.model(for: id) as? EntityPaymentMode else {
            AppLogger.data.warning("PaymentMode delete skipped: unable to resolve live instance in current context")
            return
        }

        context.undoManager = undoManager
        context.undoManager?.beginUndoGrouping()
        context.undoManager?.setActionName("Delete the Payment methods")
        context.delete(live)
        context.undoManager?.endUndoGrouping()
    }

    // MARK: default ModePaiement
    
    func createDefaultPaymentModes(for account: EntityAccount) {
        modePayments.removeAll()
        
        // Liste des noms et couleurs des méthodes de paiement
        let names = [ String(localized :"Bank Card"),
                      String(localized :"Check"),
                      String(localized :"Cash"),
                      String(localized :"Bank withdrawal"),
                      String(localized :"Discount"),
                      String(localized :"Cash withdrawal"),
                      String(localized :"Bank transfer"),
                      String(localized :"Direct debit")]
        let paymentModes: [(name: String, color: NSColor)] = [
            ( names[0], .red),
            ( names[1], .green),
            ( names[2], .yellow),
            ( names[3], .blue),
            ( names[4], .red),
            ( names[5], .gray),
            ( names[6], .brown),
            ( names[7], .black)
        ]
        
        // Création des entités de mode de paiement
        paymentModes.forEach {
            do {
                try _ = create(account: account, name: $0.name, color: $0.color)
            } catch {
                AppLogger.data.error("Default payment mode creation failed: \(error.localizedDescription)")
            }
        }
               
        let lhs = account.uuid
        let predicate = #Predicate<EntityPaymentMode>{ entity in entity.account.uuid == lhs }
        let sort = [SortDescriptor(\EntityPaymentMode.name, order: .forward)]
                
        let fetchDescriptor = FetchDescriptor<EntityPaymentMode>(
            predicate: predicate,
            sortBy: sort )
        
        // Récupération des entités EntityPaymentMode liées au compte actuel
        do {
            modePayments = try modelContext?.fetch(fetchDescriptor) ?? []
        } catch {
            AppLogger.data.error("PaymentMode fetch after default creation failed: \(error.localizedDescription)")
        }
        // modePayments now contains fresh, live instances from the current context
    }
    
//    // Resolve a live instance for a potentially stale model reference
//    private func resolveLiveInstance(_ entity: EntityPaymentMode) -> EntityPaymentMode? {
//        guard let context = modelContext else { return nil }
//        return context.model(for: entity.persistentModelID) as? EntityPaymentMode
//    }
    
    // MARK: save ModePaiement
    func save () throws {
        do {
            try modelContext?.save()
        } catch {
            throw EnumError.saveFailed
        }
    }
}

