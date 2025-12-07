//
//  AppDelegate.swift
//  WelcomeTo
//
//  Created by thierryH24 on 10/08/2025.
//

import SwiftUI
import Combine


class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationWillFinishLaunching(_ notification: Notification) {
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let mainMenu = NSApp.mainMenu {
            let appMenu = mainMenu.item(at: 0)?.submenu
            let preferencesItem = NSMenuItem(title: "Préférences…", action: #selector(openPreferences), keyEquivalent: ",")
            preferencesItem.target = self
            appMenu?.insertItem(preferencesItem, at: 1)
        }
        // ✅ Demande de permission pour les notifications
        NotificationManager.shared.requestPermission()
    }
    
    @objc func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }
    func applicationShouldTerminateAfterLastWindowClosed (_ sender: NSApplication) -> Bool {
        return true
    }
}

