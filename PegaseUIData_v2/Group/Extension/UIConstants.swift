//
//  UIConstants.swift
//  PegaseUIData
//
//  Centralized constants for UI dimensions, timing, and styling
//  Eliminates magic numbers throughout the codebase
//

import Foundation
import SwiftUI

// MARK: - UI Constants
enum UIConstants {

    // MARK: - Window Sizes

    /// Lock screen window size
    static let lockScreenSize = NSSize(width: 400, height: 400)

    /// Splash screen constraints
    static let splashScreenMinSize = NSSize(width: 700, height: 500)
    static let splashScreenMaxSize = NSSize(width: 2000, height: 1400)

    /// Main window constraints
    static let mainWindowMinSize = NSSize(width: 900, height: 600)
    static let mainWindowMaxSize = NSSize(width: 3000, height: 2000)

    /// About window size
    static let aboutWindowSize = NSSize(width: 360, height: 220)

    /// Sidebar width
    static let sidebarWidth: CGFloat = 400

    // MARK: - Timing (in nanoseconds for Task.sleep)

    /// Standard delay (1 second)
    static let standardDelay: UInt64 = 1_000_000_000

    /// Short delay (500ms) for debouncing
    static let debounceDelay: UInt64 = 500_000_000

    /// Quick delay (100ms) for UI transitions
    static let quickDelay: UInt64 = 100_000_000

    // MARK: - Timing (in seconds for Timer/Animation)

    /// Default animation duration
    static let defaultAnimationDuration: TimeInterval = 0.22

    /// Toast display duration
    static let toastDuration: TimeInterval = 3.0

    // MARK: - Component Sizes

    /// Icon sizes
    static let smallIconSize: CGFloat = 16
    static let mediumIconSize: CGFloat = 24
    static let largeIconSize: CGFloat = 50
    static let extraLargeIconSize: CGFloat = 80

    /// Form field widths
    static let labelWidth: CGFloat = 100
    static let fieldWidth: CGFloat = 200

    /// Button dimensions
    static let buttonHeight: CGFloat = 30
    static let buttonMinWidth: CGFloat = 80

    // MARK: - Spacing & Padding

    /// Standard spacing
    static let smallSpacing: CGFloat = 4
    static let standardSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24

    /// Corner radius
    static let smallCornerRadius: CGFloat = 4
    static let standardCornerRadius: CGFloat = 8
    static let largeCornerRadius: CGFloat = 12

    // MARK: - Charts

    /// Chart dimensions
    static let chartMinHeight: CGFloat = 200
    static let chartDefaultHeight: CGFloat = 300

    /// Slider dimensions
    static let sliderHeight: CGFloat = 54
}

// MARK: - Convenience Extensions

extension NSSize {
    /// Create NSSize from UIConstants
    static var lockScreen: NSSize { UIConstants.lockScreenSize }
    static var mainWindowMin: NSSize { UIConstants.mainWindowMinSize }
    static var mainWindowMax: NSSize { UIConstants.mainWindowMaxSize }
}
