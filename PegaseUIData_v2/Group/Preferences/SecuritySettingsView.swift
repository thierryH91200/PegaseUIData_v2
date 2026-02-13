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
        (String(localized: "1 minute", table: "PreferencesView"), 60),
        (String(localized: "2 minutes", table: "PreferencesView"), 120),
        (String(localized: "5 minutes", table: "PreferencesView"), 300),
        (String(localized: "10 minutes", table: "PreferencesView"), 600),
        (String(localized: "15 minutes", table: "PreferencesView"), 900),
        (String(localized: "30 minutes", table: "PreferencesView"), 1800),
        (String(localized: "Never", table: "PreferencesView"), 0)
    ]

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        _selectedTimeout = State(initialValue: authManager.inactivityTimeout)
    }

    var body: some View {
        Form {
            Section(header: Text("Security", tableName: "PreferencesView")) {
                Toggle(String(localized: "Require authentication at launch", table: "PreferencesView"), isOn: $authManager.requireLockScreenAtLaunch)

                Picker(String(localized: "Automatic locking after:", table: "PreferencesView"), selection: $selectedTimeout) {
                    ForEach(timeoutOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .disabled(!authManager.requireLockScreenAtLaunch)
                .onChange(of: selectedTimeout) { oldValue, newValue in
                    if newValue == 0 {
                        authManager.stopInactivityTimer()
                    } else {
                        authManager.setInactivityTimeout(seconds: newValue)
                    }
                }

                Text("The application will automatically lock after the selected period of inactivity.", tableName: "PreferencesView")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Actions", tableName: "PreferencesView")) {
                Button(action: {
                    authManager.lock()
                }) {
                    Label(String(localized: "Lock now", table: "PreferencesView"), systemImage: "lock.fill")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
                .disabled(!authManager.requireLockScreenAtLaunch)
            }
        }
        .formStyle(.grouped)
    }
}

