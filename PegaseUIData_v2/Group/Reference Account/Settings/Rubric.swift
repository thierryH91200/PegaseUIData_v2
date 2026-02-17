//
//  Rubric.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 10/11/2024.
//


import SwiftUI
import SwiftData
import Combine
import OSLog


struct RubricView: View {

    @EnvironmentObject var currentAccountManager : CurrentAccountManager
    @EnvironmentObject var rubricManager : RubricManager

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
                    Text("Account: \(account.name)", tableName: "SettingsView")
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
                        rubricManager.entitiesRubric.removeAll()
                        selectedCategory = nil
                        selectedRubric = nil

                        rubricManager.getAllData()
                    }
                }

                .onAppear {
                    rubricManager.getAllData()
                }
                .onDisappear {
                    rubricManager.entitiesRubric.removeAll()
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
                        let label = selectedRubric != nil ? String(localized: "Add Rubric", table: "SettingsView") : String(localized: "Add Category", table: "SettingsView")
                        Label(label, systemImage: "plus")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fixedSize()
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
                        let label = selectedRubric != nil ? String(localized: "Edit Rubric", table: "SettingsView") : String(localized: "Edit Category", table: "SettingsView")
                        Label(label, systemImage: "pencil")
                            .padding()
                            .background((selectedRubric == nil && selectedCategory == nil) ? Color.gray : Color.green)
                            .opacity((selectedRubric == nil && selectedCategory == nil) ? 0.6 : 1)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fixedSize()
                    }
                    .disabled(selectedRubric == nil && selectedCategory == nil)

                    Button(action: {
                        removeCategorySelectedItem()
                        refreshData()
                    })
                    {
                        let label = selectedRubric != nil ? String(localized: "Delete Rubric", table: "SettingsView") : String(localized: "Delete Category", table: "SettingsView")
                        Label(label, systemImage: "trash")
                            .padding()
                            .background((selectedRubric == nil && selectedCategory == nil) ? Color.gray : Color.red)
                            .opacity((selectedRubric == nil && selectedCategory == nil) ? 0.6 : 1)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fixedSize()
                    }
                    .disabled(selectedRubric == nil && selectedCategory == nil)
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
        rubricManager.getAllData()
    }

    private func removeRubric(_ rubric: EntityRubric) {
        RubricManager.shared.delete(entity: rubric)
        refreshData()
    }

    private func removeCategory(_ category: EntityCategory) {
        CategoryManager.shared.delete(entity: category)
        refreshData()
    }

    // Fonction separee pour generer la liste des rubriques
    @ViewBuilder
    private func rubricList() -> some View {
        ForEach(rubricManager.entitiesRubric, id: \.id) { rubrique in
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
                .background(selectedRubric?.name == rubrique.name ? Color.blue.opacity(0.3) : Color.clear)
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
                    Label(String(localized: "Add the rubric", table: "SettingsView"), systemImage: "plus")
                }

                Button(action: {
                    isPresentedRubric = true
                    isModeCreate = false
                }) {
                    Label(String(localized: "Edit the rubric", table: "SettingsView"), systemImage: "pencil")
                }

                Button(action: {
                    removeRubric(rubrique)
                }) {
                    Label(String(localized: "Delete the rubric", table: "SettingsView"), systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }

    // Fonction pour afficher chaque categorie avec une ligne HStack
    @ViewBuilder
    private func categoryRow(_ category: EntityCategory) -> some View {
        HStack {
            Text(category.name)
                .font(.system(size: 12))
                .frame(minWidth: 150, alignment: .leading)
            Text("\(category.objectif.description)")
                .font(.system(size: 12))
        }
        .padding(.leading, 5)
        .frame(height: 18)
        .background(selectedCategory?.name == category.name ? Color.blue.opacity(0.3) : Color.clear)
        .onTapGesture {
            selectedRubric = nil
            selectedCategory = category
        }
        .contextMenu {
            Button(action: {
                isPresentedRubric = true
                isModeCreate = true
            }) {
                Label(String(localized: "Add the category", table: "SettingsView"), systemImage: "plus")
            }

            Button(action: {
                isPresentedCategory = true
                isModeCreate = false
            }) {
                Label(String(localized: "Edit the category", table: "SettingsView"), systemImage: "pencil")
            }

            Button(action: {
                removeCategory(category)
            }) {
                Label(String(localized: "Remove the category", table: "SettingsView"), systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

struct RubricFormView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rubricManager : RubricManager

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

                Text(isMode ? String(localized: "Add the rubric", table: "SettingsView") : String(localized: "Edit Rubric", table: "SettingsView"))
                    .font(.headline)
                    .padding(.top, 10)

                TextField(String(localized: "Name", table: "SettingsView"), text: $name)
                    .textFieldStyle(.roundedBorder)

                ColorPicker(String(localized: "Choose the color", table: "SettingsView"), selection: $selectedColor)
                    .frame(height: 50)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", table: "SettingsView")) {
                        isPresented = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", table: "SettingsView")) {
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
            RubricManager.shared.create(name: name, color: color)
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

                Text(isModeCreate ? String(localized: "Add the category", table: "SettingsView") : String(localized: "Edit the category", table: "SettingsView"))
                    .font(.headline)
                    .padding(.top, 10)

                TextField(String(localized: "Name", table: "SettingsView"), text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField(String(localized: "Objectif", table: "SettingsView"), text: $objectif)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            Rectangle()
                .fill(isModeCreate ? Color.blue : Color.green)
                .frame(height: 10)

                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel", table: "SettingsView")) {
                            isPresented = false
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Save", table: "SettingsView")) {
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
            do {
                try CategoryManager.shared.save()
            } catch {
                AppLogger.data.error("Category save failed: \(error.localizedDescription)")
            }
        } else if let rubric = rubric {
            // Create a new category under the provided rubric
            _ = CategoryManager.shared.create(name: name, objectif: Double(objectif) ?? 0.0, rubric: rubric)
        } else {
            // No rubric available to attach the new category; nothing to do
            return
        }
    }
}
