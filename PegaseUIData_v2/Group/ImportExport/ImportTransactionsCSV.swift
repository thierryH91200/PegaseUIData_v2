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
import OSLog

// MARK: - Enums

enum CSVImportStep: Int, CaseIterable {
    case selectFile = 0
    case previewAndMap = 1
    case importing = 2

    var title: String {
        switch self {
        case .selectFile:    return String(localized: "Select File")
        case .previewAndMap: return String(localized: "Preview & Map")
        case .importing:     return String(localized: "Import")
        }
    }

    var icon: String {
        switch self {
        case .selectFile:    return "doc.badge.plus"
        case .previewAndMap: return "tablecells"
        case .importing:     return "tray.and.arrow.down"
        }
    }
}

enum CSVSeparator: String, CaseIterable, Identifiable {
    case auto      = "Auto"
    case comma     = "Comma (,)"
    case semicolon = "Semicolon (;)"
    case tab       = "Tab"

    var id: String { rawValue }

    var character: Character? {
        switch self {
        case .auto:      return nil
        case .comma:     return ","
        case .semicolon: return ";"
        case .tab:       return "\t"
        }
    }
}

// MARK: - Main View

struct ImportTransactionFileView: View {
    @Environment(\.dismiss) private var dismiss

    // Step
    @State private var currentStep: CSVImportStep = .selectFile

    // File data
    @State private var showFileImporter = false
    @State private var csvData: [[String]] = []
    @State private var columnMapping: [String: Int] = [:]
    @State private var rawCSVContent: String = ""

    // File info
    @State private var fileName: String = ""
    @State private var fileRowCount: Int = 0
    @State private var fileColumnCount: Int = 0

    // Separator
    @State private var detectedSeparator: Character = ","
    @State private var selectedSeparator: CSVSeparator = .auto

    // Drag and drop
    @State private var isDragOver: Bool = false

    // Import
    @State private var isImporting: Bool = false
    @State private var importProgress: Double = 0
    @State private var importCurrentCount: Int = 0

    let transactionAttributes = [
        String(localized: "Pointage Date"),
        String(localized: "Operation Date"),
        String(localized: "Comment"),
        String(localized: "Rubric"),
        String(localized: "Category"),
        String(localized: "Payment method"),
        String(localized: "Status"),
        String(localized: "Amount")
    ]

    var csvHeaders: [String] {
        csvData.first ?? []
    }

    var sampleDataRow: [String] {
        csvData.dropFirst().first ?? []
    }

