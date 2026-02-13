//
//  Untitled.swift
//  PegaseUIData
//
//  Created by thierryH24 on 13/07/2025.
//


import SwiftUI
import SwiftData
import DGCharts

struct DataTresorerie : Equatable{
    var x: Double = 0.0
    var soldeRealise: Double = 0.0
    var soldeEngage: Double = 0.0
    var soldePrevu: Double = 0.0

    init(x: Double, soldeRealise: Double, soldeEngage: Double, soldePrevu: Double)
    {
        self.x  = x
        self.soldeRealise = soldeRealise
        self.soldeEngage = soldeEngage
        self.soldePrevu = soldePrevu
    }
    init() {
        self.x  = 0
        self.soldeRealise = 0
        self.soldeEngage = 0
        self.soldePrevu = 0
    }
}

