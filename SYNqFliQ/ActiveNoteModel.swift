//
//  Untitled.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/22.
//
import Foundation
import CoreGraphics
// MARK: ActiveNote model used for runtime (spawned) notes
struct ActiveNote: Identifiable {
    let id: UUID
    let sourceID: String?
    let angleDegrees: Double
    var position: CGPoint
    let targetPosition: CGPoint
    let hitTime: Double
    let spawnTime: Double
    var isClear: Bool

    // types
    var isTap: Bool = false
    var isHold: Bool = false
    var position2: CGPoint? = nil

    // hold fields
    var holdEndTime: Double? = nil
    var holdStarted: Bool = false
    var holdFillScale: Double = 0.0
    var holdTrim: Double = 1.0
    var holdStartDeviceTime: TimeInterval? = nil
    var holdStartWallTime: TimeInterval? = nil
    var holdTotalSeconds: Double = 0.0
    var holdRemainingSeconds: Double = 0.0
    var holdPressedByUser: Bool = false
    var holdWasReleased: Bool = false
    var holdPressDeviceTime: TimeInterval? = nil
    var holdLastTickDeviceTime: TimeInterval? = nil
    var holdCompletedWhileStopped: Bool = false
    var holdReachedEnd: Bool = false

    // approach movement
    var startPosition: CGPoint = .zero
    var approachStartDeviceTime: TimeInterval? = nil
    var approachStartWallTime: TimeInterval? = nil
    var approachEndDeviceTime: TimeInterval? = nil
    var approachEndWallTime: TimeInterval? = nil
    var approachDuration: Double = 0.0
}
