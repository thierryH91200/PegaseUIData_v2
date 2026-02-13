//
//  EntityBankStatements.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 29/01/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit
import Combine
import OSLog


struct BankStatementView: View {
    
    @Binding var dashboard: DashboardState
    @State private var transactions: [EntityTransaction] = []

    @Binding var isVisible: Bool
    @StateObject var dataManager = BankStatementManager()
    
    var body: some View {
        BankStatementListView(
            transactions: transactions,
            dashboard: $dashboard)
            .environmentObject(dataManager)
            .padding()
            .task {
                await loadTransactions()
                await performFalseTask()
            }
    }
    
    private func performFalseTask() async {
        // Exécuter une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        isVisible = true
    }
    
    @MainActor
    private func loadTransactions() async {
        transactions = ListTransactionsManager.shared.getAllData()
    }
}

struct BankStatementListView: View {
    
    let transactions: [EntityTransaction]
    @Binding var dashboard: DashboardState
    
    /// Transactions filtrées par le numéro du relevé sélectionné
    var filteredTransactions: [EntityTransaction] {
        guard let statement = selectedStatement else { return [] }
        let statementNum = Double(statement.num)
        return ListTransactionsManager.shared.loadAllTransactions(ascending: true)
            .filter { $0.bankStatement == statementNum }
    }

    @Environment(\.undoManager) private var undoManager
    
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var dataManager: BankStatementManager
    
    @State private var isSheetPresented = false
    @State private var isModeCreate = false

    @State private var selectedItem: EntityBankStatement.ID?
    @State private var lastDeletedID: UUID?
    
    var selectedStatement: EntityBankStatement? {
        guard let id = selectedItem else { return nil }
        return dataManager.statements.first(where: { $0.id == id })
    }
    
    var canUndo : Bool {
        undoManager?.canUndo ?? false
    }
    var canRedo : Bool {
        undoManager?.canRedo ?? false
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack {
            if let account = CurrentAccountManager.shared.getAccount() {
                Text("Account: \(account.name)")
                    .font(.headline)
            }
            
            BankStatementTable(statements: dataManager.statements, selection: $selectedItem)
                .frame(height: 300)
                .background(Color(nsColor: .windowBackgroundColor))
                .tableStyle(.bordered)

                .onAppear {
                    setupDataManager()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in
                    refreshData()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in
                    printTag("Redo effectué, on recharge les données")
                    refreshData()
                }

                .onChange(of: currentAccountManager.getAccount()) { old, newAccount in
                    
                    if newAccount != nil {
                        dataManager.statements.removeAll()
                        selectedItem = nil
                        refreshData()
                    }
                }
            
            HStack {
                // Bouton pour ajouter un relevé
                Button(action: {
                    isSheetPresented = true
                    isModeCreate = true

                }) {
                    Label("Add", systemImage: "plus")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Bouton pour modifier un relevé
                Button(action: {
                    isSheetPresented = true
                    isModeCreate = false

                }) {
                    Label("Edit", systemImage: "pencil")
                        .actionButtonStyle(
                            isEnabled: selectedStatement != nil,
                            activeColor: .green)
                }
                .disabled(selectedStatement == nil)
                
                // Bouton pour supprimer un enregistrement
                Button(action: {
                    delete()
                }) {
                    Label("Delete", systemImage: "trash")
                        .actionButtonStyle(
                            isEnabled: selectedStatement != nil,
                            activeColor: .red)
                }
                .disabled(selectedStatement == nil) // Désactive le bouton si aucun élément n'est sélectionné
                
                Button(action: {
                    if let manager = undoManager, manager.canUndo {
                        selectedItem = nil
                        lastDeletedID = nil
                        manager.undo()
                        
                        DispatchQueue.main.async {
                            setupDataManager()
                        }
                    }
                }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .actionButtonStyle(
                            isEnabled: canUndo == true,
                            activeColor: .green)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let manager = undoManager, manager.canRedo {
                        manager.redo()
                        setupDataManager()
                    }
                }) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                        .actionButtonStyle(
                            isEnabled: canRedo == true,
                            activeColor: .orange)
                }
                .buttonStyle(.plain)

            }
                // Table des transactions filtrées par le relevé sélectionné
                if selectedStatement != nil {
                    Divider()
                    Text("Transactions for statement N° \(selectedStatement!.num)")
                        .font(.headline)
                        .padding(.top, 4)

                    if filteredTransactions.isEmpty {
                        Text("No transactions for this statement")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        SummaryView(dashboard: $dashboard)
                        BankStatementTransactionsTable(transactions: filteredTransactions)
                            .frame(maxHeight: .infinity)
                            .tableStyle(.bordered)
                    }
                }
                Spacer()

            }
            .navigationSplitViewColumnWidth(min: 700, ideal: 900, max: 1200)
        } detail: {
            if let statement = selectedStatement {
                StatementDetailView(statement: statement)
            } else {
                Text("Select a statement")
            }
        }
        .sheet(isPresented: $isSheetPresented , onDismiss: {setupDataManager()}) {
            StatementFormView(isPresented: $isSheetPresented,
                              isModeCreate: $isModeCreate,
                              statement: isModeCreate ? nil : selectedStatement)
        }
    }
    
    private func setupDataManager() {
        if currentAccountManager.getAccount() != nil {
            dataManager.statements = dataManager.getAllData() ?? []
        }
    }

    private func delete() {
        
        if let id = selectedItem,
           let item = dataManager.statements.first(where: { $0.id == id }) {
            
            lastDeletedID = item.uuid
            
            dataManager.delete(entity: item, undoManager: undoManager)
            DispatchQueue.main.async {
                selectedItem = nil
                lastDeletedID = nil
                
                refreshData()
            }
            
        }
    }
    
    private func refreshData() {
        dataManager.statements = dataManager.getAllData() ?? []
    }
}

