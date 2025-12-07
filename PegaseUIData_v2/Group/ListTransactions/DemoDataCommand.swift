//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 12/05/2025.
//



import SwiftUI

struct DemoDataCommand: Commands {
    var loadDemoAction: () -> Void
    var resetAction: () -> Void

    var body: some Commands {
        CommandGroup(after: .newItem) {
#if DEBUG
            Divider()

            Button("Load demo data") {
                loadDemoAction()
            }
            .keyboardShortcut("D", modifiers: [.command, .shift])
            .textCase(.lowercase) // ← empêche SwiftUI de mettre en majuscules


            Button("Reset the base") {
                resetAction()
            }
            .keyboardShortcut("R", modifiers: [.command, .shift])
            .textCase(.lowercase) // ← empêche SwiftUI de mettre en majuscules
#endif
        }
    }
}

