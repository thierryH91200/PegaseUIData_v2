//
//  SecuritySettingsView.swift
//  test49
//
//  Created by Claude on 22/01/2026.
//

import SwiftUI

struct SecuritySettingsView: View {
    @ObservedObject var authManager: AuthenticationManager


    @State private var selectedTimeout: TimeInterval

    // Options de timeout disponibles
    private let timeoutOptions: [(label: String, value: TimeInterval)] = [
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("Jamais", 0)
    ]

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        _selectedTimeout = State(initialValue: authManager.inactivityTimeout)
    }

    var body: some View {
        Form {
            Section(header: Text("Sécurité")) {
                Picker("Verrouillage automatique après:", selection: $selectedTimeout) {
                    ForEach(timeoutOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .onChange(of: selectedTimeout) { oldValue, newValue in
                    if newValue == 0 {
                        authManager.stopInactivityTimer()
                    } else {
                        authManager.setInactivityTimeout(seconds: newValue)
                    }
                }

                Text("L'application se verrouillera automatiquement après la période d'inactivité sélectionnée.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Actions")) {
                Button(action: {
                    authManager.lock()
                }) {
                    Label("Verrouiller maintenant", systemImage: "lock.fill")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SecuritySettingsView(authManager: AuthenticationManager())
}
