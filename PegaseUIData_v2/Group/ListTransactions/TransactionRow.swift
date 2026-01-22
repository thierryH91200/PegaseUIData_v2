////
////  TransactionRow.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 25/03/2025.
////  Refactored by Claude Code on 14/01/2026.
////
//
//import SwiftUI
//import SwiftData
//import OSLog
//
///// Displays a single transaction row in the list
/////
///// Features:
///// - Multi-selection support (Command/Shift click)
///// - Context menu for common operations (status change, payment mode, delete)
///// - Hover effect for better UX
///// - Color-coded based on transaction type
///// - Keyboard shortcuts (Cmd+A, Escape, Cmd+Z, Shift+Cmd+Z)
//struct TransactionRow: View {
//
//    @EnvironmentObject var transactionManager: TransactionSelectionManager
//    @EnvironmentObject private var colorManager: ColorManager
//
//    let transaction: EntityTransaction
//    @Binding var selectedTransactions: Set<UUID>
//    let visibleTransactions: [EntityTransaction]
//
//    @State var showTransactionInfo: Bool = false
//    @GestureState private var isShiftPressed = false
//    @GestureState private var isCmdPressed = false
//
//    @State private var showPopover = false
//    @State private var inputText = ""
//
//    @State private var backgroundColor = Color.clear
//
//    var isSelected: Bool {
//        selectedTransactions.contains(transaction.uuid)
//    }
//
//    var body: some View {
//        let isSelected = selectedTransactions.contains(transaction.uuid)
//        let textColor = isSelected ? Color.white : colorManager.colorForTransaction(transaction)
//
//        HStack(spacing: 0) {
//            Group {
//                Text(transaction.datePointageString)
//                    .frame(width: ColumnWidths.datePointage, alignment: .leading)
//                verticalDivider()
//                Text(transaction.dateOperationString)
//                    .frame(width: ColumnWidths.dateOperation, alignment: .leading)
//                verticalDivider()
//                Text(transaction.sousOperations.first?.libelle ?? "—")
//                    .frame(width: ColumnWidths.libelle, alignment: .leading)
//                verticalDivider()
//                Text(transaction.sousOperations.first?.category?.rubric?.name ?? "—")
//                    .frame(width: ColumnWidths.rubrique, alignment: .leading)
//                verticalDivider()
//                Text(transaction.sousOperations.first?.category?.name ?? "—")
//                    .frame(width: ColumnWidths.categorie, alignment: .leading)
//                verticalDivider()
//                Text(transaction.sousOperations.first?.amountString ?? "—")
//                    .frame(width: ColumnWidths.sousMontant, alignment: .leading)
//                verticalDivider()
//                Text(transaction.bankStatementString)
//                    .frame(width: ColumnWidths.releve, alignment: .leading)
//                verticalDivider()
//                Text(transaction.checkNumber != "0" ? transaction.checkNumber : "—")
//                    .frame(width: ColumnWidths.cheque, alignment: .leading)
//                verticalDivider()
//            }
//            Group {
//                Text(transaction.statusString)
//                    .frame(width: ColumnWidths.statut, alignment: .leading)
//                verticalDivider()
//                Text(transaction.paymentModeString)
//                    .frame(width: ColumnWidths.modePaiement, alignment: .leading)
//                verticalDivider()
//                Text(transaction.amountString)
//                    .frame(width: ColumnWidths.montant, alignment: .trailing)
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .listRowInsets(EdgeInsets())
//        .padding(.vertical, 6)
//        .background(
//            RoundedRectangle(cornerRadius: 8)
//                .fill(isSelected ? Color.blue.opacity(0.5) : backgroundColor)
//        )
//        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
//        .padding(.horizontal, 4)
//        .padding(.vertical, 2)
//        .foregroundColor(textColor)
//        .cornerRadius(8)
//        .contentShape(Rectangle())
//        .onTapGesture {
//            toggleSelection()
//        }
//        .onHover { hovering in
//            if !isSelected {
//                withAnimation {
//                    backgroundColor = hovering ? Color.gray.opacity(0.1) : Color.clear
//                }
//            }
//        }
//        .gesture(
//            DragGesture(minimumDistance: 0)
//                .updating($isCmdPressed)   { _, state, _ in state = NSEvent.modifierFlags.contains(.command) }
//                .updating($isShiftPressed) { _, state, _ in state = NSEvent.modifierFlags.contains(.shift) }
//        )
//        .contextMenu {
//            contextMenuContent
//        }
//        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
//            bankStatementPopover
//        }
//        .popover(isPresented: $showTransactionInfo, arrowEdge: .top) {
//            transactionDetailPopover
//        }
//        .onAppear {
//            backgroundColor = isSelected ? Color.accentColor.opacity(0.2) : Color.clear
//            setupKeyboardShortcuts()
//        }
//    }
//
//    // MARK: - View Components
//
//    @ViewBuilder
//    func verticalDivider() -> some View {
//        Rectangle()
//            .fill(Color.gray.opacity(0.4))
//            .frame(width: 2, height: 20)
//            .padding(.horizontal, 2)
//    }
//
//    private var contextMenuContent: some View {
//        Group {
//            // Show details
//            Button(action: {
//                transactionManager.selectedTransaction = transaction
//                transactionManager.isCreationMode = false
//                showTransactionInfo = true
//            }) {
//                Label("Show details", systemImage: "info.circle")
//            }
//
//            // Change status menu
//            statusChangeMenu
//
//            // Change payment mode menu
//            paymentModeChangeMenu
//
//            // Bank statement menu
//            bankStatementMenu
//
//            // Delete button
//            Button(role: .destructive, action: {
//                deleteSelectedTransactions()
//            }) {
//                Label("Remove", systemImage: "trash")
//            }
//            .disabled(selectedTransactions.isEmpty)
//        }
//    }
//
//    private var statusChangeMenu: some View {
//        let names = [
//            String(localized: "Planned"),
//            String(localized: "In progress"),
//            String(localized: "Executed")
//        ]
//
//        return Menu {
//            Button(names[0]) { updateStatusForSelection(newStatus: names[0]) }
//            Button(names[1]) { updateStatusForSelection(newStatus: names[1]) }
//            Button(names[2]) { updateStatusForSelection(newStatus: names[2]) }
//        } label: {
//            Label("Change status", systemImage: "square.and.pencil")
//        }
//        .disabled(selectedTransactions.isEmpty)
//    }
//
//    private var paymentModeChangeMenu: some View {
//        let paymentModes = PaymentModeManager.shared.getAllNames()
//
//        return Menu {
//            ForEach(paymentModes, id: \.self) { mode in
//                Button(mode) {
//                    updatePaymentModeForSelection(newMode: mode)
//                }
//            }
//        } label: {
//            Label("Change Payment Mode", systemImage: "square.and.pencil")
//        }
//        .disabled(selectedTransactions.isEmpty)
//    }
//
//    private var bankStatementMenu: some View {
//        Menu {
//            Button("New statement…") {
//                showPopover = true
//            }
//        } label: {
//            Label("Bank statement", systemImage: "square.and.pencil")
//        }
//    }
//
//    private var bankStatementPopover: some View {
//        VStack(spacing: 12) {
//            Text("Create a statement")
//                .font(.headline)
//
//            TextField("Statement number", text: $inputText)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding(.horizontal)
//
//            HStack {
//                Button("Cancel") {
//                    showPopover = false
//                }
//                Button("OK") {
//                    AppLogger.transactions.info("Bank statement entered: \(inputText)")
//                    updateBankStatementForSelection(newStatement: inputText)
//                    showPopover = false
//                }
//                .keyboardShortcut(.defaultAction)
//            }
//            .padding(.top, 8)
//        }
//        .padding()
//        .frame(width: 250)
//    }
//
//    private var transactionDetailPopover: some View {
//        Group {
//            if let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.id == transaction.id }) {
//                TransactionDetailView(currentSectionIndex: index, selectedTransaction: $selectedTransactions)
//                    .frame(minWidth: 400, minHeight: 300)
//            } else {
//                Text("Error: Transaction not found in the list.")
//                    .foregroundColor(.red)
//                    .padding()
//            }
//        }
//    }
//
//    // MARK: - Private Methods
//
//    private func transactionByID(_ uuid: UUID) -> EntityTransaction? {
//        return ListTransactionsManager.shared.listTransactions.first { $0.uuid == uuid }
//    }
//
//    private func toggleSelection() {
//        let isCommand = NSEvent.modifierFlags.contains(.command)
//        let isShift = NSEvent.modifierFlags.contains(.shift)
//
//        if isShift, let lastID = transactionManager.lastSelectedTransactionID,
//           let lastIndex = visibleTransactions.firstIndex(where: { $0.uuid == lastID }),
//           let currentIndex = visibleTransactions.firstIndex(where: { $0.id == transaction.id }) {
//
//            let range = lastIndex <= currentIndex
//                ? lastIndex...currentIndex
//                : currentIndex...lastIndex
//
//            let idsInRange = visibleTransactions[range].map { $0.uuid }
//
//            selectedTransactions.removeAll()
//            selectedTransactions.formUnion(idsInRange)
//
//        } else if isCommand {
//            if selectedTransactions.contains(transaction.uuid) {
//                selectedTransactions.remove(transaction.uuid)
//            } else {
//                selectedTransactions.insert(transaction.uuid)
//            }
//            transactionManager.lastSelectedTransactionID = transaction.uuid
//        } else {
//            selectedTransactions.removeAll()
//            selectedTransactions.insert(transaction.uuid)
//            transactionManager.lastSelectedTransactionID = transaction.uuid
//        }
//
//        if let firstSelectedId = selectedTransactions.first {
//            transactionManager.selectedTransaction = ListTransactionsManager.shared.listTransactions.first { $0.uuid == firstSelectedId }
//        }
//        transactionManager.selectedTransactions = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//        transactionManager.isCreationMode = false
//    }
//
//    private func deleteSelectedTransactions() {
//        withAnimation {
//            let selectedIDs = Array(selectedTransactions)
//            let orderedSelectedIndices: [Int] = visibleTransactions.enumerated()
//                .filter { selectedIDs.contains($0.element.uuid) }
//                .map { $0.offset }
//                .sorted()
//
//            let targetIndexAfter: Int? = orderedSelectedIndices.last.map { $0 + 1 }
//            let targetIndexBefore: Int? = orderedSelectedIndices.first.map { $0 - 1 }
//
//            let transactionsToDelete = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//
//            AppLogger.transactions.info("Deleting \(transactionsToDelete.count) transaction(s)")
//
//            for transaction in transactionsToDelete where !transaction.isDeleted {
//                ListTransactionsManager.shared.delete(entity: transaction)
//            }
//
//            _ = ListTransactionsManager.shared.getAllData(ascending: false)
//
//            let newVisible = visibleTransactions
//
//            var newSelectedID: UUID? = nil
//            if let idx = targetIndexAfter, idx >= 0, idx < newVisible.count {
//                newSelectedID = newVisible[idx].uuid
//            } else if let idx = targetIndexBefore, idx >= 0, idx < newVisible.count {
//                newSelectedID = newVisible[idx].uuid
//            }
//
//            selectedTransactions.removeAll()
//            if let uuid = newSelectedID {
//                selectedTransactions.insert(uuid)
//                transactionManager.selectedTransaction = ListTransactionsManager.shared.listTransactions.first { $0.uuid == uuid }
//                transactionManager.selectedTransactions = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//            } else {
//                transactionManager.selectedTransaction = nil
//                transactionManager.selectedTransactions = []
//            }
//            transactionManager.isCreationMode = false
//        }
//    }
//
//    private func updateBankStatementForSelection(newStatement: String) {
//        withAnimation {
//            guard let undo = ListTransactionsManager.shared.modelContext?.undoManager else {
//                let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//                for transaction in selected {
//                    transaction.bankStatement = Double(newStatement) ?? 0.0
//                }
//                return
//            }
//
//            undo.beginUndoGrouping()
//            undo.setActionName("Change bank statement")
//
//            let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//            AppLogger.transactions.info("Updating bank statement for \(selected.count) transaction(s)")
//
//            for transaction in selected {
//                transaction.bankStatement = Double(newStatement) ?? 0.0
//            }
//
//            do {
//                try ListTransactionsManager.shared.modelContext?.save()
//            } catch {
//                AppLogger.data.error("Failed to save bank statement update: \(error.localizedDescription)")
//            }
//            undo.endUndoGrouping()
//        }
//    }
//
//    private func updateStatusForSelection(newStatus: String) {
//        withAnimation {
//            guard let undo = ListTransactionsManager.shared.modelContext?.undoManager else {
//                let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//                if let status = StatusManager.shared.find(name: newStatus) {
//                    for transaction in selected {
//                        transaction.status = status
//                    }
//                }
//                return
//            }
//
//            undo.beginUndoGrouping()
//            undo.setActionName("Change status")
//
//            let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//            AppLogger.transactions.info("Updating status to '\(newStatus)' for \(selected.count) transaction(s)")
//
//            if let status = StatusManager.shared.find(name: newStatus) {
//                for transaction in selected {
//                    transaction.status = status
//                }
//            }
//
//            do {
//                try ListTransactionsManager.shared.modelContext?.save()
//            } catch {
//                AppLogger.data.error("Failed to save status update: \(error.localizedDescription)")
//            }
//            undo.endUndoGrouping()
//        }
//    }
//
//    private func updatePaymentModeForSelection(newMode: String) {
//        withAnimation {
//            guard let undo = ListTransactionsManager.shared.modelContext?.undoManager else {
//                let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//                if let mode = PaymentModeManager.shared.find(name: newMode) {
//                    for transaction in selected {
//                        transaction.paymentMode = mode
//                    }
//                }
//                return
//            }
//
//            undo.beginUndoGrouping()
//            undo.setActionName("Change payment mode")
//
//            let selected = ListTransactionsManager.shared.listTransactions.filter { selectedTransactions.contains($0.uuid) }
//            AppLogger.transactions.info("Updating payment mode to '\(newMode)' for \(selected.count) transaction(s)")
//
//            if let mode = PaymentModeManager.shared.find(name: newMode) {
//                for transaction in selected {
//                    transaction.paymentMode = mode
//                }
//            }
//
//            do {
//                try ListTransactionsManager.shared.modelContext?.save()
//            } catch {
//                AppLogger.data.error("Failed to save payment mode update: \(error.localizedDescription)")
//            }
//            undo.endUndoGrouping()
//        }
//    }
//
//    private func setupKeyboardShortcuts() {
//        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
//            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
//                // Select all
//                for transaction in ListTransactionsManager.shared.listTransactions {
//                    selectedTransactions.insert(transaction.uuid)
//                }
//                transactionManager.selectedTransactions = ListTransactionsManager.shared.listTransactions
//                AppLogger.ui.debug("Selected all transactions")
//                return nil
//            }
//
//            if event.keyCode == 53 { // Escape key
//                // Deselect all
//                selectedTransactions.removeAll()
//                transactionManager.selectedTransaction = nil
//                transactionManager.selectedTransactions = []
//                AppLogger.ui.debug("Deselected all transactions")
//                return nil
//            }
//
//            // Undo: Cmd+Z
//            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
//                ListTransactionsManager.shared.undo()
//                AppLogger.ui.debug("Undo action triggered")
//                return nil
//            }
//
//            // Redo: Shift+Cmd+Z
//            if event.modifierFlags.contains([.command, .shift]), event.charactersIgnoringModifiers == "Z" {
//                ListTransactionsManager.shared.redo()
//                AppLogger.ui.debug("Redo action triggered")
//                return nil
//            }
//
//            return event
//        }
//    }
//}
