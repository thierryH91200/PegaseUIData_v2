//
//  Content.swift
//  PegaseUI
//
//  Created by Thierry hentic on 27/10/2024.
//

import SwiftUI
import AppKit
import SwiftData
import Combine

class ContentViewModel: ObservableObject {
    @Published var isInitialized = false

    @MainActor
    init(modelContext: ModelContext) {
        InitManager.shared.initialize()
        isInitialized = true // Marqueur pour indiquer la fin de l'initialisation
    }
}

enum FormMode {
    case create
    case editSingle(EntityTransaction)
    case editMultiple([EntityTransaction])
}

class TransactionSelectionManager: ObservableObject, Identifiable {
    @Published var selectedTransaction: EntityTransaction?
    @Published var selectedTransactions: [EntityTransaction] = []
    
    @Published var isCreationMode: Bool = true
    @Published var lastSelectedTransactionID: UUID?
    
    var formMode: FormMode {
        switch selectedTransactions.count {
        case 0:
            return .create
        case 1:
            return .editSingle(selectedTransactions.first!)
        default:
            return .editMultiple(selectedTransactions)
        }
    }

    var isMultiSelection: Bool {
        selectedTransactions.count > 1
    }
}
struct ContentView100: View {
    
    @AppStorage("choixCouleur") var choixCouleur: String = "Unie"
    
    @EnvironmentObject var containerManager: ContainerManager
//    let account: EntityAccount 

    @StateObject private var currentAccountManager = CurrentAccountManager.shared
    @StateObject private var transactionManager = TransactionSelectionManager()
    @StateObject private var colorManager = ColorManager()

    @State private var selectedTransaction: EntityTransaction?
    @State private var isCreationMode : Bool = true
    
    @State private var showCSVTransactionImporter = false
    @State private var showOFXTransactionImporter = false
    @State private var showCSVTransactionExporter = false

    var transactions: [EntityTransaction] = [] // Liste des transactions

    @State private var selection1: UUID?
    @State private var selection2: String? = "Notes"
    @State private var isVisible: Bool = true
    @State private var isToggle: Bool = false

    @State private var entityAccount: [EntityAccount] = []    
    @State private var inspectorIsShown: Bool = false
    
    @State private var showImportOFX = false
    @State var viewModel = CSVViewModel()

    @State private var selectedColor: String? = "United"

//    @State private var executed: Double = 0.0
//    @State private var planned: Double = 0.0
//    @State private var engaged: Double = 0.0
//    
    @State private var dashboard: DashboardState = DashboardState()
      
