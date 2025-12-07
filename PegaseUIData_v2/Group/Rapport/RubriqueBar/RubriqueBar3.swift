//
//  RubriqueBar.swift
//  PegaseUIData
//
//  Created by thierryH24 on 22/09/2025.
//


//
//  Untitled 3.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 17/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

struct RubriqueBar: View {
    
    @StateObject private var viewModel = RubriqueBarViewModel()

    let transactions: [EntityTransaction]   
    @Binding var minDate: Date
    @Binding var maxDate: Date
    
    @AppStorage("RubriqueBar.selectedRubrique") private var storedRubrique: String = ""
    
    @State private var selectedStart: Double = 0
    @State private var selectedEnd: Double = 30
        
    private var totalDaysRange: ClosedRange<Double> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: minDate)
        let end = cal.startOfDay(for: maxDate)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return 0...Double(max(0, days))
    }
    
    var body: some View {
        VStack {
            Text("Rubrique Bar")
                .font(.headline)
                .padding()
            
            HStack(spacing: 12) {
                Text("Rubrique:")
                Picker("Rubrique", selection: $viewModel.nameRubrique) {
                    ForEach(viewModel.availableRubrics, id: \.self) { rub in
                        Text(rub.isEmpty ? String(localized: "(Toutes)") : rub).tag(rub)
                    }
                }
                .frame(maxWidth: 260)
            }
            .padding(.horizontal)
            .onChange(of: viewModel.nameRubrique) { _, newValue in
                storedRubrique = newValue
                updateChart()
            }
            if viewModel.dataEntries.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                    Text("No expenses over the period")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 600, height: 400)
                .padding()
            } else {
                
                DGBarChart5Representable(
                    viewModel: viewModel,
                    entries: viewModel.dataEntries,
                    title: String(localized: "Rubriqc Bar Chart"),
                    labels: viewModel.labels
                )
                .frame(maxWidth: .infinity,maxHeight: 400)
                .padding()
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
            }
            .padding()
            
            Spacer()
        }
        .onAppear {
            // Initialize slider bounds based on available data
            selectedStart = 0
            selectedEnd = totalDaysRange.upperBound
            updateChart()
            viewModel.nameRubrique = storedRubrique
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

