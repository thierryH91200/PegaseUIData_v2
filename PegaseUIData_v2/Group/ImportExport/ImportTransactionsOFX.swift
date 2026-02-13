//
//  ImportTransactionsOFX.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 24/05/2025.
//


import SwiftUI
import Foundation
import SwiftData
import UniformTypeIdentifiers
import Combine
import OSLog


struct ImportTransactionOFXFileView: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var isPresented: Bool
    @State private var showOFXImporter = false
    @State private var isImporting = false

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
                    .fixedSize()

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
            }
        }
        .onAppear {
            showOFXImporter = true
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
                    importOFXTransactions(from: url)
                    isImporting = false
                    isPresented = false
                } else {
                    isPresented = false
                }
            case .failure(let error):
                AppLogger.importExport.error("OFX file selection failed: \(error.localizedDescription)")
                ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
                isPresented = false
            }
        }
    }

    private func importOFXTransactions(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            AppLogger.importExport.error("Cannot access OFX file (Security Scoped)")
            ToastManager.shared.show(
                NSLocalizedString("Cannot access the file", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
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
            AppLogger.importExport.error("Cannot read OFX file with any known encoding")
            ToastManager.shared.show(
                NSLocalizedString("Failed to read OFX file", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
            return
        }

        guard let account = CurrentAccountManager.shared.getAccount() else {
            AppLogger.importExport.error("OFX import: no account selected")
            ToastManager.shared.show(
                NSLocalizedString("No account selected for import", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
            return
        }

        let entityPreference = PreferenceManager.shared.getAllData()

        let blocks = content.components(separatedBy: "<STMTTRN>").dropFirst()
        let count = blocks.count
        AppLogger.importExport.info("Importing \(count) OFX transactions")

        for block in blocks {
            guard let end = block.range(of: "</STMTTRN>") else { continue }
            let transactionBlock = String(block[..<end.lowerBound])

            func extract(_ tag: String) -> String {
                guard let range = transactionBlock.range(of: "<\(tag)>") else { return "" }
                let after = transactionBlock[range.upperBound...]
                return after.prefix(while: { $0 != "\n" && $0 != "\r" }).trimmingCharacters(in: .whitespaces)
            }

            let name = extract("NAME")
            let memo = extract("MEMO")

            let amountString = extract("TRNAMT").replacingOccurrences(of: "+", with: "")
            let amount = Double(amountString) ?? 0.0
            let dateString = extract("DTPOSTED").prefix(8)
            let date = DateFormatter.ofxDate.date(from: String(dateString)) ?? Date()

            var transaction = EntityTransaction(account: account)
            transaction.createAt  = Date().noon
            transaction.updatedAt = Date().noon
            transaction.dateOperation = date.noon
            transaction.datePointage  = date.noon
            transaction.paymentMode   = entityPreference?.paymentMode
            transaction.status        = entityPreference?.status
            transaction.bankStatement = 0.0
            transaction.checkNumber   = "0"

            let sousTransaction = EntitySousOperation()
            sousTransaction.libelle  = name.isEmpty ? memo : name
            sousTransaction.amount   = amount
            sousTransaction.category = entityPreference?.category

            transaction = ListTransactionsManager.shared.addSousTransaction(transaction: transaction, sousTransaction: sousTransaction)
        }

        do {
            try ListTransactionsManager.shared.save()
            AppLogger.importExport.info("OFX import successful")
            ToastManager.shared.show(
                NSLocalizedString("Import successful", comment: ""),
                icon: "checkmark.circle.fill",
                type: .success
            )
            NotificationCenter.default.post(name: .transactionsImported, object: nil)
        } catch {
            AppLogger.importExport.error("OFX import save failed: \(error.localizedDescription)")
            ToastManager.shared.show(
                NSLocalizedString("Import failed", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
        }
    }
}
