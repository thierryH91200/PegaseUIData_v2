//
//  Content.swift
//  PegaseUI
//
//  Main content view - Refactored for better organization
//  Components extracted to separate files in Group/Content/
//

import SwiftUI
import AppKit
import SwiftData
import Combine

struct ContentView100: View {

    @AppStorage("choixCouleur") var choixCouleur: String = "Unie"

    @EnvironmentObject var containerManager: ContainerManager

    @StateObject private var currentAccountManager = CurrentAccountManager.shared
    @StateObject private var transactionManager = TransactionSelectionManager()
    @StateObject private var colorManager = ColorManager()

    @State private var selectedTransaction: EntityTransaction?
    @State private var isCreationMode: Bool = true

    @State private var showCSVTransactionImporter = false
    @State private var showOFXTransactionImporter = false
    @State private var showCSVTransactionExporter = false

    var transactions: [EntityTransaction] = []

    @State private var selection1: UUID?
    @State private var selection2: String? = String(localized:"Notes", table: "Menu")
//    @State private var selection2: String? = String(localized:"List of transactions", table: "Menu")
    @State private var isVisible: Bool = true
    @State private var isToggle: Bool = false

    @State private var entityAccount: [EntityAccount] = []
    @State private var inspectorIsShown: Bool = false

    @State private var showImportOFX = false
    @StateObject private var viewModel = CSVViewModel()

    @State private var selectedColor: String? = "United"

    @State private var dashboard: DashboardState = DashboardState()

    @State private var contentSize: CGSize = .zero
    var isCompactContent: Bool {
        contentSize.width < 600
    }

    var body: some View {
        HStack {
            NavigationSplitView {
                SidebarContainer(selection1: $selection1, selection2: $selection2)
                    .navigationSplitViewColumnWidth(min: 256, ideal: 256, max: 400)
            }
            content: {
                GeometryReader { geo in
                    DetailContainer(
                        selection2: $selection2,
                        selectedTransaction: $selectedTransaction,
                        isCreationMode: $isCreationMode,
                        dashboard: $dashboard
                    )
                    .onAppear {
                        contentSize = geo.size
                    }
                    .onChange(of: geo.size) { oldSize, newSize in
                        contentSize = newSize
                    }
                }
                .onChange(of: isCompactContent) { pld, compact in
//                    dashboard.isVisible = !compact   // exemple métier
                }
                .navigationSplitViewColumnWidth(min: 150, ideal: 800)
            }
            detail: {
                if dashboard.isVisible {
                    OperationDialog()
                }
            }
            .environmentObject(transactionManager)
            .environmentObject(currentAccountManager)
            .navigationSplitViewStyle(.automatic)
        }
        // Example: adapt business logic / layout based on content width
        // contentSize.width < 600 => compact mode
        .onReceive(NotificationCenter.default.publisher(for: .importTransaction)) { _ in
            showCSVTransactionImporter = true
        }
        .sheet(isPresented: $showCSVTransactionImporter) {
            ImportTransactionFileView()
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
            CSVEXportTransactionView()
        }
        .toolbar {
            ContentToolbar(
                viewModel: viewModel,
                colorManager: colorManager,
                inspectorIsShown: $inspectorIsShown,
                selectedColor: $selectedColor
            )
        }
        .environmentObject(colorManager)
    }
}

// MARK: - Sidebar Container

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

// MARK: - Detail Container

struct DetailContainer: View {
    @Binding var selection2: String?
    @Binding var selectedTransaction: EntityTransaction?
    @Binding var isCreationMode: Bool
    @Binding var dashboard: DashboardState

    var detailViews: [String: (Binding<Bool>) -> AnyView] {
        [
            String(localized: "List of transactions", table: "Menu"): { _ in
                AnyView(TransactionListContainer(dashboard: $dashboard))
            },
            String(localized: "Cash flow curve", table: "Menu"): { _ in
                AnyView(TreasuryCurveView(dashboard: $dashboard))
            },
            String(localized: "Filter", table: "Menu"): { isVisible in
                AnyView(HybridContentData100(isVisible: isVisible))
            },
            String(localized: "Internet rapprochement", table: "Menu"): { isVisible in
                AnyView(InternetReconciliationView(isVisible: isVisible))
            },
            String(localized: "Bank statement", table: "Menu"): { isVisible in
                AnyView(BankStatementView(dashboard: $dashboard, isVisible: isVisible))
            },
            String(localized: "Notes", table: "Menu"): { isVisible in
                AnyView(NotesView(isVisible: isVisible))
            },

            // Rapport
            String(localized: "Category Bar1", table: "Menu"): { _ in
                AnyView(CategorieBar1View(dashboard: $dashboard))
            },
            String(localized: "Category Bar2", table: "Menu"): { _ in
                AnyView(CategorieBar2View(dashboard: $dashboard))
            },
            String(localized: "Payment method", table: "Menu"): { _ in
                AnyView(ModePaiementPieView(dashboard: $dashboard))
            },
            String(localized: "Recipe / Expense Bar", table: "Menu"): { _ in
                AnyView(RecetteDepenseBarView(dashboard: $dashboard))
            },
            String(localized: "Recipe / Expense Pie", table: "Menu"): { _ in
                AnyView(RecetteDepensePieView(dashboard: $dashboard))
            },
            String(localized: "Rubric Bar", table: "Menu"): { _ in
                AnyView(RubriqueBarView(dashboard: $dashboard))
            },
            String(localized: "Rubric Pie", table: "Menu"): { _ in
                AnyView(RubriquePieView(dashboard: $dashboard))
            },

            // Reglage
            String(localized: "Identity", table: "Menu"): { isVisible in
                AnyView(Identy(isVisible: isVisible))
            },
            String(localized: "Scheduler", table: "Menu"): { isVisible in
                AnyView(SchedulerView(isVisible: isVisible))
            },
            String(localized: "Settings", table: "Menu"): { isVisible in
                AnyView(SettingView(isVisible: isVisible))
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

// MARK: - Sidebar 2

struct Sidebar2A: View {
    @Binding var selection2: String?

    var body: some View {
        let datas = (try? Bundle.main.decode([Datas].self, from: "Feeds.plist")) ?? []
        let safeDatas: [Datas] = datas

//        let datas = Bundle.main.decode([Datas].self, from: "Feeds.plist")

        List(selection: $selection2) {
            ForEach(safeDatas) { section in
                Section(section.name) {
                    ForEach(section.children) { child in
                        Label {
                            Text(child.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } icon: {
                            Image(systemName: child.icon)
                                .font(.system(size: 13))
                        }
                        .tag(child.name)
                        .frame(minHeight: 10, maxHeight: 14)
                        .padding(.vertical, 0)
                    }
                }
            }
        }
        .navigationTitle("Display")
        .listStyle(SidebarListStyle())
        .listRowSeparator(.hidden)
        .frame(maxHeight: .infinity)
        .environment(\.defaultMinListRowHeight, 18)
    }
}
