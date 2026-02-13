//
//  About.swift
//  DataBaseManager
//
//  Created by thierryH24 on 26/10/2025.
//

import SwiftUI


struct AboutView: View {
    
    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
        ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
        ?? "Unknown App"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image("iconDataManager")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48) // réduit
            Text(appName)
                .font(.title) // plus petit que .title
                .truncationMode(.tail)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))")
                .truncationMode(.tail)
            Text("© 2025 " + appName)
            Text("Manage your finance with ease!")
                .multilineTextAlignment(.center)
            Text("Optimised for Apple Silicon")
                .multilineTextAlignment(.center)
            Text("Icons by https://icones8.fr/icons/set/finance")
                .multilineTextAlignment(.center)
        }
        .padding(8) // padding réduit
        .frame(minWidth: 72, minHeight: 72)
    }
}
