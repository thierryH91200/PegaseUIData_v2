//
//  meetInspector.swift
//  test2
//
//  Created by Thierry hentic on 24/10/2024.
//

import SwiftUI
import AppKit

class OutlineViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var outlineView: NSOutlineView!
    
    // Exemple de données pour l'outline
    var data: [Node] = [
        Node(name: "Parent 1", children: [Node(name: "Child 1"), Node(name: "Child 2")]),
        Node(name: "Parent 2", children: [Node(name: "Child 3")])
    ]
    
    override func loadView() {
        outlineView = NSOutlineView()
        
        // Configurer les colonnes
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column"))
        column.title = "Items"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        outlineView.delegate = self
        outlineView.dataSource = self
        
        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        self.view = scrollView
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? Node {
            return node.children.count
        }
        return data.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? Node {
            return !node.children.isEmpty
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? Node {
            return node.children[index]
        }
        return data[index]
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? Node else { return nil }
        
        let cell = NSTextField(labelWithString: node.name)
        cell.isBordered = false
        cell.drawsBackground = false
        return cell
    }
}

struct Node {
    let name: String
    var children: [Node] = []
}

struct OutlineViewWrapper: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> OutlineViewController {
        return OutlineViewController()
    }
    
    func updateNSViewController(_ nsViewController: OutlineViewController, context: Context) {
        // Mettre à jour la vue ici si nécessaire
    }
}

struct ContentView10: View {
    var body: some View {
        VStack {
            Text("Outline View in SwiftUI")
                .font(.headline)
                .padding()
            OutlineViewWrapper()
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}

