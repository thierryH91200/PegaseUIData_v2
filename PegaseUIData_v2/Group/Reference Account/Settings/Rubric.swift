//
//  Rubric.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 10/11/2024.
//


import SwiftUI
import SwiftData
import Combine


final class RubricDataManager: ObservableObject {
    @Published var rubrics: [EntityRubric] = []
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    func saveChanges() {
        do {
            try modelContext?.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

struct RubricView: View {
    
    @EnvironmentObject var currentAccountManager : CurrentAccountManager
    @EnvironmentObject var dataManager : RubricDataManager
    
    @State private var rubriques: [EntityRubric] = []
    
    @State private var expandedRubriques: [String: Bool] = [:]
    @State private var selectedCategory: EntityCategory?
    @State private var selectedRubric: EntityRubric?
    
    @State private var isPresentedRubric = false
    @State private var isPresentedCategory = false
    @State private var isModeCreate = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let account = currentAccountManager.getAccount() {
                    Text("Account: \(account.name)")
                        .font(.headline)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        rubricList()
                            .padding(.vertical, 0)
                    }
                    .padding(10)
                }
                
                .onChange(of: selectedCategory) { oldValue, newValue in
                }
                
                .onChange(of: currentAccountManager.currentAccountID ) { old, newValue in
                    if newValue.isEmpty {
                        dataManager.rubrics.removeAll()
                        selectedCategory = nil
                        selectedRubric = nil
                        
                        rubriques = RubricManager.shared.getAllData()
                        dataManager.rubrics = rubriques
                    }
                }
                
                .onAppear {
                    rubriques = RubricManager.shared.getAllData()
                    dataManager.rubrics = rubriques
                }
                .onDisappear {
                    dataManager.rubrics.removeAll()
                    rubriques.removeAll()
                    selectedCategory = nil
                    selectedRubric = nil
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 3)
                
                Spacer(minLength: 0)
                
                HStack {
                    Button(action: {
                        isModeCreate = true
                        if selectedRubric != nil {
                            isPresentedRubric = true
                        }
                        else {
                            isPresentedCategory = true
                        }
                    }) {
                        let label = selectedRubric != nil ? String(localized:"Add Rubric") : String(localized:"Add Category")
                        Label(label, systemImage: "plus")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fixedSize() // Ajuste la taille au contenu
                    }
                    
                    Button(action: {
                        isModeCreate = false
                        if selectedRubric != nil {
                            isPresentedRubric = true
                        }
                        else {
                            isPresentedCategory = true
                        }

                    }) {
                        let label = selectedRubric != nil ? String(localized:"Edit Rubric") : String(localized:"Edit Category")
                        Label(label, systemImage: "pencil")
                            .padding()
                            .background((selectedRubric == nil && selectedCategory == nil) ? Color.gray : Color.green) // Fond gris si désactivé
                            .opacity((selectedRubric == nil && selectedCategory == nil) ? 0.6 : 1) // Opacité réduite si désactivé
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fixedSize() // Ajuste automatiquement la taille au contenu
                    }
                    .disabled(selectedRubric == nil && selectedCategory == nil) // Désactive si aucune ligne n'est sélectionnée
                    
                    Button(action: {
                        removeCategorySelectedItem()
                        refreshData()
                    })
                    {
                        let label = selectedRubric != nil ? String(localized:"Delete Rubric") : String(localized:"Delete Category")
                        Label(label, systemImage: "trash")
                            .padding()
                            .background((selectedRubric == nil && selectedCategory == nil) ? Color.gray : Color.red) // Fond gris si désactivé
                            .opacity((selectedRubric == nil && selectedCategory == nil) ? 0.6 : 1) // Opacité réduite si désactivé
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fixedSize() // Ajuste automatiquement la taille au contenu
                    }
                    .disabled(selectedRubric == nil && selectedCategory == nil) // Désactive si aucune ligne n'est sélectionnée
                }
                .padding()
                Spacer()
            }
            .frame(width: 400, height: 500)
            .padding()
            .position(x: geometry.size.width / 2, y: 0)
            .offset(y: 350) // Ajustez cette valeur selon vos besoins
            
            .sheet(isPresented: $isPresentedRubric) {
                RubricFormView(isPresented: $isPresentedRubric,
                               isMode: $isModeCreate,
                               rubric: isModeCreate ? nil : selectedRubric)
            }
            .sheet(isPresented: $isPresentedCategory) {
                let rubric = selectedCategory?.rubric

                CategoryFormView(isPresented: $isPresentedCategory,
                                 isModeCreate: $isModeCreate,
                                 rubric: isModeCreate ? nil : rubric,
                                 category: isModeCreate ? nil : selectedCategory,)
            }
        }
    }
    private func removeCategorySelectedItem() {
        if let rubric = selectedRubric {
            RubricManager.shared.delete(entity: rubric)
        } else if let category = selectedCategory {
            CategoryManager.shared.delete(entity: category)
        }
    }
    
    func refreshData() {
        rubriques = RubricManager.shared.getAllData()
        dataManager.rubrics = rubriques
    }
    
    private func removeRubric(_ rubric: EntityRubric) {
        RubricManager.shared.delete(entity: rubric)
        refreshData()
    }
    
    private func removeCategory(_ category: EntityCategory) {
        CategoryManager.shared.delete(entity: category)
        refreshData()
    }
    
    // Fonction séparée pour générer la liste des rubriques
    @ViewBuilder
    private func rubricList() -> some View {
        ForEach(rubriques, id: \.id) { rubrique in
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedRubriques[rubrique.name] ?? true },
                    set: { expandedRubriques[rubrique.name] = $0 }
                )
            ) {
                VStack(spacing: 0) {
                    ForEach(rubrique.categorie, id: \.id) { category in
                        categoryRow(category)
                    }
                }
            } label: {
                HStack {
                    Text(rubrique.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(rubrique.color))
                        .frame(height: 20)
                    Spacer()
                    Rectangle()
                        .fill(Color(rubrique.color))
                        .frame(width: 40, height: 10)
                }
                .padding(.vertical, 2)
                .background(selectedRubric?.name == rubrique.name ? Color.blue.opacity(0.3) : Color.clear) // ✅ Sélection uniquement sur la rubrique
                .onTapGesture {
                    selectedRubric = rubrique
                    selectedCategory = nil
                }
            }
            .contextMenu {
                Button(action: {
                    isPresentedRubric = true
                    isModeCreate = true
                }) {
                    Label("Add the rubric", systemImage: "plus")
                }
                
                Button(action: {
                    isPresentedRubric = true
                    isModeCreate = false
                }) {
                    Label("Edit the rubric", systemImage: "pencil")
                }
                
                Button(action: {
                    removeRubric(rubrique)
                }) {
                    Label("Delete the rubric", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // Fonction pour afficher chaque catégorie avec une ligne HStack
    @ViewBuilder
    private func categoryRow(_ category: EntityCategory) -> some View {
        HStack {
            Text(category.name)
                .font(.system(size: 12))
                .frame(minWidth: 150, alignment: .leading)
            Text("🎯 \(category.objectif.description)")
                .font(.system(size: 12))
        }
        .padding(.leading, 5)
        .frame(height: 18)
        .background(selectedCategory?.name == category.name ? Color.blue.opacity(0.3) : Color.clear)
        .onTapGesture {
            selectedRubric = nil
            selectedCategory = category
        }
        .contextMenu {  // Ajout du menu contextuel
            Button(action: {
                isPresentedRubric = true
                isModeCreate = true
            }) {
                Label("Add the category", systemImage: "plus")
            }
            
            Button(action: {
                isPresentedCategory = true
                isModeCreate = false
            }) {
                Label("Edit the category", systemImage: "pencil")
            }
            
            Button(action: {
                removeCategory(category)
            }) {
                Label("Remove the category", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

struct RubricFormView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager : RubricDataManager

    @Binding var isPresented: Bool
    @Binding var isMode: Bool
    let rubric: EntityRubric?
    @State private var name: String = ""
    @State private var selectedColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isMode ? Color.blue : Color.green)
                .frame(height: 10)
            
            // Contenu principal
            VStack(spacing: 20) {
                
                Text(isMode ? "Add the rubric" : "Edit Rubric")
                    .font(.headline)
                    .padding(.top, 10) // Ajoute un peu d'espace après le bandeau
                
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                ColorPicker("Choose the color", selection: $selectedColor)
                    .frame(height: 50)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isPresented = false
                        save()
                        dismiss()
                    }
                }
            }
            // Bandeau du bas
            .frame(width: 300)
            
            Rectangle()
                .fill(isMode ? Color.blue : Color.green)
                .frame(height: 10)
            
                .onAppear {
                    if let rubric = rubric {
                        name = rubric.name
                        selectedColor = Color(rubric.color)
                    }
                }
        }
    }
    
    private func save() {
        
        let color = NSColor.fromSwiftUIColor(selectedColor)

        // Update existing rubric or create a new one
        if let existing = rubric {
            existing.name = name
            existing.color = color
            // Keep existing account as-is
        } else {
            
            guard let created = RubricManager.shared.create(name: name, color: color) else { return }
            
            // Keep the data manager list in sync if available
            dataManager.rubrics.append(created)
        }
    }
}

struct CategoryFormView: View {

    @Environment(\.dismiss) private var dismiss
    
    @Binding var isPresented: Bool
    @Binding var isModeCreate: Bool
    let rubric: EntityRubric?
    let category: EntityCategory?
    @State private var name: String = ""
    @State private var objectif: String = ""
    @State private var selectedColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isModeCreate ? Color.blue : Color.green)
                .frame(height: 10)
            
            // Contenu principal
            VStack(spacing: 20) {
                
                Text(isModeCreate ? "Add the category" : "Edit the category")
                    .font(.headline)
                    .padding(.top, 10) // Ajoute un peu d'espace après le bandeau
                
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Objectif", text: $objectif)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            Rectangle()
                .fill(isModeCreate ? Color.blue : Color.green)
                .frame(height: 10)
            
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            isPresented = false
                            save()
                            dismiss()
                        }
                    }
                }
            // Bandeau du bas
                .frame(width: 200)
            
                .onAppear {
                    if let category = category {
                        name = category.name
                        objectif = String(category.objectif)
                    }
                }
        }
    }
    
    private func save() {
        if let existing = category {
            // Update existing category fields
            existing.name = name
            existing.objectif = Double(objectif) ?? 0.0
            try? CategoryManager.shared.save()
        } else if let rubric = rubric {
            // Create a new category under the provided rubric
            _ = CategoryManager.shared.create(name: name, objectif: Double(objectif) ?? 0.0, rubric: rubric)
        } else {
            // No rubric available to attach the new category; nothing to do
            // You may want to show an alert in the future.
            return
        }
    }
}

