//
//  ToastView.swift
//  PegaseUIData_v2
//
//  Created by Claude on 30/01/2026.
//

import SwiftUI
import Combine

// MARK: - Toast Model

struct ToastMessage: Equatable {
    let id: UUID
    let message: String
    let icon: String
    let type: ToastType

    init(message: String, icon: String = "checkmark.circle.fill", type: ToastType = .success) {
        self.id = UUID()
        self.message = message
        self.icon = icon
        self.type = type
    }

    enum ToastType {
        case success
        case info
        case warning
        case error

        var color: Color {
            switch self {
            case .success: return .green
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, icon: String = "checkmark.circle.fill", type: ToastMessage.ToastType = .success, duration: Double = 2.0) {
        // Annuler le timer précédent si existe
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = ToastMessage(message: message, icon: icon, type: type)
        }

        // Auto-dismiss après la durée spécifiée
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    currentToast = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            currentToast = nil
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.title2)
                .foregroundColor(toast.type.color)

            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Toast Container Modifier

struct ToastContainerModifier: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast)
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                        .onTapGesture {
                            toastManager.dismiss()
                        }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func withToastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Button("Show Success") {
            ToastManager.shared.show("Transaction copiée", icon: "doc.on.doc.fill", type: .success)
        }
        Button("Show Info") {
            ToastManager.shared.show("3 transactions sélectionnées", icon: "info.circle.fill", type: .info)
        }
        Button("Show Warning") {
            ToastManager.shared.show("Attention: solde négatif", icon: "exclamationmark.triangle.fill", type: .warning)
        }
        Button("Show Error") {
            ToastManager.shared.show("Erreur de suppression", icon: "xmark.circle.fill", type: .error)
        }
    }
    .frame(width: 400, height: 300)
    .withToastContainer()
}
