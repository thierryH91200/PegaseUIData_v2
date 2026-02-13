//
//  InternetReconciliationView.swift
//  PegaseUI
//
//  Created by Thierry hentic on 30/10/2024.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import SwiftData

struct InternetReconciliationView: View {
    
    @Binding var isVisible: Bool

    var body: some View {
        Text("InternetReconciliationView")
            .font(.title)
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

