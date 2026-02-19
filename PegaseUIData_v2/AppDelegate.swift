//
//  AppDelegate.swift
//  WelcomeTo
//
//  Created by thierryH24 on 10/08/2025.
//

import SwiftUI
import Combine
import Sparkle


class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Désactiver la restauration automatique des fenêtres par macOS
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
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

        // Forcer la taille initiale de la fenêtre pour LockScreenView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                // Vérifier si c'est la fenêtre de lock (pas ContentView)
                if window.contentView?.frame.size.width ?? 0 > UIConstants.lockScreenSize.width ||
                   window.contentView?.frame.size.height ?? 0 > UIConstants.lockScreenSize.height {
                    window.setContentSize(UIConstants.lockScreenSize)
                    window.center()
                }
            }
        }
    }
    
    @objc func openPreferences() {
        PreferencesWindowController.shared?.showWindow()
    }
    func applicationShouldTerminateAfterLastWindowClosed (_ sender: NSApplication) -> Bool {
        return true
    }
}

final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()

    let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
}


