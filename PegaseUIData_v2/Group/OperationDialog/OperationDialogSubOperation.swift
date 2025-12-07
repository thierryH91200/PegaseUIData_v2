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
    
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var formState: TransactionFormState
    
    @EnvironmentObject var transactionManager: TransactionSelectionManager
    
    @Binding var subOperation: EntitySousOperation?
    
    @State private var comment           : String = ""
    @State private var selectedRubric    : EntityRubric?
    @State private var selectedCategorie : EntityCategory?
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
                        if let selected = selectedCategorie,
                           !entityCategorie.contains(where: { $0 == selected }) {
                            selectedCategorie = entityCategorie.first
                        }
                    } else {
                        entityCategorie = []
                        selectedCategorie = nil
                    }
                }
            }
            
            FormField(label: String(localized:"Category")) {
                Picker("", selection: $selectedCategorie) {
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
                    selectedCategorie = subOperation?.category
                    selectedRubric = subOperation?.category?.rubric
                    
                    if let sum = subOperation?.amount {
                        amount = String(abs(sum)) // Toujours positif à l'affichage
                        let shouldBeExpanded = sum >= 0.0
                        if isSigne != shouldBeExpanded { 
                            isSigne = shouldBeExpanded
                        }
                    } else {
                        amount = "0.0"
                        isSigne = false
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
        item.category = selectedCategorie

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
        let account = CurrentAccountManager.shared.getAccount()
        self.entityPreference = PreferenceManager.shared.getAllData(for: account)
        
        if let preference = entityPreference, let rubricIndex = entityRubric.firstIndex(where: { $0 == preference.category?.rubric }) {
            selectedRubric = entityRubric[rubricIndex]
            entityCategorie = entityRubric[rubricIndex].categorie.sorted { $0.name < $1.name }
            if let categoryIndex = entityCategorie.firstIndex(where: { $0 === preference.category }) {
                selectedCategorie = entityCategorie[categoryIndex]
            }
            isSigne = preference.signe
        }
    }
}

// MARK:  5. Composant pour la section des sous-opérations
struct SubOperationsSectionView: View {
    
    @EnvironmentObject var formState: TransactionFormState
    
    @Binding var subOperations: [EntitySousOperation]
    @Binding var currentSubOperation: EntitySousOperation?
    @Binding var isShowingDialog: Bool
    
    var body: some View {

        VStack(alignment: .leading) {
            Text("Split Transactions")
                .font(.headline)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            
            Text("Displayed sub-operations: \(subOperations.count)")
            
            List {
                ForEach(subOperations.indices, id: \.self) { index in
                    SubOperationRow(
                        subOperation: $subOperations[index] ,
                        onEdit: {
                            currentSubOperation = subOperations[index]
                            isShowingDialog = true
                        },
                        onDelete: {
                            subOperations.remove(at: index)
                        }
                    )
                }
            }
            .frame(height: 300)
            
            HStack {
                Button(action: {
                    isShowingDialog = true
                }) {
                    Image(systemName: "plus")
                    Text("Add Sub-operation")
                }
                .padding(.leading)
            }
        }
    }
}

struct SubOperationRow: View {
    
    @EnvironmentObject private var colorManager          : ColorManager
    
    @State var foregroundColor : Color = .black

    @Binding var subOperation: EntitySousOperation
    let onEdit: () -> Void
    let onDelete: () -> Void
    
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
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(BorderlessButtonStyle())
                .accessibilityLabel(String(localized: "Edit sub-operation"))
                .accessibilityHint(String(localized: "Double tap to edit \(subOperation.libelle ?? "Sans libellé")"))
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .accessibilityLabel(String(localized: "Delete sub-operation"))
                .accessibilityHint(String(localized: "Double tap to delete \(subOperation.libelle ?? "Sans libellé")"))
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

