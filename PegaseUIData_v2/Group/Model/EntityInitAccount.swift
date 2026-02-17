//
//  EntityInitAccount.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import Foundation
import SwiftData
import SwiftUI
import Combine


@Model final class EntityInitAccount {
    var bic: String = ""
    var cleRib: String = ""
    var codeAccount: String = ""
    var codeBank: String = ""
    var codeGuichet: String = ""
    
    var iban: String = ""

    var engage: Double = 0.0
    var prevu: Double = 0.0
    var realise: Double = 0.0

    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship var account: EntityAccount
    
    public init(account : EntityAccount) {
        self.iban = "FR76"
        self.account = account
    }
}

final class InitAccountManager: ObservableObject {

    static let shared = InitAccountManager()
    private var initAccounts = [EntityInitAccount]()
    @Published var currentInitAccount: EntityInitAccount?

    // Contexte pour les modifications
    @MainActor
    var currentAccount: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }

    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    init() {
    }

    // Utiliser un seul contexte pour la gestion des données
    @MainActor func getAllData() -> EntityInitAccount? {
        
        guard let account = CurrentAccountManager.shared.getAccount() else {
            printTag("Erreur : aucun compte courant trouvé.")
            return nil
        }

        let lhs = account.uuid
        let predicate = #Predicate<EntityInitAccount>{ entity in entity.account.uuid == lhs }
        let sort = [SortDescriptor(\EntityInitAccount.codeAccount)]

        let descriptor = FetchDescriptor<EntityInitAccount>(
            predicate: predicate,
            sortBy: sort )

        do {
            initAccounts = try modelContext?.fetch(descriptor) ?? []
        } catch {
            printTag("Erreur lors de la récupération des données")
        }
        
        if let firstEntity = initAccounts.first {
            currentInitAccount = firstEntity
            return firstEntity
        } else {
            do {
                let entity = try create(numAccount: "", for: account)
                currentInitAccount = entity
                return entity
            } catch {
                printTag("Erreur lors de la création d'une entité : \(error)")
                return nil
            }
        }
    }

    // Méthode de création d'entité
    func create(numAccount: String = "", for account: EntityAccount) throws -> EntityInitAccount {
        let entity = EntityInitAccount(account: account)
        
        entity.codeAccount = numAccount
        
        modelContext?.insert(entity)
        initAccounts.append(entity) // Mise à jour de la liste locale
        
        return entity
    }
    
    @MainActor func delete(entityInitAccount: EntityInitAccount) {

        modelContext?.delete(entityInitAccount)
        currentInitAccount = nil

        currentInitAccount = getAllData()      // Recharger depuis la base de donnees
    }
    
    func save () throws {

        do {
            try modelContext?.save()
        } catch {
            throw EnumError.saveFailed
        }
    }

    func saveChanges() {
        do {
            try modelContext?.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

