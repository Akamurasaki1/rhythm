//
//  FloatingButton.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/03.
//


import SwiftUI

/// Lightweight floating button wrapper you can drop in place of a normal Button.
/// It applies a slow, subtle vertical bob + tiny rotation + shadow change to give a "float" feeling.
/// Usage:
/// FloatingButton(action: { /*...*/ }) {
///     Label("Start", systemImage: "play.fill")
///         .padding(...)
/// }
public struct FloatingButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    @State private var animate = false

    /// amplitude: vertical travel in points
    /// speed: one-way duration in seconds (actual animation is autoreversing)
    public var amplitude: CGFloat = 8
    public var speed: Double = 1.6

    public init(amplitude: CGFloat = 8,
                speed: Double = 1.6,
                action: @escaping () -> Void,
                @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
        self.amplitude = amplitude
        self.speed = speed
    }

    public var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(animate ? 1.02 : 0.995)
        .rotationEffect(.degrees(animate ? 1.4 : -1.4))
        .shadow(color: Color.black.opacity(animate ? 0.28 : 0.18), radius: animate ? 10 : 4, x: 0, y: animate ? 8 : 4)
        .offset(y: animate ? -amplitude : amplitude)
        .animation(.easeInOut(duration: speed).repeatForever(autoreverses: true), value: animate)
        .onAppear { DispatchQueue.main.async { self.animate = true } }
    }
}
