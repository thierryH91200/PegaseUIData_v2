//
//  AccountView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 03/11/2024.
//

import SwiftUI
import SwiftData
import Combine

struct InitAccountView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var initAccountManager: InitAccountManager
    @EnvironmentObject var currentAccountManager: CurrentAccountManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Logo et Rapport Initial
            if let initAccount = initAccountManager.currentInitAccount {
                HStack(alignment: .top) {
                    Image(systemName: "building.columns.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading) {
                        Text("Initial report", tableName: "InitAccountView")
                            .font(.headline)

                        HStack(spacing: 40) {
                            ReportView( initAccount: initAccount)
                        }
                    }
                }
            }

            // References Bancaires
            if let initAccount = initAccountManager.currentInitAccount {
                VStack(alignment: .leading) {
                    Text("Bank references", tableName: "InitAccountView")
                        .font(.headline)
                    BankReferenceView(initAccount: initAccount)
                }
                .padding()
                .cornerRadius(8)
            }
            Spacer()
        }
        .padding()
        .frame(width: 800, height: 600)
        .onAppear {

            withAnimation {
                initializeData()
            }
        }
        .onDisappear {
            resetAccount()
        }
        .onChange(of: currentAccountManager.currentAccountID) { old, newValue in

            if !newValue.isEmpty {
                let account = CurrentAccountManager.shared.getAccount()!
                initAccountManager.currentInitAccount = nil
                loadOrCreateIdentity(for: account)
            }
        }
        .onChange(of: initAccountManager.currentInitAccount) { old , _ in
            do {
                try modelContext.save()
            } catch {
                printTag("Erreur lors de la sauvegarde : \(error)")
            }
        }

    }

    private func initializeData() {
        createAccountIfNeeded()
    }

    private func createAccountIfNeeded() {
        if initAccountManager.currentInitAccount == nil {

            let accountInitInfo = InitAccountManager.shared.getAllData()
            initAccountManager.currentInitAccount = accountInitInfo ?? {
                guard let account = CurrentAccountManager.shared.getAccount() else {
                    print("Erreur: aucun compte selectionne pour l'initialisation")
                    return nil
                }
                let newInitAccount = EntityInitAccount(account: account)
                modelContext.insert(newInitAccount)
                return newInitAccount
            }()
        }
    }

    private func resetAccount() {
        saveChanges()
        initAccountManager.currentInitAccount = nil
    }

    private func loadOrCreateIdentity(for account: EntityAccount) {

        if let existingInitAccount = InitAccountManager.shared.getAllData() {
            initAccountManager.currentInitAccount = existingInitAccount
        } else {
            let entity = EntityInitAccount(account: account)
            entity.account = account
            modelContext.insert(entity)
            initAccountManager.currentInitAccount = entity
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

// Vue pour le rapport initial (Planned, Engaged, Executed)
struct ReportView: View {

    @Environment(\.modelContext) var modelContext

    @Bindable var initAccount: EntityInitAccount

    var body: some View {
        VStack(alignment: .leading) {
            Text("Planned", tableName: "InitAccountView")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(String(localized: "Enter planned value", table: "InitAccountView"), text: Binding(
                get: { String(initAccount.prevu) },
                set: { newValue in
                    if let value = Double(newValue) {
                        initAccount.prevu = value
                    }
                }
            ))
            .font(.title3)
            .bold()
            .onSubmit {
                saveChanges()
            }
        }

        VStack(alignment: .leading) {
            Text("In progress", tableName: "InitAccountView")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(String(localized: "Enter Engaged value", table: "InitAccountView"), text: Binding(
                get: { String(initAccount.engage) },
                set: { newValue in
                    if let value = Double(newValue) {
                        initAccount.engage = value
                    }
                }
            ))
            .font(.title3)
            .bold()
            .onSubmit {
                saveChanges()
            }
        }

        VStack(alignment: .leading) {
            Text("Executed", tableName: "InitAccountView")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(String(localized: "Enter Executed value", table: "InitAccountView"), text: Binding(
                get: { String(initAccount.realise) },
                set: { newValue in
                    if let value = Double(newValue) {
                        initAccount.realise = value
                    }
                }
            ))
            .font(.title3)
            .bold()
            .onSubmit {
                saveChanges()
            }
        }
    }
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

// Vue pour les references bancaires
struct BankReferenceView: View {

    @Environment(\.modelContext) var modelContext
    @Bindable var initAccount: EntityInitAccount


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bank", tableName: "InitAccountView")
                    .frame(width: 100, alignment: .leading)
                TextField(String(localized: "Bank", table: "InitAccountView"), text: $initAccount.codeBank)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
            }

            HStack {
                Text("Indicative", tableName: "InitAccountView")
                    .frame(width: 100, alignment: .leading)
                TextField(String(localized: "Indicative", table: "InitAccountView"), text: $initAccount.codeGuichet)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Account", tableName: "InitAccountView")
                    .frame(width: 100, alignment: .leading)
                TextField(String(localized: "Account", table: "InitAccountView"), text: $initAccount.codeAccount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Key", tableName: "InitAccountView")
                    .frame(width: 100, alignment: .leading)
                TextField(String(localized: "Key", table: "InitAccountView"), text: $initAccount.cleRib)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Text("IBAN", tableName: "InitAccountView")
                    .frame(width: 100, alignment: .leading)
                TextField(String(localized: "IBAN", table: "InitAccountView"), text: Binding(
                    get: { formattedIBAN(initAccount.iban) },
                    set: { newValue in
                        initAccount.iban = newValue.replacingOccurrences(of: " ", with: "")
                    }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            }

            HStack {
                Text("BIC", tableName: "InitAccountView")
                    .frame(width: 100, alignment: .leading)
                TextField(String(localized: "BIC", table: "InitAccountView"), text: $initAccount.bic)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
            }
            .onChange(of: initAccount) {old, _ in saveChanges() }

        }
        .padding()
    }

    func formattedIBAN(_ iban: String) -> String {
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "")
        let groups = stride(from: 0, to: cleanedIBAN.count, by: 4).map { index in
            let start = cleanedIBAN.index(cleanedIBAN.startIndex, offsetBy: index)
            let end = cleanedIBAN.index(start, offsetBy: 4, limitedBy: cleanedIBAN.endIndex) ?? cleanedIBAN.endIndex
            return String(cleanedIBAN[start..<end])
        }
        return groups.joined(separator: " ")
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}
