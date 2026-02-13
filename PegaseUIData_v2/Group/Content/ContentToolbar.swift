//
//  ContentToolbar.swift
//  PegaseUIData_v2
//
//  Main toolbar for ContentView
//  Extracted from Content.swift for better code organization
//

import SwiftUI

struct ContentToolbar: ToolbarContent {
    @EnvironmentObject var containerManager: ContainerManager
    @ObservedObject var viewModel: CSVViewModel
    @ObservedObject var colorManager: ColorManager
    @Binding var inspectorIsShown: Bool
    @Binding var selectedColor: String?

    var body: some ToolbarContent {
        // Navigation Items
        ToolbarItem(placement: .navigation) {
            Button {
                containerManager.closeCurrentDatabase()
            } label: {
                Label {
                    Text(String(localized: "Home", table: "MainApp"))
                } icon: {
                    Image(systemName: "house")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            }
        }

        ToolbarItemGroup(placement: .navigation) {
            Button {
                printTag("Nouvel élément ajouté", flag: true)
            } label: {
                Label {
                    Text(String(localized: "Add", table: "MainApp"))
                } icon: {
                    Image(systemName: "plus")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            }
        }

        ToolbarItemGroup(placement: .navigation) {
            Button {
                printTag("Import", flag: true)
            } label: {
                Label {
                    Text(String(localized: "Import", table: "MainApp"))
                } icon: {
                    Image(systemName: "arrow.up.document.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            }
        }

        ToolbarItemGroup(placement: .navigation) {
            Button {
                viewModel.triggerImport()
            } label: {
                Label {
                    Text(String(localized: "Export"))
                } icon: {
                    Image(systemName: "arrow.down.document.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            }
        }

        // Automatic Items (Right side)
        ToolbarItemGroup(placement: .automatic) {
            Button {
                inspectorIsShown.toggle()
            } label: {
                Label {
                    Text(String(localized: "Show inspector", table: "MainApp"))
                } icon: {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            }

            AppearancePopoverButton()

            Menu {
                Button(action: { changeSearchFieldItem("All") }) { Text("All") }
                Button(action: { changeSearchFieldItem("Comment") }) { Text("Comment") }
                Button(action: { changeSearchFieldItem("Category") }) { Text("Category") }
                Button(action: { changeSearchFieldItem("Rubric") }) { Text("Rubric") }
            } label: {
                Label("Find", systemImage: "magnifyingglass")
            }

            Button(action: {
                printTag("Paramètres ouverts", flag: true)
            }) {
                Label("Settings", systemImage: "gear")
            }
        }

        // Color Menu
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                Button(action: { chooseCouleur("United") }) {
                    HStack {
                        Label("United", systemImage: "paintbrush.fill")
                        if selectedColor == "United" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { chooseCouleur("Income/Expense") }) {
                    Label("Income/Expense", systemImage: "dollarsign.circle")
                    if selectedColor == "Income/Expense" {
                        Image(systemName: "checkmark")
                    }
                }
                Button(action: { chooseCouleur("Rubric") }) {
                    Label("Rubric", systemImage: "tag.fill")
                    if selectedColor == "Rubric" {
                        Image(systemName: "checkmark")
                    }
                }
                Button(action: { chooseCouleur("Payment Mode") }) {
                    Label("Payment method", systemImage: "creditcard.fill")
                    if selectedColor == "Payment Mode" {
                        Image(systemName: "checkmark")
                    }
                }
                Button(action: { chooseCouleur("Status") }) {
                    HStack {
                        Label("Status", systemImage: "checkmark.circle.fill")
                        if selectedColor == "Status" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Label("Choose the color", systemImage: "paintpalette")
            }
        }
    }

    private func chooseCouleur(_ color: String) {
        colorManager.colorChoix = color
        selectedColor = color
    }

    private func changeSearchFieldItem(_ itemType: String) {
        printTag("Champ de recherche sélectionné : \(itemType)", flag: true)
    }
}
