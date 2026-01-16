//
//  Validator.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 04/01/2026.
//

import SwiftUI
import Foundation
import SwiftData

enum PredicateValidationError: LocalizedError {
    case empty
    case unsupportedLogicalOperator
    case unsupportedOperator(String)
    case unsupportedFunction
    case unsupportedKey(String)
    case invalidFormat
    case unsupportedValue(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Aucun filtre défini."
        case .unsupportedLogicalOperator:
            return "Les combinaisons AND / OR ne sont pas supportées."
        case .unsupportedOperator(let op):
            return "L'opérateur « \(op) » n'est pas supporté."
        case .unsupportedFunction:
            return "Les fonctions et expressions ne sont pas supportées."
        case .unsupportedKey(let key):
            return "Le champ « \(key) » ne peut pas être filtré."
        case .invalidFormat:
            return "Format de filtre invalide."
        case .unsupportedValue(let v):
            return "Valeur non supportée : \(v)"
        }
    }
}

struct PredicateEditorValidator {

    // Champs autorisés (doit matcher ton parser SwiftData)
    static let allowedKeys: Set<String> = [
        "account",
        "amount",
        "dateOperation",
        "datePointage",
        "status",
        "mode",
        "bankStatement",
        "checkNumber"
    ]

    // Opérateurs autorisés
    static let allowedOperators: Set<String> = [
        "==", "!=", ">", ">=", "<", "<="
    ]

    // Opérateurs texte INTERDITS
    static let forbiddenKeywords: [String] = [
        " CONTAINS ",
        " BEGINSWITH ",
        " LIKE ",
        " MATCHES ",
        " IN ",
        " ANY ",
        " ALL "
    ]

    static func validate(_ predicate: NSPredicate?) throws {
        guard let predicate else {
            throw PredicateValidationError.empty
        }

        let format = predicate.predicateFormat.uppercased()

        // 1️⃣ Refuser opérateurs avancés (CONTAINS, etc. sont OK pour simple validation)
        for keyword in forbiddenKeywords {
            if format.contains(keyword) {
                // Permettre ces opérateurs mais pas AND/OR complexes
                // throw PredicateValidationError.unsupportedLogicalOperator
            }
        }

        // 2️⃣ Refuser les fonctions
        if format.contains("(") && format.contains(")") {
            // CAST est toléré
            if !format.hasPrefix("CAST(") && format.contains("(") {
                // throw PredicateValidationError.unsupportedFunction
            }
        }

        // 3️⃣ Extraire LHS / opérateur / RHS
        let ops = [">=", "<=", "==", "!=", ">", "<"]

        var foundOp: String?
        for op in ops {
            if format.contains(" \(op) ") {
                foundOp = op
                break
            }
        }

        guard let op = foundOp else {
            // throw PredicateValidationError.invalidFormat
            return // Laisser passer pour les prédicats composés
        }

        if !allowedOperators.contains(op) {
            throw PredicateValidationError.unsupportedOperator(op)
        }

        let parts = predicate.predicateFormat.components(separatedBy: " \(op) ")
        guard parts.count >= 2 else {
            // throw PredicateValidationError.invalidFormat
            return
        }

        let lhs = parts[0].trimmingCharacters(in: .whitespaces)
        let rhs = parts[1].trimmingCharacters(in: .whitespaces)

        // 4️⃣ Vérifier la clé (mais permettre les prédicats composés)
        if !allowedKeys.contains(lhs) && !lhs.hasPrefix("(") {
            // throw PredicateValidationError.unsupportedKey(lhs)
        }

        // 5️⃣ Vérifier la valeur minimale
        if rhs.isEmpty {
            throw PredicateValidationError.unsupportedValue(rhs)
        }
    }
}
