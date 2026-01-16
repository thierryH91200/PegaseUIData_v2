//
//  TransactionPredicateEditorView.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 16/01/2026.
//

import SwiftUI
import SwiftData
import AppKit

/// Vue principale qui intègre le NSPredicateEditor pour les EntityTransaction
struct TransactionPredicateEditorView: View {
    @Binding var predicate: NSPredicate?
    var onPredicateChange: (NSPredicate?) -> Void

    @State private var validationError: String?
    @State private var parsedPredicateDescription: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // NSPredicateEditor wrapper
            TransactionNSPredicateEditorWrapper(
                predicate: $predicate,
                onPredicateChange: handlePredicateChange
            )
            .frame(minHeight: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.primary.opacity(0.25), lineWidth: 1)
            )

            // Validation error display
            if let error = validationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }

            // Parsed predicate display (for debugging)
            if !parsedPredicateDescription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SwiftData Predicate:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(parsedPredicateDescription)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)
                }
            }
        }
    }

    private func handlePredicateChange(_ newPredicate: NSPredicate?) {
        // Validate the predicate
        do {
            try PredicateEditorValidator.validate(newPredicate)
            validationError = nil

            // Parse to SwiftData predicate description
            if let pred = newPredicate {
                parsedPredicateDescription = formatPredicateForDisplay(pred)
            } else {
                parsedPredicateDescription = ""
            }

            // Notify parent
            onPredicateChange(newPredicate)

        } catch {
            validationError = error.localizedDescription
            parsedPredicateDescription = ""
            onPredicateChange(nil)
        }
    }

    private func formatPredicateForDisplay(_ predicate: NSPredicate) -> String {
        return predicate.predicateFormat
    }
}

/// Wrapper NSViewRepresentable pour NSPredicateEditor configuré pour EntityTransaction
struct TransactionNSPredicateEditorWrapper: NSViewRepresentable {
    @Binding var predicate: NSPredicate?
    var onPredicateChange: (NSPredicate?) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let predicateEditor = NSPredicateEditor()
        predicateEditor.translatesAutoresizingMaskIntoConstraints = true
        predicateEditor.autoresizingMask = [.width]

        // Configuration des templates de prédicat pour EntityTransaction
        let templates = createTransactionPredicateTemplates()
        predicateEditor.rowTemplates = templates

        // Ajouter une ligne par défaut
        predicateEditor.addRow(nil)

        predicateEditor.target = context.coordinator
        predicateEditor.action = #selector(Coordinator.predicateChanged(_:))

        context.coordinator.predicateEditor = predicateEditor

        scrollView.documentView = predicateEditor

        // Forcer la mise à jour de la taille
        DispatchQueue.main.async {
            predicateEditor.needsLayout = true
            predicateEditor.layoutSubtreeIfNeeded()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let predicateEditor = scrollView.documentView as? NSPredicateEditor else { return }

        if let predicate = predicate, predicateEditor.objectValue as? NSPredicate != predicate {
            predicateEditor.objectValue = predicate
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: TransactionNSPredicateEditorWrapper
        var predicateEditor: NSPredicateEditor?

        init(_ parent: TransactionNSPredicateEditorWrapper) {
            self.parent = parent
        }

        @objc func predicateChanged(_ sender: NSPredicateEditor) {
            print("=== TRANSACTION PREDICATE CHANGED ===")
            print("Number of rows: \(sender.numberOfRows)")

            // Vérifier si le prédicat est valide avant de l'utiliser
            guard let predicate = sender.objectValue as? NSPredicate else {
                print("No valid predicate (still editing)")
                parent.predicate = nil
                parent.onPredicateChange(nil)
                return
            }

            // Vérifier que le prédicat n'est pas vide ou incomplet
            let predicateString = predicate.predicateFormat
            if predicateString.isEmpty || predicateString.contains("nil") {
                print("Predicate incomplete: \(predicateString)")
                parent.predicate = nil
                parent.onPredicateChange(nil)
                return
            }

            print("Valid predicate: \(predicate.predicateFormat)")
            parent.predicate = predicate
            parent.onPredicateChange(predicate)
        }
    }

    // MARK: - Predicate Templates for EntityTransaction

    /// Crée les templates de prédicat pour les propriétés d'EntityTransaction
    private func createTransactionPredicateTemplates() -> [NSPredicateEditorRowTemplate] {
        var templates: [NSPredicateEditorRowTemplate] = []

        // amount (Double)
        let amountExp = [NSExpression(forKeyPath: "amount")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: amountExp,
            rightExpressionAttributeType: .doubleAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThanOrEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThanOrEqualTo.rawValue)
            ],
            options: 0
        ))

        // dateOperation (Date)
        let dateOpExp = [NSExpression(forKeyPath: "dateOperation")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: dateOpExp,
            rightExpressionAttributeType: .dateAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThanOrEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThanOrEqualTo.rawValue)
            ],
            options: 0
        ))

        // datePointage (Date)
        let datePointExp = [NSExpression(forKeyPath: "datePointage")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: datePointExp,
            rightExpressionAttributeType: .dateAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThanOrEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThanOrEqualTo.rawValue)
            ],
            options: 0
        ))

        // bankStatement (Double)
        let bankExp = [NSExpression(forKeyPath: "bankStatement")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: bankExp,
            rightExpressionAttributeType: .doubleAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThanOrEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThanOrEqualTo.rawValue)
            ],
            options: 0
        ))

        // checkNumber (String)
        let checkExp = [NSExpression(forKeyPath: "checkNumber")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: checkExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue)
            ],
            options: 0
        ))

        // status (String)
        let statusExp = [NSExpression(forKeyPath: "status")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: statusExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue)
            ],
            options: 0
        ))

        // mode (String)
        let modeExp = [NSExpression(forKeyPath: "mode")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: modeExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue)
            ],
            options: 0
        ))

        // Compound templates (AND/OR/NOT)
        let compoundTypes: [NSNumber] = [
            NSNumber(value: NSCompoundPredicate.LogicalType.and.rawValue),
            NSNumber(value: NSCompoundPredicate.LogicalType.or.rawValue),
            NSNumber(value: NSCompoundPredicate.LogicalType.not.rawValue)
        ]
        templates.append(NSPredicateEditorRowTemplate(compoundTypes: compoundTypes))

        return templates
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var predicate: NSPredicate?

        var body: some View {
            VStack {
                TransactionPredicateEditorView(
                    predicate: $predicate,
                    onPredicateChange: { newPredicate in
                        print("Predicate changed: \(newPredicate?.predicateFormat ?? "nil")")
                    }
                )
                .padding()

                Spacer()

                if let pred = predicate {
                    Text("Current predicate:")
                        .font(.headline)
                    Text(pred.predicateFormat)
                        .font(.caption)
                        .padding()
                }
            }
            .frame(width: 600, height: 400)
        }
    }

    return PreviewWrapper()
}
