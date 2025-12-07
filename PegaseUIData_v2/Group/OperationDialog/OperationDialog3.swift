//  OperationDialog3.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 22/02/2025.
//

//✅ Résultat
//    •    🔶 Mode Création → titre orange
//    •    🔵 Édition d’une transaction → bleu
//    •    🟣 Édition multiple → violet

import SwiftUI
import AppKit
import SwiftData


// MARK: - TransactionFormViewModel
struct TransactionFormViewModel: View {
    
    @Environment(\.modelContext) private var modelContext: ModelContext
    @EnvironmentObject var transactionManager: TransactionSelectionManager
    
    @Binding var linkedAccount: [EntityAccount]
    
    @Binding var transactionDate : Date
    @Binding var pointingDate    : Date
    
    @Binding var modes: [EntityPaymentMode]
    @Binding var status: [EntityStatus]
    @Binding var bankStatement: Double
    @Binding var checkNumber: Int
    @Binding var amount: String
    
    @State private var entityPreference : EntityPreference?
    
    @Binding var selectedBankStatement: String
    @Binding var selectedStatus: EntityStatus?
    @Binding var selectedMode: EntityPaymentMode?
    @Binding var selectedAccount : EntityAccount?
//    @State private var selectedAccount: EntityAccount? = nil

    // 🔁 Valeurs de remplacement pour édition multiple (batch)
    var overrideTransactionDate: Date? = nil
    var overridePointingDate: Date? = nil
    var overrideStatus: EntityStatus? = nil
    var overrideMode: EntityPaymentMode? = nil
    var overrideBankStatement: String? = nil
    
    @State private var selectedOperations: Set<EntityTransaction> = []
    
    // Récupère le compte courant de manière sécurisée.
    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }
    
    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }
    var isEditing: Bool {
        selectedOperations.count > 0
    }
    
    private var identitySection: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
                FormField(label: "Linked Account") {
                    
                    Picker("", selection: $selectedAccount) {
                        // Option "aucun compte sélectionné"
                        Text(String(localized: "(no account)"))
                            .tag(nil as EntityAccount?)  // 👈 corrige l'erreur
                        
                        // Autres comptes
                        ForEach(linkedAccount, id: \.uuid) { account in
                            let isCurrent = compteCurrent == account
                            Text(isCurrent ? String(localized: "(no transfer)") :
                                    (account.initAccount?.codeAccount ?? ""))
                            .tag(account as EntityAccount?) // 👈 obligatoire ici aussi
                        }
                    }
                }
            }
            GridRow {
                FormField(label: String(localized:"Account")) {
                    Text(selectedAccount?.name ?? "")
                }
            }
            GridRow {
                FormField(label: String(localized:"Name")) {
                    Text(selectedAccount?.identity?.name ?? "")
                }
            }
            GridRow {
                FormField(label: String(localized:"Surname")){
                    Text(selectedAccount?.identity?.surName ?? "")
                }
            }
        }
    }
    private var detailSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
                FormField(label: String(localized:"Transaction Date")) {
                    DatePicker("", selection: $transactionDate, displayedComponents: .date)
                }
                .disabled(transactionManager.selectedTransactions.count > 1)
            }
            GridRow {
                FormField(label: String(localized:"Payment method")) {
                    Picker("", selection: $selectedMode) {
                        ForEach(modes, id: \.uuid) { mode in
                            Text(mode.name).tag(mode)
                        }
                    }
                }
            }
            GridRow {
                FormField(label: String(localized:"Check")) {
                    TextField("", value: $checkNumber, formatter: integerFormatter)
                }
            }
            GridRow {
                FormField(label: String(localized:"Date of pointing")) {
                    DatePicker("", selection: $pointingDate, displayedComponents: .date)
                }
                .disabled(transactionManager.selectedTransactions.count > 1)
            }
            GridRow {
                FormField(label: String(localized:"Status")) {
                    Picker("", selection: $selectedStatus) {
                        ForEach(status, id: \.self) { index in
                            Text(index.name).tag(index)
                        }
                    }
                    HelpButton {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• **Planned**: estimated check-in date, amount subject to changee")
                            Text("• **Committed**: estimated check-in date, modifiable amount")
                            Text("• **Pointed**: exact date of the statement, amount not modifiable")
                            Divider()
                            Text("💡 **Keyboard shortcuts**: P = Planned, E = Committed, T = Pointed")
                        }
                        .font(.system(size: 12))
                        .padding(8)
                    }

                }
            }
            GridRow {
                FormField(label: String(localized:"Bank Statement")) {
                    TextField("", value: $bankStatement, formatter: integerFormatter)
                }
            }
            GridRow {
                FormField(label: String(localized:"Amount")) {
                    TextField("", value: $amount, formatter: NumberFormatter())
                }
            }
        }
    }
    
    private func handleKey(_ event: NSEvent) {
        guard let character = event.charactersIgnoringModifiers?.uppercased() else { return }

        switch character {
        case "P":
            if let prévu = status.first(where: { $0.name.hasPrefix("Prévu") }) {
                selectedStatus = prévu
            }
        case "E":
            if let engagé = status.first(where: { $0.name.hasPrefix("Engagé") }) {
                selectedStatus = engagé
            }
        case "T":
            if let pointé = status.first(where: { $0.name.hasPrefix("Pointé") }) {
                selectedStatus = pointé
            }
        default:
            break
        }
    }
    
    var body: some View {

        Form {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        Text("Informations")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GridRow {
                        identitySection
                    }
                }
            }

            HStack {
                Spacer()
                Text("⋯")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Section {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        Text("Details of the operation")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GridRow {
                        detailSection
                    }
                }
            }
            .onAppear {
                            
                selectedAccount = linkedAccount.first(where: { $0.uuid == selectedAccount?.uuid })
                if selectedAccount == nil {
                    selectedAccount = nil // Pour que le Picker reconnaisse l'état initial
                }

                let account = CurrentAccountManager.shared.getAccount()
                guard let account = account else { return }
                if let oldSelected = selectedAccount {
                    selectedAccount = linkedAccount.first(where: { $0.uuid == oldSelected.uuid })
                }

                entityPreference = PreferenceManager.shared.getAllData(for: account)
                
                //            if selectedAccount == nil, let firstAccount = linkedAccount.first {
                //                selectedAccount = firstAccount // Initialisation avec un compte valide
                //            }
                
                if selectedAccount == nil {
                    selectedAccount = linkedAccount.first ?? compteCurrent
                }
                
                DispatchQueue.main.async {
                    selectedMode = modes.first
                    selectedMode = entityPreference?.paymentMode
                    selectedStatus = entityPreference?.status
                    selectedBankStatement = ""
                }
            }
            .onChange(of: selectedAccount) { old, newValue in
//                printTag("Selected Account: \(newValue?.name ?? "nil")")
            }
            .onChange(of: selectedMode) { old, newValue in
                printTag("Selected Mode: \(newValue?.name ?? "nil")")
            }
            .onChange(of: selectedStatus) { old, newValue in
                printTag("Selected Status: \(newValue?.name ?? "nil")")
            }
            .onChange(of: compteCurrent) {old, new in
                selectedAccount = compteCurrent
            }
            
            .onChange(of: linkedAccount) { old, newValue in
                if let oldSelected = selectedAccount {
                    selectedAccount = newValue.first(where: { $0.uuid == oldSelected.uuid })
                }                
                return
            }
            .onChange(of: selectedAccount) { oldValue, newValue in
            }
        }
    }
}

struct FormField<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .bold()
                .frame(width: 120, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

