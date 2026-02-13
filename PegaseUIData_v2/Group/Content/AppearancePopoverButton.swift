//
//  AppearancePopoverButton.swift
//  PegaseUIData_v2
//
//  Button to switch between Light/Dark/System appearance
//  Extracted from Content.swift for better code organization
//

import SwiftUI
import AppKit

struct AppearancePopoverButton: View {
    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            HStack(spacing: 8) {
                if let ns = coloredSystemImage(named: "paintbrush", tint: .systemRed, size: CGSize(width: 18, height: 18)) {
                    Image(nsImage: ns)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "paintbrush")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.red)
                }
                Text(String(localized: "", table: "MainApp"))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Button("Light")  { NSApp.appearance = NSAppearance(named: .aqua); showing = false }
                Button("Dark")   { NSApp.appearance = NSAppearance(named: .darkAqua); showing = false }
                Button("System") { NSApp.appearance = nil; showing = false }
            }
            .padding()
            .frame(width: 150)
        }
    }

    func coloredSystemImage(named: String, tint: NSColor, size: CGSize = CGSize(width: 18, height: 18)) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: named, accessibilityDescription: nil) else { return nil }
        let result = NSImage(size: size)
        result.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        tint.setFill()
        rect.fill(using: .sourceAtop)
        result.unlockFocus()
        result.isTemplate = false
        return result
    }
}
