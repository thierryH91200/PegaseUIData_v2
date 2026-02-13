//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 01/03/2025.
//

import SwiftUI
import AppKit
import SwiftData

struct SubOperationDialog: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var formState: TransactionFormState
    @EnvironmentObject var transactionManager: TransactionSelectionManager
    
    @Binding var subOperation: EntitySousOperation?
    
    @State private var comment           : String = ""
    @State private var selectedRubric    : EntityRubric?
    @State private var selectedCategory : EntityCategory?
    @State private var amount            : String = ""
    
    @State private var isShowingDialog: Bool = false
    
    @State private var entityPreference : EntityPreference?
    @State private var entityRubric     : [EntityRubric] = []
    @State private var entityCategorie  : [EntityCategory] = []
    
    @State private var isSigne = false // Indicateur l'état de sélection du signe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Split Transactions")
                .font(.headline)
                .padding(.bottom)
            
            TextField("Comment", text: $comment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel(String(localized: "Comment field"))
                .accessibilityHint(String(localized: "Enter a description for this sub-operation"))
            
            FormField(label: String(localized:"Rubric")) {
                Picker("", selection: $selectedRubric) {
                    ForEach(entityRubric, id: \.self) { rubric in
                        Text(rubric.name).tag(rubric)
                    }
                }
                .accessibilityLabel(String(localized: "Rubric selection"))
                .accessibilityHint(String(localized: "Choose a rubric for categorizing this sub-operation"))
                
                .onChange(of: selectedRubric) { oldRubric, newRubric in
                    if let newRubric = newRubric {
                        // Met à jour la liste des catégories en fonction de la rubrique sélectionnée
                        entityCategorie = newRubric.categorie.sorted { $0.name < $1.name }
                        // Réinitialise la sélection de catégorie si elle ne fait plus partie des catégories disponibles
                        if let selected = selectedCategory,
                           !entityCategorie.contains(where: { $0 == selected }) {
                            selectedCategory = entityCategorie.first
                        }
                    } else {
                        entityCategorie = []
                        selectedCategory = nil
                    }
                }
            }
            
            FormField(label: String(localized:"Category")) {
                Picker("", selection: $selectedCategory) {
                    ForEach(entityCategorie, id: \.self) { category in
                        Text(category.name).tag(category)
                    }
                }
                .accessibilityLabel(String(localized: "Category selection"))
                .accessibilityHint(String(localized: "Choose a category within the selected rubric"))
            }
            HStack {
                Text("Amount")
                ZStack {
                    Rectangle()
                        .fill(isSigne ? .green : .red)
                        .frame(width: 30, height: 30)
                    
                    
                    Image(systemName: isSigne ? "plus" : "minus")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                .onTapGesture {
                    isSigne.toggle()
                }
                
                TextField("Amount", text: $amount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 20))
                    .foregroundColor(isSigne ? .green : .red)
                    .onChange(of: amount) { _, newValue in
                        if newValue.contains(",") {
                            amount = newValue.replacingOccurrences(of: ",", with: ".")
                        }
                    }
                    .accessibilityLabel(String(localized: "Amount field"))
                    .accessibilityHint(String(localized: "Enter the amount for this sub-operation"))
                    .accessibilityValue(amount.isEmpty ? String(localized: "No amount entered") :
                                            amount)
            }
            .padding(.bottom)
            
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .frame(width: 100)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(5)
                }
                .accessibilityLabel(String(localized: "Cancel sub-operation"))
                .accessibilityHint(String(localized: "Double tap to discard changes"))
                
                Button(action: {
                    saveSubOperation()
                    dismiss() // Ferme la vue après sauvegarde
                }) {
                    Text("OK")
                        .frame(width: 100)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(5)
                }
                .disabled(comment == "")
                .opacity(comment == "" ? 0.6 : 1)
            }
        }
        .padding()
        .onAppear {
            
            Task {
                do {
                    try await configureManagers()
                } catch {
                    printTag("Failed to configure form: \(error)")
                }
                
                self.entityRubric = RubricManager.shared.getAllData()
                
                if transactionManager.isCreationMode == false {
                    comment = subOperation?.libelle ?? ""
                    selectedCategory = subOperation?.category
                    selectedRubric = subOperation?.category?.rubric
                    
                    if let sum = subOperation?.amount {
                        amount = String(abs(sum)) // Toujours positif à l'affichage
                        let shouldBeExpanded = sum >= 0.0
                        if isSigne != shouldBeExpanded {
                            isSigne = shouldBeExpanded
                        }
                    } else {
                        if let entityPreference = PreferenceManager.shared.getAllData() {
                            amount = "0.0"
                            isSigne = entityPreference.signe
                        }
                    }
                } else {
                    configureForm()
                }
            }
        }
    }
        
    func saveSubOperation() {
        if transactionManager.isCreationMode == true { // Création
            formState.currentSousTransaction = EntitySousOperation()
            subOperation = formState.currentSousTransaction
        }
            
        if let subOperation = subOperation {
            updateSousOperation(subOperation)
        }
        
//        try? modelContext.save()
        dismiss() // Ferme la vue immédiatement après la sauvegarde
    }
    
    private func updateSousOperation(_ item: EntitySousOperation) {
        item.libelle = comment
        item.category = selectedCategory

        if let value = Double(amount) {
            let signedValue = isSigne ? value : -value
            
            // Vérification stricte pour éviter les mises à jour involontaires
            if item.amount != signedValue {
                item.amount = signedValue
            }
        } else {
            printTag("Erreur : Le montant saisi n'est pas valide")
        }

        item.transaction = formState.currentTransaction
    }
    
    func configureManagers() async throws {
    }
    
    func configureForm() {

        self.entityPreference = PreferenceManager.shared.getAllData()
        
        if let preference = entityPreference, let rubricIndex = entityRubric.firstIndex(where: { $0 == preference.category?.rubric }) {
            selectedRubric = entityRubric[rubricIndex]
            entityCategorie = entityRubric[rubricIndex].categorie.sorted { $0.name < $1.name }
            if let categoryIndex = entityCategorie.firstIndex(where: { $0 === preference.category }) {
                selectedCategory = entityCategorie[categoryIndex]
            }
            isSigne = preference.signe
        }
    }
}

