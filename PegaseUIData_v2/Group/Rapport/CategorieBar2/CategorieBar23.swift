////
////  CategorieBar23.swift
////  PegaseUIData
////
////  Created by Thierry hentic on 17/04/2025.
////
//
import SwiftUI
import SwiftData
import DGCharts
import Combine

struct RubricColor : Hashable {
    var name: String
    var color  : NSColor
    
    init(name:String, color : NSColor) {
        self.name = name
        self.color = color
    }
}

struct CategorieBar2View2: View {
        
    @StateObject private var viewModel = CategorieBar2ViewModel()

    let transactions: [EntityTransaction]

    @Binding var minDate: Date
    @Binding var maxDate: Date
    @Binding var dashboard: DashboardState

    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    private let oneDay = 3600.0 * 24.0 // one day
    
    @State private var chartView: BarChartView?
    
    var body: some View {
        VStack {
            Text("CategorieBar2View2")
                .font(.headline)
                .padding()
            
            HStack {
                if viewModel.dataEntries.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No entries over the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {
                    DGBarChart2Representable(
                        entries: viewModel.dataEntries,
                        labels: viewModel.labels)
                    .frame(maxWidth: .infinity,maxHeight: 400)
                    .padding()
                }
            }
            GroupBox(label: Label("Filter by period", systemImage: "calendar")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From \(formattedDate(from: selectedStart)) to \(formattedDate(from: selectedEnd))")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    RangeSlider(
                        lowerValue: $selectedStart,
                        upperValue: $selectedEnd,
                        totalRange: totalDaysRange,
                        valueLabel: { value in
                            let cal = Calendar.current
                            let base = cal.startOfDay(for: minDate)
                            let date = cal.date(byAdding: .day, value: Int(value), to: base) ?? base
                            let formatter = DateFormatter()
                            formatter.dateStyle = .short
                            let date1 = formatter.string(from: date)
                            return date1
                        },
                        thumbSize: 24,
                        trackHeight: 6
                    )
                    .frame(height: 30)
                }
                .padding(.top, 4)
                .padding(.horizontal)
                ListTransactionsView100(
                    dashboard: $dashboard)
            }
            .padding()

            Spacer()
        }
        .onAppear {
            // Initialize slider bounds based on available data
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            updateChart()
        }
        .onChange(of: minDate) { _, _ in
            selectedStart = 0
            updateChart()
        }
        .onChange(of: maxDate) { _, _ in
            selectedEnd = totalDaysRange.upperBound
            updateChart()
        }
        .onChange(of: selectedStart) { _, newStart in
            viewModel.selectedStart = newStart
            updateChart()
        }
        .onChange(of: selectedEnd) { _, newEnd in
            viewModel.selectedEnd = newEnd
            updateChart()
        }
    }
    
    private func updateChart() {
        guard minDate <= maxDate else { return }
        let start = Calendar.current.date(byAdding: .day, value: Int(selectedStart), to: minDate)!
        let end = Calendar.current.date(byAdding: .day, value: Int(selectedEnd), to: minDate)!
        guard start <= end else { return }
        viewModel.updateChartData(startDate: start, endDate: end)
    }
    
    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

}


