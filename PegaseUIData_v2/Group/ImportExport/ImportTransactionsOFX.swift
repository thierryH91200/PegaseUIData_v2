//
//  Untitled.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 24/05/2025.
//


import SwiftUI
import Foundation
import SwiftData
import UniformTypeIdentifiers
import Combine


struct ImportTransactionOFXFileView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var isPresented: Bool // Permet de fermer la sheet depuis l'intérieur
    @State private var showOFXImporter = false
    @State private var isImporting = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            
            if isImporting {
                VStack {
                    Spacer()
                    
                    ProgressView("Importing the OFX file…")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        .shadow(radius: 5)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                    .fixedSize() // Ajuste la taille au contenu

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
            }
        }
        .onAppear {
            // Ouvre automatiquement le fileImporter dès l’apparition de la sheet
//            showOFXImporter = true
        }
        .fileImporter(
            isPresented: $showOFXImporter,
            allowedContentTypes: [UTType(filenameExtension: "ofx")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    isImporting = true
                    importOFXTransactions(from: url, into: modelContext, isPresented: $isPresented)
                    // Ajoute ici un callback ou une fermeture automatique si souhaité :
                     isPresented = false
                } else {
                    // Annulation ou aucun fichier choisi
                    isPresented = false
                }
            case .failure:
                // Annulation ou erreur
                isPresented = false
            }
            isImporting = false
        }
    }
    
    private func importOFXTransactions(from url: URL, into context: ModelContext,
                                       isPresented: Binding<Bool>) {
        guard url.startAccessingSecurityScopedResource() else {
            printTag("⚠️ Impossible d'accéder au fichier OFX (Security Scoped)")
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
            printTag("⚠️ Impossible de lire le contenu du fichier OFX avec les encodages connus.")
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
        isPresented.wrappedValue = false
    }
}



