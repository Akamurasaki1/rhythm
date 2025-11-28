//
//  TouchOverlay.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/17.
//

//
// TouchOverlay.swift
// Modified TouchForwardingView: pass start position and duration on ended so caller can compute flick
//
//
// TouchOverlay.swift
// Reliable multi-touch overlay: detects tap / hold / flick and forwards lightweight callbacks
//
//
// TouchOverlay.swift
// Canonical TouchForwardingView + TouchOverlay wrapper
//
// Keep this single file as the overlay implementation. Remove any other TouchOverlay* duplicates.
//

import SwiftUI
import UIKit

/// UIView that forwards reliable multi-touch events to SwiftUI.
public final class TouchForwardingView: UIView {
    // Callbacks set by the SwiftUI wrapper
    public var onTap: ((Int, CGPoint) -> Void)?
    public var onMove: ((Int, CGPoint) -> Void)?
    public var onHoldStart: ((Int, CGPoint) -> Void)?
    public var onHoldEnd: ((Int, CGPoint, TimeInterval) -> Void)?
    public var onFlick: ((Int, CGPoint, CGPoint, CGFloat) -> Void)?

    private struct TouchInfo {
        let id: Int
        var startPos: CGPoint
        var lastPos: CGPoint
        var startTime: TimeInterval
        var moved: Bool
        var holdFired: Bool
        var workItem: DispatchWorkItem?
    }

    private var touchToInfo: [UITouch: TouchInfo] = [:]
    private var nextId: Int = 1

