//
//  String.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 18/03/2025.
//

import SwiftUI
import Foundation
import SwiftData

extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
