//
//  TransactionPredicateParser.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 16/01/2026.
//

import SwiftUI
import SwiftData
import Foundation

/// Parser qui convertit un NSPredicate en Predicate<EntityTransaction> pour SwiftData
@MainActor
struct TransactionPredicateParser {

    // Cache pour stocker l'EntityAccount extrait du NSPredicate
    private static var lhsAccount: UUID = UUID()

    // MARK: - Main Conversion Function

    /// Convertit un NSPredicate en Predicate<EntityTransaction>
    static func swiftDataPredicate(from nsPredicate: NSPredicate?) -> Predicate<EntityTransaction>? {
        guard let nsPredicate else {
            print("      [Parser] NSPredicate est nil")
            return nil
        }

        print("      [Parser] Format original: \(nsPredicate.predicateFormat)")

        // Extraire l'EntityAccount si présent dans le prédicat
//        extractAccountFromPredicate(nsPredicate)

        // Normaliser le format
        let format = normalizePredicateFormat(nsPredicate.predicateFormat)
        print("      [Parser] Format normalisé: \(format)")

        // Enlever les parenthèses externes si présentes
        let trimmedFormat = trimOuterParens(format)
        print("      [Parser] Format sans parenthèses: \(trimmedFormat)")

        // Tokenize pour gérer AND/OR
        let tokens = tokenizeTopLevel(trimmedFormat)
        print("      [Parser] Tokens: \(tokens.count)")

        // Si un seul token d'expression, traiter directement
        if tokens.count == 1, case let .expr(expr) = tokens[0] {
            print("      [Parser] Expression simple: \(expr)")
            let result = predicateForBinary(expr)
            print("      [Parser] Résultat: \(result != nil ? "✅ Succès" : "❌ Échec")")
            return result
        }

        // Combiner les tokens avec AND/OR
        print("      [Parser] Expression composée avec \(tokens.count) tokens")
        let result = combineTokens(tokens)
        print("      [Parser] Résultat: \(result != nil ? "✅ Succès" : "❌ Échec")")
        return result
    }

    // MARK: - Normalization

