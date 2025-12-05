//
//  LoadingOverlay.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/05.
//


import SwiftUI

/// Lightweight loading overlay you can place over any view.
/// Usage: .overlay(LoadingOverlay(isPresented: $isLoading, progress: loadingProgress))
struct LoadingOverlay: View {
    @Binding var isPresented: Bool
    var message: String = "Loading…"
    var progress: Double? = nil

    var body: some View {
        Group {
            if isPresented {
                ZStack {
                    // dim background
                    Color.black.opacity(0.44)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    // center card
                    VStack(spacing: 12) {
                        if let p = progress {
                            ProgressView(value: p)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 220)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.4)
                        }

                        Text(message)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 12)
                    .transition(.scale.combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.18), value: isPresented)
            }
        }
    }
}