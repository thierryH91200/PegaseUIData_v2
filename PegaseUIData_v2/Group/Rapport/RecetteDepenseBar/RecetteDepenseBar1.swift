//
//  RecetteDepenseBar1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//
//  Note: RecetteDepenseBar uses specialized DGBarChart4Representable with specific bindings
//  Keeping original implementation for compatibility
//

import SwiftUI

struct RecetteDepenseBarView: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            RecetteDepenseView(
                transactions: transactions,
                dashboard: dashboard,
                minDate: minDate,
                maxDate: maxDate
            )
        }
    }
}