// MARK:  5. Composant pour la section des sous-opérations
struct SubOperationsSectionView: View {

    @Environment(\.undoManager) private var undoManager
    @EnvironmentObject var formState: TransactionFormState
    
    @Binding var subOperations: [EntitySousOperation]
    @Binding var currentSubOperation: EntitySousOperation?
    @Binding var isShowingDialog: Bool
    
    @State private var selectedID: ObjectIdentifier?
    
    var body: some View {

        VStack(alignment: .leading) {
            Text("Split Transactions")
                .font(.headline)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            
            Text("Displayed sub-operations: \(subOperations.count)")
            
            List(selection: $selectedID) {
                ForEach(subOperations.indices, id: \.self) { index in
                    SubOperationRow(subOperation: $subOperations[index])
                        .tag(ObjectIdentifier(subOperations[index]))
                        .onTapGesture(count: 2) {
                            currentSubOperation = subOperations[index]
                            isShowingDialog = true
                        }
                }
            }            
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            HStack {
                Button(action: {
                    isShowingDialog = true
                }) {
                    Label("Add", systemImage: "plus")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Button(action: {
                    if let sel = selectedID,
                       let found = subOperations.first(where: { ObjectIdentifier($0) == sel }) {
                        currentSubOperation = found
                        isShowingDialog = true
                    }
                }) {
                    Label("Edit", systemImage: "pencil")
                        .actionButtonStyle(
                            isEnabled: selectedID != nil,
                            activeColor: .green)
                }
                .disabled(selectedID == nil)

                Button(action: {
                    if let sel = selectedID,
                       let idx = subOperations.firstIndex(where: { ObjectIdentifier($0) == sel }) {
                        let toDelete = subOperations[idx]
                        subOperations.remove(at: idx)
                        SubTransactionsManager.shared.delete(
                            entity: toDelete,
                            undoManager: undoManager)
                        selectedID = nil
                        currentSubOperation = nil
                    }
                }) {
                    Label("Remove", systemImage: "trash")
                        .actionButtonStyle(
                            isEnabled: selectedID != nil,
                            activeColor: .red)
                }
                .disabled(selectedID == nil)
            }
            .padding(.leading)
        }
    }
}

struct SubOperationRow: View {
    
    @EnvironmentObject private var colorManager          : ColorManager
    
    @State var foregroundColor : Color = .black
    @Binding var subOperation: EntitySousOperation
    
    var body: some View {

        return VStack {
            HStack {
                Text("\(subOperation.category?.rubric?.name ?? String(localized: "N/A"))")
                    .foregroundColor(foregroundColor)

                Spacer()
                Text("\(subOperation.category?.name ?? String(localized: "N/A"))")
                    .foregroundColor(foregroundColor)
                Spacer()
                    .frame(width: 20)
            }
            HStack {
                Text(subOperation.libelle ?? String(localized: "No label"))
                    .foregroundColor(foregroundColor)

                Spacer()
                Text("\(subOperation.amount, format: .currency(code: "EUR"))")
                    .foregroundColor(foregroundColor)
                    .accessibilityLabel(String(localized: "Amount"))
                    .accessibilityValue("\(subOperation.amount, format: .currency(code: "EUR"))")
                
                Spacer()
                    .frame(width: 20)
            }
            Divider()
        }
        .onAppear {
            guard subOperation.transaction != nil else {
                return        }
            foregroundColor = colorManager.colorForTransaction(subOperation.transaction!)
        }
    }
}

