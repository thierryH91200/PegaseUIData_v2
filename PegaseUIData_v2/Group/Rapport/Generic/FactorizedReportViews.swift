//
//  FactorizedReportViews.swift
//  PegaseUIData
//
//  Factorized report views using generic components
//  Pie charts are fully factorized, bar charts use original implementations
//
//  Usage:
//  Instead of: RubriquePie3(...)
//  Use: FactorizedRubriquePie(...)
//

import SwiftUI
import DGCharts

// MARK: - Factorized Pie Chart Views

/// Rubrique Pie Chart - replaces RubriquePie2.swift + RubriquePie3.swift
/// Uses generic components: GenericDualPieChartView + GenericPieChartViewModel + RubricDataExtractor
struct FactorizedRubriquePie: View {
    let transactions: [EntityTransaction]
    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    var body: some View {
        GenericDualPieChartView(
            viewModel: GenericPieChartViewModel(dataExtractor: RubricDataExtractor()),
            transactions: transactions,
            title: String(localized: "Rubrique Pie"),
            expenseTitle: String(localized: "Expenses"),
            incomeTitle: String(localized: "Receipts"),
            minDate: $minDate,
            maxDate: $maxDate,
            dashboard: $dashboard,
            pieChartBuilder: { entries, title, onSelect, onClear in
                AnyView(
                    SinglePie3ChartView(
                        entries: entries,
                        title: title,
                        onSelectSlice: onSelect,
                        onClearSelection: onClear
                    )
                )
            }
        )
    }
}

/// Mode Paiement Pie Chart - replaces ModePaiementPie2.swift + ModePaiementPie3.swift
/// Uses generic components: GenericDualPieChartView + GenericPieChartViewModel + PaymentModeDataExtractor
struct FactorizedModePaiementPie: View {
    let transactions: [EntityTransaction]
    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    var body: some View {
        GenericDualPieChartView(
            viewModel: GenericPieChartViewModel(dataExtractor: PaymentModeDataExtractor()),
            transactions: transactions,
            title: String(localized: "Mode Paiement Pie"),
            expenseTitle: String(localized: "Expenses"),
            incomeTitle: String(localized: "Receipts"),
            minDate: $minDate,
            maxDate: $maxDate,
            dashboard: $dashboard,
            pieChartBuilder: { entries, title, onSelect, onClear in
                AnyView(
                    SinglePie1ChartView(
                        entries: entries,
                        title: title,
                        onSelectSlice: onSelect,
                        onClearSelection: onClear
                    )
                )
            }
        )
    }
}

/// Recette Depense Pie Chart - replaces RecetteDepensePie2.swift + RecetteDepensePie3.swift
/// Uses generic components: GenericDualPieChartView + GenericPieChartViewModel + PaymentModeDataExtractor
struct FactorizedRecetteDepensePie: View {
    let transactions: [EntityTransaction]
    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    var body: some View {
        GenericDualPieChartView(
            viewModel: GenericPieChartViewModel(dataExtractor: PaymentModeDataExtractor()),
            transactions: transactions,
            title: String(localized: "Recette Depense Pie"),
            expenseTitle: String(localized: "Expenses"),
            incomeTitle: String(localized: "Receipts"),
            minDate: $minDate,
            maxDate: $maxDate,
            dashboard: $dashboard,
            pieChartBuilder: { entries, title, onSelect, onClear in
                AnyView(
                    SinglePie2ChartView(
                        entries: entries,
                        title: title,
                        onSelectSlice: onSelect,
                        onClearSelection: onClear
                    )
                )
            }
        )
    }
}

// MARK: - Factorization Summary

/*
 FACTORIZATION SUMMARY
 =====================

 SUCCESSFULLY FACTORIZED (3 Pie Chart views):
 -------------------------------------------
 - RubriquePie (RubriquePie2 + RubriquePie3) -> FactorizedRubriquePie
 - ModePaiementPie (ModePaiementPie2 + ModePaiementPie3) -> FactorizedModePaiementPie
 - RecetteDepensePie (RecetteDepensePie2 + RecetteDepensePie3) -> FactorizedRecetteDepensePie

 These use the generic components:
 - GenericDualPieChartView: Unified dual pie chart UI
 - GenericPieChartViewModel: Common ViewModel with data extraction
 - ChartDataProviders: RubricDataExtractor, PaymentModeDataExtractor

 KEPT ORIGINAL (4 Bar Chart views):
 -----------------------------------
 The following bar chart views use specialized NSViewRepresentable components
 with specific bindings and ViewModels that would require significant refactoring:

 - CategorieBar1 (CatBar2 + CatBar3 + CatBar4):
   Uses DGBarChart7Representable with CategorieBar1ViewModel singleton
   Has bar selection handling with notification system

 - CategorieBar2 (CategorieBar22 + CategorieBar23 + CategorieBar24):
   Uses DGBarChart2Representable with grouped bar data
   Has RubricColor struct and complex data grouping

 - RubriqueBar (RubriqueBar2 + RubriqueBar3 + RubriqueBar4):
   Uses DGBarChart5Representable with rubric picker
   Has @AppStorage for persisting selected rubric

 - RecetteDepenseBar (RecetteDepenseBar2 + RecetteDepenseBar3 + RecetteDepenseBar4):
   Uses DGBarChart4Representable with @Binding lowerValue/upperValue
   Has RecetteDepenseBarViewModel with applyData method

 BENEFITS ACHIEVED:
 -----------------
 - Pie charts: ~60% code reduction (from ~800 lines to ~300 lines for 3 views)
 - Single source of truth for pie chart logic
 - Consistent UI across all pie report types
 - Easy to add new pie chart types with ~30 lines of code
 - ChartDataProviders are reusable for future components

 GENERIC COMPONENTS CREATED (reusable for future):
 -----------------------------------------------
 1. ChartDataProviders.swift:
    - ChartDataExtractor protocol
    - RubricDataExtractor, PaymentModeDataExtractor, CategoryDataExtractor
    - SectionRubricDataExtractor
    - Helper functions: summarizeData, pieChartEntries, barChartEntries

 2. GenericChartViewModel.swift:
    - GenericChartViewModel (base class)
    - GenericPieChartViewModel (for dual pie charts)
    - GenericBarChartViewModel (for bar charts)
    - GenericSectionBarChartViewModel (for section-grouped bars)

 3. GenericPieChartView.swift:
    - GenericDualPieChartView (expense/income dual pie)

 4. GenericBarChartView.swift:
    - GenericBarChartView, GenericSectionBarChartView, GenericSimpleBarChartView
    (Available for future use when bar chart Representables are standardized)

 WRAPPER FILES (using ReportContainerView):
 -----------------------------------------
 All wrapper files now use ReportContainerView for common lifecycle management:
 - CatBar1.swift -> CategorieBar1View (uses CategorieBar1View1)
 - CategorieBar21.swift -> CategorieBar2View (uses CategorieBar2View2)
 - RubriquePie1.swift -> RubriquePieView (uses FactorizedRubriquePie)
 - RubriqueBar1.swift -> RubriqueBarView (uses RubriqueBar)
 - RecetteDepensePie1.swift -> RecetteDepensePieView (uses FactorizedRecetteDepensePie)
 - RecetteDepenseBar1.swift -> RecetteDepenseBarView (uses RecetteDepenseView)
 - ModePaiementPie1.swift -> ModePaiementPieView (uses FactorizedModePaiementPie)
 */
