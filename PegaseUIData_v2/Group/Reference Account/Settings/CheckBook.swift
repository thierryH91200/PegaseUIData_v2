//
//  Check.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 10/11/2024.
//

import SwiftUI
import SwiftData


// Vue principale pour l'affichage des carnets de chèques
struct CheckView: View {

    @Environment(\.undoManager) private var undoManager

    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var dataManager: ChequeBookManager
    
    @State private var checkBooks: [EntityCheckBook] = []

    @State private var selectedItemID: EntityCheckBook.ID?
    @State private var lastDeletedID: UUID?

    var selectedCheckBook: EntityCheckBook? {
        guard let id = selectedItemID else { return nil }
        return checkBooks.first(where: { $0.id == id })
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
            // Affiche le compte actuel
            if let account = currentAccountManager.getAccount() {
                Text("Account: \(account.name)")
                    .font(.headline)
            }
            
            // Table des carnets de chèques
            CheckBookTable(checkBooks: dataManager.checkBooks, selection: $selectedItemID)
                .frame(height: 300)
            
                .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in
                    printTag("Undo effectué, on recharge les données")
                    DispatchQueue.main.async { refreshData() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in
                    printTag("Redo effectué, on recharge les données")
                    DispatchQueue.main.async { refreshData() }
                }
                .onChange(of: currentAccountManager.getAccount()) { old, newAccount in
                    // Mise à jour de la liste en cas de changement de compte
                    dataManager.checkBooks.removeAll()
                    selectedItemID = nil
                    refreshData()
                }
            
                // Charge les données au démarrage de la vue
                .onAppear {
                    setupDataManager()
                    print("[ChequeBook] on Appear View undoManager =", undoManager as Any)
                }
            
                .onDisappear {
                    checkBooks.removeAll()
                }

            // Boutons d'action
            HStack {
                Button(action: {
                    isPresented = true
                    isModeCreate = true
                }) {
                    Label("Add", systemImage: "plus")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isPresented = true
                    isModeCreate = false
                }) {
                    Label("Edit", systemImage: "pencil")
                        .actionButtonStyle(isEnabled: selectedItemID != nil, activeColor: .green)
                }
                .disabled(selectedItemID == nil)
                
                Button( action: {
                    delete()
                    setupDataManager()
                }) {
                    Label("Delete", systemImage: "trash")
                        .actionButtonStyle(isEnabled: selectedItemID != nil, activeColor: .red)
                }
                .buttonStyle(.bordered)
                .disabled(selectedItemID == nil)
                Button(action: {
                    if let manager = undoManager, manager.canUndo {
                        selectedItemID = nil
                        lastDeletedID = nil
                        
                        manager.undo()
                        
                        DispatchQueue.main.async {
                            refreshData()
                        }
                    }
                }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(minWidth: 100) // Largeur minimale utile
                        .actionButtonStyle(isEnabled: canUndo == true, activeColor: .green)
                }
                .buttonStyle(.plain)
                Button(action: {
                    if let manager = undoManager, manager.canRedo {
                        selectedItemID = nil
                        lastDeletedID = nil

                        manager.redo()

                        DispatchQueue.main.async {
                            refreshData()
                        }
                    }
                }) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                        .frame(minWidth: 100) // Largeur minimale utile
                        .actionButtonStyle(isEnabled: canRedo == true, activeColor: .orange)
                }
                .buttonStyle(.plain)
//#endif
            }
            
            // Feuilles modales pour l'ajout/modification
            .sheet(isPresented: $isPresented, onDismiss: {setupDataManager()})
            {
                CheckBookFormView(
                    isPresented: $isPresented,
                    isModeCreate: $isModeCreate,
                    checkBook: isModeCreate ? nil : selectedCheckBook)
            }
            .padding()
            Spacer()
        }
    }
    
    // Configure le gestionnaire de données
    private func setupDataManager() {

        if currentAccountManager.getAccount() != nil {
            if let allData = ChequeBookManager.shared.getAllData() {
                dataManager.checkBooks = allData
                checkBooks = allData
            } else {
                print("❗️Erreur : getAllData() a renvoyé nil")
            }
        } else {
            // Aucun compte courant — on vide la table pour éviter des crashs
            dataManager.checkBooks = []
            checkBooks = []
            print("[ChequeBook] Aucun compte courant — table vidée.")
        }
    }
    
    // Supprime un carnet de chèques sélectionné
    private func delete() {
        if let id = selectedItemID,
           let item = checkBooks.first(where: { $0.id == id }) {

            lastDeletedID = item.uuid
            ChequeBookManager.shared.delete(entity: item, undoManager: undoManager)

            // Laisser la table garder le focus un court instant
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Ne pas remettre selectedItemID à nil immédiatement
                selectedItemID = nil
                lastDeletedID = nil
                refreshData()
            }
        }
    }

    // Rafraîchit la liste des carnets de chèques
    private func refreshData() {
        dataManager.checkBooks = ChequeBookManager.shared.getAllData() ?? []
        checkBooks = dataManager.checkBooks
    }
}

