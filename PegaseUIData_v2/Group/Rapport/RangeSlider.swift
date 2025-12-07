//
//  RangeSlider.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 16/04/2025.
//

import SwiftUI
import SwiftData
import DGCharts
import Combine

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    
    let totalRange: ClosedRange<Double>
    let valueLabel: (Double) -> String
    let thumbSize: CGFloat
    let trackHeight: CGFloat

    var selectedDays: Int {
        Int(upperValue - lowerValue) + 1
    }

    private func position(for value: Double, in width: CGFloat) -> CGFloat {
        let percent = (value - totalRange.lowerBound) / (totalRange.upperBound - totalRange.lowerBound)
        return percent * width
    }

    private func clampedPercent(from location: CGFloat, width: CGFloat) -> CGFloat {
        min(max(0, location / width), 1)
    }

    private func valueFrom(percent: CGFloat) -> Double {
        totalRange.lowerBound + percent * (totalRange.upperBound - totalRange.lowerBound)
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - thumbSize
            let safeAvailable = max(1, availableWidth)
            let clamp: (CGFloat) -> CGFloat = { min(max(0, $0), safeAvailable) }
            let lowerPosRaw = position(for: lowerValue, in: safeAvailable)
            let upperPosRaw = position(for: upperValue, in: safeAvailable)
            let lowerPos = clamp(lowerPosRaw.isFinite ? lowerPosRaw : 0)
            let upperPos = clamp(upperPosRaw.isFinite ? upperPosRaw : 0)
            let overlap = abs(upperPos - lowerPos) < thumbSize

            ZStack(alignment: .topLeading) {
                VStack(spacing: 4) {
                    // Dates
                    ZStack {
                        if overlap {
                            Text(valueLabel(lowerValue))
                                .font(.caption2)
                                .position(x: (lowerPos + upperPos)/2 + thumbSize / 2, y: 10)
                        } else {
                            Text(valueLabel(lowerValue))
                                .font(.caption2)
                                .position(x: lowerPos + thumbSize / 2, y: 10)

                            Text(valueLabel(upperValue))
                                .font(.caption2)
                                .position(x: upperPos + thumbSize / 2, y: 10)
                        }
                    }
                    .frame(height: 20)

                    // Slider
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: trackHeight)
                            .padding(.horizontal, thumbSize / 2)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(0, upperPos - lowerPos), height: trackHeight)
                            .padding(.leading, lowerPos + thumbSize / 2)
                            .padding(.trailing, max(0, safeAvailable - upperPos) + thumbSize / 2)

                        thumb(isLeft: true, offset: lowerPos, overlap: overlap) {
                            DragGesture().onChanged { value in
                                let percent = clampedPercent(from: value.location.x, width: safeAvailable)
                                let newValue = round(valueFrom(percent: percent))
                                if newValue <= upperValue {
                                    lowerValue = newValue
                                }
                            }
                        }

                        thumb(isLeft: false, offset: upperPos, overlap: false) {
                            DragGesture().onChanged { value in
                                let percent = clampedPercent(from: value.location.x, width: safeAvailable)
                                let newValue = round(valueFrom(percent: percent))
                                if newValue >= lowerValue {
                                    upperValue = newValue
                                }
                            }
                        }
                    }
                }

                // Nombre de jours sélectionnés
                Text("Number of days selected: \(selectedDays)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .frame(height: thumbSize + 30)
    }

    @ViewBuilder
    private func thumb(isLeft: Bool, offset: CGFloat, overlap: Bool, gesture: () -> some Gesture) -> some View {
        Circle()
            .fill(Color.primary)
            .frame(width: thumbSize, height: thumbSize)
            .offset(x: offset, y: isLeft && overlap ? 10 : 0)
            .gesture(gesture())
            .accessibilityLabel(isLeft ? "Start" : "End")
    }
}
