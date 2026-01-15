//
//  StatusPickerView.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI
import Combine // if you use ObservableObject/@Published elsewhere in this file

struct StatusPickerView: View {
    let statuses: [EntityStatus]

    // Make sure this is a Binding if the parent owns the state:
    @Binding var selectedStatus: EntityStatus?

    var body: some View {
        Picker("Statut", selection: $selectedStatus) {
            Text("Sélectionner...")
                .tag(nil as EntityStatus?)

            ForEach(statuses) { status in
                HStack {
                    Circle()
                        .fill(Color(status.color))
                        .frame(width: 10, height: 10)
                    Text(status.name)
                }
                .tag(status as EntityStatus?)
            }
        }
        .pickerStyle(.menu)
        // If you want a menu style:
    }
}

