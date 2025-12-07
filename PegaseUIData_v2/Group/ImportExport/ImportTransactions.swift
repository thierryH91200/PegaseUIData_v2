//
//  ImportTransactions.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 30/05/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import SwiftData

struct ImportTransactions: View {
    
    @Environment(\.dismiss) private var dismiss

    @State private var showOFXImporter = false
    @State private var showCSVImporter = false
    @State var viewModel = CSVViewModel()
    
    var body: some View {
        Button(action: {
            viewModel.triggerImport()
        }) {
            Label("Importing the CSV file…", systemImage: "arrow.down.doc")
        }
        .frame(width: 200, height: 30, alignment: .center)
        
        Button(action: {
            viewModel.triggerImport()
        }) {
            Label("Import OFX", systemImage: "arrow.down.doc")
        }
        .frame(width: 200, height: 30, alignment: .center)
        
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
    }
}
