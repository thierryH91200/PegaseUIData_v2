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


struct SettingTab: View {
    
    @StateObject private var chequeViewManager       = ChequeBookManager()
    @StateObject private var modePaiementDataManager = PaymentModeManager()
    @StateObject private var preferenceDataManager   = PreferenceDataManager()
    
    @State private var selectedTab: TabSelection = .rubric
    var body: some View {
        
        TabView {

            RubricView()
                .environmentObject(RubricManager.shared)
                .tabItem {
                    Label(String(localized: "Rubric", table: "SettingsView"), systemImage: "house")
                }

            ModePaymentView()
                .environmentObject(modePaiementDataManager)
                .tabItem {
                    Label(String(localized: "Payment method", table: "SettingsView"), systemImage: "eurosign.bank.building")
                }

            PreferenceTransactionView()
                .environmentObject(preferenceDataManager)
                .tabItem {
                    Label(String(localized: "Transaction", table: "SettingsView"), systemImage: "person")
                }

            CheckView()
                .environmentObject(chequeViewManager)
                .tabItem {
                    Label(String(localized: "Check", table: "SettingsView"), systemImage: "person")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
    }
}
