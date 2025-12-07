//
//  exportTransactions.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 27/03/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVEXportTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFileExporter = false
    @State private var exportURL: URL?

    var body: some View {
        Button("Export CSV") {
            showFileExporter = true
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: CSVDocument(data: ""),
            contentType: .commaSeparatedText,
            defaultFilename: "Transactions.csv"
        ) { result in
            switch result {
            case .success(let url):
                exportTransactions(to: url)
            case .failure(let error):
                printTag("Erreur d'exportation : \(error.localizedDescription)", flag: true)
            }
            dismiss()
        }
        .onAppear {
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var data: String

    init(data: String) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data(data.utf8))
    }
}


func exportTransactions(to url: URL) {
    let transactions = ListTransactionsManager.shared.getAllData()
    
    let header = "datePointage,dateOperation,libelle,category,rubric,paymentMode,status,bankStatement,amount"
    var csvContent = "\(header)\n"
    
    for transaction in transactions {
        let line = [
            transaction.datePointage.toCSVFormat(),
            transaction.dateOperation.toCSVFormat(),
            transaction.sousOperations.first?.libelle ?? "",
            transaction.sousOperations.first?.category?.name ?? "",
            transaction.sousOperations.first?.category?.rubric?.name ?? "",
            transaction.paymentMode?.name ?? "",
            transaction.status?.name ?? "",
            transaction.bankStatementString,
            String(format: "%.2f", transaction.sousOperations.first?.amount ?? 0.0)
        ].joined(separator: ",")
        
        csvContent.append("\(line)\n")
    }
    
    do {
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
        printTag("✅ Export réussi vers \(url.path)", flag: true)
    } catch {
        printTag("❌ Erreur lors de l'export : \(error.localizedDescription)", flag: true)
    }
}

// Extension pour formater les dates
extension Date {
    func toCSVFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: self)
    }
}
