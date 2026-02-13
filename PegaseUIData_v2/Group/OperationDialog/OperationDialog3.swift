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
                FormField(label: String(localized:"Account", table:"Account'")) {
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
                    PaymentModePickerView(
                        paymentModes: modes,
                        selectedMode: $selectedMode
                    )
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
                    HStack {
                        StatusPickerView(
                            statuses: status,
                            selectedStatus: $selectedStatus
                        )
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
                        Spacer()
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
    
    private var informationHeader: some View {
        Text("Informations")
            .font(.headline)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var detailsHeader: some View {
        Text("Details of the operation")
            .font(.headline)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private var separatorDots: some View {
        HStack {
            Spacer()
            Text("⋯")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    var body: some View {
        formContent
            .modifier(TransactionFormModifiers(
                viewModel: self,
                selectedAccount: $selectedAccount,
                selectedMode: $selectedMode,
                selectedStatus: $selectedStatus
            ))
    }
    
    private var formContent: some View {
        Form {
            informationSection
            separatorDots
            detailsSection
        }
    }
    
    private var informationSection: some View {
        Section {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow { informationHeader }
                GridRow { identitySection }
            }
        }
    }
    
    private var detailsSection: some View {
        Section {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow { detailsHeader }
                GridRow { detailSection }
            }
        }
    }
    
    // Add a new private helper just below body to reduce closure complexity
    func performInitialSelection() {
        // Keep the same behavior while simplifying expressions
        selectedAccount = linkedAccount.first(where: { $0.uuid == selectedAccount?.uuid })
        if selectedAccount == nil { selectedAccount = nil }

        if let oldSelected = selectedAccount {
            selectedAccount = linkedAccount.first(where: { $0.uuid == oldSelected.uuid })
        }

        entityPreference = PreferenceManager.shared.getAllData()

        if selectedAccount == nil {
            selectedAccount = linkedAccount.first ?? compteCurrent
        }

        DispatchQueue.main.async {
            selectedMode = entityPreference?.paymentMode
            selectedStatus = entityPreference?.status
            selectedBankStatement = ""
        }
    }
}

// MARK: - View Modifier to break up complex type-checking
struct TransactionFormModifiers: ViewModifier {
    let viewModel: TransactionFormViewModel
    @Binding var selectedAccount: EntityAccount?
    @Binding var selectedMode: EntityPaymentMode?
    @Binding var selectedStatus: EntityStatus?
    
    func body(content: Content) -> some View {
        content
            .modifier(AppearanceModifier(viewModel: viewModel))
            .modifier(SelectionChangeModifier(
                selectedAccount: $selectedAccount,
                selectedMode: $selectedMode,
                selectedStatus: $selectedStatus,
                viewModel: viewModel
            ))
    }
}

// Break up the modifiers into separate structs
private struct AppearanceModifier: ViewModifier {
    let viewModel: TransactionFormViewModel
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.performInitialSelection()
            }
    }
}

private struct SelectionChangeModifier: ViewModifier {
    @Binding var selectedAccount: EntityAccount?
    @Binding var selectedMode: EntityPaymentMode?
    @Binding var selectedStatus: EntityStatus?
    let viewModel: TransactionFormViewModel
    
    func body(content: Content) -> some View {
        content
            .onChange(of: selectedAccount) { old, newValue in }
            .onChange(of: selectedMode) { old, newValue in
                printTag("Selected Mode: " + (newValue?.name ?? "nil"))
            }
            .modifier(StatusAndAccountChangeModifier(
                selectedAccount: $selectedAccount,
                selectedStatus: $selectedStatus,
                viewModel: viewModel
            ))
    }
}

private struct StatusAndAccountChangeModifier: ViewModifier {
    @Binding var selectedAccount: EntityAccount?
    @Binding var selectedStatus: EntityStatus?
    let viewModel: TransactionFormViewModel
    
    func body(content: Content) -> some View {
        content
            .onChange(of: selectedStatus) { old, newValue in
                printTag("Selected Status: " + (newValue?.name ?? "nil"))
            }
            .onChange(of: viewModel.compteCurrent) { old, new in
                selectedAccount = viewModel.compteCurrent
            }
            .onChange(of: viewModel.linkedAccount) { old, newValue in
                if let oldSelected = selectedAccount {
                    selectedAccount = newValue.first(where: { $0.uuid == oldSelected.uuid })
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

