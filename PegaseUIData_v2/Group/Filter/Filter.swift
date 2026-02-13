//
//  InternetReconciliationView.swift
//  PegaseUI
//
//  Created by Thierry hentic on 30/10/2024.
//

import SwiftUI
import Foundation
import SwiftData

struct HybridContentData100: View {
    
    @Binding var isVisible: Bool

    var body: some View {
        TransactionFilterView()
            .task {
                await performFalseTask()
            }
    }
    
    private func performFalseTask() async {
        // Exécuter une tâche asynchrone (par exemple, un délai)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde de délai
        isVisible = true
    }
}

