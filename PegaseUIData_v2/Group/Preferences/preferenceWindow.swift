//
//  prefCont.swift
//  testPref
//
//  Created by Thierry hentic on 04/11/2024.
//

import Cocoa
import SwiftUI
import UserNotifications
import SwiftData
import Combine
import OSLog


class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    static var shared: PreferencesWindowController?
    private var authManager: AuthenticationManager

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        // Créer la fenêtre de préférences avec SwiftUI comme contenu
        let preferencesView = PreferencesView(authManager: authManager)
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "Preferences", table: "PreferencesView")
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false // Garde la fenêtre en mémoire après la fermeture

        super.init(window: window)
        window.delegate = self

        // Définir comme singleton
        PreferencesWindowController.shared = self
    }

    static func initialize(authManager: AuthenticationManager) {
        if shared == nil {
            shared = PreferencesWindowController(authManager: authManager)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // Met l'application au premier plan
    }
    
    func windowWillClose(_ notification: Notification) {
        // Assurez-vous que les changements sont sauvegardés si besoin
    }
}

struct PreferencesView: View {
    @ObservedObject var authManager: AuthenticationManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(String(localized: "General", table: "PreferencesView"), systemImage: "gear")
                }

            EyesSettingsView()
                .tabItem {
                    Label(String(localized: "Eyes", table: "PreferencesView"), systemImage: "eye")
                }
            SecuritySettingsView(authManager: authManager)
                .tabItem {
                    Label(String(localized: "Authorization", table: "PreferencesView"), systemImage: "touchid")
            }
        }
        .padding()
        .frame(width: 450, height: 350) // Taille de la fenêtre de préférences
    }
}

struct GeneralSettingsView: View {
    
    @Environment(\.modelContext) private var modelContext

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @State private var notificationsEnabled: Bool = true
    @State private var justGrantedNotifications: Bool = false
    @State private var showAlert = false

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section(header: Text("Example data", tableName: "PreferencesView")) {
                Button(String(localized: "Reset preloaded data", table: "PreferencesView")) {
                    showAlert = true
                }
            }
        }
        .alert(String(localized: "Reset data?", table: "PreferencesView"), isPresented: $showAlert) {
            Button(String(localized: "Cancel", table: "PreferencesView"), role: .cancel) {}
            Button(String(localized: "Reset", table: "PreferencesView"), role: .destructive) {
                resetPreloadedData()
            }
        } message: {
            Text("This operation will delete all data and reload the sample data.", tableName: "PreferencesView")
        }
        .padding()

        VStack(alignment: .leading) {
            Toggle(String(localized: "Launch at login", table: "PreferencesView"), isOn: $launchAtLogin)
            Toggle(String(localized: "Show in menu bar (hide from Dock)", table: "PreferencesView"), isOn: $showInMenuBar)
            if !notificationsEnabled {
                Text("Notifications are disabled. Enable them in System Settings.", tableName: "PreferencesView")
                    .foregroundColor(.red)
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(String(localized: "Open System Settings", table: "PreferencesView"), systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
            if justGrantedNotifications {
                Text("Notifications have been successfully enabled.", tableName: "PreferencesView")
                    .foregroundColor(.green)
            }
            Spacer()
        }
        .padding()
        .onReceive(refreshTimer) { _ in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    let newStatus = settings.authorizationStatus == .authorized
                    if newStatus && !notificationsEnabled {
                        justGrantedNotifications = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            justGrantedNotifications = false
                        }
                    }
                    notificationsEnabled = newStatus
                }
            }
        }
    }
    private func resetPreloadedData() {
        // Supprime le flag UserDefaults
        UserDefaults.standard.removeObject(forKey: "didPreloadDefaultData")

        // Supprime toutes les données (optionnel mais recommandé)
        deleteAllEntities(of: EntityFolderAccount.self)
        deleteAllEntities(of: EntityAccount.self)
        deleteAllEntities(of: EntityPaymentMode.self)

        // Recharge les données par le preload habituel
//        AccountFolderManager.shared.preloadDataIfNeeded(modelContext: modelContext)
    }

    private func deleteAllEntities<T: PersistentModel>(of type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        do {
            let results = try modelContext.fetch(descriptor)
            for entity in results {
                modelContext.delete(entity)
            }
            try modelContext.save()
        } catch {
            AppLogger.data.error("Delete all \(String(describing: T.self)) failed: \(error.localizedDescription)")
        }
    }
}

struct EyesSettingsView: View {
    @AppStorage("foregroundColor") private var foregroundColorHex: String = "#000000"
    @AppStorage("backgroundColor") private var backgroundColorHex: String = "#00FF00"
    @AppStorage("alphaValue") private var alphaValue: Double = 1.0

    private var foregroundColor: Binding<Color> {
        Binding(
            get: { Color(hex: foregroundColorHex) },
            set: { foregroundColorHex = $0.toHex() }
        )
    }

    private var backgroundColor: Binding<Color> {
        Binding(
            get: { Color(hex: backgroundColorHex) },
            set: { backgroundColorHex = $0.toHex() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Foreground color:", tableName: "PreferencesView")
                    .frame(width: 150, alignment: .leading)
                ColorPicker("", selection: foregroundColor)
                    .labelsHidden()
            }
            HStack {
                Text("Background color:", tableName: "PreferencesView")
                    .frame(width: 150, alignment: .leading)
                ColorPicker("", selection: backgroundColor)
                    .labelsHidden()
            }
            HStack {
                Text("Alpha value:", tableName: "PreferencesView")
                    .frame(width: 150, alignment: .leading)
                Slider(value: $alphaValue, in: 0...1)
            }

            Spacer()
        }
        .padding()
    }
}
