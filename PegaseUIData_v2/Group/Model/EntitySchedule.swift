//
//  EntitySchedule.swift
//  Pegase
//
//  Created by Thierry hentic on 03/11/2024.
//
//

import Foundation
import SwiftData
import SwiftUI
import Combine


@Model
final class EntitySchedule : Identifiable {
    var amount                   : Double = 0.0
    var dateCree                 : Date   = Date()
    var dateDebut                : Date   = Date()
    var dateFin                  : Date   = Date()
    var dateModifie              : Date   = Date()
    var dateValeur               : Date   = Date()
    var frequence                : Int16  = 0
    var libelle                  : String = ""
    var nextOccurrence           : Int16  = 0
    var occurrence               : Int16  = 0
    var typeFrequence            : Int16  = 0

    @Attribute var isProcessed: Bool = false
    
    @Attribute(.unique) var uuid: UUID = UUID()

    var category                 : EntityCategory?
    var paymentMode              : EntityPaymentMode?
    
    // Do NOT declare inverse here; the inverse is declared on EntityAccount.compteLie
    @Relationship
    var linkedAccount : EntityAccount?
    
    // Do NOT declare inverse here; the inverse is declared on EntityAccount.echeanciers
    @Relationship
    var account    : EntityAccount

    @MainActor
    public init() {
        self.account = CurrentAccountManager.shared.getAccount()!
    }
    
    public init(
        amount        : Double,
        dateValeur    : Date,
        dateDebut     : Date,
        dateFin       : Date,
        frequence     : Int16,
        libelle       : String,
        nextOccurrence : Int16,
        occurrence    : Int16,
        typeFrequence : Int16,
        account       : EntityAccount ){
            
            self.amount = amount
            self.libelle = libelle
            self.dateFin = dateFin
            self.dateDebut = dateDebut
            self.dateValeur = dateValeur
            self.frequence =  frequence
            self.libelle = libelle
            self.nextOccurrence = nextOccurrence
            self.occurrence = occurrence
            self.typeFrequence = typeFrequence
            self.account = account
        }
}

extension EntitySchedule: CustomStringConvertible {
    public var description: String {
        "EntitySchedule(libelle: \(libelle), amount: \(amount), dateValeur: \(dateValeur.formatted()), isProcessed: \(isProcessed), uuid: \(uuid))"
    }
}

extension EntitySchedule {
    var categoryName: String {
        category?.name ?? "N/A"
    }
}

@MainActor
protocol ScheduleManaging {
    func create() -> EntitySchedule
    func getAllData() -> [EntitySchedule]?
    func save () throws
}

@MainActor
final class SchedulerManager: ScheduleManaging, ObservableObject  {

    @Published var schedulers = [EntitySchedule]()
    
    static let shared = SchedulerManager()
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    init() { }
    
    func reset() {
        schedulers.removeAll()
    }

    @MainActor func create() -> EntitySchedule {
        let entity = EntitySchedule()
        modelContext?.insert(entity)
        do {
            try save()
            schedulers.append(entity)
        } catch {
            // Log and avoid appending if save failed
            printTag("Erreur lors de la sauvegarde de l'échéancier: \(error.localizedDescription)", flag: true)
        }
        return entity
    }
    
    func update(entity: EntitySchedule, name: String) {
        entity.libelle = name
    }
    
    // Suppression d'une entité
    func delete(entity: EntitySchedule, undoManager: UndoManager?) {
        guard let modelContext = modelContext else { return }

        modelContext.undoManager = undoManager
        modelContext.undoManager?.beginUndoGrouping()
        modelContext.undoManager?.setActionName("Delete Schedule")
        modelContext.delete(entity)
        modelContext.undoManager?.endUndoGrouping()
    }
    
    // Récupérer toutes les données filtrées par compte
    @MainActor func getAllData() -> [EntitySchedule]? {
        
        guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
            printTag("Erreur : aucun compte courant trouvé.", flag: true)
            return nil
        }
        
        let lhs = currentAccount.uuid
        let predicate = #Predicate<EntitySchedule>{ entity in entity.account.uuid == lhs }
        let sort =  [SortDescriptor(\EntitySchedule.libelle, order: .forward)]
        
        let descriptor = FetchDescriptor<EntitySchedule>(
            predicate: predicate,
            sortBy: sort )
        
