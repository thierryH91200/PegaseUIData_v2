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
        Picker("", selection: $selectedStatus) {
            ForEach(statuses) { status in
                Text(status.name)
                    .foregroundColor(Color(status.color))
                    .tag(status as EntityStatus?)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(minWidth: 150, alignment: .leading)
    }
}