    var canImport: Bool {
        !csvData.isEmpty && columnMapping.values.contains(where: { $0 >= 0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            CSVStepIndicatorView(currentStep: currentStep)

            Divider()

            // Content
            switch currentStep {
            case .selectFile:
                CSVFileSelectionView(
                    isDragOver: $isDragOver,
                    showFileImporter: $showFileImporter,
                    onFileLoaded: { url in loadFile(from: url) }
                )

            case .previewAndMap:
                ScrollView {
                    VStack(spacing: UIConstants.mediumSpacing) {
                        CSVFileInfoBar(
                            fileName: fileName,
                            rowCount: fileRowCount,
                            columnCount: fileColumnCount,
                            separator: detectedSeparator,
                            selectedSeparator: $selectedSeparator,
                            onSeparatorChange: { reparseCSV() }
                        )

                        CSVPreviewTableView(data: csvData)

                        CSVColumnMappingView(
                            transactionAttributes: transactionAttributes,
                            headers: csvHeaders,
                            sampleRow: sampleDataRow,
                            columnMapping: $columnMapping
                        )
                    }
                    .padding(.vertical, UIConstants.mediumSpacing)
                }

            case .importing:
                CSVImportingView(
                    totalRows: fileRowCount,
                    currentCount: $importCurrentCount,
                    progress: $importProgress
                )
            }

            Divider()

            // Action buttons
            CSVActionButtonsView(
                currentStep: currentStep,
                canProceed: canImport,
                isImporting: isImporting,
                onCancel: { dismiss() },
                onBack: { currentStep = .selectFile },
                onImport: { performImport() }
            )
        }
        .frame(minWidth: 1000, minHeight: 650)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadFile(from: url)
                }
            case .failure(let error):
                AppLogger.importExport.error("File selection failed: \(error.localizedDescription)")
                ToastManager.shared.show(error.localizedDescription, icon: "xmark.circle.fill", type: .error)
            }
        }
    }

    // MARK: - File Loading

    private func loadFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            AppLogger.importExport.error("Cannot access file (Security Scoped)")
            ToastManager.shared.show(
                NSLocalizedString("Cannot access the file", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            rawCSVContent = content
            fileName = url.lastPathComponent

            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            detectedSeparator = detectSeparator(from: rows.first ?? "")

            let separator = selectedSeparator.character ?? detectedSeparator
            csvData = rows.map { $0.components(separatedBy: String(separator)) }
            fileRowCount = max(0, csvData.count - 1)
            fileColumnCount = csvData.first?.count ?? 0
            columnMapping = [:]

            withAnimation {
                currentStep = .previewAndMap
            }
        } catch {
            AppLogger.importExport.error("CSV file read failed: \(error.localizedDescription)")
            ToastManager.shared.show(
                NSLocalizedString("Failed to read CSV file", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
        }
    }

    private func reparseCSV() {
        guard !rawCSVContent.isEmpty else { return }
        let separator = selectedSeparator.character ?? detectedSeparator
        let rows = rawCSVContent.components(separatedBy: "\n").filter { !$0.isEmpty }
        csvData = rows.map { $0.components(separatedBy: String(separator)) }
        fileRowCount = max(0, csvData.count - 1)
        fileColumnCount = csvData.first?.count ?? 0
        columnMapping = [:]
    }

    private func detectSeparator(from firstLine: String) -> Character {
        let commaCount = firstLine.filter { $0 == "," }.count
        let semicolonCount = firstLine.filter { $0 == ";" }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count

        let maxCount = max(commaCount, semicolonCount, tabCount)
        if maxCount == 0 { return "," }
        if tabCount == maxCount { return "\t" }
        if semicolonCount == maxCount { return ";" }
        return ","
    }

    // MARK: - Import

    private func performImport() {
        withAnimation {
            currentStep = .importing
            isImporting = true
        }
        importProgress = 0
        importCurrentCount = 0

        Task { @MainActor in
            await importCSVTransactions()
            isImporting = false
            dismiss()
        }
    }

    private func importCSVTransactions() async {
        guard !csvData.isEmpty else { return }

        guard let account = CurrentAccountManager.shared.getAccount() else {
            AppLogger.importExport.error("CSV import: no account selected")
            ToastManager.shared.show(
                NSLocalizedString("No account selected for import", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
            return
        }

        let dataRows = Array(csvData.dropFirst())
        let total = dataRows.count
        AppLogger.importExport.info("Importing \(total) CSV transactions")

        let entityPreference = PreferenceManager.shared.getAllData()

        // ── Optimisation 1 : Pré-charger les caches de lookup ──
        let categoryIndex = columnMapping[String(localized: "Category")]
        let paymentModeIndex = columnMapping[String(localized: "Payment method")]
        let statusIndex = columnMapping[String(localized: "Status")]

        // Extraire les noms uniques du CSV
        var uniqueCategories = Set<String>()
        var uniquePaymentModes = Set<String>()
        var uniqueStatuses = Set<String>()

        for row in dataRows {
            let cat = getString(from: row, index: categoryIndex)
            if !cat.isEmpty { uniqueCategories.insert(cat) }

            let pm = getString(from: row, index: paymentModeIndex)
            if !pm.isEmpty { uniquePaymentModes.insert(pm) }

            let st = getString(from: row, index: statusIndex)
            if !st.isEmpty { uniqueStatuses.insert(st) }
        }

        // Construire les dictionnaires de cache (1 requête par nom unique au lieu de 1 par ligne)
        var categoryCache: [String: EntityCategory] = [:]
        for name in uniqueCategories {
            categoryCache[name] = CategoryManager.shared.find(name: name)
        }

        var paymentModeCache: [String: EntityPaymentMode] = [:]
        for name in uniquePaymentModes {
            paymentModeCache[name] = PaymentModeManager.shared.find(account: account, name: name)
        }

        var statusCache: [String: EntityStatus] = [:]
        for name in uniqueStatuses {
            statusCache[name] = StatusManager.shared.find(name: name)
        }

        // ── Optimisation 2 : DateFormatter réutilisé ──
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"

        let defaultCategory = entityPreference?.category
        let defaultPaymentMode = entityPreference?.paymentMode
        let defaultStatus = entityPreference?.status
        let batchSize = 100
        let nowNoon = Date().noon

        // ── Boucle d'import optimisée ──
        for (index, row) in dataRows.enumerated() {

            let dateOperation = getDate(from: row, index: columnMapping[String(localized: "Operation Date")], formatter: dateFormatter) ?? nowNoon
            let datePointage  = getDate(from: row, index: columnMapping[String(localized: "Pointage Date")], formatter: dateFormatter) ?? dateOperation

            let libelle = getString(from: row, index: columnMapping[String(localized: "Comment")])

            let category = getString(from: row, index: categoryIndex)
            let entityCategory = categoryCache[category] ?? defaultCategory

            let paymentMode = getString(from: row, index: paymentModeIndex)
            let entityModePaiement = paymentModeCache[paymentMode] ?? defaultPaymentMode

            let status = getString(from: row, index: statusIndex)
            let entityStatus = statusCache[status] ?? defaultStatus

            let amount = getDouble(from: row, index: columnMapping[String(localized: "Amount")])

            var transaction = EntityTransaction(account: account)
            transaction.createAt  = nowNoon
            transaction.updatedAt = nowNoon
            transaction.dateOperation = dateOperation.noon
            transaction.datePointage  = datePointage.noon
            transaction.paymentMode   = entityModePaiement
            transaction.status        = entityStatus
            transaction.bankStatement = 0.0
            transaction.checkNumber   = "0"

            let sousTransaction = EntitySousOperation()
            sousTransaction.libelle  = libelle
            sousTransaction.amount   = amount
            sousTransaction.category = entityCategory

            transaction = ListTransactionsManager.shared.addSousTransaction(transaction: transaction, sousTransaction: sousTransaction)

            // ── Optimisation 3 : Progression UI ──
            if (index + 1) % batchSize == 0 || index == total - 1 {
                importCurrentCount = index + 1
                importProgress = Double(index + 1) / Double(total)
                await Task.yield()
            }
        }

        do {
            try ListTransactionsManager.shared.save()
            AppLogger.importExport.info("CSV import successful")
            ToastManager.shared.show(
                NSLocalizedString("Import successful", comment: ""),
                icon: "checkmark.circle.fill",
                type: .success
            )
            NotificationCenter.default.post(name: .transactionsImported, object: nil)
        } catch {
            AppLogger.importExport.error("CSV import save failed: \(error.localizedDescription)")
            ToastManager.shared.show(
                NSLocalizedString("Import failed", comment: ""),
                icon: "xmark.circle.fill",
                type: .error
            )
        }
    }

    // MARK: - Utilities

    private func getString(from row: [String], index: Int?) -> String {
        guard let index = index, index >= 0, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespaces)
    }

    private func getDouble(from row: [String], index: Int?) -> Double {
        guard let index = index, index >= 0, index < row.count else { return 0.0 }
        let value = row[index]
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return Double(value) ?? 0.0
    }

    private func getDate(from row: [String], index: Int?, formatter: DateFormatter) -> Date? {
        guard let index = index, index >= 0, index < row.count else { return nil }
        return formatter.date(from: row[index].trimmingCharacters(in: .whitespaces))?.noon
    }
}

// MARK: - Step Indicator

struct CSVStepIndicatorView: View {
    let currentStep: CSVImportStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CSVImportStep.allCases, id: \.rawValue) { step in
                VStack(spacing: UIConstants.smallSpacing) {
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 32, height: 32)
                        if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        } else {
                            Text("\(step.rawValue + 1)")
                                .foregroundColor(step == currentStep ? .white : .secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    Text(step.title)
                        .font(.caption)
                        .foregroundColor(step.rawValue <= currentStep.rawValue ? .primary : .secondary)
                }

                if step != CSVImportStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, UIConstants.standardSpacing)
                }
            }
        }
        .padding(.horizontal, UIConstants.largeSpacing)
        .padding(.vertical, UIConstants.mediumSpacing)
    }

    private func stepColor(for step: CSVImportStep) -> Color {
        if step.rawValue < currentStep.rawValue { return .green }
        if step == currentStep { return .accentColor }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - File Selection (Step 1)

struct CSVFileSelectionView: View {
    @Binding var isDragOver: Bool
    @Binding var showFileImporter: Bool
    let onFileLoaded: (URL) -> Void

    var body: some View {
        VStack(spacing: UIConstants.largeSpacing) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundColor(isDragOver ? .accentColor : .gray.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
                            .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                    .frame(maxWidth: 500, maxHeight: 200)

                VStack(spacing: UIConstants.mediumSpacing) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(isDragOver ? .accentColor : .secondary)

                    Text("Drop your CSV file here")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("or")
                        .foregroundColor(.secondary)

                    Button(action: { showFileImporter = true }) {
                        Label("Browse Files", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onDrop(of: [.commaSeparatedText, .fileURL], delegate: CSVDropDelegate(
                isDragOver: $isDragOver,
                onFileLoaded: onFileLoaded
            ))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Drop Delegate

struct CSVDropDelegate: DropDelegate {
    @Binding var isDragOver: Bool
    let onFileLoaded: (URL) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.commaSeparatedText, .fileURL])
    }

    func dropEntered(info: DropInfo) {
        isDragOver = true
    }

    func dropExited(info: DropInfo) {
        isDragOver = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isDragOver = false

        for provider in info.itemProviders(for: [.fileURL]) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    onFileLoaded(url)
                }
            }
            return true
        }
        return false
    }
}

