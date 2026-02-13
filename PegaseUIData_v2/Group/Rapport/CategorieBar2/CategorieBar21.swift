//
//  CategorieBar21.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//
//  Note: CategorieBar2 uses specialized DGBarChart2Representable with CategorieBar2ViewModel
//  Keeping original implementation for compatibility
//

import SwiftUI

struct CategorieBar2View: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            CategorieBar2View2(
                viewModel: CategoryBar2ViewModel(),
                transactions: transactions,
                minDate: minDate,
                maxDate: maxDate,
                dashboard: dashboard
            )
        }
    }
}