    /// Normalise le format du prédicat en enlevant les modificateurs [cd], [c], [d]
    private static func normalizePredicateFormat(_ format: String) -> String {
        var normalized = format

        // Enlever les modificateurs case-insensitive et diacritic-insensitive
        let modifiers = ["[cd]", "[c]", "[d]"]
        let operators = ["==", "!=", ">=", "<=", ">", "<"]

        for op in operators {
            for modifier in modifiers {
                normalized = normalized.replacingOccurrences(of: "\(op)\(modifier)", with: op)
            }
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Enlève les parenthèses externes si elles englobent toute l'expression
    private static func trimOuterParens(_ s: String) -> String {
        var s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("(") && s.hasSuffix(")") {
            var level = 0
            var isBalanced = true
            for (i, ch) in s.enumerated() {
                if ch == "(" { level += 1 }
                else if ch == ")" {
                    level -= 1
                    if level < 0 { isBalanced = false; break }
                }
                if i < s.count - 1 && level == 0 { isBalanced = false; break }
            }
            if isBalanced {
                s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return s
    }

    // MARK: - Tokenization
    private enum Token {
        case expr(String)
        case and
        case or
    }

    /// Tokenize l'expression en séparant les expressions et les opérateurs logiques AND/OR
    private static func tokenizeTopLevel(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var level = 0
        var i = s.startIndex

        func flush() {
            let part = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty {
                tokens.append(.expr(part))
            }
            current = ""
        }

        while i < s.endIndex {
            let ch = s[i]

            if ch == "(" {
                level += 1
                current.append(ch)
                i = s.index(after: i)
                continue
            }

            if ch == ")" {
                level -= 1
                current.append(ch)
                i = s.index(after: i)
                continue
            }

            // Détecter AND/OR au niveau 0 uniquement
            if level == 0 {
                if s[i...].hasPrefix(" AND ") {
                    flush()
                    tokens.append(.and)
                    i = s.index(i, offsetBy: 5)
                    continue
                }
                if s[i...].hasPrefix(" OR ") {
                    flush()
                    tokens.append(.or)
                    i = s.index(i, offsetBy: 4)
                    continue
                }
            }

            current.append(ch)
            i = s.index(after: i)
        }

        flush()
        return tokens
    }

    // MARK: - Token Combination

    /// Combine les tokens en un seul Predicate avec AND/OR
    private static func combineTokens(_ tokens: [Token]) -> Predicate<EntityTransaction>? {
        var currentPredicate: Predicate<EntityTransaction>?
        var pendingOp: Token?

        for token in tokens {
            switch token {
            case .expr(let expr):
                guard let next = predicateForBinary(expr) else { return nil }

                if let pending = pendingOp, let existing = currentPredicate {
                    switch pending {
                    case .and:
                        currentPredicate = #Predicate<EntityTransaction> { entity in
                            existing.evaluate(entity) && next.evaluate(entity)
                        }
                    case .or:
                        currentPredicate = #Predicate<EntityTransaction> { entity in
                            existing.evaluate(entity) || next.evaluate(entity)
                        }
                    default:
                        break
                    }
                    pendingOp = nil
                } else {
                    currentPredicate = next
                }

            case .and, .or:
                pendingOp = token
            }
        }

        return currentPredicate
    }

    // MARK: - Binary Predicate Parsing

    /// Parse une expression binaire (key op value)
    private static func predicateForBinary(_ expr: String) -> Predicate<EntityTransaction>? {
        
        let account = CurrentAccountManager.shared.getAccount()
        guard let account else { return nil }
        lhsAccount = account.uuid

        let s = trimOuterParens(expr)
        print("         [Binary] Expression: \(s)")

        // Trouver l'opérateur
        let ops = [">=", "<=", "==", "!=", ">", "<"]
        var lhs = ""
        var op = ""
        var rhs = ""

        for candidate in ops {
            if let range = s.range(of: " \(candidate) ") {
                lhs = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                op = candidate
                rhs = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard !lhs.isEmpty, !op.isEmpty, !rhs.isEmpty else {
            print("         [Binary] ❌ Impossible d'extraire lhs/op/rhs")
            return nil
        }

        print("         [Binary] lhs='\(lhs)', op='\(op)', rhs='\(rhs)'")

        // Nettoyer le RHS (enlever quotes, parenthèses)
        var cleanedRHS = rhs.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
        if (cleanedRHS.hasPrefix("'") && cleanedRHS.hasSuffix("'")) ||
           (cleanedRHS.hasPrefix("\"") && cleanedRHS.hasSuffix("\"")) {
            cleanedRHS = String(cleanedRHS.dropFirst().dropLast())
        }
        print("         [Binary] cleanedRHS='\(cleanedRHS)'")

        // Parser la valeur selon le type attendu
        guard let parsed = parseValue(for: lhs, from: cleanedRHS) else {
            print("         [Binary] ❌ Impossible de parser la valeur pour le champ '\(lhs)'")
            return nil
        }

        print("         [Binary] Type parsé: \(parsed)")

        // Construire le prédicat selon le type
        let result: Predicate<EntityTransaction>?
        switch parsed {
        case .string(let v):
            print("         [Binary] → Création prédicat String")
            result = predicateForString(key: lhs, op: op, value: v)
        case .double(let v):
            print("         [Binary] → Création prédicat Double")
            result = predicateForDouble(key: lhs, op: op, value: v)
        case .bool(let v):
            print("         [Binary] → Création prédicat Bool")
            result = predicateForBool(key: lhs, op: op, value: v)
        case .date(let v):
            print("         [Binary] → Création prédicat Date")
            result = predicateForDate(key: lhs, op: op, value: v)
        case .account(let v):
            print("         [Binary] → Création prédicat Account")
            result = predicateForAccount(key: lhs, op: op, value: v)
        }

        print("         [Binary] Résultat: \(result != nil ? "✅" : "❌")")
        return result
    }

    // MARK: - Value Parsing

    private enum ParsedValue {
        case string(String)
        case double(Double)
        case bool(Bool)
        case date(Date)
        case account(EntityAccount)
    }

    /// Parse une valeur selon la clé (détermine le type attendu)
    private static func parseValue(for key: String, from rhs: String) -> ParsedValue? {
        // Normaliser la clé pour gérer les cas où NSPredicateEditor génère des keyPaths complets
        let normalizedKey: String
        if key.hasPrefix("status.") {
            normalizedKey = "status"
        } else if key.hasPrefix("paymentMode.") || key.hasPrefix("mode.") {
            normalizedKey = "mode"
        } else {
            normalizedKey = key
        }

        print("         [ParseValue] key='\(key)', normalizedKey='\(normalizedKey)', rhs='\(rhs)'")

        switch normalizedKey {

        case "status", "mode", "checkNumber":
            return .string(rhs)

        case "amount", "bankStatement":
            if let v = Double(rhs) {
                return .double(v)
            }

        case "dateOperation", "datePointage":
            if let d = parseDate(rhs) {
                return .date(d)
            }

        default:
            break
        }

        return nil
    }

    /// Parse une date depuis différents formats
    private static func parseDate(_ rhs: String) -> Date? {
        let s = rhs.trimmingCharacters(in: .whitespacesAndNewlines)

        // CAS 1: CAST(Double, "NSDate")
        if s.uppercased().hasPrefix("CAST("),
           let comma = s.firstIndex(of: ",") {
            let inside = s.dropFirst(5) // après "CAST("
            let raw = inside[..<comma].trimmingCharacters(in: .whitespaces)

            if let ti = Double(raw) {
                return Date(timeIntervalSinceReferenceDate: ti)
            }
        }

        // CAS 2: CAST("string", "NSDate")
        if s.uppercased().hasPrefix("CAST("),
           let firstQuote = s.firstIndex(of: "\""),
           let secondQuote = s[s.index(after: firstQuote)...].firstIndex(of: "\"") {
            let literal = String(s[s.index(after: firstQuote)..<secondQuote])
            return parseDateLiteral(literal)
        }

        // CAS 3: string directe
        return parseDateLiteral(s)
    }

    /// Parse une date depuis un format string
    private static func parseDateLiteral(_ literal: String) -> Date? {
        // ISO 8601
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: literal) {
            return d
        }

        // Formats classiques
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy"
        ]

        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: literal) {
                return d
            }
        }

        return nil
    }

