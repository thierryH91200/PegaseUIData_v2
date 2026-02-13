//
//  ModePaiementPie1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//
//  Refactored to use generic components via FactorizedModePaiementPie
//

import SwiftUI

struct ModePaiementPieView: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            FactorizedModePaiementPie(
                transactions: transactions,
                minDate: minDate,
                maxDate: maxDate,
                dashboard: dashboard
            )
        }
    }
}
