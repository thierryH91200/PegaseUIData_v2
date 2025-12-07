//
//  exemple2.swift
//  test2
//
//  Created by Thierry hentic on 26/10/2024.
//


import SwiftUI
import Combine


struct Identy: View {
    
    @Binding var isVisible: Bool
    
    var body: some View {
        Accueil()
            .padding()
            .task {
                await performFalseTask()
            }
    }
    
    private func performFalseTask() async {
        // Exécuter une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        isVisible = false
    }
}

struct Accueil: View {
    var body: some View {
        TabView {
            Account()
                .tabItem {
                    Label("Account", systemImage: "house")
                }
            
            Bank()
                .tabItem {
                    Label("Bank", systemImage: "eurosign.bank.building")
                }
            
            Identite()
                .tabItem {
                    Label("Identities", systemImage: "person")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1) // Priorité élevée pour occuper tout l’espace disponible
    }
}

struct Account: View {
    
    @StateObject private var initAccountViewManager = InitAccountDataManager()

    var body: some View {
        VStack {
            InitAccountView()
                .environmentObject(initAccountViewManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1) // Priorité élevée pour occuper tout l’espace disponible
        }
        .padding()
    }
}

struct Bank: View {
    
    @StateObject private var banqueViewManager = BankDataManager()
    
    var body: some View {
        VStack {
            BankView()
                .environmentObject(banqueViewManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1) // Priorité élevée pour occuper tout l’espace disponible
        }
        .padding()
    }
}

struct Identite: View {
    @StateObject private var identityViewManager = IdentityDataManager()

    var body: some View {
        VStack {
            IdentityView()
                .environmentObject(identityViewManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1) // Priorité élevée pour occuper tout l’espace disponible
        }
        .padding()
    }
}



