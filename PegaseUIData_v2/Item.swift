//
//  Item.swift
//  PegaseUIData_v2
//
//  Created by thierryH24 on 13/02/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
