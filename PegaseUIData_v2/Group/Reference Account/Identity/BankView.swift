//
//  BankView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 03/11/2024.
//

import SwiftUI
import SwiftData
import Combine

struct BankView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var bankManager: BankManager

    var body: some View {
        VStack(spacing: 30) {
            if let account = CurrentAccountManager.shared.getAccount() {
                Text("Account: \(account.name)", tableName: "BankView")
                    .font(.headline)
            }

            if let banqueInfo = bankManager.currentBanqueInfo {
                SectionView(sectionType: .bank, title: String(localized: "Bank", table: "BankView"), banqueInfo: banqueInfo)
                SectionView(sectionType: .contact, title: String(localized: "Contact", table: "BankView"), banqueInfo: banqueInfo)
                Spacer()
            } else {
                Text("No bank information available", tableName: "BankView")
            }
        }
        .padding()
        .onAppear {

            // Creer un nouvel enregistrement si la base de donnees est vide
            if bankManager.currentBanqueInfo == nil {

                let banqueInfo = BankManager.shared.getAllData()

                if banqueInfo == nil {
                    let newbanqueInfo = EntityBanqueInfo()
                    bankManager.currentBanqueInfo = newbanqueInfo
                    modelContext.insert(newbanqueInfo)
                }
            }
        }
        .onDisappear {
            saveChanges()
            bankManager.saveChanges()
            bankManager.currentBanqueInfo = nil
        }

        .onChange(of: currentAccountManager.currentAccountID) { old, newValue in

            if !newValue.isEmpty {
                let account = currentAccountManager.getAccount()
                bankManager.currentBanqueInfo = nil
                loadOrCreate(for: account)
            }
        }
        .onChange(of: bankManager.currentBanqueInfo) { old , _ in
            do {
                try modelContext.save()
            } catch {
                printTag("Erreur lors de la sauvegarde : \(error)")
            }
        }
    }

    private func loadOrCreate(for account: EntityAccount?) {
        guard let account else { return }

        bankManager.currentBanqueInfo = BankManager.shared.getAllData() ?? {
            let entity = EntityBanqueInfo()
            entity.account = account
            modelContext.insert(entity)
            return entity
        }()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

struct SectionView: View {

    enum SectionType {
        case bank
        case contact
    }

    let sectionType: SectionType
    let title: String
    @Bindable var banqueInfo: EntityBanqueInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)

            switch sectionType {
            case .bank:
                FieldView(label: String(localized: "Bank", table: "BankView"), text: $banqueInfo.nomBanque)
                FieldView(label: String(localized: "Address", table: "BankView"), text: $banqueInfo.adresse)
                FieldView(label: String(localized: "Complement", table: "BankView"), text: $banqueInfo.complement)
                FieldView(label: String(localized: "CP", table: "BankView"), text: $banqueInfo.cp)
                FieldView(label: String(localized: "Town", table: "BankView"), text: $banqueInfo.town)
            case .contact:
                FieldView(label: String(localized: "Name", table: "BankView"), text: $banqueInfo.name)
                FieldView(label: String(localized: "Function", table: "BankView"), text: $banqueInfo.fonction)
                FieldView(label: String(localized: "Phone", table: "BankView"), text: $banqueInfo.phone)
            }
        }
        .padding()
        .cornerRadius(8)
    }
}

struct FieldView: View {

    @Environment(\.modelContext) var modelContext

    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            TextField("", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300, alignment: .leading)
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