        do {
            // Récupérez les entités en utilisant le FetchDescriptor
            schedulers = try modelContext?.fetch( descriptor ) ?? []
        } catch {
            print("Erreur lors de la récupération des données: \(error)")
            return [] // Retourne nil en cas d'erreur
        }
        return schedulers
    }
    
    
    @MainActor func createTransaction (entitySchedule: EntitySchedule) {

        entitySchedule.nextOccurrence += 1
        guard let account = CurrentAccountManager.shared.getAccount() else {
            printTag("Erreur: aucun compte courant trouvé")
            return
        }
        let entityStatus = StatusManager.shared.getAllData(for: account)

        let dateValeur = entitySchedule.dateValeur.noon

        let entityTransaction = EntityTransaction(account: entitySchedule.account)

        entityTransaction.createAt       = Date().noon
        entityTransaction.updatedAt    = Date().noon
        entityTransaction.dateOperation  = dateValeur
        entityTransaction.datePointage   = dateValeur
        
        entityTransaction.paymentMode    = entitySchedule.paymentMode
        entityTransaction.status         = Date() >= dateValeur ? entityStatus[2] : entityStatus[1]
        
        entityTransaction.bankStatement = 0
        entityTransaction.uuid           = UUID()
        
        // create sous transaction
        let entitySousOperation = createSousOperation(for: entitySchedule)
        
        // addd sous transaction
        entityTransaction.addSubOperation(  entitySousOperation)
        
        if entitySchedule.linkedAccount != nil {
            //            createComptelie()
        }
        do {
            try save()
        } catch {
            
        }
    }
    
    func createComptelie() {
        // (omitted legacy commented code)
    }
    
    // Créer une sous-opération
    @MainActor func createSousOperation(for schedule: EntitySchedule) -> EntitySousOperation {
        let sousOperation = EntitySousOperation()
        
        let rubricName = schedule.category?.rubric?.name ?? ""
        let color = schedule.category?.rubric?.color ?? .black
        let rubric = RubricManager.shared.findOrCreate(account: schedule.account, name: rubricName, color: color)
        
        let categoryName = schedule.category?.name ?? ""
        let objectif = schedule.category?.objectif ?? 0.0
        let category = CategoryManager.shared.findOrCreate(
            account: schedule.account,
            name: categoryName,
            objectif: objectif,
            rubric: rubric)
        
        sousOperation.category = category
        sousOperation.category?.rubric = rubric
        sousOperation.amount = schedule.amount
        sousOperation.libelle = schedule.libelle
        
        return sousOperation
    }
    
    @MainActor func createTransaction(for schedule: EntitySchedule, on dateValeur: Date) {
        schedule.nextOccurrence += 1

        let transaction = EntityTransaction(account: schedule.account)

        transaction.createAt = Date()
        transaction.updatedAt = Date()
        transaction.dateOperation = dateValeur
        transaction.datePointage = dateValeur
        transaction.paymentMode = schedule.paymentMode
        transaction.bankStatement = 0
        transaction.uuid = UUID()
        
        let sousOperation = createSousOperation(for: schedule)
        transaction.sousOperations.append( sousOperation )
        
        if let linkedAccount = schedule.linkedAccount {
            let transferTransaction = EntityTransaction(account: linkedAccount)
            transferTransaction.createAt = transaction.createAt
            transferTransaction.updatedAt = transaction.updatedAt
            transferTransaction.dateOperation = transaction.dateOperation
            transferTransaction.datePointage = transaction.datePointage
            transferTransaction.status = transaction.status
            transferTransaction.bankStatement = transaction.bankStatement
            
            let paymentModeName = transferTransaction.paymentMode?.name ?? ""
            let color = transferTransaction.paymentMode?.color ?? .black
            let paymentModeUUID = transferTransaction.paymentMode?.uuid ?? UUID()
            let paymentMode = PaymentModeManager.shared.findOrCreate(account: linkedAccount, name: paymentModeName, color: Color(color), uuid: paymentModeUUID)
            
            transferTransaction.paymentMode = paymentMode
            
            let rubric = RubricManager.shared.findOrCreate(
                account: linkedAccount,
                name: paymentModeName,
                color: .black)
            
            let categoryName = schedule.category?.name ?? "nil"
            let objectif = schedule.category?.objectif ?? 0.0
            let category = CategoryManager.shared.findOrCreate(
                account: linkedAccount,
                name: categoryName,
                objectif: objectif,
                rubric: rubric)
            
            let transferSousOperation = EntitySousOperation()
            transferSousOperation.category = category
            transferSousOperation.category?.rubric = rubric
            transferSousOperation.amount = -schedule.amount
            
            transferTransaction.sousOperations.append(transferSousOperation)
            transferTransaction.uuid = UUID()
            modelContext?.insert(transferTransaction)
        }
        if modelContext?.hasChanges ?? false{
            do {
                try modelContext?.save()
            } catch {
                printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)", flag: true)
            }
        }
    }
    func save () throws {
        do {
            try modelContext?.save()
        } catch {
            throw EnumError.saveFailed
        }
    }
    
    func selectScheduler(_ scheduler: EntitySchedule) {
        NotificationCenter.default.post(name: .didSelectScheduler, object: scheduler)
    }
    
}

