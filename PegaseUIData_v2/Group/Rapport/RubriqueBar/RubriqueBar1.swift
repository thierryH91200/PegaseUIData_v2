//
//  RubriqueBar1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//
//  Note: RubriqueBar uses specialized DGBarChart5Representable with RubriqueBarViewModel
//  Keeping original implementation for compatibility
//

import SwiftUI

struct RubriqueBarView: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            RubriqueBar(
                transactions: transactions,
                minDate: minDate,
                maxDate: maxDate,
                dashboard: dashboard
            )
        }
    }
}