// MARK: - File Info Bar

struct CSVFileInfoBar: View {
    let fileName: String
    let rowCount: Int
    let columnCount: Int
    let separator: Character
    @Binding var selectedSeparator: CSVSeparator
    let onSeparatorChange: () -> Void

    private var separatorLabel: String {
        switch separator {
        case ",":  return "Comma (,)"
        case ";":  return "Semicolon (;)"
        case "\t": return "Tab"
        default:   return String(separator)
        }
    }

    var body: some View {
        GroupBox {
            HStack(spacing: UIConstants.largeSpacing) {
                Label(fileName, systemImage: "doc.text")
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Divider().frame(height: 20)

                Label("\(rowCount) rows", systemImage: "list.number")
                    .font(.subheadline)

                Divider().frame(height: 20)

                Label("\(columnCount) columns", systemImage: "tablecells")
                    .font(.subheadline)

                Divider().frame(height: 20)

                HStack(spacing: UIConstants.smallSpacing) {
                    Text("Separator:")
                        .font(.subheadline)
                    Picker("", selection: $selectedSeparator) {
                        ForEach(CSVSeparator.allCases) { sep in
                            Text(sep.rawValue).tag(sep)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .onChange(of: selectedSeparator) { _, _ in
                        onSeparatorChange()
                    }
                }
            }
            .padding(.vertical, UIConstants.smallSpacing)
        }
        .padding(.horizontal, UIConstants.mediumSpacing)
    }
}

// MARK: - Preview Table

struct CSVPreviewTableView: View {
    let data: [[String]]
    private let maxPreviewRows = 5

    var headers: [String] {
        guard let firstRow = data.first else { return [] }
        return firstRow
    }

    var dataRows: [[String]] {
        Array(data.dropFirst().prefix(maxPreviewRows))
    }

    var body: some View {
        GroupBox(label: Label("CSV Preview (\(min(maxPreviewRows, max(0, data.count - 1))) of \(max(0, data.count - 1)) rows)", systemImage: "eye")) {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(headers.indices, id: \.self) { index in
                            Text(headers[index].trimmingCharacters(in: .whitespaces))
                                .font(.system(.caption, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(minWidth: 100, maxWidth: 180, alignment: .leading)
                                .padding(.horizontal, UIConstants.standardSpacing)
                                .padding(.vertical, UIConstants.smallSpacing)
                                .background(Color.accentColor.opacity(0.15))
                        }
                    }

                    Divider()

                    // Data rows
                    ForEach(dataRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<headers.count, id: \.self) { colIndex in
                                let value = colIndex < dataRows[rowIndex].count
                                    ? dataRows[rowIndex][colIndex].trimmingCharacters(in: .whitespaces)
                                    : ""
                                Text(value)
                                    .font(.system(.caption))
                                    .lineLimit(1)
                                    .frame(minWidth: 100, maxWidth: 180, alignment: .leading)
                                    .padding(.horizontal, UIConstants.standardSpacing)
                                    .padding(.vertical, UIConstants.smallSpacing)
                            }
                        }
                        .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color.gray.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, UIConstants.mediumSpacing)
    }
}

// MARK: - Column Mapping

struct CSVColumnMappingView: View {
    let transactionAttributes: [String]
    let headers: [String]
    let sampleRow: [String]
    @Binding var columnMapping: [String: Int]

    var body: some View {
        GroupBox(label: Label("Column Mapping", systemImage: "arrow.left.arrow.right")) {
            Grid(alignment: .leading, horizontalSpacing: UIConstants.mediumSpacing, verticalSpacing: UIConstants.standardSpacing) {
                // Grid header
                GridRow {
                    Text("Attribute")
                        .font(.caption.bold())
                        .frame(width: 140, alignment: .leading)
                    Text("CSV Column")
                        .font(.caption.bold())
                        .frame(width: 200, alignment: .leading)
                    Text("Sample Value")
                        .font(.caption.bold())
                        .frame(minWidth: 150, alignment: .leading)
                }

                Divider()

                ForEach(transactionAttributes, id: \.self) { attribute in
                    GridRow {
                        Text(attribute)
                            .font(.subheadline)
                            .frame(width: 140, alignment: .leading)

                        Picker("", selection: Binding(
                            get: { columnMapping[attribute] ?? -1 },
                            set: { columnMapping[attribute] = $0 }
                        )) {
                            Text("-- Ignore --").tag(-1)
                            ForEach(headers.indices, id: \.self) { index in
                                Text(headers[index].trimmingCharacters(in: .whitespaces))
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)

                        let mappedIndex = columnMapping[attribute] ?? -1
                        if mappedIndex >= 0 && mappedIndex < sampleRow.count {
                            Text(sampleRow[mappedIndex].trimmingCharacters(in: .whitespaces))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(minWidth: 150, alignment: .leading)
                                .padding(.horizontal, UIConstants.smallSpacing)
                                .background(Color.gray.opacity(0.08))
                                .cornerRadius(UIConstants.smallCornerRadius)
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(minWidth: 150, alignment: .leading)
                        }
                    }
                }
            }
            .padding(UIConstants.standardSpacing)
        }
        .padding(.horizontal, UIConstants.mediumSpacing)
    }
}

// MARK: - Importing View (Step 3)

struct CSVImportingView: View {
    let totalRows: Int
    @Binding var currentCount: Int
    @Binding var progress: Double

    var body: some View {
        VStack(spacing: UIConstants.largeSpacing) {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text("Import en cours")
                    .font(.title2.bold())
            }

            VStack(spacing: 12) {
                ProgressView(value: progress) {
                    Text("\(currentCount) / \(totalRows)")
                        .font(.headline)
                        .monospacedDigit()
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .progressViewStyle(.linear)
                .padding(.horizontal, 60)
            }

            Text("Veuillez patienter pendant l'import des transactions...")
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Action Buttons

struct CSVActionButtonsView: View {
    let currentStep: CSVImportStep
    let canProceed: Bool
    let isImporting: Bool
    let onCancel: () -> Void
    let onBack: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if currentStep == .previewAndMap {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(isImporting)
                .padding(.trailing, UIConstants.standardSpacing)

                Button(action: onImport) {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canProceed || isImporting)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(UIConstants.mediumSpacing)
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let ofxDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
}
