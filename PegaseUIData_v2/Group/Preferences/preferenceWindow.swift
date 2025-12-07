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


class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PreferencesWindowController()
    
    private init() {
        // Créer la fenêtre de préférences avec SwiftUI comme contenu
        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false // Garde la fenêtre en mémoire après la fermeture
        
        super.init(window: window)
        window.delegate = self
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
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            EyesSettingsView()
                .tabItem {
                    Label("Eyes", systemImage: "eye")
                }
        }
        .padding()
        .frame(width: 450, height: 250) // Taille de la fenêtre de préférences
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
            Section(header: Text("Example data")) {
                Button("Reset preloaded data") {
                    showAlert = true
                }
            }
        }
        .alert("Reset data?", isPresented: $showAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetPreloadedData()
            }
        } message: {
            Text("This operation will delete all data and reload the sample data.")
        }
        .padding()

        VStack(alignment: .leading) {
            Toggle("Launch at login", isOn: $launchAtLogin)
            Toggle("Show in menu bar (hide from Dock)", isOn: $showInMenuBar)
            if !notificationsEnabled {
                Text("🔕 Notifications are disabled. Enable them in System Settings.")
                    .foregroundColor(.red)
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
            if justGrantedNotifications {
                Text("✅ Notifications have been successfully enabled.")
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
        if let results = try? modelContext.fetch(descriptor) {
            for entity in results {
                modelContext.delete(entity)
            }
            try? modelContext.save()
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
                Text("Foreground color:")
                    .frame(width: 150, alignment: .leading)
                ColorPicker("", selection: foregroundColor)
                    .labelsHidden()
            }
            HStack {
                Text("Background color:")
                    .frame(width: 150, alignment: .leading)
                ColorPicker("", selection: backgroundColor)
                    .labelsHidden()
            }
            HStack {
                Text("Alpha value:")
                    .frame(width: 150, alignment: .leading)
                Slider(value: $alphaValue, in: 0...1)
            }
            
            Spacer()
        }
        .padding()
    }
}
