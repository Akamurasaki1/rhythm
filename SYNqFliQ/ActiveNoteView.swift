//
//  ActiveNoteView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/22.
//


import SwiftUI

// A small view that renders one ActiveNote. Keeps the ViewBuilder simpler so the compiler can type-check.
struct ActiveNoteView: View {
    let note: ActiveNote
    let playheadTime: Double
    let canvasSize: CGSize
    // callback passes the DragGesture.Value for flick handling
    var onFlick: ((DragGesture.Value) -> Void)? = nil

    var body: some View {
      /*  VStack(spacing: 8) {
            Text("This is ActiveNoteView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        } */
        // precompute frequently-used values to simplify the view code
        let pos: CGPoint = (note.position == .zero) ? note.targetPosition : note.position
        let pos2: CGPoint = (note.position2 == nil || note.position2 == .zero) ? note.targetPosition : (note.position2 ?? note.targetPosition)

        Group {
            if note.isTap {
                TriangleUp()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray]), startPoint: .top, endPoint: .bottom))
                    .frame(width: 66, height: 33)
                    .position(pos)
                    .zIndex(3)

                TriangleDown()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray]), startPoint: .bottom, endPoint: .top))
                    .frame(width: 66, height: 33)
                    .position(pos2)
                    .zIndex(3)
                    .opacity(note.isClear ? 1.0 : 0.95)
            } else if note.isHold {
                HoldView(size: 64, fillScale: note.holdFillScale, trimProgress: note.holdTrim,
                         ringColor: .black.opacity(0.9),
                         fillColor: note.holdPressedByUser ? Color.green.opacity(0.95) : Color.white.opacity(0.95))
                    .position(note.targetPosition)
                    .zIndex(4)
            } else {
                RodView(angleDegrees: note.angleDegrees)
                    .frame(width: 160, height: 10)
                    .opacity(note.isClear ? 1.0 : 0.35)
                    .position(pos)
                    .zIndex(note.isClear ? 2 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onEnded { value in
                                onFlick?(value)
                            }
                    )
            }
        }
    }
}
