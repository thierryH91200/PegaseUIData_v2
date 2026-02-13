//
//  Date.swift
//  PegaseUIData
//
//  Created by thierryH24 on 10/08/2025.
//

import Foundation

extension Date {
    /// Format simple pour affichage
    var shortFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
