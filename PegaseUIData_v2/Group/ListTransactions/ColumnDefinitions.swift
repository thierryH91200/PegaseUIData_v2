//
//  ColumnDefinitions.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 30/10/2024.
//  Refactored by Claude Code on 14/01/2026.
//

import Foundation
import CoreGraphics

/// Defines column widths for the transaction table view
///
/// These values ensure consistent column sizing across all transaction list views.
/// Adjust these constants to change the table layout.
enum ColumnWidths {
    /// Width for operation date column
    static let dateOperation: CGFloat = 120

    /// Width for pointing/cleared date column
    static let datePointage: CGFloat = 120

    /// Width for transaction description/comment column
    static let libelle: CGFloat = 150

    /// Width for rubric/category group column
    static let rubrique: CGFloat = 100

    /// Width for category column
    static let categorie: CGFloat = 100

    /// Width for sub-operation amount column
    static let sousMontant: CGFloat = 100

    /// Width for bank statement number column
    static let releve: CGFloat = 120

    /// Width for check number column
    static let cheque: CGFloat = 120

    /// Width for transaction status column (Planned/Engaged/Executed)
    static let statut: CGFloat = 100

    /// Width for payment method column
    static let modePaiement: CGFloat = 120

    /// Width for total transaction amount column
    static let montant: CGFloat = 100
}
