//
//  EntityCategory.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import Foundation
import SwiftData
import SwiftUI
import Combine
import OSLog


@Model final class EntityCategory {

    var name: String
    var objectif: Double = 0.0

    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship(inverse: \EntitySchedule.category) var echeancier: [EntitySchedule]?
    @Relationship(inverse: \EntityPreference.category) var preference: EntityPreference?
    
    var rubric: EntityRubric?
    @Relationship(inverse: \EntitySousOperation.category) var sousOperations: [EntitySousOperation]?
    
    public init(name: String, objectif : Double, rubric: EntityRubric) {
        self.name = name
        self.objectif = objectif
        self.rubric = rubric
        
        self.uuid = UUID()
    }
}

final class CategoryManager: ObservableObject {
    
    static let shared = CategoryManager()
     
    var modelContext: ModelContext? {
        DataContext.shared.context
    }
    var undoManager: UndoManager? {
        DataContext.shared.context?.undoManager
    }

    init() {}
    
    func create( name: String, objectif: Double, rubric: EntityRubric) -> EntityCategory? {
        
        let entity = EntityCategory(name: name, objectif: objectif, rubric: rubric)
        modelContext?.insert(entity)
        
        // Sauvegardez le contexte
        do {
            try save()
        } catch {
            AppLogger.data.error("Category save failed: \(error.localizedDescription)")
        }
        return entity
    }

    @MainActor func findOrCreate(account: EntityAccount,
                      name: String,
                      objectif: Double,
                      rubric: EntityRubric ) -> EntityCategory {
        
       if let existingCategory = find(name: name) {
            return existingCategory
        } else {
            let newCategory = EntityCategory(name: name, objectif: objectif, rubric: rubric)
            modelContext?.insert(newCategory) // Ajoute l'entité au contexte
            return newCategory
        }
    }
    
    @MainActor func find(name: String) -> EntityCategory? {
        guard let modelContext = modelContext else { return nil }

        let account = CurrentAccountManager.shared.getAccount()!
        let descriptor = FetchDescriptor.byName(name)

        let results = SwiftDataHelper.fetchAll(from: modelContext, descriptor: descriptor)
        return results.firstMatchingAccount(account)
    }
    
    func findWithRubric(account: EntityAccount, rubric: EntityRubric, name: String) -> EntityCategory? {
        // Supposons que 'category' soit un tableau d'EntityCategory
        let categories = rubric.categorie       // Accès direct, sans conversion
        return categories.first { $0.name == name } ?? categories.first
    }
    
    func delete(entity: EntityCategory) {
        
        guard let modelContext = modelContext else { return }

        modelContext.undoManager = undoManager
        modelContext.undoManager?.beginUndoGrouping()
        modelContext.undoManager?.setActionName("Delete Category")
        modelContext.delete(entity)
        modelContext.undoManager?.endUndoGrouping()
    }
    func save () throws {
        do {
            try modelContext?.save()
        } catch {
            throw EnumError.saveFailed
        }
    }

}

extension Sequence where Element == EntityCategory {
    func filtered(byAccount account: EntityAccount) -> [EntityCategory] {
        let accountUUID = account.uuid
        return self.filter { $0.rubric?.account.uuid == accountUUID }
    }

    func firstMatchingAccount(_ account: EntityAccount) -> EntityCategory? {
        return self.filtered(byAccount: account).first
    }
}

extension FetchDescriptor<EntityCategory> {
    static func byName(_ name: String, limit: Int? = nil) -> FetchDescriptor<EntityCategory> {
        let predicate: Predicate<EntityCategory> = #Predicate { category in
            category.name == name
        }

        var descriptor = FetchDescriptor<EntityCategory>(
            predicate: predicate,
            sortBy: [SortDescriptor(\EntityCategory.name, order: .forward)]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return descriptor
    }
}

struct SwiftDataHelper {
    static func fetchFirst<T: PersistentModel>(
        from modelContext: ModelContext,
        descriptor: FetchDescriptor<T>
    ) -> T? {
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("[SwiftDataHelper] Erreur lors du fetch SwiftData : \(error)")
            return nil
        }
    }

    static func fetchAll<T: PersistentModel>(
        from modelContext: ModelContext,
        descriptor: FetchDescriptor<T>
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("[SwiftDataHelper] Erreur lors du fetch SwiftData : \(error)")
            return []
        }
    }
}