    /// Parse un booléen
    private static func parseBool(_ s: String) -> Bool? {
        let lower = s.lowercased()
        if ["true", "yes", "1"].contains(lower) { return true }
        if ["false", "no", "0"].contains(lower) { return false }
        return nil
    }

    // MARK: - Predicate Builders by Type

    /// Construit un prédicat pour les propriétés de type String
    private static func predicateForString(key: String, op: String, value: String) -> Predicate<EntityTransaction>? {
        // Normaliser la clé pour gérer les cas où NSPredicateEditor génère des keyPaths complets
        
        let normalizedKey: String
        if key.hasPrefix("status.") {
            normalizedKey = "status"
        } else if key.hasPrefix("paymentMode.") || key.hasPrefix("mode.") {
            normalizedKey = "mode"
        } else {
            normalizedKey = key
        }

        print("         [PredicateForString] key='\(key)', normalizedKey='\(normalizedKey)', op='\(op)', value='\(value)'")

        switch normalizedKey {
        case "status":
            // Filtrer sur status directement (relation avec EntityStatus)
            switch op {
                case "==": return #Predicate<EntityTransaction> { entity in entity.status?.name == value && entity.account.uuid == lhsAccount }
            case "!=": return #Predicate<EntityTransaction> { entity in entity.status?.name != value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        case "mode":
            // Filtrer sur paymentMode directement (relation avec EntityPaymentMode)
            switch op {
            case "==": return #Predicate<EntityTransaction> { entity in entity.paymentMode?.name == value && entity.account.uuid == lhsAccount }
            case "!=": return #Predicate<EntityTransaction> { entity in entity.paymentMode?.name != value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        case "checkNumber":
            switch op {
            case "==": return #Predicate<EntityTransaction> { entity in entity.checkNumber == value && entity.account.uuid == lhsAccount }
            case "!=": return #Predicate<EntityTransaction> { entity in entity.checkNumber != value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        default:
            return nil
        }
    }

    /// Construit un prédicat pour les propriétés de type Double
    private static func predicateForDouble(key: String, op: String, value: Double) -> Predicate<EntityTransaction>? {
        switch key {
        case "amount":
            switch op {
            case "==": return #Predicate<EntityTransaction> { entity in entity.amount == value && entity.account.uuid == lhsAccount }
                case "!=": return #Predicate<EntityTransaction> { entity in entity.amount != value && entity.account.uuid == lhsAccount }
            case ">":  return #Predicate<EntityTransaction> { entity in entity.amount > value && entity.account.uuid == lhsAccount }
            case ">=": return #Predicate<EntityTransaction> { entity in entity.amount >= value && entity.account.uuid == lhsAccount }
            case "<":  return #Predicate<EntityTransaction> { entity in entity.amount < value && entity.account.uuid == lhsAccount }
            case "<=": return #Predicate<EntityTransaction> { entity in entity.amount <= value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        case "bankStatement":
            switch op {
            case "==": return #Predicate<EntityTransaction> { entity in entity.bankStatement == value && entity.account.uuid == lhsAccount }
            case "!=": return #Predicate<EntityTransaction> { entity in entity.bankStatement != value && entity.account.uuid == lhsAccount }
            case ">":  return #Predicate<EntityTransaction> { entity in entity.bankStatement > value && entity.account.uuid == lhsAccount }
            case ">=": return #Predicate<EntityTransaction> { entity in entity.bankStatement >= value && entity.account.uuid == lhsAccount }
            case "<":  return #Predicate<EntityTransaction> { entity in entity.bankStatement < value && entity.account.uuid == lhsAccount }
            case "<=": return #Predicate<EntityTransaction> { entity in entity.bankStatement <= value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        default:
            return nil
        }
    }

    /// Construit un prédicat pour les propriétés de type Bool
    private static func predicateForBool(key: String, op: String, value: Bool) -> Predicate<EntityTransaction>? {
        // Pas de propriété bool pour EntityTransaction pour le moment
        return nil
    }

    /// Construit un prédicat pour les propriétés de type Date
    private static func predicateForDate(key: String, op: String, value: Date) -> Predicate<EntityTransaction>? {
        switch key {
        case "datePointage":
            switch op {
            case "==": return #Predicate<EntityTransaction> { entity in entity.datePointage == value && entity.account.uuid == lhsAccount }
            case "!=": return #Predicate<EntityTransaction> { entity in entity.datePointage != value && entity.account.uuid == lhsAccount }
            case ">":  return #Predicate<EntityTransaction> { entity in entity.datePointage > value && entity.account.uuid == lhsAccount }
            case ">=": return #Predicate<EntityTransaction> { entity in entity.datePointage >= value && entity.account.uuid == lhsAccount }
            case "<":  return #Predicate<EntityTransaction> { entity in entity.datePointage < value && entity.account.uuid == lhsAccount }
            case "<=": return #Predicate<EntityTransaction> { entity in entity.datePointage <= value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        case "dateOperation":
            switch op {
            case "==": return #Predicate<EntityTransaction> { entity in entity.dateOperation == value && entity.account.uuid == lhsAccount }
            case "!=": return #Predicate<EntityTransaction> { entity in entity.dateOperation != value && entity.account.uuid == lhsAccount }
            case ">":  return #Predicate<EntityTransaction> { entity in entity.dateOperation > value && entity.account.uuid == lhsAccount }
            case ">=": return #Predicate<EntityTransaction> { entity in entity.dateOperation >= value && entity.account.uuid == lhsAccount }
            case "<":  return #Predicate<EntityTransaction> { entity in entity.dateOperation < value && entity.account.uuid == lhsAccount }
            case "<=": return #Predicate<EntityTransaction> { entity in entity.dateOperation <= value && entity.account.uuid == lhsAccount }
            default: return nil
            }

        default:
            return nil
        }
    }

    /// Construit un prédicat pour la propriété account (EntityAccount)
    private static func predicateForAccount(key: String, op: String, value: EntityAccount) -> Predicate<EntityTransaction>? {
        guard key == "account" else { return nil }

        // Utiliser l'UUID pour la comparaison
        let accountUUID = value.uuid

        switch op {
        case "==": return #Predicate<EntityTransaction> { entity in entity.account.uuid == accountUUID }
        case "!=": return #Predicate<EntityTransaction> { entity in entity.account.uuid != accountUUID }
        default: return nil
        }
    }

    /// Extrait l'EntityAccount depuis un NSPredicate
//    private static func extractAccountFromPredicate(_ predicate: NSPredicate) {
//        // Réinitialiser le cache
//        cachedAccount = nil
//
//        // Si c'est un NSCompoundPredicate, explorer les sous-prédicats
//        if let compound = predicate as? NSCompoundPredicate {
//            for subPredicate in compound.subpredicates as? [NSPredicate] ?? [] {
//                extractAccountFromPredicate(subPredicate)
//                if cachedAccount != nil { return }
//            }
//        }
//
//        // Si c'est un NSComparisonPredicate
//        if let comparison = predicate as? NSComparisonPredicate {
//            // Vérifier si le left expression est "account"
//            if let keyPath = comparison.leftExpression.keyPathString,
//               keyPath == "account" {
//                // Extraire l'objet depuis le right expression
//                if comparison.rightExpression.expressionType == .constantValue,
//                   let account = comparison.rightExpression.constantValue as? EntityAccount {
//                    print("      [Parser] EntityAccount trouvé: \(account.name) (\(account.uuid))")
//                    cachedAccount = account
//                }
//            }
//        }
//    }
}

// MARK: - Helper Extensions

extension NSExpression {
    var keyPathString: String? {
        if expressionType == .keyPath {
            return self.keyPath
        }
        return nil
    }
}

extension TransactionPredicateParser {

    /// Crée un FetchDescriptor à partir d'un NSPredicate
    static func createFetchDescriptor(
        from nsPredicate: NSPredicate?,
        sortBy: [SortDescriptor<EntityTransaction>] = [SortDescriptor(\.dateOperation, order: .forward)]
    ) -> FetchDescriptor<EntityTransaction> {
        let predicate = swiftDataPredicate(from: nsPredicate)
        return FetchDescriptor<EntityTransaction>(
            predicate: predicate,
            sortBy: sortBy
        )
    }

    /// Teste si un NSPredicate est valide et peut être converti
    static func canConvert(_ nsPredicate: NSPredicate?) -> Bool {
        guard let nsPredicate else { return false }

        do {
            try PredicateEditorValidator.validate(nsPredicate)
            return swiftDataPredicate(from: nsPredicate) != nil
        } catch {
            return false
        }
    }
}
