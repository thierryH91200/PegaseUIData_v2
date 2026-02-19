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

    @EnvironmentObject var container: AppContainer

    var body: some View {
        VStack {
            InitAccountView()
                .environmentObject(container.initAccounts)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .padding()
    }
}

struct Bank: View {

    @EnvironmentObject var container: AppContainer

    var body: some View {
        VStack {
            BankView()
                .environmentObject(container.banks)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .padding()
    }
}

struct Identite: View {

    @EnvironmentObject var container: AppContainer

    var body: some View {
        VStack {
            IdentityView()
                .environmentObject(container.identities)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .padding()
    }
}
