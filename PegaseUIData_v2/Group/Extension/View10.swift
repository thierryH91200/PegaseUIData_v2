//
//  View.swift
//  PegaseUIData
//
//  Created by thierryH24 on 15/08/2025.
//

import SwiftUI


extension View {
    /// Applies a consistent action button style.
    /// - Parameters:
    ///   - isEnabled: Whether the control is enabled.
    ///   - activeColor: The background color when enabled.
    /// - Returns: A styled view with padding, background, opacity, foreground color and corner radius.
    func actionButtonStyle(isEnabled: Bool, activeColor: Color) -> some View {
        self
            .padding()
            .background(isEnabled ? activeColor : Color.gray)
            .opacity(isEnabled ? 1 : 0.6)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}


extension View {
    func placeholder(_ text: String, when shouldShow: Bool) -> some View {
        self.overlay(
            Group {
                if shouldShow {
                    Text(text)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.leading, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        )
    }
}
