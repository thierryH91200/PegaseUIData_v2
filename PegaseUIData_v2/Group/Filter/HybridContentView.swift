import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

import SwiftData
import SwiftDate

struct HybridContentData: View {
    @StateObject private var vm = HybridViewModel()
    @Binding var dashboard: DashboardState


    var body: some View {
        VStack(spacing: 0) {
            // NSPredicateEditor embedded in SwiftUI
    #if os(macOS)
            PredicateEditorView(
                predicate: $vm.predicate,
                rowTemplates: PredicateEditorView.defaultRowTemplates()
            )
            .frame(minHeight: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.primary.opacity(0.25), lineWidth: 1)
            )
            .padding(.bottom, 12)
    #else
            Text("Predicate Editor available on macOS")
                .padding(.bottom, 12)
    #endif
            
            VStack(spacing: 12) {
                Text(vm.predicate?.predicateFormat ?? "Aucun prédicat")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                HStack {
                    Text(vm.swiftDataPredicate(from: vm.predicate) != nil ? "Parsed → OK" : "Parsed → nil")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
    #if DEBUG
                    Spacer()
                    Button("Log Predicates") {
                        print("NSPredicate:", vm.predicate?.predicateFormat ?? "nil")
                        let parsed = vm.swiftDataPredicate(from: vm.predicate)
                        print("SwiftData Predicate:", parsed != nil ? "OK" : "nil")
                    }
                    .buttonStyle(.bordered)
    #endif
                }
                ListTransactionsView100(dashboard: $dashboard)


            }
            .padding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