struct BankStatementTable: View {
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var statements: [EntityBankStatement]
    @Binding var selection: EntityBankStatement.ID?
    
    var body: some View {
        Table(statements, selection: $selection) {
            
            Group {
                TableColumn("N°") {  (statement: EntityBankStatement) in Text("\(statement.num)") }
                TableColumn("Start Date") { statement in Text(dateFormatter.string(from: statement.startDate)) }
                TableColumn("Initial balance") { statement in Text(statement.formattedStartSolde) }
                TableColumn("Inter Date") { statement in Text(dateFormatter.string(from: statement.interDate)) }
                TableColumn("Inter balance") { statement in Text(statement.formattedInterSolde) }
            }
            
            Group {
                TableColumn("End Date") {  (statement: EntityBankStatement) in Text(dateFormatter.string(from: statement.endDate)) }
                TableColumn("End balance") { statement in
                    Text(statement.formattedEndSolde) }
                TableColumn("Date CB") { statement in Text(dateFormatter.string(from: statement.cbDate)) }
                TableColumn("CB Balance") { statement in
                    Text(statement.formattedCBSolde) }
                TableColumn("Surname") { statement in Text(statement.accountSurname) }
                TableColumn("Name") { statement in Text(statement.accountName) }
            }
        }
    }
}

class StatementFormViewModel: ObservableObject {
    @Published var num: String = ""
    @Published var libelle: String = ""
    @Published var startDate = Date()
    @Published var startSolde: String = ""
    @Published var interDate = Date()
    @Published var interSolde: String = ""
    @Published var endDate = Date()
    @Published var endSolde: String = ""
    @Published var cbDate = Date()
    @Published var cbSolde: String = ""
    @Published var pdfData: Data?
    
    func load(from statement: EntityBankStatement) {
        num = String(statement.num)
        startDate = statement.startDate
        startSolde = formatPrice( statement.startSolde)
        interDate = statement.interDate
        interSolde = formatPrice( statement.interSolde)
        endDate = statement.endDate
        endSolde = formatPrice( statement.endSolde)
        cbDate = statement.cbDate
        cbSolde = formatPrice(statement.cbSolde)
        pdfData = statement.pdfDoc
    }
    
    func apply(to statement: EntityBankStatement) {
        statement.num = Int(num) ?? 0
        statement.startDate = startDate
        statement.startSolde = cleanDouble(from: startSolde)
        statement.interDate = interDate
        statement.interSolde = cleanDouble(from: interSolde)
        statement.endDate = endDate
        statement.endSolde = cleanDouble(from: endSolde)
        statement.cbDate = cbDate
        statement.cbSolde = cleanDouble(from: cbSolde)
        statement.pdfDoc = pdfData
    }
    
    func reset() {
        num = ""
        startDate = Date()
        startSolde = ""
        interDate = Date()
        interSolde = ""
        endDate = Date()
        endSolde = ""
        cbDate = Date()
        cbSolde = ""
        pdfData = nil
    }
}

struct StatementFormView: View {

    @Environment(\.dismiss) private var dismiss
        
    @Binding var isPresented: Bool
    @Binding var isModeCreate: Bool
    
    @State var statement: EntityBankStatement?

    @StateObject private var viewModel = StatementFormViewModel()
    
    @State private var dragOver = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("General information") {
                    TextField("Number", text: $viewModel.num)
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                    TextField("Initial balance", text: $viewModel.startSolde)                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("Inter Date", selection: $viewModel.interDate, displayedComponents: .date)
                    TextField("Inter balance", text: $viewModel.interSolde)
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                    TextField("Final balance", text: $viewModel.endSolde)
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("CB Date", selection: $viewModel.cbDate, displayedComponents: .date)
                    TextField("CB Balance", text: $viewModel.cbSolde)
                        .textFieldStyle(.roundedBorder)
                }
                
                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section("Document PDF") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(dragOver ? Color.red.opacity(0.3) : Color.gray.opacity(0.2))
                            .frame(height: 100)
                        
