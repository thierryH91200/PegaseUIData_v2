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

struct MainContentView: View {

    @AppStorage("choixCouleur") var choixCouleur: String = "Unie"

    @EnvironmentObject var containerManager: ContainerManager
    @EnvironmentObject var container: AppContainer

    @State private var selectedTransaction: EntityTransaction?
    @State private var isCreationMode: Bool = true

    @State private var showCSVTransactionImporter = false
    @State private var showOFXTransactionImporter = false
    @State private var showCSVTransactionExporter = false

    var transactions: [EntityTransaction] = []

    @State private var selection1: UUID?
    @State private var selection2: DetailViewKind? = .notes
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
            .environmentObject(container.transactionSelection)
            .environmentObject(container.currentAccount)
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
                colorManager: container.colors,
                inspectorIsShown: $inspectorIsShown,
                selectedColor: $selectedColor
            )
        }
        .environmentObject(container.colors)
    }
}

// MARK: - Sidebar Container
struct SidebarContainer: View {
    @Binding var selection1: UUID?
    @Binding var selection2: DetailViewKind?

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
    @Binding var selection2: DetailViewKind?
    @Binding var selectedTransaction: EntityTransaction?
    @Binding var isCreationMode: Bool
    @Binding var dashboard: DashboardState

    var body: some View {
        VStack {
            switch selection2 {
            // Suivi de trésorerie
            case .transactionList:
                TransactionListContainer(dashboard: $dashboard)
            case .cashFlowCurve:
                TreasuryCurveView(dashboard: $dashboard)
            case .filter:
                HybridContentData100(isVisible: $dashboard.isVisible)
            case .internetReconciliation:
                InternetReconciliationView(isVisible: $dashboard.isVisible)
            case .bankStatement:
                BankStatementView(dashboard: $dashboard, isVisible: $dashboard.isVisible)
            case .notes:
                NotesView(isVisible: $dashboard.isVisible)

            // Rapports
            case .categoryBar1:
                CategorieBar1View(dashboard: $dashboard)
            case .categoryBar2:
                CategorieBar2View(dashboard: $dashboard)
            case .paymentMethod:
                ModePaiementPieView(dashboard: $dashboard)
            case .incomeExpenseBar:
                RecetteDepenseBarView(dashboard: $dashboard)
            case .incomeExpensePie:
                RecetteDepensePieView(dashboard: $dashboard)
            case .rubricBar:
                RubriqueBarView(dashboard: $dashboard)
            case .rubricPie:
                RubriquePieView(dashboard: $dashboard)

            // Référence compte
            case .identity:
                Identy(isVisible: $dashboard.isVisible)
            case .scheduler:
                SchedulerView(isVisible: $dashboard.isVisible)
            case .settings:
                SettingView(isVisible: $dashboard.isVisible)

            case nil:
                Text("Select an item")
            }
        }
    }
}

// MARK: - Sidebar 2

struct Sidebar2A: View {
    @Binding var selection2: DetailViewKind?

    var body: some View {
        let datas = (try? Bundle.main.decode([Datas].self, from: "Feeds.plist")) ?? []

        List(selection: $selection2) {
            ForEach(datas) { section in
                Section(section.name) {
                    ForEach(section.children) { child in
                        if let kind = child.detailViewKind {
                            Label {
                                Text(child.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            } icon: {
                                Image(systemName: child.icon)
                                    .font(.system(size: 13))
                            }
                            .tag(kind)
                            .frame(minHeight: 10, maxHeight: 14)
                            .padding(.vertical, 0)
                        }
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
