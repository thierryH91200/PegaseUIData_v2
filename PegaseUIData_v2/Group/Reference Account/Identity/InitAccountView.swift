//
//  AccountView.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 03/11/2024.
//

import SwiftUI
import SwiftData
import Combine

final class InitAccountDataManager: ObservableObject {
    @Published var initAccount: EntityInitAccount? {
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

struct InitAccountView: View {
    
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var dataManager: InitAccountDataManager
    @EnvironmentObject var currentAccountManager: CurrentAccountManager

//    @Query private var banqueInfos: [EntityInitAccount]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Logo et Rapport Initial
            if let initAccount = dataManager.initAccount {
                HStack(alignment: .top) {
                    Image(systemName: "building.columns.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Initial report")
                            .font(.headline)
                        
                        HStack(spacing: 40) {
                            ReportView( initAccount: initAccount)
                        }
                    }
                }
            }

            // Références Bancaires
            if let initAccount = dataManager.initAccount {
                VStack(alignment: .leading) {
                    Text("Bank references")
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
                dataManager.initAccount = nil
                loadOrCreateIdentity(for: account)
            }
        }
        .onChange(of: dataManager.initAccount) { old , _ in
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
        if dataManager.initAccount == nil {

            let accountInitInfo = InitAccountManager.shared.getAllData()
            dataManager.initAccount = accountInitInfo ?? {
                let newInitAccount = EntityInitAccount(account: CurrentAccountManager.shared.getAccount()!)
                modelContext.insert(newInitAccount)
                return newInitAccount
            }()
        }
    }
    
    private func resetAccount() {
        saveChanges()
//        initAccountViewManager.saveChanges(using: modelContext)
        dataManager.initAccount = nil
    }
    
    private func loadOrCreateIdentity(for account: EntityAccount) {
        
        if let existingInitAccount = InitAccountManager.shared.getAllData() {
            dataManager.initAccount = existingInitAccount
        } else {
            let entity = EntityInitAccount(account: account)
            entity.account = account
            modelContext.insert(entity)
            dataManager.initAccount = entity
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

// Vue pour le rapport initial (Planned, Engaged, Executed)
struct ReportView: View {
    
    @Environment(\.modelContext) var modelContext

    @Bindable var initAccount: EntityInitAccount
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Planned")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Enter planned value", text: Binding(
                get: { String(initAccount.prevu) }, // Convertir en String pour l'affichage
                set: { newValue in
                    if let value = Double(newValue) { // Convertir en Double pour le stockage
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
            Text("In progress")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Enter Engaged value", text: Binding(
                get: { String(initAccount.engage) }, // Convertir en String pour l'affichage
                set: { newValue in
                    if let value = Double(newValue) { // Convertir en Double pour le stockage
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
            Text("Executed")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Enter Executed value", text: Binding(
                get: { String(initAccount.realise) }, // Convertir en String pour l'affichage
                set: { newValue in
                    if let value = Double(newValue) { // Convertir en Double pour le stockage
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
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}

// Vue pour les références bancaires
struct BankReferenceView: View {
    
    @Environment(\.modelContext) var modelContext
    @Bindable var initAccount: EntityInitAccount

    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bank")
                    .frame(width: 100, alignment: .leading)
                TextField("Bank", text: $initAccount.codeBank)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
            }
            
            HStack {
                Text("Indicative")
                    .frame(width: 100, alignment: .leading)
                TextField("Indicative", text: $initAccount.codeGuichet)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Account")
                    .frame(width: 100, alignment: .leading)
                TextField("Account", text: $initAccount.codeAccount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("Key")
                    .frame(width: 100, alignment: .leading)
                TextField("Key", text: $initAccount.cleRib)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Text("IBAN")
                    .frame(width: 100, alignment: .leading)
                TextField("IBAN", text: Binding(
                    get: { formattedIBAN(initAccount.iban) },
                    set: { newValue in
                        initAccount.iban = newValue.replacingOccurrences(of: " ", with: "") // Nettoyer pour stocker sans espaces
                    }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            }
            
            HStack {
                Text("BIC")
                    .frame(width: 100, alignment: .leading)
                TextField("BIC", text: $initAccount.bic)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
            }
            .onChange(of: initAccount) {old, _ in saveChanges() }

        }
        .padding()
    }
    
    func formattedIBAN(_ iban: String) -> String {
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "") // Retirer les espaces existants
        let groups = stride(from: 0, to: cleanedIBAN.count, by: 4).map { index in
            let start = cleanedIBAN.index(cleanedIBAN.startIndex, offsetBy: index)
            let end = cleanedIBAN.index(start, offsetBy: 4, limitedBy: cleanedIBAN.endIndex) ?? cleanedIBAN.endIndex
            return String(cleanedIBAN[start..<end])
        }
        return groups.joined(separator: " ") // Rejoindre les groupes avec des espaces
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            printTag("Erreur lors de la sauvegarde : \(error.localizedDescription)")
        }
    }
}