    var body: some View {
        HStack
        {
            NavigationSplitView {
                SidebarContainer(selection1: $selection1, selection2: $selection2)
                    .navigationSplitViewColumnWidth(min: 256, ideal: 256, max: 400)
            }
            content :
            {
                DetailContainer(selection2: $selection2,
                                selectedTransaction: $selectedTransaction,
                                isCreationMode: $isCreationMode,
                                dashboard: $dashboard)
                    .navigationSplitViewColumnWidth( min: 150, ideal: 800)
            }
            detail :
            {
                if dashboard.isVisible
                {
                    OperationDialog()
                }
            }
            .environmentObject(transactionManager)
            .environmentObject(currentAccountManager)
            .navigationSplitViewStyle(.automatic)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importTransaction)) { _ in
            showCSVTransactionImporter = true
        }
        .sheet(isPresented: $showCSVTransactionImporter) {
            ImportTransactionFileView() // Affiche la fenêtre d'importation CSV
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .importTransactionOFX)) { _ in
            showOFXTransactionImporter = true
        }
        .sheet(isPresented: $showOFXTransactionImporter) {
            ImportTransactionOFXFileView(isPresented: $showOFXTransactionImporter)
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .exportTransactionCSV)) { _ in
            showCSVTransactionExporter = true
        }
        .sheet(isPresented: $showCSVTransactionExporter) {
            CSVEXportTransactionView() // Affiche la fenêtre d'exportation CSV
        }

        .toolbar {
            
            ToolbarItem(placement: .navigation) {
                Button {
                    containerManager.closeCurrentDatabase()
                } label: {
                    Label {
                        Text(String(localized: "Home", table: "MainApp"))
                    } icon: {
                        Image(systemName: "house")
                            .foregroundStyle(.red)     // couleur rouge
                            .font(.title2)       // taille un peu plus grande
                    }
                }
            }

            ToolbarItemGroup(placement: .navigation) {
                Button {
                    printTag("Nouvel élément ajouté", flag: true)
                }label: {
                    Label {
                        Text(String(localized: "Add", table: "MainApp"))
                    } icon: {
                        Image(systemName: "plus")
                            .foregroundStyle(.red)     // couleur rouge
                            .font(.title2)      // taille un peu plus grande
                    }

                }
            }
            
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    viewModel.triggerImport()
                }label: {
                    Label {
                        Text(String(localized: "Import", table: "MainApp"))
                    } icon: {
                        Image(systemName: "arrow.down.doc")
                            .foregroundStyle(.red)     // couleur rouge
                            .font(.title2)      // taille un peu plus grande
                    }
                    
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                Button {
                    inspectorIsShown.toggle()
                } label: {
                    Label {
                        Text(String(localized: "Show inspector", table: "MainApp"))
                    } icon: {
                        Image(systemName: "sidebar.right")
                            .foregroundStyle(.red)     // couleur rouge
                            .font(.title2)      // taille un peu plus grande
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
                if dashboard.isVisible == false {
//                    ListTransactions(isVisible: $isVisible, selectedTransaction: $selectedTransaction, isCreationMode: $isCreationMode)
//                        .environmentObject(colorManager)
                }
            }
        }
        .environmentObject(colorManager)  // Injection de ColorManager pour toutes les sous-vues
    }

    private func chooseCouleur(_ color: String) {
        colorManager.colorChoix = color
        selectedColor = color
    }
    
    func tintedSystemImage(named: String, tint: NSColor, size: CGSize = CGSize(width: 18, height: 18)) -> NSImage? {
        guard let base = NSImage(systemSymbolName: named, accessibilityDescription: nil) else { return nil }
        let img = base.copy() as! NSImage
        img.size = size

        // Dessiner la couleur par dessus (méthode simple qui fonctionne pour les symboles template)
        img.lockFocus()
        tint.set()
        let imageRect = NSRect(origin: .zero, size: size)
        imageRect.fill(using: .sourceAtop)
        img.unlockFocus()

        return img
    }
}

// Fonction d'action pour chaque choix de couleur
private func changeSearchFieldItem(_ itemType: String) {
    // Ajoute la logique pour gérer la sélection du champ de recherche
    printTag("Champ de recherche sélectionné : \(itemType)", flag: true)
}

private func setAppearance(_ appearance: NSAppearance.Name) {
    NSApp.appearance = NSAppearance(named: appearance)

    // Pour s'assurer que la fenêtre actuelle est également mise à jour
    if let window = NSApplication.shared.windows.first {
        window.appearance = NSAppearance(named: appearance)
    }
}


// Helper : crée une NSImage colorée à partir d'un SF Symbol

struct AppearancePopoverButton: View {
    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            HStack(spacing: 8) {
                if let ns = coloredSystemImage(named: "paintbrush", tint: .systemRed, size: CGSize(width: 18, height: 18)) {
                    Image(nsImage: ns)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else {
                    // fallback
                    Image(systemName: "paintbrush")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.red)
                }
                Text(String(localized: "", table: "MainApp"))
            }
        }
        .buttonStyle(PlainButtonStyle()) // empêche le système d'imposer un style
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Button("Light")  { NSApp.appearance = NSAppearance(named: .aqua); showing = false }
                Button("Dark")   { NSApp.appearance = NSAppearance(named: .darkAqua); showing = false }
                Button("System") { NSApp.appearance = nil; showing = false }
            }
            .padding()
            .frame(width: 150)
        }
    }
    func coloredSystemImage(named: String, tint: NSColor, size: CGSize = CGSize(width: 18, height: 18)) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: named, accessibilityDescription: nil) else { return nil }
        // Nouvelle image de la bonne taille
        let result = NSImage(size: size)
        result.lockFocus()
        // dessine le symbole dans le rect
        let rect = NSRect(origin: .zero, size: size)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        // applique la couleur en mode sourceAtop (teinte)
        tint.setFill()
        rect.fill(using: .sourceAtop)
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

}

struct SidebarContainer: View {
    @Binding var selection1: UUID?
    @Binding var selection2: String?

