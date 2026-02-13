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
        
        // Charger les traductions depuis Predicate.strings
        loadPredicateLocalizations(for: predicateEditor)


        // Configuration des templates de prédicat pour EntityTransaction
        let templates =  defaultPredicateTemplates()
        predicateEditor.rowTemplates = templates

        // Ajouter une ligne par défaut
        predicateEditor.addRow(self)
        predicateEditor.canRemoveAllRows = false


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

    func defaultPredicateTemplates() -> [NSPredicateEditorRowTemplate] {

        let templateCompoundTypes = NSPredicateEditorRowTemplate( compoundTypes: [.and, .or, .not] )

        let template1 = RowTemplateRelationshipDate(leftExpressions: [NSExpression(forKeyPath: "Date Operation")], leftEntity: "dateOperation")
        let template2 = RowTemplateRelationshipDate(leftExpressions: [NSExpression(forKeyPath: "Date Pointage")], leftEntity: "datePointage")

        let template3 = RowTemplateRelationshipStatus(leftExpressions: [NSExpression(forKeyPath: "Status")], leftEntity: "statut")
        let template4 = RowTemplateRelationshipMode(leftExpressions: [NSExpression(forKeyPath: "Mode")], leftEntity: "paymentMode")

        let template5 = RowTemplateRelationshipLibelle(leftExpressions: [NSExpression(forKeyPath: "Libelle")])
        let template6 = RowTemplateRelationshipRubrique(leftExpressions: [NSExpression(forKeyPath: "Rubric")])
        let template7 = RowTemplateRelationshipCategory(leftExpressions: [NSExpression(forKeyPath: "Category")])
        let template8 = RowTemplateRelationshipMontant(leftExpressions: [NSExpression(forKeyPath: "Amount")])
        let template9 = RowTemplateRelationshipBankStatement(leftExpressions: [NSExpression(forKeyPath: "Bank Statement")])

//        predicateEditor.rowTemplates.removeAll()
        let rowTemplates = [ templateCompoundTypes, template1, template2, template3, template4, template5, template6, template7, template8, template9]

        return rowTemplates
    }
    
    // MARK: - Localization Support

    /// Charge les traductions depuis le fichier Predicate.strings
    private func loadPredicateLocalizations(for predicateEditor: NSPredicateEditor) {
        // Essayer de charger le fichier Predicate.strings depuis le bundle
        guard let stringsFile = Bundle.main.path(forResource: "Predicate", ofType: "strings") else {
            print("⚠️ Fichier Predicate.strings introuvable dans le bundle")
            return
        }

        do {
            // Lire le contenu du fichier avec l'encodage UTF-16
            let strings = try String(contentsOfFile: stringsFile, encoding: .utf16)

            // Convertir en Data pour PropertyListSerialization
            guard let data = strings.data(using: .utf8) else {
                print("⚠️ Impossible de convertir Predicate.strings en Data")
                return
            }

            // Désérialiser le format .strings en dictionnaire
            if let formattingDictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: String] {
                // Appliquer le dictionnaire de formatage au predicateEditor
                predicateEditor.formattingDictionary = formattingDictionary
                print("✅ Traductions NSPredicateEditor chargées avec succès")
            }

        } catch {
            print("⚠️ Erreur lors du chargement de Predicate.strings : \(error)")
        }
    }

}

