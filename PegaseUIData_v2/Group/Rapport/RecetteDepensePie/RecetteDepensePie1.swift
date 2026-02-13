//
//  RecetteDepensePie1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//
//  Refactored to use generic components via FactorizedRecetteDepensePie
//

import SwiftUI

struct RecetteDepensePieView: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            FactorizedRecetteDepensePie(
                transactions: transactions,
                minDate: minDate,
                maxDate: maxDate,
                dashboard: dashboard
            )
        }
    }
}