struct CheckBookTable: View {
    
    var checkBooks: [EntityCheckBook]
    @Binding var selection: EntityCheckBook.ID?
    
    var body: some View {
        
        Table(checkBooks, selection: $selection) {
            
            TableColumn( "Name", value: \EntityCheckBook.name)
            
            TableColumn( "Number of Checks") { (item: EntityCheckBook) in
                Text(String(item.nbCheques))
            }
            
            TableColumn( "First Number") { (item: EntityCheckBook) in
                Text(String(item.numPremier))
            }
            
            TableColumn( "Next Number") { (item: EntityCheckBook) in
                Text(String(item.numSuivant))
            }
            
            TableColumn( "Prefix") { (item: EntityCheckBook) in
                Text(item.prefix)
            }
            
            TableColumn("Name") { item in
                Text(item.account?.identity?.name ?? "")
            }
            
            TableColumn("Surname") { (item: EntityCheckBook) in
                Text(item.account?.identity?.surName ?? "")
            }
            
            TableColumn("Number") { item in
                Text(item.account?.initAccount?.codeAccount ?? "")
            }
        }
        .tableStyle(.bordered)
    }
}

// Vue pour la boîte de dialogue d'ajout
struct CheckBookFormView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: ChequeBookManager
    
    @Binding var isPresented: Bool
    @Binding var isModeCreate: Bool
    let checkBook: EntityCheckBook?
    
    @State private var name: String = ""
    @State private var nbCheques: Int = 0
    @State private var numPremier: Int = 0
    @State private var numSuivant: Int = 0
    @State private var prefix: String = ""
    
    var body: some View {
        VStack(spacing: 0) { // Spacing à 0 pour que les bandeaux soient collés au contenu
            // Bandeau du haut
            Rectangle()
                .fill(isModeCreate ? Color.blue : Color.green)
                .frame(height: 10)
            
            // Contenu principal
            VStack(spacing: 20) {
                Text(isModeCreate ? "Add CheckBook" : "Edit CheckBook")
                    .font(.headline)
                    .padding(.top, 10) // Ajoute un peu d'espace après le bandeau
                
                HStack {
                    Text("Name")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Number of Checks")
                        .frame(width: 100, alignment: .leading)
                    TextField("", value: $nbCheques, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("First Number")
                        .frame(width: 100, alignment: .leading)
                    TextField("", value: $numPremier, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Next Number")
                        .frame(width: 100, alignment: .leading)
                    TextField("", value: $numSuivant, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Prefix")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $prefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Spacer()
            }
            .padding()
            .navigationTitle(checkBook == nil ? "New checkBook" : "Edit CheckBook")
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
                    .disabled(prefix.isEmpty || name.isEmpty || numPremier <= 0 || numSuivant <= 0 || nbCheques <= 0)
                    .opacity(prefix.isEmpty || name.isEmpty || numPremier <= 0 || numSuivant <= 0 || nbCheques <= 0 ? 0.6 : 1)
                }
            }
            .frame(width: 400)
            
            // Bandeau du bas
            Rectangle()
                .fill(isModeCreate ? Color.blue : Color.green)
                .frame(height: 10)
        }
        .onAppear {
            if let checkBook = checkBook {
                name = checkBook.name
                nbCheques = checkBook.nbCheques
                numPremier = checkBook.numPremier
                numSuivant = checkBook.numSuivant
                prefix = checkBook.prefix
            }
        }
    }
    
    private func save() {
        if isModeCreate { // Création
            ChequeBookManager.shared.create(
                name: name,
                nbCheques: nbCheques,
                numPremier: numPremier,
                numSuivant: numSuivant,
                prefix: prefix
            )
        } else { // Modification
            if let existingItem = checkBook {
                existingItem.name = name
                existingItem.nbCheques = nbCheques
                existingItem.numPremier = numPremier
                existingItem.numSuivant = numSuivant
                existingItem.prefix = prefix
                
                ChequeBookManager.shared.save()
            }
        }
        
        isPresented = false
        dismiss()
    }
    
    private func updateCheckBook(_ item: EntityCheckBook) {
        item.name = name
        item.nbCheques = nbCheques
        item.numPremier = numPremier
        item.numSuivant = numSuivant
        item.prefix = prefix
    }
}

