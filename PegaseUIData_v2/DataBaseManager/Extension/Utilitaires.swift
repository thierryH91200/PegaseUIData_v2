//
//  Utilitaires.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 31/12/2025.
//


import Foundation
import SwiftData
import SwiftUI
import os
import Combine

// Logging utilitaire
@inline(__always)
func printTag(_ message: String,
              flag: Bool = true,
              file: String = #fileID,
              function: String = #function,
              line: Int = #line) {
    guard flag else { return }
    let tag = "[PegaseUIData]"
    print("\(tag) [\(file):\(line)] \(function) — \(message)")
}


func logUI(_ message: String, pr: Bool = false) {
    if !pr { return }
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[UI] \(ts) - \(message)")
}



