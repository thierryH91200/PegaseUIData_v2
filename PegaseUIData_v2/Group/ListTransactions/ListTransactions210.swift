


//
//  ListTransactions2.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 23/03/2025.
//

import SwiftUI
import SwiftData


struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private var transaction: EntityTransaction {
        ListTransactionsManager.shared.listTransactions[currentSectionIndex]
    }
    
    @State var currentSectionIndex: Int
    @Binding var selectedTransaction: Set<UUID>
    @State var refresh = false
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: { showPreviousSection() }) {
                    Text("◀️")
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .disabled(currentSectionIndex == 0)
                
                Spacer()
                
                Button(action: { showNextSection() }) {
                    Text("▶️")
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .disabled(currentSectionIndex >= ListTransactionsManager.shared.listTransactions.count - 1)
            }
            .padding()
            
            Text("Transaction Details")
                .font(.title)
                .bold()
                .padding(.bottom, 10)
            
            HStack {
                Text("Created at :")
                    .bold()
                Spacer()
                Text(Self.dateFormatter.string(from: transaction.createAt))
            }
            HStack {
                Text("Update at :")
                    .bold()
                Spacer()
                Text(Self.dateFormatter.string(from: transaction.updatedAt))
            }
            
            Divider()
            
            HStack {
                Text("Amount :")
                    .bold()
                Spacer()
                Text("\(String(format: "%.2f", transaction.amount)) €")
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
            }
            Divider()
            
            HStack {
                Text("Date of pointing :")
                    .bold()
                Spacer()
                Text(Self.dateFormatter.string(from: transaction.datePointage))
            }
            HStack {
                Text("Date operation :")
                    .bold()
                Spacer()
                Text(Self.dateFormatter.string(from: transaction.dateOperation))
            }
            HStack {
                Text("Payment method :")
                    .bold()
                Spacer()
                Text(transaction.paymentMode?.name ?? "—")
            }
            HStack {
                Text("Bank Statement :")
                    .bold()
                Spacer()
                Text(String(transaction.bankStatement))
            }
            
            HStack {
                Text("Status :")
                    .bold()
                Spacer()
                Text(transaction.status?.name ?? "N/A")
            }
            
            Divider()
            
            // Section pour les sous-opérations
            if let premiereSousOp = transaction.sousOperations.first {
                HStack {
                    Text("Comment :")
                        .bold()
                    Spacer()
                    Text(premiereSousOp.libelle ?? "Sans libellé")
                }
                HStack {
                    Text("Rubric :")
                        .bold()
                    Spacer()
                    Text(premiereSousOp.category?.rubric?.name ?? "N/A")
                }
                HStack {
                    Text("Category :")
                        .bold()
                    Spacer()
                    Text(premiereSousOp.category?.name ?? "N/A")
                }
                HStack {
                    Text("Amount :")
                        .bold()
                    Spacer()
                    Text("\(String(format: "%.2f", premiereSousOp.amount)) €")
                        .foregroundColor(premiereSousOp.amount >= 0 ? .green : .red)
                }
            } else {
                Text("No sub-operations available")
                    .italic()
                    .foregroundColor(.gray)
            }
            
            // Si vous avez plusieurs sous-opérations, vous pourriez ajouter une liste ici
            
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    //                    transactionManager.selectedTransaction = nil
                    dismiss()
                }) {
                    Text("Close")
                        .frame(width: 100)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            if let index = ListTransactionsManager.shared.listTransactions.firstIndex(where: { $0.uuid == selectedTransaction.first }) {
                currentSectionIndex = index
            }
        }
    }
    
    private func showPreviousSection() {
        guard currentSectionIndex > 0 else { return }
        currentSectionIndex -= 1
    }
    
    private func showNextSection() {
        guard currentSectionIndex < ListTransactionsManager.shared.listTransactions.count - 1 else { return }
        currentSectionIndex += 1
    }
}

//    .onAppear {
//        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
//            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
//                // Tout sélectionner
//                for transaction in dataManager.listTransactions {
//                    selectedTransactions.insert(transaction.id)
//                }
//                transactionManager.selectedTransactions = dataManager.listTransactions
//                return nil
//            }
//            if event.keyCode == 53 { // Escape key
//                // Tout désélectionner
//                selectedTransactions.removeAll()
//                transactionManager.selectedTransaction = nil
//                transactionManager.selectedTransactions = []
//                return nil
//            }
//            return event
//        }
//    }
