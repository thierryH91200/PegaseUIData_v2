////
////  Parser.swift
////  THPredicateEditorSwiftUI
////
////  Created by thierryH24 on 01/01/2026.
////
//
import SwiftUI
import Combine
import AppKit
import SwiftData
import SwiftDate

@MainActor
final class HybridViewModel: ObservableObject {
    @Published var person: [EntityTransaction] = []
    @Published var predicate: NSPredicate? = nil
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    init() {
        person = ListTransactionsManager.shared.getAllData()
//        if person.isEmpty {
//            seedData()
//        }
        // Optionally apply a default predicate similar to MainWindowController
//        let defaultFormat = "firstName ==[cd] 'John' OR lastName ==[cd] 'doe' OR (dateOfBirth <= CAST('11/18/2018 00:00', 'NSDate') AND dateOfBirth >= CAST('01/01/2018', 'NSDate')) OR country ==[cd] 'United States' OR age = 25"
//        let defaultFormat = "amount >= 100" // OR lastName ==[cd] 'doe'"
        let defaultFormat = "(dateOperation <= CAST('11/18/2018 00:00', 'NSDate') AND dateOperation >= CAST('01/01/2018', 'NSDate')) OR amount > 100"

        self.predicate = NSPredicate(format: defaultFormat)
    }

    
    // MARK: - Predicate parsing helpers
    private func trimOuterParens(_ s: String) -> String {
        var s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("(") && s.hasSuffix(")") {
            var level = 0
            var isBalanced = true
            for (i, ch) in s.enumerated() {
                if ch == "(" { level += 1 }
                else if ch == ")" { level -= 1; if level < 0 { isBalanced = false; break } }
                if i < s.count - 1 && level == 0 && i != s.count - 1 { isBalanced = false; break }
            }
            if isBalanced {
                s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return s
    }

    private enum Token { case expr(String); case and; case or }

    private func tokenizeTopLevel(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var level = 0
        var i = s.startIndex
        func flush() {
            let part = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { tokens.append(.expr(part)) }
            current = ""
        }
        while i < s.endIndex {
            let ch = s[i]
            if ch == "(" { level += 1; current.append(ch); i = s.index(after: i); continue }
            if ch == ")" { level -= 1; current.append(ch); i = s.index(after: i); continue }
            if level == 0 {
                if s[i...].hasPrefix(" AND ") {
                    flush(); tokens.append(.and); i = s.index(i, offsetBy: 5); continue
                }
                if s[i...].hasPrefix(" OR ") {
                    flush(); tokens.append(.or); i = s.index(i, offsetBy: 4); continue
                }
            }
            current.append(ch)
            i = s.index(after: i)
        }
        flush()
        return tokens
    }

    // Value parsing helpers
    private func parseBool(_ s: String) -> Bool? {
        let lower = s.lowercased()
        if ["true", "yes", "1"].contains(lower) { return true }
        if ["false", "no", "0"].contains(lower) { return false }
        return nil
    }

    private enum ParsedValue { case string(String), double(Double), bool(Bool), date(Date) }
    
    // Parse date from common literal formats: 'yyyy-MM-dd' or CAST('MM/dd/yyyy HH:mm', 'NSDate') / CAST('MM/dd/yyyy', 'NSDate')
    private func parseDate(_ rhs: String) -> Date? {
        let s = rhs.trimmingCharacters(in: .whitespacesAndNewlines)

        // --- CAS 1 : CAST(Double, "NSDate")
        if s.uppercased().hasPrefix("CAST("),
           let comma = s.firstIndex(of: ",") {

            let inside = s.dropFirst(5) // après "CAST("
            let raw = inside[..<comma].trimmingCharacters(in: .whitespaces)

            if let ti = Double(raw) {
                // TimeInterval depuis 2001-01-01
                return Date(timeIntervalSinceReferenceDate: ti)
            }
        }

        // --- CAS 2 : CAST("string", "NSDate")
        if s.uppercased().hasPrefix("CAST("),
           let firstQuote = s.firstIndex(of: "\""),
           let secondQuote = s[s.index(after: firstQuote)...].firstIndex(of: "\"") {

            let literal = String(s[s.index(after: firstQuote)..<secondQuote])
            return parseDateLiteral(literal)
        }

        // --- CAS 3 : string directe (fallback)
        return parseDateLiteral(s)
    }
    
    private func parseDateLiteral(_ literal: String) -> Date? {

        // 1️⃣ ISO 8601 (très fréquent)
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: literal) {
            return d
        }

        // 2️⃣ NSPredicate classique
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]

        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: literal) {
                return d
            }
        }

        return nil
    }
    private func parseValue(for key: String, from rhs: String) -> ParsedValue? {
        switch key {
        case "mode", "status":
            return .string(rhs)
        case "amount":
            if let v = Double(rhs) { return .double(v) }
        case "isBool":
            if let v = parseBool(rhs) { return .bool(v) }
        case "dateOperation", "datePointage":
            if let d = parseDate(rhs) { return .date(d) }
        default:
            break
        }
        return nil
    }

    // Builders per type
    private func predicateForString(key: String, op: String, value: String) -> Predicate<EntityTransaction>? {
        switch key {
        case "status":
            switch op {
                case "==":
                    return #Predicate { $0.statusString == value };
                case "!=":
                    return #Predicate { $0.statusString != value };
                default:
                    return nil }
        case "mode":
            switch op {
            case "==":
                return #Predicate { $0.paymentModeString == value };
            case "!=":
                return #Predicate { $0.paymentModeString != value };
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private func predicateForDouble(key: String, op: String, value: Double) -> Predicate<EntityTransaction>? {
        switch key {
        case "amount":
            switch op {
            case "==": return #Predicate { $0.amount == value }
            case "!=": return #Predicate { $0.amount != value }
            case ">":  return #Predicate { $0.amount > value }
            case ">=": return #Predicate { $0.amount >= value }
            case "<":  return #Predicate { $0.amount < value }
            case "<=": return #Predicate { $0.amount <= value }
            default: return nil
            }
        default:
            return nil
        }
    }

    private func predicateForBool(key: String, op: String, value: Bool) -> Predicate<EntityTransaction>? {
//        switch key {
//        case "isBool":
//            switch op { case "==": return #Predicate { $0.isBool == value }; case "!=": return #Predicate { $0.isBool != value }; default: return nil }
//        default:
            return nil
//        }
    }
    
    private func predicateForDate(key: String, op: String, value: Date) -> Predicate<EntityTransaction>? {
        switch key {
        case "datePointage":
            switch op {
            case "==": return #Predicate { $0.datePointage == value }
            case "!=": return #Predicate { $0.datePointage != value }
            case ">":  return #Predicate { $0.datePointage > value }
            case ">=": return #Predicate { $0.datePointage >= value }
            case "<":  return #Predicate { $0.datePointage < value }
            case "<=": return #Predicate { $0.datePointage <= value }
            default: return nil
            }
        case "dateOperation":
            switch op {
            case "==": return #Predicate { $0.dateOperation == value }
            case "!=": return #Predicate { $0.dateOperation != value }
            case ">":  return #Predicate { $0.dateOperation > value }
            case ">=": return #Predicate { $0.dateOperation >= value }
            case "<":  return #Predicate { $0.dateOperation < value }
            case "<=": return #Predicate { $0.dateOperation <= value }
            default: return nil
            }

        default:
            return nil
        }
    }

    private func predicateForBinary(_ expr: String) -> Predicate<EntityTransaction>? {
        let s = trimOuterParens(expr)
        let ops = [">=", "<=", "==", "!=", ">", "<"]
        var lhs = ""
        var op = ""
        var rhs = ""
        for candidate in ops {
            if let range = s.range(of: " " + candidate + " ") {
                lhs = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                op = candidate
                rhs = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        guard !lhs.isEmpty, !op.isEmpty, !rhs.isEmpty else { return nil }
        var cleanedRHS = rhs.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
        if (cleanedRHS.hasPrefix("'") && cleanedRHS.hasSuffix("'")) || (cleanedRHS.hasPrefix("\"") && cleanedRHS.hasSuffix("\"")) {
            cleanedRHS = String(cleanedRHS.dropFirst().dropLast())
        }
        guard let parsed = parseValue(for: lhs, from: cleanedRHS) else { return nil }
        switch parsed {
        case .string(let v): return predicateForString(key: lhs, op: op, value: v)
        case .double(let v): return predicateForDouble(key: lhs, op: op, value: v)
        case .bool(let v):   return predicateForBool(key: lhs, op: op, value: v)
        case .date(let v):   return predicateForDate(key: lhs, op: op, value: v)
        }
    }
    
    func swiftDataPredicate(from ns: NSPredicate?) -> Predicate<EntityTransaction>? {
        guard let ns else { return nil }

        // Normalize and parse the predicateFormat, supporting simple AND/OR combinations
        let raw = ns.predicateFormat
        // 1) Normalize operators with [cd] and trim
        var format = raw
            .replacingOccurrences(of: "==[cd]", with: "==")
            .replacingOccurrences(of: "==[c]", with: "==")
            .replacingOccurrences(of: "==[d]", with: "==")
            .replacingOccurrences(of: "!=[cd]", with: "!=")
            .replacingOccurrences(of: "!=[c]", with: "!=")
            .replacingOccurrences(of: "!=[d]", with: "!=")
            .replacingOccurrences(of: ">=[cd]", with: ">=")
            .replacingOccurrences(of: ">=[c]", with: ">=")
            .replacingOccurrences(of: ">=[d]", with: ">=")
            .replacingOccurrences(of: "<=[cd]", with: "<=")
            .replacingOccurrences(of: "<=[c]", with: "<=")
            .replacingOccurrences(of: "<=[d]", with: "<=")
            .replacingOccurrences(of: ">[cd]", with: ">")
            .replacingOccurrences(of: ">[c]", with: ">")
            .replacingOccurrences(of: ">[d]", with: ">")
            .replacingOccurrences(of: "<[cd]", with: "<")
            .replacingOccurrences(of: "<[c]", with: "<")
            .replacingOccurrences(of: "<[d]", with: "<")
            .trimmingCharacters(in: .whitespacesAndNewlines)            .trimmingCharacters(in: .whitespacesAndNewlines)

        format = trimOuterParens(format)

        // Tokenize top-level AND/OR
        let tokens = tokenizeTopLevel(format)
        // If only one expression, return directly
        if tokens.count == 1, case let .expr(expr) = tokens[0] {
            return predicateForBinary(expr)
        }

        // Fold tokens left-to-right with AND/OR
        var currentPredicate: Predicate<EntityTransaction>? = nil
        var pendingOp: Token? = nil
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
    
    func fetchFilteredData() -> [EntityTransaction] {
        guard let modelContext else { return [] }

        let descriptor = FetchDescriptor<EntityTransaction>(
            predicate: swiftDataPredicate(from: predicate),
            sortBy: [SortDescriptor(\.dateOperation, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Erreur fetch :", error)
            return []
        }
    }
    
    var filteredData: [EntityTransaction] {
        fetchFilteredData()
    }
}

