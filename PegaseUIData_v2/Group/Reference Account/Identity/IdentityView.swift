//  IdentyView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 03/11/2024.
//

import SwiftUI
import SwiftData
import Combine


struct IdentityView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var identityManager: IdentityManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Identity", tableName: "IdentityView")
                .font(.title)
                .padding(.bottom, 10)
                .accessibilityLabel("Identity title")

            if let account = currentAccountManager.getAccount() {
                Text("Current Account: \(account.name)", tableName: "IdentityView")
            } else {
                Text("No account selected.", tableName: "IdentityView")
            }

            VStack(alignment: .leading, spacing: 8) {

                if identityManager.currentIdentity != nil {
                    SectionInfoView(identityInfo: identityManager.currentIdentity!)
                }
            }
        }
        .padding()
        .frame(width: 600)
        .cornerRadius(10)
        .onAppear {

            // Creer un nouvel enregistrement si la base de donnees est vide
            if identityManager.currentIdentity == nil {
                let identity = IdentityManager.shared.getAllData()

                if identity == nil {
                    let newIdentityInfo = EntityIdentity()
                    identityManager.currentIdentity = newIdentityInfo
                    modelContext.insert(newIdentityInfo)
                }
            }
        }
        .onDisappear {
            saveChanges()
            identityManager.saveChanges()
            identityManager.currentIdentity = nil
        }
        .onChange(of: currentAccountManager.getAccount()) { old, newAccount in

            if let account = newAccount {
                identityManager.currentIdentity = nil
                loadOrCreate(for: account)
            }
        }

        .onChange(of: identityManager.currentIdentity) { old , _ in
            do {
                try modelContext.save()
            } catch {
                printTag("Erreur lors de la sauvegarde : \(error)")
            }
        }
    }

    private func loadOrCreate(for account: EntityAccount) {

        if let existingIdentity = IdentityManager.shared.getAllData() {
            identityManager.currentIdentity = existingIdentity
        } else {
            let entity = EntityIdentity()
            entity.account = account
            modelContext.insert(entity)
            identityManager.currentIdentity = entity
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

struct SectionInfoView: View {

    @Environment(\.modelContext) var modelContext
    @Bindable var identityInfo: EntityIdentity

    var body: some View {
        HStack {
            Text("Name", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Name", table: "IdentityView"), text: $identityInfo.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Spacer()
            Text("Surname", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Surname", table: "IdentityView"), text: $identityInfo.surName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        HStack {
            Text("Address", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Address", table: "IdentityView"), text: $identityInfo.adress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        HStack {
            Text("Complement", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Complement", table: "IdentityView"), text: $identityInfo.complement)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        HStack {
            Text("CP", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Postal Code", table: "IdentityView"), text: $identityInfo.cp)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 80)

            Spacer()
            Text("Town", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Town", table: "IdentityView"), text: $identityInfo.town)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        HStack {
            Text("Country", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Country", table: "IdentityView"), text: $identityInfo.country)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        HStack {
            Text("Phone", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Phone", table: "IdentityView"), text: $identityInfo.phone)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)

            Spacer()
            Text("Mobile", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Mobile", table: "IdentityView"), text: $identityInfo.mobile)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)
        }
        HStack {
            Text("Email", tableName: "IdentityView")
                .frame(width: 100, alignment: .leading)
            TextField(String(localized: "Email", table: "IdentityView"), text: $identityInfo.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .onChange(of: identityInfo) {old, _ in saveChanges() }
        Spacer()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }

}
