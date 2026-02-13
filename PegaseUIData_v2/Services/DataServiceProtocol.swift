//
//  DataServiceProtocol.swift
//  PegaseUIData
//
//  Base protocols for the Service Layer
//  Provides abstraction for data operations and enables dependency injection
//

import Foundation
import SwiftData
import Combine

// MARK: - Base Service Protocol

/// Base protocol for all data services
/// Provides common functionality for CRUD operations
protocol DataService {
    associatedtype Entity: PersistentModel

    /// The model context used for data operations
    var modelContext: ModelContext? { get }

    /// Fetch all entities
    func fetchAll() -> [Entity]

    /// Fetch entity by UUID
    func fetch(byUUID uuid: UUID) -> Entity?

    /// Save changes to the context
    func save() throws

    /// Delete an entity
    func delete(_ entity: Entity) throws
}

// MARK: - Default Implementation

extension DataService {
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    func save() throws {
        guard let context = modelContext else {
            throw ServiceError.contextUnavailable
        }
        try context.save()
    }

    func delete(_ entity: Entity) throws {
        guard let context = modelContext else {
            throw ServiceError.contextUnavailable
        }
        context.delete(entity)
        try context.save()
    }
}

// MARK: - Service Errors

/// Errors that can occur during service operations
enum ServiceError: LocalizedError {
    case contextUnavailable
    case entityNotFound
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case validationFailed(reason: String)
    case operationFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return NSLocalizedString("Database context is not available", comment: "")
        case .entityNotFound:
            return NSLocalizedString("The requested entity was not found", comment: "")
        case .saveFailed(let error):
            return NSLocalizedString("Failed to save: \(error.localizedDescription)", comment: "")
        case .deleteFailed(let error):
            return NSLocalizedString("Failed to delete: \(error.localizedDescription)", comment: "")
        case .validationFailed(let reason):
            return NSLocalizedString("Validation failed: \(reason)", comment: "")
        case .operationFailed(let reason):
            return NSLocalizedString("Operation failed: \(reason)", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .contextUnavailable:
            return NSLocalizedString("Try reopening the database", comment: "")
        case .entityNotFound:
            return NSLocalizedString("The item may have been deleted", comment: "")
        case .saveFailed:
            return NSLocalizedString("Check available disk space and try again", comment: "")
        case .deleteFailed:
            return NSLocalizedString("Close any related views and try again", comment: "")
        case .validationFailed:
            return NSLocalizedString("Check the form fields and try again", comment: "")
        case .operationFailed:
            return NSLocalizedString("Try the operation again", comment: "")
        }
    }
}

// MARK: - Service Result Type

/// Result type for async service operations
typealias ServiceResult<T> = Result<T, ServiceError>

// MARK: - Date Range Protocol

/// Protocol for services that support date-based filtering
protocol DateRangeFilterable {
    associatedtype Entity

    /// Fetch entities within a date range
    func fetch(from startDate: Date, to endDate: Date) -> [Entity]
}

// MARK: - Cacheable Protocol

/// Protocol for services that support caching
protocol CacheableService {
    /// Invalidate all cached data
    func invalidateCache()

    /// Check if cache is valid
    var isCacheValid: Bool { get }
}

// MARK: - Observable Service Protocol

/// Protocol for services that publish updates
protocol ObservableService: ObservableObject {
    associatedtype Entity

    /// Published list of entities
    var entities: [Entity] { get }

    /// Publisher for entity changes
    var entitiesPublisher: Published<[Entity]>.Publisher { get }
}

// MARK: - Undoable Service Protocol

/// Protocol for services that support undo/redo
protocol UndoableService {
    /// UndoManager for the service
    var undoManager: UndoManager? { get }

    /// Perform undo
    func undo()

    /// Perform redo
    func redo()

    /// Check if undo is available
    var canUndo: Bool { get }

    /// Check if redo is available
    var canRedo: Bool { get }
}

extension UndoableService {
    var undoManager: UndoManager? {
        DataContext.shared.undoManager
    }

    var canUndo: Bool {
        undoManager?.canUndo ?? false
    }

    var canRedo: Bool {
        undoManager?.canRedo ?? false
    }
}
