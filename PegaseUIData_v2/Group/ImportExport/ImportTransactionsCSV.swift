//
//  ImportTransactions.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 19/03/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import SwiftData
import Combine


struct ImportTransactionFileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showFileImporter = false
    @State private var showOFXImporter = false
    @State private var csvData: [[String]] = []
    @State private var columnMapping: [String: Int] = [:] // Associe les attributs aux colonnes
    
    // Attributs disponibles
    let transactionAttributes = [String(localized:"Pointage Date"),
                                 String(localized:"Operation Date"),
                                 String(localized:"Comment"),
                                 String(localized:"Rubric"),
                                 String(localized:"Category"),
                                 String(localized:"Payment method"),
                                 String(localized:"Status"),
                                 String(localized:"Amount")]
    
    var body: some View {
        VStack {
            Button("Import a CSV file") {
                showFileImporter = true
            }
            .frame(width: 200, height: 30, alignment: .center)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, let data = readCSV(from: url) {
                        csvData = data
                    }
                case .failure(let error):
                    printTag("Erreur de sélection de fichier : \(error.localizedDescription)", flag: true)
                }
            }
            Spacer()
            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16) // réduit la hauteur
                    .padding(.vertical, 4)    // réduit la hauteur
                    .background(Color.red)
                    .cornerRadius(8)
            }
           
            
//            Button("Import an OFX file") {
//                showOFXImporter = true
//            }
//            .frame(width: 200, height: 30, alignment: .center)
//            .fileImporter(
//                isPresented: $showOFXImporter,
//                allowedContentTypes: [.data],
//                allowsMultipleSelection: false
//            ) { result in
//                switch result {
//                case .success(let urls):
//                    if let url = urls.first {
//                        importOFXTransactions(from: url, context: modelContext)
//                        dismiss()
//                    }
//                case .failure(let error):
//                    printTag("Erreur de sélection de fichier OFX : \(error.localizedDescription)")
//                }
//            }
            
            if !csvData.isEmpty {
                Text("CSV Preview").font(.headline)
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        TableView(data: csvData)
                    }
                    .frame(minWidth: {
                        let columns = max(1, csvData.first?.count ?? 1)
                        let cellWidth: CGFloat = 120
                        let computed = CGFloat(columns) * cellWidth
                        return computed.isFinite ? min(computed, 20000) : cellWidth
                    }(), alignment: .leading)
                    .background(Color.clear)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Match the columns :").font(.headline)
                ForEach(transactionAttributes, id: \.self) { attribute in
                    Picker(attribute, selection: Binding(
                        get: { columnMapping[attribute] ?? -1 },
                        set: { columnMapping[attribute] = $0 }
                    )) {
                        let csvData1 = csvData.dropFirst()
                        Text("Ignore").tag(-1)
                        ForEach(0..<(csvData1.first?.count ?? 0), id: \.self) { index in
                            Text("Column \(index)").tag(index)
                        }
                    }
                    .frame(width: 300) // Réduit la largeur du picker
                    .pickerStyle(MenuPickerStyle()) // Utilisation d'un menu déroulant compact
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        importCSVTransactions(context: modelContext)
                        dismiss()
                    }) {
                        Label("Import", systemImage: "tray.and.arrow.down")
                            .padding()
                            .background( Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(columnMapping.isEmpty)
                            .fixedSize() // Ajuste automatiquement la taille au contenu
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Cancel", systemImage: "stop")
                            .padding()
                            .background( Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(columnMapping.isEmpty)
                            .fixedSize() // Ajuste automatiquement la taille au contenu
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .frame(minWidth: 1400, minHeight: 700)
    }
    
    // Fonction d'importation
    func importCSVTransactions(context: ModelContext) {
        guard !csvData.isEmpty else { return }
        
        let count = csvData.count
        printTag("Importation de \(count) transactions CSV.", flag: true)
        
        let account = CurrentAccountManager.shared.getAccount()!

        let entityPreference = PreferenceManager.shared.getAllData(for: account)
        
        for row in csvData.dropFirst() { // Ignorer l'en-tête
            
            let dateOperation = getDate(from: row, index: columnMapping[String(localized:"Operation Date")]) ?? Date().noon
            let datePointage =  getDate(from: row, index: columnMapping[String(localized:"Pointage Date")])  ?? dateOperation

            let libelle = getString(from: row, index: columnMapping[String(localized:"Comment")])
            
            let bankStatement = 0.0
            
            //            let rubric = getString(from: row, index: columnMapping[String(localized:"Rubric")])
            let category = getString(from: row, index: columnMapping[String(localized:"Category")])
            
            let entityCategory = CategoryManager.shared.find( name: category) ?? entityPreference?.category
            
            let paymentMode = getString(from: row, index: columnMapping[String(localized:"Payment method")])
            let entityModePaiement = PaymentModeManager.shared.find(account: account, name: paymentMode) ?? entityPreference?.paymentMode
            
            let status = getString(from: row, index: columnMapping[String(localized:"Status")])
            let entityStatus = StatusManager.shared.find(name: status) ?? entityPreference?.status
            
            let amount = getDouble(from: row, index: columnMapping[String(localized:"Amount")])
            
            let transaction = EntityTransaction()
            transaction.createAt  = Date().noon
            transaction.updatedAt = Date().noon
            
            transaction.dateOperation = dateOperation.noon
            transaction.datePointage  = datePointage.noon
            transaction.paymentMode   = entityModePaiement
            transaction.status        = entityStatus
            transaction.bankStatement = bankStatement
            transaction.checkNumber   = "0"
            transaction.account       = account
            
            context.insert(transaction)

            let sousTransaction = EntitySousOperation()
            sousTransaction.libelle  = libelle
            sousTransaction.amount  = amount
            sousTransaction.category = entityCategory
            sousTransaction.transaction = transaction
            
            context.insert(sousTransaction)
            transaction.addSubOperation(sousTransaction)
        }
        
        do {
            try context.save()
            printTag("Importation réussie 🎉", flag: true)
            NotificationCenter.default.post(name: .transactionsImported, object: nil)

        } catch {
            printTag("Erreur lors de l'enregistrement : \(error)", flag: true)
        }
    }
    
    func readCSV(from url: URL) -> [[String]]? {
        
        guard url.startAccessingSecurityScopedResource() else {
            printTag("⚠️ Impossible d'accéder au fichier (Security Scoped)", flag: true)
            return nil
        }
        
        defer { url.stopAccessingSecurityScopedResource() } // Libérer l'accès à la fin
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Détecter le séparateur
            let separator: Character = content.contains(";") ? ";" : ","
            
            let parsedData = rows.map { $0.components(separatedBy: String(separator)) }
            return parsedData
        } catch {
            printTag("Erreur lors de la lecture du fichier CSV : \(error.localizedDescription)", flag: true)
            return nil
        }
    }

    
    // Fonctions utilitaires
    func getString(from row: [String], index: Int?) -> String {
        guard let index = index, index >= 0, index < row.count else { return "" }
        return row[index]
    }
    
    func getDouble(from row: [String], index: Int?) -> Double {
        guard let index = index, index >= 0, index < row.count else { return 0.0 }
        let value = row[index].replacingOccurrences(of: String(","), with: ".")
        return Double(value) ?? 0.0
    }
    
    func getDate(from row: [String], index: Int?) -> Date? {
        guard let index = index, index >= 0, index < row.count else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy" // Ajuste selon le format de ton CSV
        return formatter.date(from: row[index])?.noon
    }
}

