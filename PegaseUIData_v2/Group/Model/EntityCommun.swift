//
//  EntityCommun.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 14/03/2025.
//

import Foundation
import SwiftData
import SwiftUI
import os
import Combine


enum EnumError: Error {
    case contextNotConfigured
    case accountNotFound
    case invalidStatusType
    case saveFailed
    case fetchFailed
}

// Singleton global pour centraliser le ModelContext et l'UndoManager.
final class DataContext {
    static let shared = DataContext()

    var container: ModelContainer?
    var context: ModelContext?
    var undoManager: UndoManager?

    private init() {}
}

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



