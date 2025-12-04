//
//  CrescentView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/04.
//
import SwiftUI
// MARK: - Crescent shape: outer circle minus inner circle (even-odd fill)
public struct CrescentShape: Shape {
    var innerAngle: CGFloat = .pi
    var innerOffsetFraction: CGFloat = 0.62
    var innerRadiusRatio: CGFloat = 0.62

    public func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2.0
        let innerR = outerR * innerRadiusRatio
        let maxOffset = max(0, outerR - innerR)
        let offset = maxOffset * innerOffsetFraction
        let innerCx = cx + cos(innerAngle) * offset
        let innerCy = cy + sin(innerAngle) * offset

        var p = Path()
        p.addEllipse(in: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
        p.addEllipse(in: CGRect(x: innerCx - innerR, y: innerCy - innerR, width: innerR * 2, height: innerR * 2))
        return p
    }
}


// MARK: - CrescentView
// Visual content for the crescent-shaped control. Does NOT itself handle taps — that's wrapped by FloatingButton.
public struct CrescentView<Content: View>: View {
    var size: CGFloat
    var innerAngle: Angle
    var innerOffsetFraction: CGFloat = 0.62
    var innerRadiusRatio: CGFloat = 0.62
    var gradient: LinearGradient? = nil
    var color: Color? = nil
    var strokeWidth: CGFloat = 4.0
    @ViewBuilder var content: () -> Content

    public var body: some View {
        ZStack {
            // Fill the crescent
            if let g = gradient {
                CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                              innerOffsetFraction: innerOffsetFraction,
                              innerRadiusRatio: innerRadiusRatio)
                    .fill(g, style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: size, height: size)
            } else if let c = color {
                CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                              innerOffsetFraction: innerOffsetFraction,
                              innerRadiusRatio: innerRadiusRatio)
                    .fill(c, style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: size, height: size)
            } else {
                CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                              innerOffsetFraction: innerOffsetFraction,
                              innerRadiusRatio: innerRadiusRatio)
                    .fill(Color.yellow.opacity(0.9), style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: size, height: size)
            }

            // Black outline similar to your sketch: stroke applies to both outer and inner arcs
            CrescentShape(innerAngle: CGFloat(innerAngle.radians),
                          innerOffsetFraction: innerOffsetFraction,
                          innerRadiusRatio: innerRadiusRatio)
                .stroke(Color.black, lineWidth: strokeWidth)
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 2)

            // content (icon + label)
            content()
                .foregroundColor(.black)
                // nudge content slightly toward the visible bulge side so text sits on the crescent area
                .offset(x: (size * 0.12) * cos(innerAngle.radians))
        }
        .frame(width: size, height: size)
        .compositingGroup()
    }
}
