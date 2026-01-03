//
//  EntityCommun.swift
//  PegaseUIData
//
//  Created by Thierry hentic on 14/03/2025.
//

import Foundation
import SwiftData
import SwiftUI
import os
import Combine


enum EnumError: Error {
    case contextNotConfigured
    case accountNotFound
    case invalidStatusType
    case saveFailed
    case fetchFailed
}

