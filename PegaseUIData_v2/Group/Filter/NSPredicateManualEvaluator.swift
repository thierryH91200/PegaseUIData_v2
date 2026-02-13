//
//  NSPredicateManualEvaluator.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 19/01/2026.
//

import Foundation

/// Manual evaluator for NSPredicate on SwiftData entities
/// This is needed because SwiftData entities don't support KVC (Key-Value Coding)
struct NSPredicateManualEvaluator {

    /// Manually evaluates an NSPredicate on an EntityTransaction
    static func evaluate(predicate: NSPredicate, transaction: EntityTransaction) -> Bool {
        let format = predicate.predicateFormat

        print("   [Evaluator] Format: \(format)")

        // Handle SUBQUERY patterns
        if format.contains("SUBQUERY(sousOperations") {
            return evaluateSubquery(format: format, transaction: transaction)
        }

        // Handle other simple predicates if needed
        print("   [Evaluator] ⚠️ Type de prédicat non supporté")
        return false
    }

    /// Evaluates SUBQUERY predicates manually
    private static func evaluateSubquery(format: String, transaction: EntityTransaction) -> Bool {
        // Parse: SUBQUERY(sousOperations, $var, condition).@count > 0

        // Extract the condition part
        guard let conditionStart = format.range(of: ", $")?.upperBound,
              let conditionEnd = format.range(of: ").@count")?.lowerBound else {
            print("   [Evaluator] ❌ Cannot parse SUBQUERY format")
            return false
        }

        // Skip variable name (e.g., "$sousOperation, ")
        guard let commaAfterVar = format[conditionStart...].range(of: ", ")?.upperBound else {
            print("   [Evaluator] ❌ Cannot find condition start")
            return false
        }

        let condition = String(format[commaAfterVar..<conditionEnd])
        print("   [Evaluator] Condition: \(condition)")

        // Extract comparator (.@count > 0 or .@count == 0)
        let comparator: String
        if format.contains(".@count > 0") || format.contains(".@count != 0") {
            comparator = "any"
        } else if format.contains(".@count == 0") {
            comparator = "none"
        } else {
            print("   [Evaluator] ⚠️ Comparateur non supporté")
            return false
        }

        print("   [Evaluator] Comparator: \(comparator)")

        // Detect condition type and extract value
        if condition.contains("category.rubric.name") {
            return evaluateRubricCondition(condition: condition, comparator: comparator, transaction: transaction)
        } else if condition.contains("category.name") {
            return evaluateCategoryCondition(condition: condition, comparator: comparator, transaction: transaction)
        } else if condition.contains("libelle") {
            return evaluateLibelleCondition(condition: condition, comparator: comparator, transaction: transaction)
        } else if condition.contains("amount") {
            return evaluateAmountCondition(condition: condition, comparator: comparator, transaction: transaction)
        }

        print("   [Evaluator] ⚠️ Type de condition non supporté: \(condition)")
        return false
    }

    // MARK: - Condition Evaluators

    private static func evaluateRubricCondition(condition: String, comparator: String, transaction: EntityTransaction) -> Bool {
        // Extract value from condition like: $sousOperation.category.rubric.name == "Alimentation"
        guard let value = extractStringValue(from: condition) else {
            print("   [Evaluator] ❌ Cannot extract rubric value")
            return false
        }

        print("   [Evaluator] Rubric value: '\(value)'")

        let matches = transaction.sousOperations.contains { sousOperation in
            sousOperation.category?.rubric?.name == value
        }

        let result = comparator == "any" ? matches : !matches
        print("   [Evaluator] Result: \(result) (matches: \(matches), comparator: \(comparator))")
        return result
    }

    private static func evaluateCategoryCondition(condition: String, comparator: String, transaction: EntityTransaction) -> Bool {
        guard let value = extractStringValue(from: condition) else {
            print("   [Evaluator] ❌ Cannot extract category value")
            return false
        }

        print("   [Evaluator] Category value: '\(value)'")

        let matches = transaction.sousOperations.contains { sousOperation in
            sousOperation.category?.name == value
        }

        let result = comparator == "any" ? matches : !matches
        print("   [Evaluator] Result: \(result)")
        return result
    }

