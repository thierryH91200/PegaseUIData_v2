//
//  NSPredicateEditorView.swift
//  test44
//
//  Created by thierryH24 on 10/01/2026.
//


import SwiftUI
import SwiftData
import AppKit


// MARK: - NSPredicateEditor SwiftUI Wrapper
struct NSPredicateEditorView: NSViewRepresentable {
    @Binding var predicate: NSPredicate?
    var onPredicateChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        
        let predicateEditor = NSPredicateEditor()
        predicateEditor.translatesAutoresizingMaskIntoConstraints = true
        predicateEditor.autoresizingMask = [.width]
        
        // Configuration des templates de prédicat
        let templates = createPredicateTemplates()
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
        var parent: NSPredicateEditorView
        var predicateEditor: NSPredicateEditor?
        
        init(_ parent: NSPredicateEditorView) {
            self.parent = parent
        }
        
        @objc func predicateChanged(_ sender: NSPredicateEditor) {
            print("=== PREDICATE CHANGED ===")
            print("Number of rows: \(sender.numberOfRows)")
            
            // Vérifier si le prédicat est valide avant de l'utiliser
            guard let predicate = sender.objectValue as? NSPredicate else {
                print("No valid predicate (still editing)")
                parent.predicate = nil
                return
            }
            
            // Vérifier que le prédicat n'est pas vide ou incomplet
            let predicateString = predicate.predicateFormat
            if predicateString.isEmpty || predicateString.contains("nil") {
                print("Predicate incomplete: \(predicateString)")
                parent.predicate = nil
                return
            }
            
            print("Valid predicate: \(predicate)")
            parent.predicate = predicate
            parent.onPredicateChange()
        }
    }
    
    // MARK: - Predicate Templates
    private func createPredicateTemplates() -> [NSPredicateEditorRowTemplate] {
        var templates: [NSPredicateEditorRowTemplate] = []
        
        // String properties - firstName
        let firstNameExp = [NSExpression(forKeyPath: "firstName")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: firstNameExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.contains.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.beginsWith.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.endsWith.rawValue)
            ],
            options: (Int(NSComparisonPredicate.Options.caseInsensitive.rawValue | NSComparisonPredicate.Options.diacriticInsensitive.rawValue))
        ))

//            options: 0
//        ))
        
        // String properties - lastName
        let lastNameExp = [NSExpression(forKeyPath: "lastName")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: lastNameExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.contains.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.beginsWith.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.endsWith.rawValue)
            ],
            options: 0
        ))
        
        // String properties - department
        let departmentExp = [NSExpression(forKeyPath: "department")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: departmentExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.contains.rawValue)
            ],
            options: 0
        ))
        
        // String properties - country
        let countryExp = [NSExpression(forKeyPath: "country")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: countryExp,
            rightExpressionAttributeType: .stringAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.contains.rawValue)
            ],
            options: 0
        ))
        
        // Integer property - age
        let ageExp = [NSExpression(forKeyPath: "age")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: ageExp,
            rightExpressionAttributeType: .integer64AttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThanOrEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThanOrEqualTo.rawValue)
            ],
            options: 0
        ))
        
        // Boolean property - isBool
        let boolExp = [NSExpression(forKeyPath: "isBool")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: boolExp,
            rightExpressionAttributeType: .booleanAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue)
            ],
            options: 0
        ))
        
        // Date property - dateOfBirth
        let dateExp = [NSExpression(forKeyPath: "dateOfBirth")]
        templates.append(NSPredicateEditorRowTemplate(
            leftExpressions: dateExp,
            rightExpressionAttributeType: .dateAttributeType,
            modifier: .direct,
            operators: [
                NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.notEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.lessThanOrEqualTo.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThan.rawValue),
                NSNumber(value: NSComparisonPredicate.Operator.greaterThanOrEqualTo.rawValue)
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

