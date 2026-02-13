//
//  AppErrors.swift
//  PegaseUIData
//
//  Created for error handling improvement
//

import Foundation

// MARK: - Account Errors
enum AccountError: LocalizedError {
    case currentAccountNotFound
    case failedToCreateAccount

    var errorDescription: String? {
        switch self {
        case .currentAccountNotFound:
            return NSLocalizedString("Unable to retrieve current account", comment: "")
        case .failedToCreateAccount:
            return NSLocalizedString("Failed to create account entity", comment: "")
        }
    }
}

// MARK: - Resource Errors
enum ResourceError: LocalizedError {
    case fileNotFound(String)
    case failedToLoad(String)
    case failedToDecode(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let file):
            return NSLocalizedString("Failed to locate resource: \(file)", comment: "")
        case .failedToLoad(let file):
            return NSLocalizedString("Failed to load resource: \(file)", comment: "")
        case .failedToDecode(let file):
            return NSLocalizedString("Failed to decode resource: \(file)", comment: "")
        }
    }
}

// MARK: - Data Errors (replaces EnumError)
enum DataError: LocalizedError {
    case contextNotConfigured
    case accountNotFound
    case invalidStatusType
    case saveFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .contextNotConfigured:
            return NSLocalizedString("Database context is not configured", comment: "")
        case .accountNotFound:
            return NSLocalizedString("Account not found", comment: "")
        case .invalidStatusType:
            return NSLocalizedString("Invalid status type", comment: "")
        case .saveFailed:
            return NSLocalizedString("Failed to save data", comment: "")
        case .fetchFailed:
            return NSLocalizedString("Failed to fetch data", comment: "")
        }
    }
}

// MARK: - Import/Export Errors
enum ImportError: LocalizedError {
    case fileAccessDenied
    case fileReadFailed(String)
    case invalidFormat
    case noAccountSelected
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return NSLocalizedString("Cannot access the file (Security Scoped)", comment: "")
        case .fileReadFailed(let detail):
            return NSLocalizedString("Failed to read file: \(detail)", comment: "")
        case .invalidFormat:
            return NSLocalizedString("Invalid file format", comment: "")
        case .noAccountSelected:
            return NSLocalizedString("No account selected for import", comment: "")
        case .saveFailed(let error):
            return NSLocalizedString("Failed to save imported data: \(error.localizedDescription)", comment: "")
        }
    }
}

// MARK: - Database Lifecycle Errors
enum DatabaseError: LocalizedError {
    case creationFailed(underlying: Error)
    case openFailed(underlying: Error)
    case deleteFailed(entity: String)

    var errorDescription: String? {
        switch self {
        case .creationFailed(let error):
            return NSLocalizedString("Failed to create database: \(error.localizedDescription)", comment: "")
        case .openFailed(let error):
            return NSLocalizedString("Failed to open database: \(error.localizedDescription)", comment: "")
        case .deleteFailed(let entity):
            return NSLocalizedString("Failed to delete \(entity) data", comment: "")
        }
    }
}
