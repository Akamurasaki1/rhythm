//
//  GlitchOverlay.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/03.
//


import SwiftUI

/// GlitchOverlay
/// - Place this view above your background image in the ZStack.
/// - It slices the image horizontally and briefly offsets/colour-shifts some slices to create a "glitch" effect.
/// - Usage: GlitchOverlay(imageName: "title_bg", sliceCount: 8, maxOffset: 48, colorShift: 30, interval: 6.0, duration: 0.28)
public struct GlitchOverlay: View {
    public var imageName: String
    public var sliceCount: Int = 8
    public var maxOffset: CGFloat = 36 // px - how far slices move horizontally
    public var colorShiftDegrees: Double = 50 // hue shift degrees for coloured separation
    public var interval: TimeInterval = 3.0 // seconds between glitch pulses
    public var duration: TimeInterval = 0.28 // how long one glitch pulse lasts
    public var intensity: Double = 0.6 // 0..1 multiplier controlling how many slices glitch each pulse

    public init(imageName: String,
                sliceCount: Int = 8,
                maxOffset: CGFloat = 36,
                colorShiftDegrees: Double = 24,
                interval: TimeInterval = 3.0,
                duration: TimeInterval = 0.28,
                intensity: Double = 0.6) {
        self.imageName = imageName
        self.sliceCount = max(1, sliceCount)
        self.maxOffset = maxOffset
        self.colorShiftDegrees = colorShiftDegrees
        self.interval = interval
        self.duration = duration
        self.intensity = min(1.0, max(0.0, intensity))
    }

    private struct SliceState: Identifiable {
        let id = UUID()
        var offset: CGFloat = 0
        var hue: Double = 0
        var opacity: Double = 1.0
    }

    @State private var slices: [SliceState] = []
    @State private var timer: Timer?

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Each slice is a copy of the background image masked to its horizontal band.
                ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                    // compute y position and height for this slice
                    let sliceH = geo.size.height / CGFloat(sliceCount)
                    let y = CGFloat(idx) * sliceH

                    // The image copy
                    Image(imageName)
                        .resizable(resizingMode: .tile)
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        // horizontal shift applied per-slice
                        .offset(x: slice.offset, y: 0)
                        // color separation / tint
                        .hueRotation(.degrees(slice.hue))
                        // keep compositing local for nicer blend
                        .compositingGroup()
                        .blendMode(.screen)
                        // mask to the slice band
                        .mask(
                            Rectangle()
                                .frame(width: geo.size.width + abs(slice.offset)*2, height: sliceH + 1)
                                .offset(x: 0, y: y)
                        )
                        // place exactly
                        .position(x: geo.size.width/2, y: geo.size.height/2)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear {
                // initialize slices
                slices = (0..<sliceCount).map { _ in SliceState() }
                scheduleTimer()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
        .allowsHitTesting(false)
    }

    // schedules repeating timer
    private func scheduleTimer() {
        timer?.invalidate()
        // small initial jitter so it doesn't always align
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1 ... min(interval, 1.0))) {
            triggerGlitch()
        }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            triggerGlitch()
        }
    }

    // do one glitch pulse: pick some slices, animate them to offsets/hue then back
    private func triggerGlitch() {
        guard !slices.isEmpty else { return }
        // select random subset based on intensity
        let count = slices.count
        let expected = max(1, Int(Double(count) * intensity))
        var indices = Array(0..<count).shuffled().prefix(expected)

        // also add 1-2 random small neighbors to make it feel natural
        if Bool.random() && count > 2 {
            indices.append(Int.random(in: 0..<count))
        }

        // apply random offsets and hue shifts
        for i in indices {
            let sign: CGFloat = Bool.random() ? 1.0 : -1.0
            let offset = sign * CGFloat(Double.random(in: 0.25...1.0)) * maxOffset
            let hue = Double.random(in: -colorShiftDegrees...colorShiftDegrees)
            // immediately set state, then animate back
            withAnimation(.linear(duration: 0)) {
                slices[i].offset = offset
                slices[i].hue = hue
                slices[i].opacity = 1.0
            }
        }

        // animate return to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.02) {
            // animate back with easing so it feels like a snap
            withAnimation(.easeOut(duration: duration)) {
                for i in indices {
                    slices[i].offset = 0
                    slices[i].hue = 0
                    slices[i].opacity = 0.999
                }
            }
        }
    }
}
