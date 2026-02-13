//
//  RubriquePie1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//
//  Refactored to use generic components via FactorizedRubriquePie
//

import SwiftUI

struct RubriquePieView: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            FactorizedRubriquePie(
                transactions: transactions,
                minDate: minDate,
                maxDate: maxDate,
                dashboard: dashboard
            )
        }
    }
}
