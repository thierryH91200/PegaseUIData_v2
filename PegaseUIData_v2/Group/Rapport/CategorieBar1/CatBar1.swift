//
//  CatBar1.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 16/04/2025.
//
//  Note: CategorieBar1 uses specialized DGBarChart7Representable with CategorieBar1ViewModel
//  Keeping original implementation for compatibility
//

import SwiftUI

struct CategorieBar1View: View {

    @Binding var dashboard: DashboardState

    var body: some View {
        ReportContainerView(dashboard: $dashboard) { transactions, minDate, maxDate, dashboard in
            CategorieBar1View1(
                transactions: transactions,
                minDate: minDate,
                maxDate: maxDate,
                dashboard: dashboard
            )
        }
    }
}
