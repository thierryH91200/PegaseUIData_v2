//import SwiftUI
//import Combine
//#if os(macOS)
//import AppKit
//#endif
//
//import SwiftData
//import SwiftDate
//
//struct HybridContentData: View {
//    @Binding var dashboard: DashboardState
//    
//    @Environment(\.modelContext) private var modelContext
//    @Query private var allPersons: [EntityTransaction]
//
//    @State private var currentPredicate: NSPredicate?
//    @State private var displayedPersons: [EntityTransaction] = []
//    @State private var parsedSwiftDataPredicate: String = ""
//    @State private var showingAddPerson = false
//    @State private var isFiltered = false
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // NSPredicateEditor embedded in SwiftUI
//
//            NSPredicateEditorView(
//                predicate: $currentPredicate,
//                onPredicateChange: applyPredicate
////                rowTemplates: PredicateEditorView.defaultRowTemplates()
//            )
//            .frame(minHeight: 220)
//            .overlay(
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(.primary.opacity(0.25), lineWidth: 1)
//            )
//            .padding( 12)
//
//            VStack(spacing: 12) {
//                
//                TransactionListContainer(dashboard: $dashboard)
//                    .task {
//                    }
//            }
//            .padding()
//        }
//        .frame(maxHeight: .infinity, alignment: .top)
//    }
//    private func applyPredicate() {
//        guard let predicate = currentPredicate else {
//            clearPredicate()
//            return
//        }
//        
//        print("=== APPLY PREDICATE ===")
//        print("NSPredicate: \(predicate)")
//        print("Predicate format: \(predicate.predicateFormat)")
//        
//        // Vérifier que le prédicat est complet
//        let predicateString = predicate.predicateFormat
//        if predicateString.isEmpty || predicateString.contains("nil") {
//            print("Predicate incomplete, skipping filter")
//            return
//        }
//        
//        // Filtrer les personnes en convertissant chaque personne en dictionnaire
//        displayedPersons = allPersons.filter { transaction in
//            let dict: [String: Any] = [
//                "status": transaction.status?.name ?? "Unknown",
//                "mode": transaction.paymentMode?.name ?? "Unknown",
//            ]
//            
//            return predicate.evaluate(with: dict)
//        }
//        
//        // Convertir en SwiftData predicate
//        parsedSwiftDataPredicate = convertToSwiftDataPredicate(predicate)
//        
//        isFiltered = true
//        
//        print("Filtered: \(displayedPersons.count) / \(allPersons.count)")
//    }
//    
//    private func clearPredicate() {
//        currentPredicate = nil
//        displayedPersons = allPersons
//        parsedSwiftDataPredicate = ""
//        isFiltered = false
//    }
//    
//    private func convertToSwiftDataPredicate(_ predicate: NSPredicate) -> String {
//        let predicateString = predicate.predicateFormat
//        
//        // Conversion basique du format NSPredicate vers SwiftData
//        var converted = predicateString
//        
//        // Remplacer les noms de clés par person.property
//        let properties = ["status", "mode"]
//        for property in properties {
//            converted = converted.replacingOccurrences(of: property, with: "transaction.\(property)")
//        }
//        
//        // Remplacer les opérateurs NSPredicate par Swift
//        converted = converted.replacingOccurrences(of: " AND ", with: " && ")
//        converted = converted.replacingOccurrences(of: " OR ", with: " || ")
//        converted = converted.replacingOccurrences(of: " NOT ", with: " !")
//        converted = converted.replacingOccurrences(of: "BEGINSWITH", with: "hasPrefix")
//        converted = converted.replacingOccurrences(of: "ENDSWITH", with: "hasSuffix")
//        converted = converted.replacingOccurrences(of: "CONTAINS", with: "contains")
//        
//        return "#Predicate<EntityTransaction> { transaction in\n    \(converted)\n}"
//    }
//    
//    private func addSampleData() {
//    }
//}
//
//
