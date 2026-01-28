//
//  PaymentModePickerView.swift
//  PegaseUIData
//
//  Created by Claude Code Refactoring on 15/01/2026.
//

import SwiftUI

/// Reusable payment mode picker component
/// Replaces duplicated picker code across multiple files
struct PaymentModePickerView: View {
    let paymentModes: [EntityPaymentMode]
    @Binding var selectedMode: EntityPaymentMode?
    
    var body: some View {
        HStack  {
            Picker("", selection: $selectedMode) {
                ForEach(paymentModes, id: \.self) { mode in
                    Text(mode.name)
                        .foregroundColor(Color(mode.color))
                        .tag(mode as EntityPaymentMode?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(minWidth: 150)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
