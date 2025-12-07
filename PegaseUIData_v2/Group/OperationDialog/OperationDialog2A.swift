//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry Hentic on 03/06/2025.
//

//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry Hentic on 03/06/2025.
//

import SwiftUI
import AppKit
import SwiftData
import Observation

// MARK: 3. Composant d'en-tête
struct FormTitleView: View {
    let formMode: FormMode

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(8)
        .background(backgroundColor)
        .frame(maxWidth: .infinity)
        .padding()
        .cornerRadius(8)
    }

    private var title: String {
        switch formMode {
        case .create:
            return String(localized:"Mode Creation")
        case .editSingle:
            return String(localized:"Mode Edit")
        case .editMultiple(let ops):
            return String(localized:"Edition multiple \(ops.count) transactions")
        }
    }

    private var backgroundColor: Color {
        switch formMode {
        case .create:
            return .orange
        case .editSingle:
            return .blue
        case .editMultiple:
            return .purple
        }
    }
}

// ⚙️ Extension utilitaire pour extraire un élément unique
extension Collection {
    var uniqueElement: Element? {
        count == 1 ? first : nil
    }
}

// 🧩 Vue principale unifiée pour édition normale ou groupée
struct TransactionFormUnifiedView: View {
    @EnvironmentObject var transactionManager: TransactionSelectionManager
    @EnvironmentObject var formState: TransactionFormState

    var body: some View {
        if transactionManager.selectedTransactions.count > 1 {
            let uniqueStatus = transactionManager.selectedTransactions.compactMap { $0.status }.uniqueElement
            let uniqueMode = transactionManager.selectedTransactions.compactMap { $0.paymentMode }.uniqueElement
            let uniqueDate = transactionManager.selectedTransactions.map { $0.dateOperation }.uniqueElement
            let uniquePointingDate = transactionManager.selectedTransactions.map { $0.datePointage }.uniqueElement
            let uniqueBankStatement = transactionManager.selectedTransactions.map { $0.bankStatement }.uniqueElement.map { String($0) }

            TransactionFormView(
                overrideTransactionDate: uniqueDate,
                overridePointingDate: uniquePointingDate,
                overrideStatus: uniqueStatus,
                overrideMode: uniqueMode,
                overrideBankStatement: uniqueBankStatement
            )
        } else {
            TransactionFormView()
        }
    }
}

// 📋 Vue d'entrée pour appeler TransactionFormViewModel avec ou sans override
struct TransactionFormView: View {
    @EnvironmentObject var formState: TransactionFormState
    
    var overrideTransactionDate: Date? = nil
    var overridePointingDate: Date? = nil
    var overrideStatus: EntityStatus? = nil
    var overrideMode: EntityPaymentMode? = nil
    var overrideBankStatement: String? = nil
    
    var body: some View {
        if $formState.accounts.count == 0 {
            EmptyView()
        } else {
            TransactionFormViewModel(
                linkedAccount           : $formState.accounts,
                transactionDate         : $formState.transactionDate,
                pointingDate            : $formState.pointingDate,
                modes                   : $formState.paymentModes,
                status                  : $formState.status,
                bankStatement           : $formState.bankStatement,
                checkNumber             : $formState.checkNumber,
                amount                  : $formState.amount,
                selectedBankStatement   : $formState.selectedBankStatement,
                selectedStatus          : $formState.selectedStatus,
                selectedMode            : $formState.selectedMode,
                selectedAccount         : $formState.selectedAccount,
                overrideTransactionDate : overrideTransactionDate,
                overridePointingDate    : overridePointingDate,
                overrideStatus          : overrideStatus,
                overrideMode            : overrideMode,
                overrideBankStatement   : overrideBankStatement
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Transaction form section"))
        }
    }
}





