//
//  NoiseSweepView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/03.
//


import SwiftUI

/// NoiseSweepView
/// - Overlay a (tileable) noise image with a short, colored sweep animation at intervals.
/// - It expects an asset in your asset catalog named "NoiseTile" (a small tileable noise texture, grayscale is fine).
///   If you don't have such an asset, you can create one (e.g. 256x256 grayscale noise) and add to Assets.
/// - Configure interval, duration, color shift and blend mode as needed.
///
/// Usage:
/// ZStack {
///   Image("background").resizable()...
///   NoiseSweepView() // put above background
///   // rest of UI...
/// }
public struct NoiseSweepView: View {
    /// how often a sweep is triggered (sec)
    public var interval: TimeInterval = 6.0
    /// sweep animation length (sec)
    public var duration: TimeInterval = 0.9
    /// color tint applied to the noise sweep
    public var tint: Color = Color.white.opacity(0.85)
    /// blend mode to mix with background; .screen/.plusLighter etc. try to see what you like
    public var blendMode: BlendMode = .screen
    /// scale multiplier of the noise layer (1.0 fills, >1.0 larger)
    public var scale: CGFloat = 1.3
    /// edge bleed to allow sweep to slide in/out
    public var horizontalPaddingFactor: CGFloat = 0.2

    @State private var isActive = false
    @State private var showing = false
    @State private var hueShiftDeg: Double = 0
    @State private var timerToken: Timer? = nil

    public init(interval: TimeInterval = 6.0,
                duration: TimeInterval = 0.9,
                tint: Color = Color.white.opacity(0.85),
                blendMode: BlendMode = .screen,
                scale: CGFloat = 1.3) {
        self.interval = interval
        self.duration = duration
        self.tint = tint
        self.blendMode = blendMode
        self.scale = scale
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                if showing {
                    // the noise image is slightly wider than screen and animates its x offset.
                    Image("NoiseTile")
                        .resizable(resizingMode: .tile)
                        .scaledToFill()
                        .frame(width: geo.size.width * scale, height: geo.size.height * 1.05)
                        .clipped()
                        // color variation each sweep (gives the "color push")
                        .hueRotation(.degrees(hueShiftDeg))
                        .colorMultiply(tint)
                        .blendMode(blendMode)
                        .opacity(isActive ? 0.95 : 0.0)
                        // slide across a bit to create 'push' feeling
                        .offset(x: isActive ? geo.size.width * horizontalPaddingFactor : -geo.size.width * horizontalPaddingFactor)
                        .animation(.easeOut(duration: duration), value: isActive)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                // schedule repeating timer
                scheduleTimer()
            }
            .onDisappear {
                timerToken?.invalidate()
                timerToken = nil
            }
        }
        .allowsHitTesting(false)
    }

    private func scheduleTimer() {
        // create initial random delay so multiple runs don't always align
        timerToken?.invalidate()
        timerToken = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            triggerSweep()
        }
        // fire first sweep with a short delay (more natural)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.2...1.0)) {
            triggerSweep()
        }
    }

    private func triggerSweep() {
        // randomize hue slightly each time for color variance
        hueShiftDeg = Double.random(in: -30...30)
        showing = true
        // small delay then animate active -> sweep motion
        DispatchQueue.main.async {
            isActive = false
            // slight delay for a crisp "pop in"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                withAnimation(.easeOut(duration: duration)) {
                    self.isActive = true
                }
            }
            // hide after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.06) {
                withAnimation(.linear(duration: 0.08)) {
                    self.isActive = false
                }
                // small delay to remove the image from view hierarchy (prevents leftovers)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.showing = false
                }
            }
        }
    }
}
