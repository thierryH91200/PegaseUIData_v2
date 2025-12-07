//  IdentyView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 03/11/2024.
//

import SwiftUI
import SwiftData
import Combine


final class IdentityDataManager: ObservableObject {
    @Published var identity: EntityIdentity? {
        didSet {
            // Sauvegarder les modifications dès qu'il y a un changement
            saveChanges()
        }
    }
    
    var modelContext: ModelContext? {
        DataContext.shared.context
    }

    func saveChanges() {
       
        do {
            try modelContext?.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

struct IdentityView: View {
    
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var currentAccountManager: CurrentAccountManager
    @EnvironmentObject var dataManager: IdentityDataManager
    
//    @Query private var identityInfo: [EntityIdentity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Identity")
                .font(.title)
                .padding(.bottom, 10)
                .accessibilityLabel("Identity title")

            if let account = currentAccountManager.getAccount() {
                Text("Current Account: \(account.name)")
            } else {
                Text("No account selected.")
            }

            VStack(alignment: .leading, spacing: 8) {
                
                if dataManager.identity != nil {
                    SectionInfoView(identityInfo: dataManager.identity!)
                }
            }
        }
        .padding()
        .frame(width: 600)
        .cornerRadius(10)
        .onAppear {
                        
            // Créer un nouvel enregistrement si la base de données est vide
            if dataManager.identity == nil {
                let identity = IdentityManager.shared.getAllData()
                dataManager.identity = identity

                if identity == nil {
                    
                    let newIdentityInfo = EntityIdentity()
                    dataManager.identity = newIdentityInfo
                    modelContext.insert(newIdentityInfo)
                }
            }
        }
        .onDisappear {
            saveChanges()
            dataManager.saveChanges()
            dataManager.identity = nil
        }
        .onChange(of: currentAccountManager.getAccount()) { old, newAccount in
            
            if let account = newAccount {
                dataManager.identity = nil
                
                loadOrCreate(for: account)
            }
        }

        .onChange(of: dataManager.identity) { old , _ in
            do {
                try modelContext.save()
            } catch {
                printTag("Erreur lors de la sauvegarde : \(error)")
            }
        }
    }
    
    private func loadOrCreate(for account: EntityAccount) {
        
        if let existingIdentity = IdentityManager.shared.getAllData() {
            dataManager.identity = existingIdentity
        } else {
            let entity = EntityIdentity()
            entity.account = account
            modelContext.insert(entity)
            dataManager.identity = entity
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

struct SectionInfoView: View {
    
    @Environment(\.modelContext) var modelContext
    @Bindable var identityInfo: EntityIdentity
        
    var body: some View {
        HStack {
            Text("Name")
                .frame(width: 100, alignment: .leading)
            TextField("Name", text: $identityInfo.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Spacer()
            Text("Surname")
                .frame(width: 100, alignment: .leading)
            TextField("Surname", text: $identityInfo.surName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
            Text("Address")
                .frame(width: 100, alignment: .leading)
            TextField("Address", text: $identityInfo.adress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
            Text("Complement")
                .frame(width: 100, alignment: .leading)
            TextField("Complement", text: $identityInfo.complement)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
            Text("CP")
                .frame(width: 100, alignment: .leading)
            TextField("Postal Code", text: $identityInfo.cp)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 80)

            Spacer()
            Text("Town")
                .frame(width: 100, alignment: .leading)
            TextField("Town", text: $identityInfo.town)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
            Text("Country")
                .frame(width: 100, alignment: .leading)
            TextField("Country", text: $identityInfo.country)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
            Text("Phone")
                .frame(width: 100, alignment: .leading)
            TextField("Phone", text: $identityInfo.phone)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)

            Spacer()
            Text("Mobile")
                .frame(width: 100, alignment: .leading)
            TextField("Mobile", text: $identityInfo.mobile)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)
        }
        HStack {
            Text("Email")
                .frame(width: 100, alignment: .leading)
            TextField("Email", text: $identityInfo.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .onChange(of: identityInfo) {old, _ in saveChanges() }
        Spacer()
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }

}