                        Text(viewModel.pdfData != nil ? "Selected PDF" : "Drop your PDF here")
                    }
                    .onDrop(of: [UTType.pdf], delegate: PDFDropDelegate(pdfData: $viewModel.pdfData, isDragOver: $dragOver))
                }
            }
            .padding()
            .navigationTitle(statement == nil ? "New statement" : "Edit statement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if validate() {
                            save()
                            dismiss()
                        }
                    }
                }
            }
        }
        .onChange(of: statement) { _, newValue in
            if let statement = newValue {
                viewModel.load(from: statement)
            }
        }
        .onAppear {
            if let statement = statement {
                viewModel.load(from: statement)
            }
        }
    }
    
    private func validate() -> Bool {
        // Vérifier que le numéro est un entier valide
        if viewModel.num.isEmpty || Int(viewModel.num) == nil {
            validationError = String(localized:"The number must be a valid integer.")
            return false
        }

        // Vérifier que les soldes sont des nombres valides
        let soldes = [
            ("Initial balance", viewModel.startSolde),
            ("Inter balance", viewModel.interSolde),
            ("Final balance", viewModel.endSolde),
            ("CB Balance", viewModel.cbSolde)
        ]
        for (label, value) in soldes {
            if !value.isEmpty && cleanDouble(from: value) == 0 && value != "0" {
                validationError = String(localized: "\(label) : Invalid numeric value.")
                return false
            }
        }

        // Vérifier la cohérence des dates
        if viewModel.startDate > viewModel.endDate {
            validationError = String(localized:"The start date must be earlier than the end date.")
            return false
        }

        validationError = nil
        return true
    }

    private func save() {
        // Determine target entity: reuse existing or create a new one
        let entityBankStatement: EntityBankStatement = {
            if let existing = statement {
                return existing
            } else {
                return BankStatementManager.shared.create(num: 0, startDate: Date(), startSolde: 0.0)!
            }
        }()

        // Apply values from the form view model
        viewModel.apply(to: entityBankStatement)

        // Attach to current account if available
        if let account = CurrentAccountManager.shared.getAccount() {
            entityBankStatement.account = account
        }

        // Persist using BankStatementManager
        do {
            try BankStatementManager.shared.save()
        } catch {
            AppLogger.data.error("BankStatement save failed: \(error.localizedDescription)")
            ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
        }
    }
}

struct PDFDropDelegate: DropDelegate {
    @Binding var pdfData: Data?
    @Binding var isDragOver: Bool
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.pdf])
    }
    
    func dropEntered(info: DropInfo) {
        isDragOver = true
    }
    
    func dropExited(info: DropInfo) {
        isDragOver = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDragOver = false
        
        guard let provider = info.itemProviders(for: [UTType.pdf]).first else { return false }
        
        let _ = provider.loadItem(forTypeIdentifier: UTType.pdf.identifier) { (urlData, error) in
            if let url = urlData as? URL {
                do {
                    let data = try Data(contentsOf: url)
                    DispatchQueue.main.async {
                        self.pdfData = data
                    }
                } catch {
                    printTag("Erreur lors du chargement du PDF: \(error)", flag: true)
                }
            } else if let error = error {
                printTag("Erreur fournisseur d'élément: \(error)", flag: true)
            }
        }
        return true
    }
}

struct StatementDetailView: View {
    let statement: EntityBankStatement
    
    var body: some View {
        VStack {
            if let pdfData = statement.pdfDoc {
                PDFKitView(data: pdfData)
            } else {
                Text("No PDF available")
            }
        }
        .padding()
    }
}

// PDFKit wrapper for SwiftUI

struct PDFKitView: NSViewRepresentable {
    let data: Data
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

/// Table simplifiée des transactions liées à un relevé bancaire
struct BankStatementTransactionsTable: View {

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var transactions: [EntityTransaction]

    var body: some View {
        Table(transactions) {
            TableColumn("Date Pointage") { transaction in
                Text(dateFormatter.string(from: transaction.datePointage))
            }
            TableColumn("Date Operation") { transaction in
                Text(dateFormatter.string(from: transaction.dateOperation))
            }
            TableColumn("Comment") { transaction in
                Text(transaction.sousOperations.first?.libelle ?? "—")
            }
            TableColumn("Category") { transaction in
                Text(transaction.sousOperations.first?.category?.name ?? "—")
            }
            TableColumn("Payment") { transaction in
                Text(transaction.paymentModeString)
            }
            TableColumn("Status") { transaction in
                Text(transaction.statusString)
            }
            TableColumn("Amount") { transaction in
                Text(transaction.amountString)
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
            }
        }
    }
}

