import SwiftUI
import AppKit

struct PredicateEditorView: NSViewRepresentable {
    @Binding var predicate: NSPredicate?
    var rowTemplates: [NSPredicateEditorRowTemplate]

    func makeNSView(context: Context) -> NSPredicateEditor {
        let editor = NSPredicateEditor()

//        if let path = Bundle.main.path(forResource: "Predicate", ofType: "strings"),
//           let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
//            editor.formattingDictionary = dict
//        }

        editor.rowTemplates = rowTemplates
        editor.objectValue = predicate

        editor.target = context.coordinator
        editor.action = #selector(Coordinator.changed(_:))
        adjustFieldPresentation(in: editor)
        return editor
    }

    func updateNSView(_ nsView: NSPredicateEditor, context: Context) {
        nsView.objectValue = predicate
        adjustFieldPresentation(in: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(predicate: $predicate)
    }

    final class Coordinator: NSObject {
        var predicate: Binding<NSPredicate?>
        init(predicate: Binding<NSPredicate?>) { self.predicate = predicate }
        
        @objc func changed(_ sender: NSPredicateEditor) {
            predicate.wrappedValue = sender.predicate
        }
    }
}

extension PredicateEditorView {
    /// Ajuste la présentation des champs (largeur des NSTextField) dans l'éditeur de prédicats.
    /// Cette approche parcourt les sous-vues pour appliquer des contraintes de largeur raisonnables.
    fileprivate func adjustFieldPresentation(in editor: NSPredicateEditor) {
        // Utiliser Auto Layout pour éviter les frames fixes
        func widenTextFields(in view: NSView) {
            for sub in view.subviews {
                if let textField = sub as? NSTextField {
                    // Désactiver la traduction des masques en contraintes pour ajouter nos contraintes
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    // Supprimer les contraintes de largeur existantes liées à ce textField si nécessaire
                    let existingWidthConstraints = textField.constraints.filter { constraint in
                        return (constraint.firstAttribute == .width)
                    }
                    NSLayoutConstraint.deactivate(existingWidthConstraints)
                    // Appliquer une largeur minimale confortable
                    let minWidth: CGFloat = 160
                    let widthConstraint = textField.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth)
                    widthConstraint.priority = .defaultHigh
                    widthConstraint.isActive = true
                }
                // Descendre récursivement dans la hiérarchie
                widenTextFields(in: sub)
            }
        }
        widenTextFields(in: editor)
        // Forcer un relayout
        editor.needsLayout = true
        editor.layoutSubtreeIfNeeded()
    }
}

// MARK: - Helper to build default row templates similar to MainWindowController
extension PredicateEditorView {
    static func defaultRowTemplates() -> [NSPredicateEditorRowTemplate] {
        var templates: [NSPredicateEditorRowTemplate] = []

        // Compound
        let compound = NSPredicateEditorRowTemplate(compoundTypes: [.and, .or, .not])
        templates.append(compound)
        
        // Date comparaisons for dateOperation
       let dateOps: [NSComparisonPredicate.Operator] = [.equalTo, .greaterThanOrEqualTo, .lessThanOrEqualTo, .greaterThan, .lessThan]
        templates.append(NSPredicateEditorRowTemplate(DateCompareForKeyPaths: ["date Operation"], operators: dateOps))
        
        // Date comparaisons for datePointage
        templates.append(NSPredicateEditorRowTemplate(DateCompareForKeyPaths: ["date Pointage"], operators: dateOps))

        // Double comparaisons for amount
        let doubleOps: [NSComparisonPredicate.Operator] = [.equalTo, .notEqualTo, .greaterThan, .greaterThanOrEqualTo, .lessThan, .lessThanOrEqualTo]
        templates.append(NSPredicateEditorRowTemplate(DoubleCompareForKeyPaths: ["amount"], operators: doubleOps))

        // Constant values for Status
        let statusOps: [NSComparisonPredicate.Operator] = [.equalTo, .notEqualTo]
        let namesStatus = StatusManager.shared.getAllNames()
        templates.append(NSPredicateEditorRowTemplate(forKeyPath: "Status", withValues: namesStatus, operators: statusOps))
        
        // Constant values for Mode
        let modeOps: [NSComparisonPredicate.Operator] = [.equalTo, .notEqualTo]
        let namesMode = PaymentModeManager.shared.getAllNames()
        templates.append(NSPredicateEditorRowTemplate(forKeyPath: "Mode", withValues: namesMode, operators: modeOps))
        
        //        // String comparisons for status, mode
        //        let stringOps: [NSComparisonPredicate.Operator] = [.equalTo, .notEqualTo]
        //        templates.append(NSPredicateEditorRowTemplate(stringCompareForKeyPaths: ["Status"], operators: stringOps))
        //        templates.append(NSPredicateEditorRowTemplate(stringCompareForKeyPaths: ["Mode"], operators: stringOps))

        return templates
    }
}
