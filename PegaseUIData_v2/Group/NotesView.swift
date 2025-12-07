//
//  NotesView.swift
//  PegaseUI
//
//  Created by Thierry hentic on 30/10/2024.
//
import SwiftUI
import SwiftData
import Combine

struct NotesView: View {
    
    @Binding var isVisible: Bool
    @StateObject private var dataManager = BankStatementManager()

    var body: some View {
        NotesView10()
            .environmentObject(dataManager)

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

struct NotesView10: View {
    @Environment(\.modelContext) private var modelContext: ModelContext

    @EnvironmentObject var dataManager: BankStatementManager
    @EnvironmentObject var currentAccountManager: CurrentAccountManager

    // Récupère le compte courant de manière sécurisée.
    var compteCurrent: EntityAccount? {
        CurrentAccountManager.shared.getAccount()
    }

    var body: some View {
        
        Text("NotesView")
            .font(.title)
        Text("\(compteCurrent?.name ?? String(localized:"No current account" ))")
//            .onChange(of: currentAccountManager.getAccount()) { old, newAccount in
//                if newAccount != "" {
//                    refreshData()
//                }
//            }
    }
    private func refreshData() {
        dataManager.statements = BankStatementManager.shared.getAllData() ?? []
    }
}
