//
//  Notification.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 19/03/2025.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers


extension Notification.Name {
    static let importTransaction = Notification.Name("importTransaction")
    static let importTransactionOFX = Notification.Name("importTransactionOFX")
    static let importReleve      = Notification.Name("importReleve")
    static let exportTransactionCSV = Notification.Name("exportTransactionCSV")
    static let exportTransactionOFX = Notification.Name("exportTransactionOFX")
    static let exportReleve      = Notification.Name("exportReleve")
        
    static let loadDemoRequested = Notification.Name("loadDemoRequested")
    static let resetDatabaseRequested = Notification.Name("resetDatabaseRequested")

    static let transactionsImported = Notification.Name("transactionsImported")
    static let transactionsAddEdit = Notification.Name("transactionsAddEdit")

}



extension UTType {
    static var ofx: UTType {
        UTType(importedAs: "com.opengroup.ofx")
    }
}

extension View {
    func debugFrame(_ label: String = "") -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        print("[\(label)] size: \(geo.size)")
                    }
            }
        )
    }
}
