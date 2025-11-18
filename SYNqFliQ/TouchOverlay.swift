//
//  TouchOverlay.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/17.
//

import SwiftUI
import UIKit

// UIView that forwards multi-touch events to SwiftUI via closures.
final class TouchForwardingView: UIView {
    var onTouchBegan: ((Int, CGPoint) -> Void)?
    var onTouchMoved: ((Int, CGPoint) -> Void)?
    var onTouchEnded: ((Int, CGPoint) -> Void)?

    // map UITouch pointers to Int ids
    private var touchToId: [UITouch: Int] = [:]
    private var nextId: Int = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    private func id(for touch: UITouch) -> Int {
        if let existing = touchToId[touch] { return existing }
        let new = nextId
        nextId += 1
        touchToId[touch] = new
        return new
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let id = id(for: t)
            let loc = t.location(in: self)
            DispatchQueue.main.async { self.onTouchBegan?(id, loc) }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let id = touchToId[t] else { continue }
            let loc = t.location(in: self)
            DispatchQueue.main.async { self.onTouchMoved?(id, loc) }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let id = touchToId[t] else { continue }
            let loc = t.location(in: self)
            DispatchQueue.main.async { self.onTouchEnded?(id, loc) }
            touchToId[t] = nil
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let id = touchToId[t] else { continue }
            let loc = t.location(in: self)
            DispatchQueue.main.async { self.onTouchEnded?(id, loc) }
            touchToId[t] = nil
        }
    }
}

// SwiftUI wrapper
struct TouchOverlay: UIViewRepresentable {
    var onBegan: (Int, CGPoint) -> Void
    var onMoved: (Int, CGPoint) -> Void
    var onEnded: (Int, CGPoint) -> Void

    func makeUIView(context: Context) -> TouchForwardingView {
        let v = TouchForwardingView()
        v.onTouchBegan = { id, loc in self.onBegan(id, loc) }
        v.onTouchMoved = { id, loc in self.onMoved(id, loc) }
        v.onTouchEnded = { id, loc in self.onEnded(id, loc) }
        return v
    }
    func updateUIView(_ uiView: TouchForwardingView, context: Context) {}
}
