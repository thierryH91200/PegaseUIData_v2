//
//  exemple2.swift
//  test2
//
//  Created by Thierry hentic on 26/10/2024.
//


import SwiftUI
import Combine


struct Identy: View {

    @Binding var isVisible: Bool

    var body: some View {
        Accueil()
            .padding()
            .onAppear {
                isVisible = false
            }
    }
}

struct Accueil: View {
    var body: some View {
        TabView {
            Account()
                .tabItem {
                    Label("Account", systemImage: "house")
                }

            Bank()
                .tabItem {
                    Label("Bank", systemImage: "eurosign.bank.building")
                }

            Identite()
                .tabItem {
                    Label("Identities", systemImage: "person")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
    }
}

struct Account: View {

    var body: some View {
        VStack {
            InitAccountView()
                .environmentObject(InitAccountManager.shared)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .padding()
    }
}

struct Bank: View {

    var body: some View {
        VStack {
            BankView()
                .environmentObject(BankManager.shared)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .padding()
    }
}

struct Identite: View {

    var body: some View {
        VStack {
            IdentityView()
                .environmentObject(IdentityManager.shared)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .padding()
    }
}
