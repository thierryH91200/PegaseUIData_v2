//
//  ContentViewModel.swift
//  PegaseUIData_v2
//
//  Extracted from Content.swift for better code organization
//

import SwiftUI
import SwiftData
import Combine

class ContentViewModel: ObservableObject {
    @Published var isInitialized = false

    @MainActor
    init(modelContext: ModelContext) {
        InitManager.shared.initialize()
        isInitialized = true
    }
}
