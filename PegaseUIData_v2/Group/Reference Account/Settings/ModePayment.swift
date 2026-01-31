//
//  ModePayment.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 10/11/2024.
//

import SwiftUI
import SwiftData

struct ModePaymentView: View {
    
    @Environment(\.undoManager) private var undoManager
    
    @EnvironmentObject var currentAccountManager : CurrentAccountManager
    @EnvironmentObject var dataManager : PaymentModeManager
       
    // Ajoutez un état pour suivre l'élément sélectionné
    @State private var selectedItem: EntityPaymentMode.ID?
    @State private var lastDeletedID: UUID?
    
    var selectedMode: EntityPaymentMode? {
        guard let id = selectedItem else { return nil }
        return dataManager.modePayments.first(where: { $0.id == id })
    }
    
    @State private var isPresented = false
    @State private var isModeCreate = false
    
    var canUndo : Bool? {
        undoManager?.canUndo ?? false
    }
    var canRedo : Bool? {
        undoManager?.canRedo ?? false
    }
    
    var body: some View {
        VStack(spacing: 10) {
            
            // Affiche le nom du compte courant s'il existe
            if let account = currentAccountManager.getAccount()  {
                Text("Account: \(account.name)", tableName: "SettingsView")
                    .font(.headline)
            }
            
            // Affiche le tableau des modes de paiement
            ModePaiementTable(
                modePayments: dataManager.modePayments,
                selection: $selectedItem)
            .frame(height: 300)
            
            // Mise à jour de l'élément sélectionné
            .onChange(of: selectedItem) { _, newValue in
                
                if let selected = newValue {
                    selectedItem = selected
                } else {
                    selectedItem = nil
                }
            }
            .onDisappear {
                dataManager.modePayments = []
            }

            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in
                printTag("Undo effectué, on recharge les données")
                refreshData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in
                printTag("Redo effectué, on recharge les données")
                refreshData()
            }
            
            // Recharge les données lorsqu'un nouvel ID de compte est sélectionné
            .onChange(of: currentAccountManager.currentAccountID ) { old, newValue in
                if !newValue.isEmpty {
                    dataManager.modePayments.removeAll()
                    selectedItem = nil
                    refreshData()
                } else {
                    // Cas aucun compte sélectionné si nécessaire
                    dataManager.modePayments.removeAll()
                    selectedItem = nil
                }
            }
            
            // Recharge aussi lorsqu'un nouveau compte résolu est détecté
            .onChange(of: currentAccountManager.getAccount()) { _, newAccount in
                dataManager.modePayments.removeAll()
                selectedItem = nil
                if newAccount != nil {
                    refreshData()
                }
            }
            
            // Charge les données au démarrage de la vue
            .onAppear {
                setupDataManager()
            }
            
            HStack {
                Button(action: {
                    isPresented = true
                    isModeCreate = true

                }) {
                    Label(String(localized: "Add", table: "SettingsView"), systemImage: "plus")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                // Boutons d'action (Ajouter, Modifier, Supprimer)
                Button(action: {
                    isPresented = true
                    isModeCreate = false
                }) {
                    Label(String(localized: "Edit", table: "SettingsView"), systemImage: "pencil")
                        .actionButtonStyle(
                            isEnabled: selectedItem != nil,
                            activeColor: .green)
                }
                .disabled(selectedItem == nil) // Désactive si aucune ligne n'est sélectionnée

                Button(action: {
                    delete()
                    setupDataManager()
                })
                {
                    Label(String(localized: "Delete", table: "SettingsView"), systemImage: "trash")
                        .actionButtonStyle(
                            isEnabled: selectedItem != nil,
                            activeColor: .red)
                }
                .disabled(selectedItem == nil)
                // Désactive si aucune ligne n'est sélectionnée

                Button(action: {
                    if let manager = undoManager, manager.canUndo {
                        selectedItem = nil
                        lastDeletedID = nil
                        manager.undo()
                        DispatchQueue.main.async {
                            refreshData()
                        }
                    }
                }) {
                    Label(String(localized: "Undo", table: "SettingsView"), systemImage: "arrow.uturn.backward")
                        .actionButtonStyle(
                            isEnabled: canUndo == false,
                            activeColor: .green)
                }
                .disabled(canUndo == false)
                .buttonStyle(.plain)

            }
            .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Utilise tout l'espace parent et aligne en haut
        .padding()
        
        // Formulaire d'ajout et de modification
        .sheet(isPresented: $isPresented) {
            ModePaiementFormView(isPresented: $isPresented,
                                 isModeCtreate: $isModeCreate,
                                 modePaiement:  isModeCreate ? nil : selectedMode)
        }
    }
    
    private func setupDataManager() {
        
        if currentAccountManager.getAccount() != nil {
            let allData = PaymentModeManager.shared.getAllData()
                dataManager.modePayments = allData
        }
    }
    
    private func delete()
    {
        if let id = selectedItem,
           let modeToDelete = dataManager.modePayments.first(where: { $0.id == id }) {
            PaymentModeManager.shared.delete(entity: modeToDelete, undoManager: undoManager)
            DispatchQueue.main.async {
                selectedItem = nil
                lastDeletedID = nil
                refreshData()
            }
        }
    }
    
    private func refreshData() {
        let allData = PaymentModeManager.shared.getAllData()
            dataManager.modePayments = allData
    }
}

struct ModePaiementTable: View {

