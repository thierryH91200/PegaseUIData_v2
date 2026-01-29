//
//  FormActionButtonsView.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI

/// Reusable action buttons (Save/Cancel) for forms
struct FormActionButtonsView: View {
    let onSave: () -> Void
    let onCancel: () -> Void
    let canSave: Bool

    var body: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save") {
                onSave()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding()
    }
}
