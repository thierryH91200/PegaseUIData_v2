//
//  EntityAccount.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//
import Foundation
import SwiftData
import SwiftUI
import Combine


@Model class EntityAccount: Identifiable {

    var name: String = ""
    var nameIcon: String = ""
    var currencyCode : String = "EUR"
    var dateEcheancier: Date = Date().noon
    var isDemo : Bool = false
    var isAccount : Bool = true

    //    @Attribute(.ephemeral) var solde: Double? = 0.0

    @Relationship(deleteRule: .cascade, inverse: \EntitySchedule.account)
    var echeanciers: [EntitySchedule] = []
    
    @Relationship(deleteRule: .cascade, inverse: \EntityIdentity.account)
    var identity: EntityIdentity?
    
    @Relationship(deleteRule: .cascade, inverse: \EntityBanqueInfo.account)
    var bank: EntityBanqueInfo?
    
    @Relationship(deleteRule: .cascade, inverse: \EntityPreference.account)
    var preference: EntityPreference?
    
    @Relationship(deleteRule: .cascade, inverse: \EntityInitAccount.account)
    var initAccount: EntityInitAccount?
    
    @Relationship(deleteRule: .cascade, inverse: \EntityPaymentMode.account)
    var paymentMode: [EntityPaymentMode] = []
    
    @Relationship(deleteRule: .cascade, inverse: \EntityStatus.account)
    var status: [EntityStatus] = []

    @Relationship(deleteRule: .cascade, inverse: \EntityBankStatement.account)
    var bankStatement: [EntityBankStatement] = []
    
    @Relationship(deleteRule: .cascade, inverse: \EntityRubric.account)
    var rubric: [EntityRubric] = []
    
    @Relationship(deleteRule: .cascade, inverse: \EntityCheckBook.account)
    var carnetCheques: [EntityCheckBook] = []

    var compteLie: EntityTransaction?
    
    @Relationship(deleteRule: .cascade, inverse: \EntityTransaction.account)
    var transactions: [EntityTransaction] = []
    
    @Relationship var folder: EntityFolderAccount?

    @Attribute(.unique) var uuid: UUID = UUID()

    public init() {
    }
    
    public init(name: String, nameIcon: String) {
        self.name = name
        self.nameIcon = nameIcon
    }
}

extension EntityAccount: Equatable {
    static func == (lhs: EntityAccount, rhs: EntityAccount) -> Bool {
        lhs.uuid == rhs.uuid
    }
}

extension EntityAccount {
    @Transient
    @MainActor
    var solde: Double {
        guard isAccount else { return 0.0 }
        return transactions.reduce(0.0) { $0 + $1.amount }
    }
}

//extension EntityTransaction {
//    func asChartEntry() -> ChartDataEntry {
//        ChartDataEntry(x: dateOperation.timeIntervalSince1970,
//                       y: amount)
//    }
//}



protocol AccountManaging {
    func create(nameAccount: String,
                nameImage: String,
                idName: String,
                idPrenom: String,
                numAccount: String ) -> EntityAccount?
    func createAccount(
        name: String,
        icon: String,
        folder: EntityFolderAccount) -> EntityAccount
    @MainActor func createOptionAccount(
        account : EntityAccount,
        idName: String,
        idSurName: String,
        numAccount: String) -> EntityAccount

    func getAccount(uuid: UUID) -> EntityAccount?
    func getAllData() -> [EntityAccount]
    func delete ( account : EntityAccount)
    func save()
}


final class AccountManager: AccountManaging {
      
