//
//  ColorManager.swift
//  PegaseUIData
//
//  Created by thierryH24 on 16/08/2025.
//

import SwiftUI
import AppKit
import SwiftData
import Combine

class ColorManager: ObservableObject {

    private let key: String
    @Published var colorChoix: String {
        didSet {
            UserDefaults.standard.set(colorChoix, forKey: key)
        }
    }

    @MainActor
    init( ) {
        
        let account = CurrentAccountManager.shared.getAccount()
        guard let account = account else {
            self.key = "colorChoix_Arthur"
            self.colorChoix = UserDefaults.standard.string(forKey: key) ?? "United"
            return }
        
        print("account A",account.uuid)

        let name = account.identity?.name ?? " "
        let surName = account.identity?.surName ?? " "
        let accountName = name + surName
        
        self.key = "colorChoix_" + accountName
    
        self.colorChoix = UserDefaults.standard.string(forKey: key) ?? "United"
    }

    func colorForTransaction(_ transaction: EntityTransaction) -> Color {
        switch colorChoix {
        case "United":
            return .primary
        case "Income/Expense":
            return transaction.amount >= 0 ? .green : .red
        case "Rubric":
            return Color(transaction.sousOperations.first?.category?.rubric?.color ?? .black)
        case "Payment Mode":
            return Color(transaction.paymentMode?.color ?? .black)
        case "Status":
            return Color(transaction.status?.color ?? .gray)
        default:
            return .black
        }
    }
}
