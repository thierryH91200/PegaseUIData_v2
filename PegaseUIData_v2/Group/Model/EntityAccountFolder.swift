//
//  Untitled.swift
//  PegaseUIData
//
//  Created by thierryH24 on 16/08/2025.
//

import Foundation
import SwiftData
import SwiftUI
import Combine
import OSLog


@Model
final class EntityFolderAccount: Identifiable  {
    
    var name: String = ""
    var nameImage: String = "folder.fill"
    var isRoot : Bool = false

    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship(deleteRule: .cascade, inverse: \EntityAccount.folder)
    var children: [EntityAccount] = []
    
    public init() {
    }
    
    public init(name: String, isRoot: Bool, children: [EntityAccount]) {
        self.name = name
//        self.isRoot = isRoot
        self.children = children
    }
}

extension EntityFolderAccount {
    var childrenSorted: [EntityAccount] {
        children.sorted { $0.name < $1.name }
    }
}

extension EntityFolderAccount {
    func addAccounts(_ accounts: [EntityAccount]) {
        for account in accounts {
            self.addChild(account)
        }
    }
    
    func addChild(_ child: EntityAccount) {
        if children.isEmpty == true {
            children = []
        }
        children.append(child)
    }
}


protocol AccountFoldeManaging {
    func reset()
    func create(name: String, nameImage: String) -> EntityFolderAccount
    func getAllData() -> [EntityFolderAccount]
    func getRoot() -> [EntityFolderAccount]
    func findAccount(by id: UUID) -> EntityAccount?
    func findFolder(containing account: EntityAccount) -> EntityFolderAccount?
    @MainActor func preloadDataIfNeeded()
    func saveIfNeeded()
}

final class AccountFolderManager: AccountFoldeManaging {
    
    static let shared = AccountFolderManager()
    @Published var folderAccount = [EntityFolderAccount]()
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }
    
    init() { }
    
    func reset() {
        folderAccount.removeAll()
    }

    func create(name: String, nameImage: String) -> EntityFolderAccount{
        let entity = EntityFolderAccount()
        entity.name = name
        entity.nameImage = nameImage
        
        modelContext?.insert(entity)
        saveIfNeeded()
        return entity
    }
    
    func createHeader(name: String) -> EntityFolderAccount {
        let header = EntityFolderAccount()
        header.name = name
        header.nameImage = "folder.fill"
        header.uuid = UUID()
        
        modelContext?.insert(header)
        return header
    }

    
    func getAllData() -> [EntityFolderAccount] {
        
        let predicate =  #Predicate<EntityFolderAccount>{ _ in true }
        let sort = [SortDescriptor(\EntityFolderAccount.name, order: .forward)]
        
        let fetchDescriptor = FetchDescriptor<EntityFolderAccount>(
            predicate: predicate,
            sortBy: sort )

        do {
            folderAccount = try modelContext?.fetch(fetchDescriptor) ?? []
        } catch {
            folderAccount = []
            printTag("Erreur lors de la récupération des données avec SwiftData")
        }
        return folderAccount
    }
    
    func getRoot() -> [EntityFolderAccount] {
        // NOTE: Current logic filters non-root items; keep this if you rely on it for preload decisions.
        let request = FetchDescriptor<EntityFolderAccount>(
            predicate: #Predicate { $0.isRoot == false }
        )
        do {
            let entities = try modelContext?.fetch(request) ?? []
            return entities
        } catch {
            printTag("Erreur lors du fetch des dossiers (getRoot): \(error.localizedDescription)")
            return []
        }
    }
    
    func findAccount(by id: UUID) -> EntityAccount? {
        for folder in folderAccount {
            if let child = folder.children.first(where: { $0.uuid == id }) {
                return child
            }
        }
        return nil
    }
    
    func findFolder(containing account: EntityAccount) -> EntityFolderAccount? {
        for folder in folderAccount {
            if folder.children.contains(where: { $0.uuid == account.uuid }) == true {
                return folder
            }
        }
        return nil
    }
   
    @MainActor func preloadDataIfNeeded() {
        // Vérifie si des données existent déjà
        guard let modelContext = modelContext else { return }
        
        let existingFolders = getAllData()
        guard existingFolders.isEmpty == true else { return }
        
        // Ajout de données d'exemple
        let folder1 = EntityFolderAccount()
        folder1.name = String(localized:"Bank Account",table : "Account")
        
        var account1 = AccountManager.shared.createAccount(
            name: String(localized:"Current account1"),
            icon: "dollarsign.circle",
            folder: folder1 )
        account1 = AccountManager.shared.createOptionAccount(
            account: account1,
            idName: "Martin",
            idSurName: "Pierre",
            numAccount: "00045700E")
        
        var account2 = AccountManager.shared.createAccount(
            name: String(localized:"Current account2"),
            icon: "eurosign.circle",
            folder: folder1
        )
        account2 = AccountManager.shared.createOptionAccount(
            account: account2,
            idName: "Martin",
            idSurName: "Marie",
            numAccount: "00045701F")
        
        folder1.children = [
            account1, account2 ]
        
        let folder2 = EntityFolderAccount()
        folder2.name = String(localized:"Save",table : "Account")
        
        var account3 = AccountManager.shared.createAccount(
            name: String(localized:"Current account3"),
            icon: "calendar.circle",
            folder: folder2 )
        account3 = AccountManager.shared.createOptionAccount(
            account: account3,
            idName: "Durand",
            idSurName: "Jean",
            numAccount: "00045703H")
        
        folder2.children = [
            account3 ]
        
        // Enregistrer les dossiers
        modelContext.insert(folder1)
        modelContext.insert(folder2)
        
        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("AccountFolder save failed: \(error.localizedDescription)")
        }
    }
    
    func saveIfNeeded() {
        do {
            try modelContext?.save()
        } catch {
            #if DEBUG
            print("Save failed: \(error)")
            #endif
        }
    }
}
