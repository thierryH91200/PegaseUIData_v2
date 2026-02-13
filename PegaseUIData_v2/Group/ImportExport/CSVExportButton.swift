//
//  CSVExportButton.swift
//  CSVEditor
//
//  Created by Karin Prater on 12/11/2024.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine


struct CSVExportButton: View {
    
    @ObservedObject var viewModel: CSVViewModel
    @State private var isPresented: Bool = false
    
    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Export CSV", systemImage: "square.and.arrow.up")
        }
        .disabled(viewModel.content.isEmpty)
        
        .fileExporter(isPresented: $isPresented,
                      document: viewModel,
                      contentType: UTType.commaSeparatedText) { result in
            printTag("result \(result)", flag: true)
        }
    }
}