    private static func evaluateLibelleCondition(condition: String, comparator: String, transaction: EntityTransaction) -> Bool {
        // Handle CONTAINS, ==, IS, !=, IS NOT, BEGINSWITH, ENDSWITH
        let conditionUpper = condition.uppercased()

        if conditionUpper.contains("BEGINSWITH") {
            guard let value = extractStringValue(from: condition) else {
                print("   [Evaluator] ❌ Cannot extract libelle value")
                return false
            }

            print("   [Evaluator] Libelle BEGINSWITH value: '\(value)'")

            let matches = transaction.sousOperations.contains { sousOperation in
                sousOperation.libelle?.hasPrefix(value) ?? false
            }

            let result = comparator == "any" ? matches : !matches
            print("   [Evaluator] Result: \(result)")
            return result

        } else if conditionUpper.contains("ENDSWITH") {
            guard let value = extractStringValue(from: condition) else {
                print("   [Evaluator] ❌ Cannot extract libelle value")
                return false
            }

            print("   [Evaluator] Libelle ENDSWITH value: '\(value)'")

            let matches = transaction.sousOperations.contains { sousOperation in
                sousOperation.libelle?.hasSuffix(value) ?? false
            }

            let result = comparator == "any" ? matches : !matches
            print("   [Evaluator] Result: \(result)")
            return result

        } else if conditionUpper.contains("CONTAINS") {
            guard let value = extractStringValue(from: condition) else {
                print("   [Evaluator] ❌ Cannot extract libelle value")
                return false
            }

            print("   [Evaluator] Libelle CONTAINS value: '\(value)'")

            let matches = transaction.sousOperations.contains { sousOperation in
                sousOperation.libelle?.contains(value) ?? false
            }

            let result = comparator == "any" ? matches : !matches
            print("   [Evaluator] Result: \(result)")
            return result

        } else if conditionUpper.contains(" IS NOT ") || condition.contains("!=") {
            guard let value = extractStringValue(from: condition) else {
                print("   [Evaluator] ❌ Cannot extract libelle value")
                return false
            }

            print("   [Evaluator] Libelle IS NOT/!= value: '\(value)'")

            let matches = transaction.sousOperations.contains { sousOperation in
                sousOperation.libelle != value
            }

            let result = comparator == "any" ? matches : !matches
            print("   [Evaluator] Result: \(result)")
            return result

        } else if conditionUpper.contains(" IS ") || condition.contains("==") {
            guard let value = extractStringValue(from: condition) else {
                print("   [Evaluator] ❌ Cannot extract libelle value")
                return false
            }

            print("   [Evaluator] Libelle IS/== value: '\(value)'")

            let matches = transaction.sousOperations.contains { sousOperation in
                sousOperation.libelle == value
            }

            let result = comparator == "any" ? matches : !matches
            print("   [Evaluator] Result: \(result)")
            return result
        }

        print("   [Evaluator] ⚠️ Opérateur libelle non supporté: \(condition)")
        return false
    }

    private static func evaluateAmountCondition(condition: String, comparator: String, transaction: EntityTransaction) -> Bool {
        // Parse operators: ==, !=, >, <, >=, <=
        let operators = ["==", "!=", ">=", "<=", ">", "<"]

        for op in operators {
            if condition.contains(op) {
                let parts = condition.components(separatedBy: op).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let value = Double(parts[1]) else {
                    continue
                }

                print("   [Evaluator] Amount \(op) \(value)")

                let matches = transaction.sousOperations.contains { sousOperation in
                    switch op {
                    case "==": return sousOperation.amount == value
                    case "!=": return sousOperation.amount != value
                    case ">": return sousOperation.amount > value
                    case "<": return sousOperation.amount < value
                    case ">=": return sousOperation.amount >= value
                    case "<=": return sousOperation.amount <= value
                    default: return false
                    }
                }

                let result = comparator == "any" ? matches : !matches
                print("   [Evaluator] Result: \(result)")
                return result
            }
        }

        print("   [Evaluator] ❌ Cannot parse amount condition")
        return false
    }

    // MARK: - Helper Functions

    /// Extracts a string value from a condition like: field == "value" or field BEGINSWITH "value"
    private static func extractStringValue(from condition: String) -> String? {
        // Find text between quotes
        let pattern = #""([^"]*)""#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: condition, range: NSRange(condition.startIndex..., in: condition)),
           let range = Range(match.range(at: 1), in: condition) {
            return String(condition[range])
        }

        // If no quotes found, try to extract value after operators
        let conditionUpper = condition.uppercased()
        let operators = [" BEGINSWITH ", " ENDSWITH ", " CONTAINS ", " IS NOT ", " IS ", " == ", " != "]

        for op in operators {
            if let range = conditionUpper.range(of: op) {
                let value = String(condition[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    return value
                }
            }
        }

        return nil
    }
}