struct TableView: View {
    let data: [[String]]
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(0..<min(5, data.count), id: \.self) { rowIndex in
                HStack {
                    ForEach(data[rowIndex].indices, id: \.self) { colIndex in
                        VStack {
                            if rowIndex == 0 {
                                Text("Column \(colIndex)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Text(data[rowIndex][colIndex])
                        }
                        .frame(width: 120, height: rowIndex == 0 ? 60 : 30)
                        .border(Color.gray)
                    }
                }
            }
        }
    }

    
    @MainActor func importOFXTransactions(from url: URL, context: ModelContext) {
        guard url.startAccessingSecurityScopedResource() else {
            printTag("⚠️ Impossible d'accéder au fichier OFX (Security Scoped)", flag: true)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let encodings: [String.Encoding] = [.utf8, .windowsCP1252, .isoLatin1, .macOSRoman]
        
        var content: String? = nil
        for encoding in encodings {
            if let result = try? String(contentsOf: url, encoding: encoding), !result.isEmpty {
                content = result
                break
            }
        }
        guard let content = content else {
            printTag("⚠️ Impossible de lire le contenu du fichier OFX avec les encodages connus.", flag: true)
            return
        }
        
        let blocks = content.components(separatedBy: "<STMTTRN>").dropFirst()
        for block in blocks {
            guard let end = block.range(of: "</STMTTRN>") else { continue }
            let transaction = String(block[..<end.lowerBound])
            
            func extract(_ tag: String) -> String {
                guard let range = transaction.range(of: "<\(tag)>") else { return "" }
                let after = transaction[range.upperBound...]
                return after.prefix(while: { $0 != "\n" && $0 != "\r" }).trimmingCharacters(in: .whitespaces)
            }
            
            //        let type = extract("TRNTYPE")
            let name = extract("NAME")
            //        let memo = extract("MEMO")
            
            let amountString = extract("TRNAMT").replacingOccurrences(of: "+", with: "")
            let amount = Double(amountString) ?? 0.0
            let dateString = extract("DTPOSTED").prefix(8)
            let date = DateFormatter.ofxDate.date(from: String(dateString)) ?? Date()
            
            let account = CurrentAccountManager.shared.getAccount()!
            
            let entityTransaction = EntityTransaction()
            entityTransaction.dateOperation = date.noon
            entityTransaction.datePointage = date.noon
            entityTransaction.account = account
            entityTransaction.checkNumber = "0"
            entityTransaction.bankStatement = 0.0
            
            let preference = PreferenceManager.shared.getAllData(for: account)
            entityTransaction.status = preference?.status
            entityTransaction.paymentMode = preference?.paymentMode
            
            let sousOperation = EntitySousOperation()
            sousOperation.amount = amount
            sousOperation.libelle = name
            sousOperation.category = preference?.category
            sousOperation.transaction = entityTransaction
            
            context.insert(sousOperation)
            entityTransaction.addSubOperation(sousOperation)
            context.insert(entityTransaction)
        }
        
        try? context.save()
    }
}

extension DateFormatter {
    static let ofxDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
}