    static let shared = AccountManager()
    var entities = [EntityAccount]()
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }
    
    init() { }
    
    func reset() {
        entities.removeAll()
    }

    // MARK: create account
    @MainActor
    func create(nameAccount: String,
                nameImage: String,
                idName: String,
                idPrenom: String,
                numAccount: String ) -> EntityAccount? {
        
        // Crée un nouvel objet EntityAccount
        let account            = EntityAccount()
        account.name           = nameAccount
        account.nameIcon      = nameImage
        account.dateEcheancier = Date().noon
        account.uuid           = UUID()
        
        // Crée une nouvelle identité et un compte initial pour cet EntityAccount
        let identity = IdentityManager.shared.create(name: idName, surName: idPrenom)
        identity.account = account
        account.identity = identity
        
        do {
            let initAccount = try InitAccountManager.shared.create(numAccount: numAccount, for: account)
            initAccount.account = account
            account.initAccount = initAccount
        } catch {
            // Gère les erreurs lors de la création du compte initial
            printTag("Failed to create InitAccount: \(error.localizedDescription)")
            return nil
        }
        
        // Ajoute le nouveau compte à la liste des entités
        modelContext?.insert(account)
        save()
        return account
    }
    
    // createAccount -> crée un compte minimal (sans relations complètes)
    // createOptionAccount -> complète le compte avec identité, banque, init, modes de paiement, statuts, rubriques, préférences
    func createAccount(
        name: String,
        icon: String,
        folder: EntityFolderAccount) -> EntityAccount
    {
        let account = EntityAccount()
        account.name = name
        account.nameIcon = icon
        account.uuid = UUID()
        account.folder = folder
        modelContext?.insert(account)
        save()
        return account
    }

    @MainActor func createOptionAccount(account : EntityAccount, idName: String, idSurName: String, numAccount: String) -> EntityAccount {
        
        let id = account.uuid.uuidString
        CurrentAccountManager.shared.setAccount(id )
        
        // MARK: identity
        let identity = EntityIdentity(
            name: idName, surName: idSurName,
            account: account)
        account.identity = identity
        
        // MARK: Banque Info
        let banqueInfo = EntityBanqueInfo(account: account)
        account.bank = banqueInfo
        
        // MARK: init Account
        let initAccount = EntityInitAccount(account: account)
        initAccount.codeAccount = numAccount
        initAccount.account = account
        account.initAccount = initAccount
        
        // MARK: Payment Mode
        PaymentModeManager.shared.createDefaultPaymentModes(for: account)
        account.paymentMode = PaymentModeManager.shared.modePayments
        
        // MARK: Status
        StatusManager.shared.defaultStatus(account: account)
        account.status = StatusManager.shared.resolveStatuses(for: account)
        
        // MARK: Rubric
        RubricManager.shared.defaultRubric(for: account)
        let rubric = RubricManager.shared.getAllData(account: account)
        account.rubric = rubric

        let entityPreference = PreferenceManager.shared.defaultPref(account: account)
        account.preference = entityPreference
        
        self.modelContext?.insert(account)
        save()
        return account
    }

    @MainActor
    func getAccount(uuid: UUID) -> EntityAccount? {
        guard let ctx = modelContext else {
            printTag("getAccount(uuid:): ModelContext indisponible")
            return nil
        }
        let predicate = #Predicate<EntityAccount> { $0.uuid == uuid }
        var descriptor = FetchDescriptor<EntityAccount>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let entity = try ctx.fetch(descriptor).first
            return entity
        } catch {
            printTag("Erreur lors de la récupération des données : \(error.localizedDescription)")
            return nil
        }
    }

    func getAllData() -> [EntityAccount] {
        do {
            // Exécution d'une requête manuelle si besoin de filtrer ou trier
            let request = FetchDescriptor<EntityAccount>()
            entities = try modelContext?.fetch(request) ?? []
        } catch {
            printTag("Erreur lors de la récupération des données avec SwiftData")
        }
        return entities
    }

    func delete ( account : EntityAccount) {
        
        modelContext?.undoManager = DataContext.shared.undoManager
        modelContext?.undoManager?.beginUndoGrouping()
        modelContext?.undoManager?.setActionName("Delete Account")
        modelContext?.delete(account)
        modelContext?.undoManager?.endUndoGrouping()
        save()
    }

    func save() {
        do {
            try modelContext?.save()
        } catch {
            assertionFailure("Save failed: \(error)")
            print(EnumError.saveFailed)
        }
    }
    
    // Juste pour le debug
    func printAccount(entityAccount : EntityAccount, description : String) {
        let name     = entityAccount.name
        let identity = entityAccount.identity
        let idName   = identity?.name
        let idSurname = identity?.surName
        let idNumber = entityAccount.initAccount?.codeAccount
        let id = entityAccount.uuid

        printTag("\(description)       : \(id) \(name) \(idName ?? "") \(idSurname ?? "") \(idNumber ?? "")")
    }

}


@MainActor
final class CurrentAccountManager: ObservableObject {

    static let shared = CurrentAccountManager()

    // UUID du compte courant (String pour AppStorage / UI)
    @Published private(set) var currentAccountID: String = ""
    @Published private(set) var currentAccount: EntityAccount?
    @Published var isSwitchingAccount: Bool = false


    private init() {}

    /// Accès direct au compte courant
//    var currentAccount: EntityAccount? {
//        getAccount()
//    }
    func switchAccount(_ account: EntityAccount) {
        guard currentAccount?.uuid != account.uuid else { return }

        isSwitchingAccount = true

        Task.detached(priority: .userInitiated) {
            // 🔥 Travail préparatoire hors UI
            await self.preloadAccountData(account)

            // 🔄 Switch UI atomique
            await MainActor.run {
                withAnimation(nil) {
                    self.currentAccount = account
                    self.isSwitchingAccount = false
                }
            }
        }
    }

    // MARK: - Préchargement (hors MainActor)
    nonisolated private func preloadAccountData(_ account: EntityAccount) async {
        // 👉 Ici tu mets ce qui est lent
        // ex: requêtes SwiftData, calculs, cache

        _ = await ListTransactionsManager.shared.prefetchTransactions(
            for: account
        )
    }


    /// Définit le compte courant
    @discardableResult
    func setAccount(_ id: String) -> Bool {
        guard let uuid = UUID(uuidString: id) else {
            printTag("CurrentAccountManager.setAccount: UUID invalide \(id)")
            return false
        }

        guard let account = AccountManager.shared.getAccount(uuid: uuid) else {
            printTag("CurrentAccountManager.setAccount: compte introuvable \(id)")
            return false
        }

        // Invalider le cache des transactions car on change de compte
        ListTransactionsManager.shared.invalidateCache()

        currentAccountID = account.uuid.uuidString
        return true
    }

    /// Récupération du compte courant
    func getAccount() -> EntityAccount? {
        guard let uuid = UUID(uuidString: currentAccountID) else {
            return nil
        }
        return AccountManager.shared.getAccount(uuid: uuid)
    }

    /// Réinitialise le compte courant
    func clearAccount() {
        currentAccountID = ""
    }
}

