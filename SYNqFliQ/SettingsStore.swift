//
//  SettingsStore.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/20.
//

// Add or replace this file in your project
import Foundation
import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let approachDistanceFraction = "settings.approachDistanceFraction"
        static let approachSpeed = "settings.approachSpeed"
        static let holdFillDurationFraction = "settings.holdFillDurationFraction"
        static let holdFinishTrimThreshold = "settings.holdFinishTrimThreshold"
    }

    // Defaults (tune as you like)
    static let defaultApproachDistanceFraction: Double = 0.25
    static let defaultApproachSpeed: Double = 800.0
    static let defaultHoldFillDurationFraction: Double = 1.0
    static let defaultHoldFinishTrimThreshold: Double = 0.02

    @Published var approachDistanceFraction: Double {
        didSet { UserDefaults.standard.set(approachDistanceFraction, forKey: Keys.approachDistanceFraction) }
    }

    @Published var approachSpeed: Double {
        didSet { UserDefaults.standard.set(approachSpeed, forKey: Keys.approachSpeed) }
    }

    @Published var holdFillDurationFraction: Double {
        didSet { UserDefaults.standard.set(holdFillDurationFraction, forKey: Keys.holdFillDurationFraction) }
    }

    @Published var holdFinishTrimThreshold: Double {
        didSet { UserDefaults.standard.set(holdFinishTrimThreshold, forKey: Keys.holdFinishTrimThreshold) }
    }

    init() {
        let ud = UserDefaults.standard
        self.approachDistanceFraction = ud.object(forKey: Keys.approachDistanceFraction) as? Double ?? SettingsStore.defaultApproachDistanceFraction
        self.approachSpeed = ud.object(forKey: Keys.approachSpeed) as? Double ?? SettingsStore.defaultApproachSpeed
        self.holdFillDurationFraction = ud.object(forKey: Keys.holdFillDurationFraction) as? Double ?? SettingsStore.defaultHoldFillDurationFraction
        self.holdFinishTrimThreshold = ud.object(forKey: Keys.holdFinishTrimThreshold) as? Double ?? SettingsStore.defaultHoldFinishTrimThreshold
    }

    func restoreDefaults() {
        approachDistanceFraction = SettingsStore.defaultApproachDistanceFraction
        approachSpeed = SettingsStore.defaultApproachSpeed
        holdFillDurationFraction = SettingsStore.defaultHoldFillDurationFraction
        holdFinishTrimThreshold = SettingsStore.defaultHoldFinishTrimThreshold
    }
}
