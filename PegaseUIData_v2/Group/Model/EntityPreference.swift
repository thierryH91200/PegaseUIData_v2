//
//  EntityPreference.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import Foundation
import SwiftData
import SwiftUI
import Combine


@Model final class EntityPreference {

    var signe       : Bool = true
    var status      : EntityStatus?
    var category    : EntityCategory?
    var paymentMode : EntityPaymentMode?
    var groupCarteBancaire: Bool = false  // Regrouper les transactions CB (carte débit différé)
    var splitAmountColumns: Bool = false  // Afficher Recettes/Dépenses au lieu d'un seul Montant

    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship var account: EntityAccount

    init(account: EntityAccount,
                category: EntityCategory? = nil,
                paymentMode: EntityPaymentMode? = nil,
                status: EntityStatus? = nil,
                groupCarteBancaire: Bool = false,
                splitAmountColumns: Bool = false) {

        self.category    = category
        self.paymentMode = paymentMode
        self.status      = status
        self.signe       = true
        self.groupCarteBancaire = groupCarteBancaire
        self.splitAmountColumns = splitAmountColumns

        self.account     = account
    }
}

@MainActor
protocol PreferenceManaging {

    func defaultPref(account: EntityAccount) -> EntityPreference?
    func getAllData() -> EntityPreference?
    func saveContext()
}

// MARK: preferenceManager
@MainActor
final class PreferenceManager: PreferenceManaging, ObservableObject {
    
    static let shared = PreferenceManager()
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    private init() { }
    
    func reset() {
        // No in-memory cache to reset
    }
    
    // MARK: - default
    @MainActor func defaultPref(account: EntityAccount) -> EntityPreference? {
        // Vérifie si une préférence existe déjà
        if let existingPreference = getAllData() {
            return existingPreference
        }

        let newPreference = EntityPreference(account: account)
        
        if newPreference.category == nil,
           let rubric = RubricManager.shared.getAllData(account: account).first {
            if let category = rubric.categorie.sorted(by: { $0.name < $1.name }).first {
                newPreference.category = category
            }
        }
        
        newPreference.paymentMode = PaymentModeManager.shared.getAllData().first

        let rubrics = RubricManager.shared.getAllData(account: account)
        if let firstRubric = rubrics.first {
            newPreference.category = firstRubric.categorie.first
            newPreference.category?.rubric = firstRubric
        }
        
        // Configuration de status
        newPreference.status = StatusManager.shared.getAllData(for: account).first

        newPreference.signe = true
        newPreference.account = account
        
        modelContext?.insert(newPreference)
        
        saveContext()
        return newPreference
    }
    
    func getAllData() -> EntityPreference? {
        
        let account = CurrentAccountManager.shared.getAccount()
        guard let account = account else {
            printTag("Preference : Erreur : Account est nil")
            return nil
        }
        let accountID = account.uuid
        let predicate = #Predicate<EntityPreference> { entity in entity.account.uuid == accountID }
        let fetchDescriptor = FetchDescriptor<EntityPreference>(predicate: predicate)
        do {
            let results = try modelContext?.fetch(fetchDescriptor) ?? []
            return results.first
        } catch {
            printTag("Erreur lors de la récupération des données : \(error.localizedDescription)")
            return nil
        }
    }
    func update(status: EntityStatus,
                mode: EntityPaymentMode,
                rubric: EntityRubric,
                category: EntityCategory,
                preference: EntityPreference,
                sign : Bool) async throws {
        guard let context = modelContext else { return }

        // Re-resolve live instances in the current context
        // Note: persistentModelID is non-optional in recent SwiftData, so don't conditionally bind it.
        let prefID = preference.persistentModelID
        let statusID = status.persistentModelID
        let modeID = mode.persistentModelID
        let categoryID = category.persistentModelID
        let rubricID = rubric.persistentModelID

        guard
            let livePreference = context.model(for: prefID) as? EntityPreference,
            let liveStatus = context.model(for: statusID) as? EntityStatus,
            let liveMode = context.model(for: modeID) as? EntityPaymentMode,
            let liveCategory = context.model(for: categoryID) as? EntityCategory,
            let liveRubric = context.model(for: rubricID) as? EntityRubric
        else {
            // If any model cannot be re-resolved in this context, skip update to avoid crashing
            printTag("Preference update skipped: unable to resolve live instances in current context")
            return
        }

        // Apply updates on live instances
        livePreference.status = liveStatus
        livePreference.paymentMode = liveMode
        livePreference.category = liveCategory
        livePreference.category?.rubric = liveRubric
        livePreference.signe = sign

        saveContext()
    }
    
    func saveContext() {
        do {
            try modelContext?.save()
        } catch {
            if let path = getSQLiteFilePath() {
                printTag("Erreur de sauvegarde. Base de données SQLite : \(path)")
            }
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

func getSQLiteFilePath() -> String? {
    guard let _ = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last else { return nil}
    
    if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        let path = "Core Data SQLite file is located at: \(url.path)"
        return path
    }
    return nil
}

