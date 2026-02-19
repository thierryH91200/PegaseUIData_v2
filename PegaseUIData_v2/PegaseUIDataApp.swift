//
//  PegaseUIDataApp.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 03/11/2024.
//

import SwiftUI
import SwiftData
import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers
import Sparkle

// MARK: - App principale
@main
struct DatabaseManagerApp: App {
    
    @StateObject private var authManager = AuthenticationManager()

    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var containerManager = ContainerManager()
    @StateObject private var appContainer = AppContainer.shared
    @StateObject private var viewModel = CSVViewModel()
    @StateObject private var sparkleUpdater = SparkleUpdater.shared

    init() {
        ColorTransformer.register()
        // Initialiser PreferencesWindowController avec authManager
        let authMgr = AuthenticationManager()
        _authManager = StateObject(wrappedValue: authMgr)
        PreferencesWindowController.initialize(authManager: authMgr)
    }

    var body: some Scene {
        WindowGroup {
            if authManager.isUnlocked {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(containerManager)
                    .environmentObject(appContainer)
                    .environmentObject(sparkleUpdater)

            } else {
                LockScreenView(authManager: authManager)
                    .onAppear {
                        authManager.authenticate()
                    }
                    .background(WindowAccessor { window in
                        window?.setContentSize(UIConstants.lockScreenSize)
                        window?.center()
                        window?.isRestorable = false
                    })
            }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Lock the application") {
                    authManager.lock()
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appInfo) {
                Button("About \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "l’app")") {
                    openWindow(id: "about")
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    SparkleUpdater.shared.updaterController.checkForUpdates(nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    PreferencesWindowController.shared?.showWindow()
                }
            }

            CommandGroup(after: .newItem) {
                Button(String(localized: "Create New Document...")) {
                    presentSavePanelAndCreate()
                }
                .keyboardShortcut("n")
                
                Button(String(localized: "Open existing document...")) {
                    presentOpenPanelAndOpen()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Divider()
                
                Button(String(localized: "Import CSV…")) {
                    _ = ImportTransactionFileView()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                Button(String(localized: "Import OFX…")) {
                    viewModel.triggerOFXImport()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Button(String(localized: "Export CSV…")) {
                    print("Export")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandMenu(String(localized: "Help")) {
                Button(String(localized: "Application Manual")) {
                    WindowControllerManager.shared.showHelpWindow()
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
        }
        Window("About", id: "about") {
            AboutView()
        }
        .defaultSize(width: 360, height: 220)
    }
    
    // MARK: - Helpers pour les panneaux système
    private func presentSavePanelAndCreate() {
        let panel = NSSavePanel()
        // N’autoriser que .store
        panel.allowedContentTypes = [.store]
        panel.nameFieldStringValue = "New Base"
        panel.canCreateDirectories = true
        panel.allowsOtherFileTypes = false
        
        panel.begin { response in
            if response == .OK, var url = panel.url {
                // Sécurité supplémentaire: forcer l’extension .store si l’utilisateur a retiré l’extension
                if url.pathExtension.lowercased() != "store" {
                    url.deletePathExtension()
                    url.appendPathExtension("store")
                }
                containerManager.createNewDatabase(at: url)
            }
        }
    }
    
    private func presentOpenPanelAndOpen() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // N’autoriser que .store
        panel.allowedContentTypes = [.store]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                containerManager.openDatabase(at: url)
            }
        }
    }
    
    private func presentCSVImportPanelAndImport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // Autoriser uniquement les fichiers CSV
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.triggerImport()

                // TODO: Branchez ici votre logique d'import CSV
                // Par exemple: containerManager.importCSV(at: url)
                print("Selected CSV file: \(url.path)")
            }
        }
    }
}

final class AppSchema {
    static let shared = AppSchema()
    
    let schema = Schema([
        EntityAccount.self,
        EntityBankStatement.self,
        EntityBanqueInfo.self,
        EntityCategory.self,
        EntityCheckBook.self,
        EntityFolderAccount.self,
        EntityIdentity.self,
        EntityInitAccount.self,
        EntityPaymentMode.self,
        EntityStatus.self,
        EntityPreference.self,
        EntityRubric.self,
        EntitySchedule.self,
        EntitySousOperation.self,
        EntityTransaction.self
    ])
    
    private init() {}
}

