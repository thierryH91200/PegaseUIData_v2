//
//  Status.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 12/11/2024.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@Model final class EntityStatus :  Identifiable , Hashable {
    
    var name: String
    var rawType: Int
    
    @Attribute(.transformable(by: ColorTransformer.self)) var color: NSColor

    @Attribute(.unique) var uuid: UUID = UUID()

    @Relationship var account: EntityAccount

    var type: StatusType {
        get { StatusType(rawValue: rawType) ?? .planned }
        set { rawType = newValue.rawValue }
    }
    
    // Implémente Hashable
    public static func == (lhs: EntityStatus, rhs: EntityStatus) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    init(type : StatusType, account : EntityAccount) {
        self.name    = type.localizedName
        self.rawType = type.rawValue
        self.color   = type.color
        self.account = account
    }
}

extension EntityStatus: CustomStringConvertible {
    public var description: String {
        "EntityStatus(name: \(name), type: \(type), color: \(color.description), account: \(account.name), uuid: \(uuid))"
    }
}

@MainActor
protocol StatusManaging {
    func create(account: EntityAccount?, name: String, type: Int, color: NSColor) throws -> EntityStatus?
    func find( account: EntityAccount?, name: String) -> EntityStatus?
    func saveContext()
    func defaultStatus(account: EntityAccount)
}

//@Observable
@MainActor
final class StatusManager: StatusManaging, ObservableObject {
    
    static let shared = StatusManager()
    
    @Published private(set) var statusIDs: [UUID] = []

    var modelContext: ModelContext? {
        DataContext.shared.context
    }
    
    private init() {}
    
    @MainActor func reset() {
        statusIDs.removeAll()
    }
    
    /// Refetch des statuts valides pour un compte
    func resolveStatuses(for account: EntityAccount) -> [EntityStatus] {
        guard let context = modelContext else { return [] }
        
        var list: [EntityStatus] = []
        let lhs = account.uuid

        for id in statusIDs {
            let predicate = #Predicate<EntityStatus> { $0.uuid == id && $0.account.uuid == lhs }
            let fd = FetchDescriptor<EntityStatus>(predicate: predicate)
            if let found = try? context.fetch(fd).first {
                list.append(found)
            }
        }
        return list
    }

    func create(account: EntityAccount?, name: String, type: Int, color: NSColor) throws -> EntityStatus? {
        
        guard let statusType = StatusType(rawValue: type) else {
            throw EnumError.invalidStatusType
        }

        guard let context = modelContext else { return nil }
        guard let account = account ?? CurrentAccountManager.shared.getAccount() else {
            throw EnumError.accountNotFound
        }
        
        let newStatus = EntityStatus( type: statusType, account: account)
        context.insert(newStatus)
        try context.save()
        return newStatus
    }
    
    func find( account: EntityAccount? = nil, name: String) -> EntityStatus? {
        
        guard let account = account ?? CurrentAccountManager.shared.getAccount() else { return nil }
        
        let lhs = account.uuid
        let predicate = #Predicate<EntityStatus> { $0.account.uuid == lhs && $0.name == name }
        let sort = [SortDescriptor(\EntityStatus.name, order: .forward)] // Trier par le nom
        
        let fetchDescriptor = FetchDescriptor<EntityStatus>(
            predicate: predicate, // Filtrer par le compte
            sortBy: sort )
        
        do {
            let searchResults = try modelContext?.fetch(fetchDescriptor) ?? []
            let result = searchResults.isEmpty == false ? searchResults.first : nil
            return result
        } catch {
            printTag("Error with request: \(error)", flag: true)
            return nil
        }
    }
    
    @MainActor func getAllNames() -> [String] {
        
        return getAllData().map { $0.name }
    }

    func getAllData(for account: EntityAccount? = nil) -> [EntityStatus] {
        
        guard let account = account ?? CurrentAccountManager.shared.getAccount() else { return [] }
        guard let context = modelContext else { return [] }

        do {
            let lhs = account.uuid
            let predicate = #Predicate<EntityStatus> { $0.account.uuid == lhs }
            let sort = [SortDescriptor(\EntityStatus.name, order: .forward)]
            let fd = FetchDescriptor<EntityStatus>(predicate: predicate, sortBy: sort)
            
            let fetched = try context.fetch(fd)
            statusIDs = fetched.map { $0.uuid }
            return fetched
        } catch {
            printTag("❌ Erreur fetch Status: \(error)")
            return []
        }
    }
    
    func save () throws {
        
        do {
            try modelContext?.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)", flag: true)
        }
    }
    
    func saveContext() {
        if let path = getSQLiteFilePath() {
            printTag("Base de données SQLite : \(path)", flag: true)
        } else {
            printTag("Erreur : Impossible de récupérer le chemin SQLite", flag: true)
        }
        
        do {
            try save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)", flag: true)
        }
    }
    
    func defaultStatus(account: EntityAccount) {
        statusIDs.removeAll()
        
        for type in StatusType.allCases {
            let status = EntityStatus(type: type, account: account)
            modelContext?.insert(status)
        }
        
        do {
            try modelContext?.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)", flag: true)
        }
        _ = getAllData(for: account)
    }
}

enum StatusType: Int, CaseIterable, Identifiable {
    case planned = 0
    case inProgress = 1
    case executed = 2

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .planned:
            return String(localized: "Planned")
        case .inProgress:
            return String(localized: "In progress")
        case .executed:
            return String(localized: "Executed")
        }
    }

    var color            : NSColor {
        switch self {
        case .planned    : return .blue
        case .inProgress : return .green
        case .executed   : return .red
        }
    }
}
