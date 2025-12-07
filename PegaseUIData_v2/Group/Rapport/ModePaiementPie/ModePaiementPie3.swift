//
//  ModePaiementPie3.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

struct ModePaiementView: View {

    @StateObject private var viewModel = ModePaymentPieViewModel()

    let transactions: [EntityTransaction]

    @Binding var minDate: Date
    @Binding var maxDate: Date

    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }

    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ModePaiement Pie")
                .font(.headline)
                .padding()
            
            HStack {
                if viewModel.dataEntriesDepense.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No expenses over the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {
                    SinglePie1ChartView(entries: viewModel.dataEntriesDepense,
                                       title: String(localized : "Expenses"))
                        .frame(width: 600, height: 400)
                        .padding()
                }

                if viewModel.dataEntriesRecette.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                        Text("No receipts for the period")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 600, height: 400)
                    .padding()
                } else {
                    SinglePie1ChartView(
                        entries: viewModel.dataEntriesRecette,
                        title: String(localized : "Receipts"))
                        .frame(width: 600, height: 400)
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

                    Spacer()
                }
                .padding(.top, 4)
                .padding(.horizontal)
            }
        }
        .onAppear {
            // Initialize slider bounds based on available data
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            updatePieData()
        }
        .onChange(of: minDate) { _, _ in
            selectedStart = 0
            updatePieData()
        }
        .onChange(of: maxDate) { _, _ in
            selectedEnd = totalDaysRange.upperBound
            updatePieData()
        }
        .onChange(of: selectedStart) { _, _ in
            updatePieData()
        }
        .onChange(of: selectedEnd) { _, _ in
            updatePieData()
        }
    }
    
    func formattedDate(from dayOffset: Double) -> String {
        let date = Calendar.current.date(byAdding: .day, value: Int(dayOffset), to: minDate)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func updatePieData() {
        // Ensure prerequisites are valid
        guard selectedStart <= selectedEnd else { return }
        guard minDate <= maxDate else { return }

        let calendar = Calendar.current
        let startOfMin = calendar.startOfDay(for: minDate)

        guard let start = calendar.date(byAdding: .day, value: Int(selectedStart), to: startOfMin),
              let endRaw = calendar.date(byAdding: .day, value: Int(selectedEnd), to: startOfMin) else {
            return
        }

        // Clamp to maxDate then extend to end-of-day for inclusive range
        let endClamped = min(endRaw, maxDate)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: endClamped)) ?? endClamped

        viewModel.updateChartData( startDate: start, endDate: endOfDay)
    }
    
}

