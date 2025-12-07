//
//  setupForNilLibrary.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 10/11/2024.
//

import SwiftUI
import SwiftData
import Combine


struct AccountFactory {
    static func createAccount(modelContext: ModelContext, name: String, icon: String) -> EntityAccount {
        
        let account = EntityAccount()
        account.name = name
        account.nameIcon = icon
        account.uuid = UUID()
        
        print(account.uuid.uuidString)
        
        modelContext.insert(account)
        save()
        return account
    }

    @MainActor static func createOptionAccount(modelContext: ModelContext, account : EntityAccount, idName: String, idSurName: String, numAccount: String) -> EntityAccount {
        
        print(account.uuid.uuidString)
        
        let id = account.uuid.uuidString
        CurrentAccountManager.shared.setAccount(id )
        
        let identity = EntityIdentity(name: idName, surName: idSurName, account: account)
        account.identity = identity
        
        let banqueInfo = EntityBanqueInfo(account: account)
        account.bank = banqueInfo
        
        let initAccount = EntityInitAccount(account: account)
        initAccount.codeAccount = numAccount
        initAccount.account = account
        account.initAccount = initAccount
        
        PaymentModeManager.shared.createDefaultPaymentModes(for: account)
        account.paymentMode = PaymentModeManager.shared.modePayments
        
        StatusManager.shared.defaultStatus(account: account)
        account.status = StatusManager.shared.resolveStatuses(for: account)
        
        RubricManager.shared.defaultRubric(for: account)
        let rubric = RubricManager.shared.getAllData(account: account)
        account.rubric = rubric

        let entityPreference = PreferenceManager.shared.defaultPref(account: account)
        account.preference = entityPreference
        
        modelContext.insert(account)
        do {
            try modelContext.save()
        } catch {
            // Log technique; tu peux remplacer par OSLog si tu préfères
            print("❌ Error saving after create Person:", error)
        }

        return account
    }
    
    static func save () {
        var modelContext: ModelContext? {
            DataContext.shared.context
        }

        do {
            try modelContext?.save()
        } catch {
            printTag("Erreur lors de la sauvegarde de l'entité : \(error)", flag: true)
        }
    }


    static func createHeader(modelContext: ModelContext, name: String) -> EntityFolderAccount {
        let header = EntityFolderAccount()
        header.name = name
        header.nameImage = "folder.fill"
        header.uuid = UUID()
        
        modelContext.insert(header)
        return header
    }
}

@Observable
final class InitManager {
    
    static let shared = InitManager()
        
    private enum DefaultIcons {
        static let currentAccount = "building.columns"
        static let savings = "banknote"
        static let creditCard = "creditcard"
    }
    
    // Contexte pour les modifications
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    private init() { }

    // Initialise la base si elle est vide
    @MainActor func initialize() {
//        guard let ctx = modelContext else {
//            printTag("InitManager.initialize: ModelContext indisponible.", flag: true)
//            return
//        }
        // Déterminer si des dossiers existent déjà (critère: isRoot == false)
        let entities = AccountFolderManager.shared.getRoot()
        guard entities.isEmpty == true else {
            // Déjà initialisé
            return
        }
        setupDefaultLibrary()
    }
    
    @MainActor func setupDefaultLibrary() {
        guard let ctx = modelContext else {
            printTag("InitManager.setupDefaultLibrary: ModelContext indisponible.", flag: true)
            return
        }
        
        // Création des dossiers (folders)
        let folder1 = AccountFactory.createHeader(modelContext: ctx,
                                                  name: String(localized :"Bank Account",table : "Account"))
        let folder2 = AccountFactory.createHeader(modelContext: ctx,
                                                  name: String(localized :"Save",table : "Account"))
        
        let typeAccounts : [String] = [
            String(localized :"Current account1",table : "Account"),
            String(localized :"Current account2",table : "Account"),
            String(localized :"Credit card1",table : "Account"),
            String(localized :"Credit card2",table : "Account"),
            String(localized :"Save",table : "Account"),
            String(localized :"Current account3",table : "Account")]
        
        let accountsConfig: [(name: String, icon: String, idName: String, idSurname: String, numAccount: String)] = [
            (typeAccounts[0], DefaultIcons.currentAccount, "Martin", "Pierre", "00045700E"),
            (typeAccounts[1], DefaultIcons.currentAccount, "Martin", "Marie", "00045701F"),
            (typeAccounts[2], DefaultIcons.creditCard, "Martin", "Pierre", "00045702G"),
            (typeAccounts[3], DefaultIcons.creditCard, "Durand", "Jean", "00045705K"),
            (typeAccounts[4], DefaultIcons.currentAccount, "Durand", "Jean", "00045703H"),
            (typeAccounts[5], DefaultIcons.currentAccount, "Durand", "Sarah", "00045704J")
        ]
        
        // Comptes rattachés au premier dossier
        for config in accountsConfig[0...2] {
            var account = AccountFactory.createAccount(
                modelContext: ctx,
                name: config.0,
                icon: config.1
            )
            account = AccountFactory.createOptionAccount(
                modelContext: ctx,
                account : account,
                idName: config.2,
                idSurName: config.3,
                numAccount: config.4
            )
            folder1.addChild(account)
            print("account ", account.uuid)
        }

        // Comptes rattachés au second dossier
        for config in accountsConfig[3...3] {
            var account = AccountFactory.createAccount(
                modelContext: ctx,
                name: config.0,
                icon: config.1
            )
            account = AccountFactory.createOptionAccount(
                modelContext: ctx,
                account : account,
                idName: config.2,
                idSurName: config.3,
                numAccount: config.4
            )
            folder2.addChild(account)
            print("account ", account.uuid)
        }
        
        // Enregistrer les dossiers
        ctx.insert(folder1)
        ctx.insert(folder2)
        
        // Enregistrement des modifications
        saveContext()
    }
    
    func saveContext() {
        guard let ctx = modelContext else {
            printTag("InitManager.saveContext: ModelContext indisponible.", flag: true)
            return
        }

        if let path = getSQLiteFilePath() {
            printTag(path, flag: true)
        } else {
            printTag("Erreur : chemin SQLite introuvable.", flag: true)
        }
        do {
            try ctx.save()
        } catch {
            printTag("Erreur : \(error.localizedDescription)", flag: true)
        }
    }
}
