//
//  ListTransactions120.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 25/03/2025.
//

import SwiftUI
import SwiftData


struct TransactionLigne: View {
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var transactionManager   : TransactionSelectionManager
    @EnvironmentObject private var colorManager : ColorManager
    
    let transaction: EntityTransaction
    @Binding var selectedTransactions: Set<UUID>
    let visibleTransactions: [EntityTransaction]
    
    @State var showTransactionInfo: Bool = false
    @GestureState private var isShiftPressed = false
    @GestureState private var isCmdPressed = false

    @State private var showPopover = false
    @State private var inputText = ""

    
    @State private var backgroundColor = Color.clear
    
    var isSelected: Bool {
        selectedTransactions.contains(transaction.uuid)
    }
    
    var body: some View {
        let isSelected = selectedTransactions.contains(transaction.uuid)
        let textColor = isSelected ? Color.white : colorManager.colorForTransaction(transaction)
        
        HStack(spacing: 0) {
            Group {
                Text(transaction.datePointageString)
                    .frame(width: ColumnWidths.datePointage, alignment: .leading)
                verticalDivider()
                Text(transaction.dateOperationString)
                    .frame(width: ColumnWidths.dateOperation, alignment: .leading)
                verticalDivider()
                Text(transaction.sousOperations.first?.libelle ?? "—")
                    .frame(width: ColumnWidths.libelle, alignment: .leading)
                verticalDivider()
                Text(transaction.sousOperations.first?.category?.rubric?.name ?? "—")
                    .frame(width: ColumnWidths.rubrique, alignment: .leading)
                verticalDivider()
                Text(transaction.sousOperations.first?.category?.name ?? "—")
                    .frame(width: ColumnWidths.categorie, alignment: .leading)
                verticalDivider()
                Text(transaction.sousOperations.first?.amountString ?? "—")
                    .frame(width: ColumnWidths.sousMontant, alignment: .leading)
                verticalDivider()
                Text(transaction.bankStatementString)
                    .frame(width: ColumnWidths.releve, alignment: .leading)
                verticalDivider()
                Text(transaction.checkNumber != "0" ? transaction.checkNumber : "—").frame(width: ColumnWidths.cheque, alignment: .leading)
                verticalDivider()
            }
            Group {
                Text(transaction.statusString)
                    .frame(width: ColumnWidths.statut, alignment: .leading)
                verticalDivider()
                Text(transaction.paymentModeString)
                    .frame(width: ColumnWidths.modePaiement, alignment: .leading)
                verticalDivider()
                Text(transaction.amountString)
                    .frame(width: ColumnWidths.montant, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets()) // ⬅️ Supprime la marge à gauche des lignes
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.5) : backgroundColor)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .foregroundColor(textColor)
        .cornerRadius(8) // Arrondi les coins du fond sélectionné
        .contentShape(Rectangle()) // Permet de cliquer sur toute la ligne
        .onTapGesture {
            toggleSelection()
        }
        .onHover { hovering in
            if !isSelected {
                withAnimation {
                    backgroundColor = hovering ? Color.gray.opacity(0.1) : Color.clear
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isCmdPressed)   { _, state, _ in state = NSEvent.modifierFlags.contains(.command) }
                .updating($isShiftPressed) { _, state, _ in state = NSEvent.modifierFlags.contains(.shift) }
        )
        .contextMenu {
            // Afficher les détails
            Button(action: {
                transactionManager.selectedTransaction = transaction
                transactionManager.isCreationMode = false
                showTransactionInfo = true
            }) {
                Label("Show details", systemImage: "info.circle")
            }
            // Liste des noms et couleurs des status
            let names = [ String(localized :"Planned"),
                          String(localized :"In progress"),
                          String(localized :"Executed") ]
            Menu {
                Button(names[0]) { mettreAJourStatusPourSelection(nouveauStatus: names[0]) }
                Button(names[1]) { mettreAJourStatusPourSelection(nouveauStatus: names[1]) }
                Button(names[2]) { mettreAJourStatusPourSelection(nouveauStatus: names[2]) }
            } label: {
                Label("Change status", systemImage: "square.and.pencil")
            }
            .disabled(selectedTransactions.isEmpty)
            
            let namesPayements = PaymentModeManager.shared.getAllNames()
            Menu {
                ForEach(namesPayements, id: \.self) { mode in
                    Button(mode) {
                        mettreAJourModePourSelection(nouveauMode: mode)
                    }
                }
            } label: {
                Label("Change Payment Mode", systemImage: "square.and.pencil")
            }
            .disabled(selectedTransactions.isEmpty)
            
            Menu {
                Button("New statement…") {
                    showPopover = true
                }
            } label: {
                Label("Bank statement", systemImage: "square.and.pencil")
            }
            
            Button(role: .destructive, action: {
                supprimerTransactionsSelectionnees()
            }) {
                Label("Remove", systemImage: "trash")
            }
            .disabled(selectedTransactions.isEmpty)
        }
        
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(spacing: 12) {
                Text("Create a statement")
                    .font(.headline)

                TextField("Statement number", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                HStack {
                    Button("Cancel") {
                        showPopover = false
                    }
                    Button("OK") {
                        print("Relevé saisi: \(inputText)")
                        mettreAJourRelevePourSelection(nouveauReleve: inputText)
                        showPopover = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(width: 250)
        }

        .popover(isPresented: $showTransactionInfo, arrowEdge: .top) {
            if let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.id == transaction.id }) {
                TransactionDetailView(currentSectionIndex: index, selectedTransaction: $selectedTransactions)
                    .frame(minWidth: 400, minHeight: 300)
            } else {
                Text("Error: Transaction not found in the list.")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        // Keyboard shortcut: Cmd+A to select all transactions, Escape to deselect all
        .onAppear {
            backgroundColor = isSelected ? Color.accentColor.opacity(0.2) : Color.clear
            NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
                    // Tout sélectionner
                    for transaction in ListTransactionsManager.shared.listTransactions {
                        selectedTransactions.insert(transaction.uuid)
                    }
                    transactionManager.selectedTransactions = ListTransactionsManager.shared.listTransactions
                    return nil
                }
                
                if event.keyCode == 53 { // Escape key
                    // Tout désélectionner
                    selectedTransactions.removeAll()
                    transactionManager.selectedTransaction = nil
                    transactionManager.selectedTransactions = []
                    return nil
                }
                // Undo: Cmd+Z
                if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
                    ListTransactionsManager.shared.undo()
                    return nil
                }
                // Redo: Shift+Cmd+Z
                if event.modifierFlags.contains([.command, .shift]), event.charactersIgnoringModifiers == "Z" {
                    ListTransactionsManager.shared.redo()
                    return nil
                }
                return event
            }
        }
    }
    
    @ViewBuilder
    func verticalDivider() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 2, height: 20)
            .padding(.horizontal, 2)
    }
    
    private func transactionByID(_ uuid: UUID) -> EntityTransaction? {
        return ListTransactionsManager.shared.listTransactions.first { $0.uuid == uuid }
    }
    
    private func toggleSelection() {
        let isCommand = NSEvent.modifierFlags.contains(.command)
        let isShift = NSEvent.modifierFlags.contains(.shift)
        
        if isShift, let lastID = transactionManager.lastSelectedTransactionID,
           let lastIndex = visibleTransactions.firstIndex(where: { $0.uuid == lastID }),
           let currentIndex = visibleTransactions.firstIndex(where: { $0.id == transaction.id }) {

            let range = lastIndex <= currentIndex
                ? lastIndex...currentIndex
                : currentIndex...lastIndex

            // Sélectionne tous les IDs dans la plage visible
            let idsInRange = visibleTransactions[range].map { $0.uuid }

            // Nettoie l’ancienne sélection et ajoute la nouvelle
            selectedTransactions.removeAll()
            selectedTransactions.formUnion(idsInRange)
            
        } else if isCommand {
            if selectedTransactions.contains(transaction.uuid) {
                selectedTransactions.remove(transaction.uuid)
            } else {
                selectedTransactions.insert(transaction.uuid)
            }
            // MAJ du dernier élément sélectionné, très important pour la sélection shift !
            transactionManager.lastSelectedTransactionID = transaction.uuid
        } else {
            selectedTransactions.removeAll()
            selectedTransactions.insert(transaction.uuid)
            // MAJ du dernier élément sélectionné, très important pour la sélection shift !
            transactionManager.lastSelectedTransactionID = transaction.uuid
        }

        if let firstSelectedId = selectedTransactions.first {
            transactionManager.selectedTransaction = ListTransactionsManager.shared.listTransactions.first { $0.uuid == firstSelectedId }
        }
        transactionManager.selectedTransactions = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
        transactionManager.isCreationMode = false
    }
    
    private func supprimerTransactionsSelectionnees() {
        withAnimation {
            // 1) Capture les indices ordonnés des éléments sélectionnés dans la liste visible
            let selectedIDs = Array(selectedTransactions)
            let orderedSelectedIndices: [Int] = visibleTransactions.enumerated()
                .filter { selectedIDs.contains($0.element.uuid) }
                .map { $0.offset }
                .sorted()

            // 2) Déterminer une cible de re-sélection (index voisin)
            let targetIndexAfter: Int? = orderedSelectedIndices.last.map { $0 + 1 }
            let targetIndexBefore: Int? = orderedSelectedIndices.first.map { $0 - 1 }

            // 3) Supprimer du contexte si non déjà supprimé
            let transactionsToDelete = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
            for transaction in transactionsToDelete where !transaction.isDeleted {
                ListTransactionsManager.shared.delete(entity: transaction)
            }

            // 4) Rafraîchir les données
            _ = ListTransactionsManager.shared.getAllData(ascending: false)

            // 5) Reconstituer la liste visible après suppression
            //    Ici, on part de visibleTransactions passé en paramètre de la vue. Si ta source change
            //    (filtre/tri), assure-toi que la vue parent le réévalue. On se contente de l'état courant.
            let newVisible = visibleTransactions

            // 6) Choisir une nouvelle sélection (l'élément après, sinon l'élément avant)
            var newSelectedID: UUID? = nil
            if let idx = targetIndexAfter, idx >= 0, idx < newVisible.count {
                newSelectedID = newVisible[idx].uuid
            } else if let idx = targetIndexBefore, idx >= 0, idx < newVisible.count {
                newSelectedID = newVisible[idx].uuid
            }

            // 7) Appliquer la nouvelle sélection et synchroniser le TransactionSelectionManager
            selectedTransactions.removeAll()
            if let uuid = newSelectedID {
                selectedTransactions.insert(uuid)
                transactionManager.selectedTransaction = ListTransactionsManager.shared.listTransactions.first { $0.uuid == uuid }
                transactionManager.selectedTransactions = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
            } else {
                transactionManager.selectedTransaction = nil
                transactionManager.selectedTransactions = []
            }
            transactionManager.isCreationMode = false
        }
    }
    private func mettreAJourRelevePourSelection(nouveauReleve: String) {
        withAnimation {
            guard let undo = ListTransactionsManager.shared.modelContext?.undoManager else {
                // Fallback sans undo manager
                let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
                for transaction in selected {
                    transaction.bankStatement = Double(nouveauReleve) ?? 0.0
                }
                
                return
            }

            undo.beginUndoGrouping()
            undo.setActionName("Change status")

            let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
            for transaction in selected {
                transaction.bankStatement = Double(nouveauReleve) ?? 0.0
            }
            

            do {
                try ListTransactionsManager.shared.modelContext?.save()
            } catch {
                print("Error saving context after status change: \(error)")
            }
            undo.endUndoGrouping()
        }
    }

    private func mettreAJourStatusPourSelection(nouveauStatus: String) {
        withAnimation {
            guard let undo = ListTransactionsManager.shared.modelContext?.undoManager else {
                // Fallback sans undo manager
                let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
                if let status = StatusManager.shared.find(name: nouveauStatus) {
                    for transaction in selected {
                        transaction.status = status
                    }
                }
                return
            }

            undo.beginUndoGrouping()
            undo.setActionName("Change status")

            let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
            if let status = StatusManager.shared.find(name: nouveauStatus) {
                for transaction in selected {
                    transaction.status = status
                }
            }

            do {
                try ListTransactionsManager.shared.modelContext?.save()
            } catch {
                print("Error saving context after status change: \(error)")
            }
            undo.endUndoGrouping()
        }
    }
    private func mettreAJourModePourSelection(nouveauMode: String) {
        withAnimation {
            guard let undo = ListTransactionsManager.shared.modelContext?.undoManager else {
                // Fallback sans undo manager
                let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
                if let mode = PaymentModeManager.shared.find(name: nouveauMode) {
                    for transaction in selected {
                        transaction.paymentMode = mode
                    }
                }
                return
            }

            undo.beginUndoGrouping()
            undo.setActionName("Change payment mode")

            let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
            if let mode = PaymentModeManager.shared.find(name: nouveauMode) {
                for transaction in selected {
                    transaction.paymentMode = mode
                }
            }

            do {
                try ListTransactionsManager.shared.modelContext?.save()
            } catch {
                print("Error saving context after status change: \(error)")
            }
            undo.endUndoGrouping()
        }
    }
}