    var body: some View {
        VStack(spacing: 0) {
            Sidebar1A()
            Divider()
            Sidebar2A(selection2: $selection2)
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
    }
}

struct DashboardState {
    var isVisible: Bool = true
    var executed: Double = 0
    var planned: Double = 0
    var engaged: Double = 0
}

struct DetailContainer: View {
    @Binding var selection2: String?
    @Binding var selectedTransaction: EntityTransaction?
    @Binding var isCreationMode: Bool

    @Binding var dashboard: DashboardState

    var detailViews: [String: (Binding<Bool>) -> AnyView] {
        [
            String(localized: "List of transactions",table: "Menu")     : { isVisible in
                AnyView(ListTransactionsView100(
                    dashboard: $dashboard)) },
            
            String(localized: "Cash flow curve",table: "Menu")          : { isVisible in
                AnyView(TreasuryCurveView(
                    dashboard: $dashboard)) },

            String(localized: "Bank website",table: "Menu")             : { isVisible in
                AnyView(BankWebsiteView(isVisible            : isVisible,)) },
            String(localized: "Internet rapprochement",table: "Menu")   : { isVisible in AnyView(InternetReconciliationView(isVisible : isVisible)) },
            String(localized: "Bank statement",table: "Menu")           : { isVisible in AnyView(BankStatementView(isVisible          : isVisible)) },
            String(localized: "Notes",table: "Menu")                    : { isVisible in AnyView(NotesView(isVisible                  : isVisible)) },
            
            // Rapport
            String(localized: "Category Bar1",table: "Menu")
            : { isVisible in
                AnyView(CategorieBar1View(
                    dashboard: $dashboard)) },
            String(localized: "Category Bar2",table: "Menu")
            : { isVisible in
                AnyView(CategorieBar2View(
                    dashboard: $dashboard)) },
            String(localized: "Payment method" ,table: "Menu")          : { isVisible in AnyView(ModePaiementPieView(isVisible : isVisible)) },
            String(localized: "Recipe / Expense Bar",table: "Menu")     : { isVisible in AnyView(RecetteDepenseBarView(isVisible: isVisible, dashboard: $dashboard)) },
            String(localized: "Recipe / Expense Pie",table: "Menu")     : { isVisible in AnyView(RecetteDepensePieView(isVisible     : isVisible)) },
            String(localized: "Rubric Bar",table: "Menu")               : { isVisible in AnyView(RubriqueBarView(isVisible           : isVisible)) },
            String(localized: "Rubric Pie" ,table: "Menu")              : { isVisible in AnyView(RubriquePieView(isVisible           : isVisible)) },
            
            // Reglage
            String(localized: "Identity",table: "Menu")                 : {  isVisible in AnyView(Identy(isVisible                   : isVisible)) },
            String(localized: "Scheduler",table: "Menu" )               : {  isVisible in AnyView(SchedulerView(isVisible            : isVisible)) },
            String(localized: "Settings",table: "Menu" )                : {  isVisible in AnyView(SettingView(isVisible              : isVisible))
            }
        ]
    }

    var body: some View {
        VStack {
            if let detailView = localizedDetailView(for: selection2) {
                detailView($dashboard.isVisible)
            } else {
                Text("Content for Sidebar 2 \(selection2 ?? "")")
            }
        }
    }

    func localizedDetailView(for selection: String?) -> ((Binding<Bool>) -> AnyView)? {
        guard let selection = selection else { return nil }
        return detailViews[selection]
    }
}


struct Sidebar2A: View {
    @Binding var selection2: String?

    var body: some View {
        let datas = Bundle.main.decode([Datas].self, from: "Feeds.plist")

        List(selection: $selection2) {
            ForEach(datas) { section in
                Section(section.name) {
                    ForEach(section.children) { child in
                        Label {
                            Text(child.name)
                                .font(.system(size: 11)) // plus petit
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } icon: {
                            Image(systemName: child.icon)
                                .font(.system(size: 13)) // icône plus petit
                        }
                        .tag(child.name)
                        .frame(minHeight: 10, maxHeight: 14) // Hauteur réduite
//                        .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)) // marges réduites
                        .padding(.vertical, 0) // retire les espaces verticaux
                    }
                }
            }
        }
        .navigationTitle("Display")
        .listStyle(SidebarListStyle())
        .listRowSeparator(.hidden)
        .frame(maxHeight: .infinity)
        .environment(\.defaultMinListRowHeight, 18) // hauteur min liste réduite
    }
}

