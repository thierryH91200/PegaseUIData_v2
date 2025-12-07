//
//  SettingView.swift
//  PegaseUI
//
//  Created by Thierry hentic on 31/10/2024.
//

import SwiftUI

struct SettingView: View {
    
    @Binding var isVisible: Bool
    
    var body: some View {
        SettingTab()
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

enum TabSelection: Hashable {
    case rubric
    case modePaiement
    case preference
    case checkBook
}

struct SettingTab1: View {
    
    @StateObject private var chequeViewManager       = ChequeBookManager()
    @StateObject private var modePaiementDataManager = PaymentModeManager()
    @StateObject private var rubricDataManager       = RubricDataManager()
    @StateObject private var preferenceDataManager   = PreferenceDataManager()
    
    @State private var selectedTab: TabSelection = .rubric
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            RubricView()
                .environmentObject(rubricDataManager)
                .tabItem {
                    Label("Rubric", systemImage: "house")
                }
                .tag(TabSelection.rubric)
            
//            ModePaiementView()
//                .environmentObject(modePaiementDataManager)
//                .tabItem {
//                    Label("Modes de paiement", systemImage: "creditcard")
//                }
//                .tag(TabSelection.modePaiement)
            
            PreferenceTransactionView()
                .environmentObject(preferenceDataManager)
                .tabItem {
                    Label("Preferences", systemImage: "gear")
                }
                .tag(TabSelection.preference)
            
            CheckView()
                .environmentObject(chequeViewManager)
            
                .tabItem {
                    Label("Check", systemImage: "person")
                }
                .tag(TabSelection.checkBook)


        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1) // Priorité élevée pour occuper tout l’espace disponible

    }
}

//enum TabSelection: Hashable {
//    case rubric
//    case modePaiement
//    case preference
//}
struct SettingTab: View {
    
    @StateObject private var chequeViewManager       = ChequeBookManager()
    @StateObject private var modePaiementDataManager = PaymentModeManager()
    @StateObject private var rubricDataManager       = RubricDataManager()
    @StateObject private var preferenceDataManager   = PreferenceDataManager()
    
    @State private var selectedTab: TabSelection = .rubric
    var body: some View {
        
        TabView {
            
            RubricView()
                .environmentObject(rubricDataManager)
                .tabItem {
                    Label ("Rubric", systemImage: "house" )
                }

            ModePaymentView()
                .environmentObject(modePaiementDataManager)
                .tabItem {
                    Label("Payment method", systemImage: "eurosign.bank.building")
                }
            
            PreferenceTransactionView()
                .environmentObject(preferenceDataManager)
                .tabItem {
                    Label("Transaction", systemImage: "person")
                }
            
            CheckView()
                .environmentObject(chequeViewManager)
                .tabItem {
                    Label("Check", systemImage: "person")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
    }
}
