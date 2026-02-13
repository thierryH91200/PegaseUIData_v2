//
//  Item.swift
//  testPref
//
//  Created by Thierry hentic on 04/11/2024.
//


import SwiftData
import SwiftUI
import Combine
import OSLog



@Model
final class EntityBankStatement: Identifiable {
       
    @Attribute(.unique) var uuid: UUID = UUID()

    @Attribute var num        : Int
    
    @Attribute var startDate  : Date = Date()
    @Attribute var startSolde : Double
    
    @Attribute var interDate  : Date = Date()
    @Attribute var interSolde : Double
    
    @Attribute var endDate    : Date = Date()
    @Attribute var endSolde   : Double
    
    @Attribute var cbDate     : Date = Date()
    @Attribute var cbSolde    : Double
    
    @Attribute var pdfLink    : String = ""
    @Attribute(.externalStorage) var pdfDoc: Data?
    
    @Relationship var account: EntityAccount
    
    @MainActor
    init(num       : Int  = 0,
         startDate : Date = Date(), startSolde : Double = 0.0,
         interDate : Date = Date(), interSolde : Double = 0.0,
         endDate   : Date = Date(), endSolde   : Double = 0.0,
         cbDate    : Date = Date(), cbSolde    : Double = 0.0,
         pdfLink   : String = "")
    {
        self.num        = num
        self.startDate  = startDate
        self.startSolde = startSolde
        
        self.interDate  = interDate
        self.interSolde = interSolde
        
        self.endDate    = endDate
        self.endSolde   = endSolde
        
        self.cbDate     = cbDate
        self.cbSolde    = cbSolde
        
        self.pdfLink    = pdfLink
        
        self.account = CurrentAccountManager.shared.getAccount()!
    }
}

extension EntityBankStatement: CustomStringConvertible {
    public var description: String {
        "EntityBankStatement(title: \(num), date: \(startSolde.formatted()), uuid: \(uuid))"
    }
}

extension EntityBankStatement {
    
    func formatEuro(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }

    var formattedStartSolde: String { formatEuro(startSolde) }
    var formattedInterSolde: String { formatEuro(interSolde) }
    var formattedEndSolde: String { formatEuro(endSolde) }
    var formattedCBSolde: String { formatEuro(cbSolde) }

    var accountName: String {
        account.identity?.name ?? ""
    }
    
    var accountSurname: String {
        account.identity?.surName ?? ""
    }
}

@MainActor
protocol BankStatementManaging {
    func create(num: Int, startDate: Date, startSolde: Double) -> EntityBankStatement?
    func getAllData() -> [EntityBankStatement]?
    func delete(entity: EntityBankStatement, undoManager: UndoManager?)

    func save () throws
}

@MainActor
final class BankStatementManager : BankStatementManaging, ObservableObject {
    
    // Contexte pour les modifications
    static let shared = BankStatementManager()
    
    @Published var statements = [EntityBankStatement]()
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    init() { }
    
    func reset() {
        statements.removeAll()
    }

    
    func create(num: Int, startDate: Date, startSolde: Double) -> EntityBankStatement? {
        
        guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
            print("[BankStatementManager] Erreur : aucun compte courant trouvé.")
            return nil
        }
        
        let newMode = EntityBankStatement(num: num, startDate: startDate, startSolde: startSolde)
        newMode.account = currentAccount
        
        modelContext?.insert(newMode)
        do {
            try save()
        } catch {
            AppLogger.data.error("BankStatement save failed: \(error.localizedDescription)")
        }
        return newMode
    }
    
    // MARK: - Public Methods
    func getAllData() -> [EntityBankStatement]? {
        
        guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
            print("[BankStatementManager] Erreur : aucun compte courant trouvé.")
            return nil
        }
        
        do {
            let lhs = currentAccount.uuid
            let predicate = #Predicate<EntityBankStatement>{ entity in entity.account.uuid  ==  lhs }
            let sort = [SortDescriptor(\EntityBankStatement.num, order: .forward)]

            let descriptor = FetchDescriptor<EntityBankStatement>(
                predicate: predicate,
                sortBy: sort )
            
            statements = try modelContext?.fetch(descriptor) ?? []
        } catch {
            print("[BankStatementManager] Erreur lors de la récupération des données : \(error.localizedDescription)")
            return []
        }
        return statements
    }

    
    // MARK: - Public Methods
    // Supprimer une transaction
    func delete(entity: EntityBankStatement, undoManager: UndoManager?) {
        guard let context = modelContext else { return }

        context.undoManager = undoManager

        context.undoManager?.beginUndoGrouping()
        context.undoManager?.setActionName("Delete BankStatement")
        context.delete(entity)
        context.undoManager?.endUndoGrouping()
    }
    
    
    func save () throws {
        
        do {
            try modelContext?.save()
        } catch {
            throw EnumError.saveFailed
        }
    }
}