    // Tunables (tweak if needed)
    public var longPressThreshold: TimeInterval = 0.35
    public var longPressMaxMove: CGFloat = 20.0
    public var tapMaxMove: CGFloat = 20.0
    public var tapMaxTime: TimeInterval = 0.30
    public var flickSpeedThreshold: CGFloat = 300.0 // px/sec

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isUserInteractionEnabled = true
        isExclusiveTouch = false
    }

    private func allocateId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }

    private func scheduleHoldCheck(for touch: UITouch) {
        guard var info = touchToInfo[touch] else { return }
        info.workItem?.cancel()
        let id = info.id
        let work = DispatchWorkItem { [weak self, weak touch] in
            guard let self = self, let t = touch else { return }
            if var cur = self.touchToInfo[t] {
                let dx = cur.lastPos.x - cur.startPos.x
                let dy = cur.lastPos.y - cur.startPos.y
                if hypot(dx, dy) > self.longPressMaxMove {
                    cur.workItem = nil
                    self.touchToInfo[t] = cur
                    return
                }
                cur.holdFired = true
                cur.workItem = nil
                self.touchToInfo[t] = cur
                self.onHoldStart?(id, cur.startPos)
            }
        }
        info.workItem = work
        touchToInfo[touch] = info
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressThreshold, execute: work)
    }

    private func cancelHoldCheck(for touch: UITouch) {
        guard var info = touchToInfo[touch] else { return }
        info.workItem?.cancel()
        info.workItem = nil
        touchToInfo[touch] = info
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let now = Date().timeIntervalSince1970
        for t in touches {
            let id = allocateId()
            let p = t.location(in: self)
            let info = TouchInfo(id: id, startPos: p, lastPos: p, startTime: now, moved: false, holdFired: false, workItem: nil)
            touchToInfo[t] = info
            scheduleHoldCheck(for: t)
            onMove?(id, p)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard var info = touchToInfo[t] else { continue }
            let p = t.location(in: self)
            info.lastPos = p
            if !info.moved {
                let dx = p.x - info.startPos.x
                let dy = p.y - info.startPos.y
                if hypot(dx, dy) > longPressMaxMove {
                    info.moved = true
                    info.workItem?.cancel()
                    info.workItem = nil
                }
            }
            touchToInfo[t] = info
            onMove?(info.id, p)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let now = Date().timeIntervalSince1970
        for t in touches {
            guard let info = touchToInfo[t] else { continue }
            let end = t.location(in: self)
            cancelHoldCheck(for: t)

            if info.holdFired {
                let duration = now - info.startTime
                onHoldEnd?(info.id, end, duration)
                touchToInfo[t] = nil
                continue
            }

            let dx = end.x - info.startPos.x
            let dy = end.y - info.startPos.y
            let dist = hypot(dx, dy)
            let duration = max(1e-6, now - info.startTime)
            let speed = dist / CGFloat(duration)

            if speed >= flickSpeedThreshold {
                onFlick?(info.id, info.startPos, end, speed)
                touchToInfo[t] = nil
                continue
            }

            if dist <= tapMaxMove && duration <= tapMaxTime {
                onTap?(info.id, end)
                touchToInfo[t] = nil
                continue
            }

            touchToInfo[t] = nil
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}

/// SwiftUI wrapper for the forwarder view.
/// Keep exactly one of these struct definitions in the project.
public struct TouchOverlay: UIViewRepresentable {
    public var onTap: (Int, CGPoint) -> Void
    public var onMove: (Int, CGPoint) -> Void
    public var onHoldStart: (Int, CGPoint) -> Void
    public var onHoldEnd: (Int, CGPoint, TimeInterval) -> Void
    public var onFlick: (Int, CGPoint, CGPoint, CGFloat) -> Void

    public init(onTap: @escaping (Int, CGPoint) -> Void,
                onMove: @escaping (Int, CGPoint) -> Void,
                onHoldStart: @escaping (Int, CGPoint) -> Void,
                onHoldEnd: @escaping (Int, CGPoint, TimeInterval) -> Void,
                onFlick: @escaping (Int, CGPoint, CGPoint, CGFloat) -> Void) {
        self.onTap = onTap
        self.onMove = onMove
        self.onHoldStart = onHoldStart
        self.onHoldEnd = onHoldEnd
        self.onFlick = onFlick
    }

    public func makeUIView(context: Context) -> TouchForwardingView {
        let v = TouchForwardingView()
        v.onTap = onTap
        v.onMove = onMove
        v.onHoldStart = onHoldStart
        v.onHoldEnd = onHoldEnd
        v.onFlick = onFlick
        return v
    }

    public func updateUIView(_ uiView: TouchForwardingView, context: Context) {
        // no-op
    }
}
/*
import SwiftUI
import UIKit

/// Lightweight multi-touch overlay.
/// Callbacks:
///  - onTap(id, location)
///  - onMove(id, location)
///  - onHoldStart(id, location)
///  - onHoldEnd(id, location, duration)
///  - onFlick(id, startLocation, endLocation, velocityPxPerSec)
public final class TouchForwardingView: UIView {
    // Callbacks set by the SwiftUI wrapper
    public var onTap: ((Int, CGPoint) -> Void)?
    public var onMove: ((Int, CGPoint) -> Void)?
    public var onHoldStart: ((Int, CGPoint) -> Void)?
    public var onHoldEnd: ((Int, CGPoint, TimeInterval) -> Void)?
    public var onFlick: ((Int, CGPoint, CGPoint, CGFloat) -> Void)?

    // Per-touch info
    private struct TouchInfo {
        let id: Int
        var startPos: CGPoint
        var lastPos: CGPoint
        var startTime: TimeInterval
        var moved: Bool
        var holdFired: Bool
        var workItem: DispatchWorkItem?
    }

    private var touchToInfo: [UITouch: TouchInfo] = [:]
    private var nextId: Int = 1

    // Tunables (tweak as needed)
    public var longPressThreshold: TimeInterval = 0.35
    public var longPressMaxMove: CGFloat = 16.0
    public var tapMaxMove: CGFloat = 16.0
    public var tapMaxTime: TimeInterval = 0.30
    public var flickSpeedThreshold: CGFloat = 600.0 // px / sec

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    private func allocateId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }

    // Schedule a work item on main queue (lightweight) for long-press detection.
    private func scheduleHoldCheck(for touch: UITouch) {
        guard var info = touchToInfo[touch] else { return }
        // cancel existing if any
        info.workItem?.cancel()

        let id = info.id
        let work = DispatchWorkItem { [weak self, weak touch] in
            guard let self = self, let t = touch else { return }
            // run check on main (touch callbacks are on main anyway; we keep it minimal)
            if var cur = self.touchToInfo[t] {
                // If moved too far, ignore
                let dx = cur.lastPos.x - cur.startPos.x
                let dy = cur.lastPos.y - cur.startPos.y
                if hypot(dx, dy) > self.longPressMaxMove {
                    cur.workItem = nil
                    self.touchToInfo[t] = cur
                    return
                }
                cur.holdFired = true
                cur.workItem = nil
                self.touchToInfo[t] = cur
                // deliver hold-start callback (lightweight)
                self.onHoldStart?(id, cur.startPos)
            }
        }

        info.workItem = work
        touchToInfo[touch] = info
        // Schedule on main after threshold
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressThreshold, execute: work)
    }

    private func cancelHoldCheck(for touch: UITouch) {
        guard var info = touchToInfo[touch] else { return }
        info.workItem?.cancel()
        info.workItem = nil
        touchToInfo[touch] = info
    }

    // MARK: - Touch overrides (all on main thread)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let now = Date().timeIntervalSince1970
        for t in touches {
            let id = allocateId()
            let p = t.location(in: self)
            let info = TouchInfo(id: id, startPos: p, lastPos: p, startTime: now, moved: false, holdFired: false, workItem: nil)
            touchToInfo[t] = info
            // schedule hold check
            scheduleHoldCheck(for: t)
            // minimal move callback to allow ContentView to track finger
            onMove?(id, p)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let now = Date().timeIntervalSince1970
        for t in touches {
            guard var info = touchToInfo[t] else { continue }
            let p = t.location(in: self)
            info.lastPos = p
            // if moved beyond longPressMaxMove, cancel scheduled hold check
            if !info.moved {
                let dx = p.x - info.startPos.x
                let dy = p.y - info.startPos.y
                if hypot(dx, dy) > longPressMaxMove {
                    info.moved = true
                    info.workItem?.cancel()
                    info.workItem = nil
                }
            }
            touchToInfo[t] = info
            onMove?(info.id, p)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let now = Date().timeIntervalSince1970
        for t in touches {
            guard let info = touchToInfo[t] else { continue }
            let end = t.location(in: self)
            // cancel scheduled hold check
            cancelHoldCheck(for: t)

            // if hold had fired earlier -> deliver hold end with duration
            if info.holdFired {
                let duration = now - info.startTime
                onHoldEnd?(info.id, end, duration)
                touchToInfo[t] = nil
                continue
            }

            // compute movement / duration for flick or tap
            let dx = end.x - info.startPos.x
            let dy = end.y - info.startPos.y
            let dist = hypot(dx, dy)
            let duration = max(1e-6, now - info.startTime)
            let speed = dist / CGFloat(duration) // px / sec

            // flick check
            if speed >= flickSpeedThreshold {
                onFlick?(info.id, info.startPos, end, speed)
                touchToInfo[t] = nil
                continue
            }

            // tap check
            if dist <= tapMaxMove && duration <= tapMaxTime {
                onTap?(info.id, end)
                touchToInfo[t] = nil
                continue
            }

            // otherwise, no special event — just cleanup
            touchToInfo[t] = nil
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // treat cancel as end
        touchesEnded(touches, with: event)
    }
}*/
/*
// SwiftUI wrapper with simple closure-based API matching ContentView usage
public struct TouchOverlay: UIViewRepresentable {
    public var onTap: (Int, CGPoint) -> Void
    public var onMove: (Int, CGPoint) -> Void
    public var onHoldStart: (Int, CGPoint) -> Void
    public var onHoldEnd: (Int, CGPoint, TimeInterval) -> Void
    public var onFlick: (Int, CGPoint, CGPoint, CGFloat) -> Void

    public init(onTap: @escaping (Int, CGPoint) -> Void,
                onMove: @escaping (Int, CGPoint) -> Void,
                onHoldStart: @escaping (Int, CGPoint) -> Void,
                onHoldEnd: @escaping (Int, CGPoint, TimeInterval) -> Void,
                onFlick: @escaping (Int, CGPoint, CGPoint, CGFloat) -> Void) {
        self.onTap = onTap
        self.onMove = onMove
        self.onHoldStart = onHoldStart
        self.onHoldEnd = onHoldEnd
        self.onFlick = onFlick
    }

    public func makeUIView(context: Context) -> TouchForwardingView {
        let v = TouchForwardingView()
        v.onTap = onTap
        v.onMove = onMove
        v.onHoldStart = onHoldStart
        v.onHoldEnd = onHoldEnd
        v.onFlick = onFlick
        return v
    }

    public func updateUIView(_ uiView: TouchForwardingView, context: Context) {
        // no-op; state kept in closures
    }
}
*/