    var modePayments: [EntityPaymentMode]
    @Binding var selection: EntityPaymentMode.ID?

    var body: some View {

        VStack(spacing: 10) {
            Table(modePayments, selection: $selection) {
                TableColumn(String(localized: "Name", table: "SettingsView"), value: \EntityPaymentMode.name)
                TableColumn(String(localized: "Color", table: "SettingsView")) { item in
                    Rectangle()
                        .fill(Color(item.color))
                        .frame(width: 40, height: 20)
                }
                TableColumn(String(localized: "Account", table: "SettingsView"), value: \EntityPaymentMode.account.name)
                TableColumn(String(localized: "Surname", table: "SettingsView")) { paymentMode in
                    Text(paymentMode.account.identity?.surName ?? String(localized: "Unknown", table: "SettingsView"))
                }
                TableColumn(String(localized: "First name", table: "SettingsView"))  { paymentMode in
                    Text(paymentMode.account.identity?.name ?? String(localized: "Unknown", table: "SettingsView"))
                }
                TableColumn(String(localized: "Number", table: "SettingsView")) { paymentMode in
                    Text(paymentMode.account.initAccount?.codeAccount ?? String(localized: "Unknown", table: "SettingsView"))
                }
            }
        }
    }
}

// Vue pour la boîte de dialogue d'ajout
struct ModePaiementFormView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var modePaiementViewManager: PaymentModeManager
    @EnvironmentObject var currentAccountManager: CurrentAccountManager

    @Binding var isPresented: Bool
    @Binding var isModeCtreate: Bool
    let modePaiement: EntityPaymentMode?
    
    @State private var name: String = ""
    @State private var selectedColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isModeCtreate ? Color.blue : Color.green)
                .frame(height: 10)
            
            // Contenu principal
            VStack(spacing: 20) {

                Text(isModeCtreate ? String(localized: "Add Payment Mode", table: "SettingsView") : String(localized: "Edit Payment Mode", table: "SettingsView"))
                    .font(.headline)
                    .padding(.top, 10) // Ajoute un peu d'espace après le bandeau

                TextField(String(localized: "Name", table: "SettingsView"), text: $name)
                    .textFieldStyle(.roundedBorder)

                ColorPicker(String(localized: "Choose the color", table: "SettingsView"), selection: $selectedColor)
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
                .fill(isModeCtreate ? Color.blue : Color.green)
                .frame(height: 10)
            
                .onAppear {
                    if let modePaiement = modePaiement {
                        name = modePaiement.name
                        selectedColor = Color(modePaiement.color)
                    } else {
                        selectedColor = .blue // Mettre une couleur par défaut sympa
                    }
                }
        }
    }
    
    private func save() {
        // Ensure we have a current account before proceeding
        guard let account = CurrentAccountManager.shared.getAccount() else {
            return
        }

        do {
            let color = NSColor.fromSwiftUIColor(selectedColor)

            if let existing = modePaiement {
                // Update existing entity
                // Persist using the manager if needed (manager expected to handle persistence/undo)
                PaymentModeManager.shared.update(entity: existing, name: name, color: color)
            } else {
                // Create a new entity
                let created = try PaymentModeManager.shared.create(account: account, name: name, color: color)
                // Append to the view manager list for UI refresh if creation succeeded
                if let newItem = created {
                    modePaiementViewManager.modePayments.append(newItem)
                } else {
                    print("PaymentModeManager.create returned nil entity")
                }
            }
        } catch {
            // You may want to present an alert to the user in the future
            // For now, simply log the error
            print("Failed to save payment mode: \(error)")
        }
    }
}

